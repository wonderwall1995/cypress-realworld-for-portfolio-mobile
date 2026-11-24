import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../transactions/transaction.dart' show formatUsd;
import 'simulation_case.dart';
import 'simulation_driver.dart';
import 'simulation_fixtures.dart';
import 'simulation_run.dart';

part 'simulation_auth_cases.dart';
part 'simulation_money_cases.dart';
part 'simulation_transaction_cases.dart';

class _Person {
  _Person(this.api, this.actor, {String passwordPrefix = ''}) {
    username = SimulationFixtures.korean(3);
    password = '$passwordPrefix${SimulationFixtures.digits(4)}';
    phone = SimulationFixtures.phone();
    firstName = SimulationFixtures.english(6);
    lastName = SimulationFixtures.english(6);
  }
  final ApiClient api;
  final String actor;
  late final String username;
  late final String password;
  late final String phone;
  late final String firstName;
  late final String lastName;
  Map<String, dynamic> user = {};
  Map<String, dynamic> account = {};
  String get id => user['id'] as String;
  String get accountId => account['id'] as String;
  String get name => '$lastName $firstName';
  Map<String, dynamic> get profile => {
    'lastName': lastName,
    'firstName': firstName,
    'email': '',
    'phoneNumber': phone,
  };
}

/// Native counterparts of tests/e2e/000..009. PC-only checks are explicitly
/// omitted. Fixture calls use separate, memory-only sessions for each person.
class SimulationScenarios {
  SimulationScenarios({
    required this.api,
    required this.session,
    required this.router,
    required this.ui,
    required this.run,
    ApiClient Function()? clientFactory,
  }) : _clientFactory =
           clientFactory ??
           (() => ApiClient(
             baseUrl: api.dio.options.baseUrl,
             cookieJar: CookieJar(),
           ));

  final ApiClient api;
  final SessionController session;
  final GoRouter router;
  final SimulationDriver ui;
  final SimulationRun run;
  final ApiClient Function() _clientFactory;
  final _people = <_Person>[];
  static const maxDollars = 21474836;

  Future<T> _call<T>(Future<T> Function() action) async {
    await run.checkpoint();
    final result = await action();
    await run.checkpoint();
    return result;
  }

  void _check(bool value) {
    if (!value) throw StateError('Simulation expectation did not match');
  }

  Future<void> _status(
    _Person person,
    String method,
    String path,
    int expected, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final answer = await _call(
      () => person.api.dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, validateStatus: (_) => true),
      ),
    );
    _check(answer.statusCode == expected);
  }

  Future<void> execute(SimulationCase selected) async {
    try {
      await ui.waitFor('signin-username');
      switch (selected) {
        case SimulationCase.auth:
          await auth();
        case SimulationCase.bankAccount:
          await bankAccount();
        case SimulationCase.deposit:
          await deposit();
        case SimulationCase.transfer:
          await transfer();
        case SimulationCase.detail:
          await detail();
        case SimulationCase.filter:
          await filter();
        case SimulationCase.settings:
          await settings();
        case SimulationCase.visibility:
          await visibility();
        case SimulationCase.notifications:
          await notifications();
        case SimulationCase.loginLogout:
          await loginLogout();
      }
    } finally {
      // Like spec afterEach: only accounts owned by this run are cleaned up.
      // Users and transaction history remain. This also runs after cancellation.
      for (final person in _people) {
        try {
          if (person.user.isNotEmpty) {
            await person.api.dio.delete<Object>('/demo/bankaccounts');
          }
        } catch (_) {
          run.cleanupWarning = true;
        } finally {
          try {
            await person.api.logout();
          } catch (_) {
            /* local cookies are cleared */
          }
          person.api.dio.close();
        }
      }
    }
  }

  _Person _person(String tag, {String passwordPrefix = ''}) {
    final value = _Person(
      _clientFactory(),
      tag,
      passwordPrefix: passwordPrefix,
    );
    _people.add(value);
    return value;
  }

  Future<_Person> _prepare(
    String tag, {
    int? dollars,
    bool bank = true,
    String passwordPrefix = '',
  }) async {
    final p = _person(tag, passwordPrefix: passwordPrefix);
    await _call(
      () => p.api.signUp(
        firstName: p.firstName,
        lastName: p.lastName,
        username: p.username,
        password: p.password,
        phoneNumber: p.phone,
      ),
    );
    p.user = await _call(
      () => p.api.login(
        username: p.username,
        password: p.password,
        remember: false,
      ),
    );
    if (bank) {
      p.account = await _newAccount(p);
      if (dollars != null) {
        await _call(
          () => p.api.moveMoney(
            bankAccountId: p.accountId,
            amount: dollars,
            type: 'deposit',
          ),
        );
      }
    }
    return p;
  }

  Future<Map<String, dynamic>> _newAccount(_Person p, {int? sequence}) {
    final fixture = SimulationFixtures.account(sequence: sequence);
    return _call(
      () => p.api.createBankAccount(
        bankName: fixture['bankName']!,
        accountNumber: fixture['accountNumber']!,
      ),
    );
  }

  Future<void> _signIn(
    _Person p, {
    String? password,
    String? username,
    bool success = true,
  }) async {
    await ui.enter('signin-username', username ?? p.username);
    await ui.enter('signin-password', password ?? p.password);
    await ui.tap('signin-submit');
    if (success) await ui.waitFor('sidenav-home');
  }

  Future<void> _signOut() async {
    await ui.tap('sidenav-more');
    await ui.tap('sidenav-signout');
    await ui.waitFor('signin-username');
    await ui.gone('sidenav-home');
  }

  Future<void> _banks() => ui.tap('sidenav-bankaccounts');

  Future<void> _balance(_Person p, int cents) async {
    final accounts = await _call(p.api.getBankAccounts);
    final me = await _call(p.api.checkAuth);
    _check(
      accounts.fold<int>(0, (sum, a) => sum + (a['balance'] as num).toInt()) ==
          cents,
    );
    _check(me?['balance'] == cents);
    await ui.tap('sidenav-my-account');
    await ui.expectText('sidenav-user-balance', formatUsd(cents));
  }

  Future<void> _go(String route) async {
    await run.checkpoint();
    router.go(route);
    await run.delay(const Duration(milliseconds: 400));
  }

  Future<Map<String, dynamic>> _send(
    _Person from,
    _Person to,
    int dollars, {
    String privacy = 'public',
    String memo = '시연 이체',
  }) => _call(
    () => from.api.createTransaction(
      receiverId: to.id,
      description: memo,
      amount: dollars,
      myAccountId: from.accountId,
      otherAccountId: to.accountId,
      password: from.password,
      privacyLevel: privacy,
    ),
  );

  Map<String, dynamic> _payment(
    _Person from,
    _Person to,
    Object amount, {
    String? password,
  }) => {
    'transactionType': 'payment',
    'amount': amount,
    'description': '시연 거절 시험',
    'receiverId': to.id,
    'myAccountId': from.accountId,
    'otherAccountId': to.accountId,
    'password': password ?? from.password,
  };

  Future<List<Map<String, dynamic>>> _mine(_Person p) async => (await _call(
    () => p.api.getTransactions('/transactions', page: 1, limit: 100),
  )).results;

  Future<void> _clearAccounts(_Person p) async {
    await _call(() => p.api.dio.delete<Object>('/demo/bankaccounts'));
    _check((await _call(p.api.getBankAccounts)).isEmpty);
  }

  Future<void> _row(String id) => ui.show('transaction-item-$id');

  Future<void> _myTransactions() async {
    await ui.tap('sidenav-home');
    await ui.tap('nav-personal-tab');
  }
}
