import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';
import '../support/transfer_helpers.dart';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])
  ..balance = 20000
  ..users.add(testOtherUser('u2', 'Bob', 'Test'))
  ..everyone.add(testTransaction('t1', description: 'Dinner'));

const expiredText = '로그인이 만료되었습니다. 다시 로그인해 주세요.';

void main() {
  group('the server forgot the session', () {
    testWidgets('opening a tab goes to the sign-in screen, which says why', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      server.sessionLost = true;
      await tapId(tester, 'sidenav-bankaccounts');

      expect(byId('signin-submit'), findsOneWidget);
      expect(find.text(expiredText), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);
    });

    testWidgets('the 내 계좌 tab too (checkAuth says nobody is signed in)', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      server.signedIn = false;
      await tapId(tester, 'sidenav-my-account');

      expect(find.text(expiredText), findsOneWidget);
    });

    testWidgets('a deposit in progress is closed and not sent again after signing in', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-deposit');
      await enter(tester, 'deposit-amount-input', '5');

      server.sessionLost = true;
      await tapId(tester, 'deposit-submit-button');
      expect(find.text(expiredText), findsOneWidget);
      expect(byId('deposit-dialog'), findsNothing);

      await enter(tester, 'signin-username', 'tester');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');

      expect(byId('nav-transaction-tabs'), findsOneWidget);
      expect(server.calls.where((c) => c == 'POST /bankTransfers'), hasLength(1));
      expect(server.transfers, isEmpty);
    });

    testWidgets('a transfer in progress: the password dialog is closed', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-transfer');
      await tapId(tester, 'user-list-item-u2');
      await enter(tester, 'transaction-create-amount-input', '5');
      await enter(tester, 'transaction-create-description-input', 'x');
      await tester.pump();
      await tapId(tester, 'transaction-create-submit-payment');

      server.sessionLost = true;
      await confirmTransfer(tester);

      expect(find.text(expiredText), findsOneWidget);
      expect(find.text('정말 이체하겠습니까?'), findsNothing);
    });

    testWidgets('a wrong sign-in is not "expired"', (tester) async {
      final server = FakeServer()..loginOk = false;
      await pumpApp(tester, server);
      await enter(tester, 'signin-username', 'tester');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');

      expect(find.text(expiredText), findsNothing);
      expect(byId('signin-error'), findsOneWidget);
    });

    testWidgets('signing out by hand does not say "expired"', (tester) async {
      await pumpApp(tester, newServer());
      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');

      expect(byId('signin-submit'), findsOneWidget);
      expect(byId('signin-error'), findsNothing);
    });
  });

  group('while the server is started again', () {
    testWidgets('using the app does not sign out, and goes on afterwards', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      server.restarting = true;
      await tapId(tester, 'sidenav-bankaccounts');
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-notifications');
      expect(byId('signin-submit'), findsNothing);
      expect(byId('sidenav-home'), findsOneWidget);

      server.restarting = false;
      await tapId(tester, 'sidenav-bankaccounts');
      expect(find.text('First Bank'), findsOneWidget);
    });

    testWidgets('opening the app offers to ask again; the saved sign-in is kept', (tester) async {
      final server = newServer()..restarting = true;
      await pumpApp(tester, server);
      expect(byId('offline'), findsOneWidget);
      expect(byId('signin-submit'), findsNothing);

      server.restarting = false;
      await tapId(tester, 'offline-retry');
      expect(byId('nav-transaction-tabs'), findsOneWidget);
    });

    testWidgets('a transfer in that moment is of unknown result, not failed', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-deposit');
      await enter(tester, 'deposit-amount-input', '5');
      server.restarting = true;
      await tapId(tester, 'deposit-submit-button');
      expect(find.text('응답을 받지 못해 처리 결과를 확인할 수 없습니다.'), findsOneWidget);
      expect(find.textContaining('502'), findsNothing);
    });
  });

  testWidgets('a late answer for user A does not show up for user B', (tester) async {
    final server = newServer();
    await pumpApp(tester, server);

    // A opens the bank accounts; the answer is held back.
    final hold = Completer<void>();
    server.gate = (key) => key == 'GET /bankAccounts' ? hold.future : null;
    await tester.tap(byId('sidenav-bankaccounts'));
    await tester.pumpAndSettle();
    expect(server.calls.last, 'GET /bankAccounts');

    // A signs out, B signs in with another account.
    server.gate = null;
    await tapId(tester, 'sidenav-more');
    await tapId(tester, 'sidenav-signout');
    server.accounts
      ..clear()
      ..add(testAccount('b9', bank: 'Bank of B'));
    server.profile['id'] = 'u9';
    await enter(tester, 'signin-username', 'bbb');
    await enter(tester, 'signin-password', 'pw-1234');
    await tapId(tester, 'signin-submit');
    await tapId(tester, 'sidenav-bankaccounts');
    expect(find.text('Bank of B'), findsOneWidget);

    hold.complete();
    await tester.pumpAndSettle();

    expect(find.text('Bank of B'), findsOneWidget);
    expect(find.text('First Bank'), findsNothing);
  });

  testWidgets('an answer that cannot be read shows the retry screen, not a crash', (tester) async {
    final server = newServer()..strangeAnswer.add('GET /transactions/public');
    await pumpApp(tester, server);

    expect(tester.takeException(), isNull);
    expect(byId('transaction-list-load-error'), findsOneWidget);
  });
}
