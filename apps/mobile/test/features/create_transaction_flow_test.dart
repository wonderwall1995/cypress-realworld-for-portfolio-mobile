import 'package:cypress_realworld_for_personal_portfolio_mobile/app.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// A signed-in user ($100.00) with a bank account and two other users.
FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')])
  ..balance = 10000
  ..users.addAll([
    testOtherUser('u2', 'Bob', 'Test', username: 'bob'),
    testOtherUser('u3', 'Cara', 'Test', username: 'cara'),
  ]);

Future<void> openCreate(WidgetTester tester) => tapId(tester, 'nav-top-new-transaction');

Future<void> fillForm(WidgetTester tester, {String amount = '25', String note = 'Lunch'}) async {
  await enter(tester, 'transaction-create-amount-input', amount);
  await enter(tester, 'transaction-create-description-input', note);
}

/// Types in the search box and lets the 200 ms wait pass.
Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(of: byId('user-list-search-input'), matching: find.byType(TextField)),
    text,
  );
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void main() {
  group('entry points', () {
    testWidgets('home has a 새 거래 button to the left of the tabs', (tester) async {
      await pumpApp(tester, newServer());

      expect(byId('nav-top-new-transaction'), findsOneWidget);
      final button = tester.getTopLeft(byId('nav-top-new-transaction'));
      final tabs = tester.getTopLeft(byId('nav-transaction-tabs'));
      expect(button.dx, lessThan(tabs.dx));
      // The tabs still work next to it.
      await tapId(tester, 'nav-contacts-tab');
      expect(byId('transaction-list-empty'), findsOneWidget);
    });

    testWidgets('an empty list has a button to create a transaction', (tester) async {
      await pumpApp(tester, newServer());

      await tapId(tester, 'transaction-list-empty-create-transaction-button');

      expect(byId('transaction-create-steps'), findsOneWidget);
    });
  });

  group('step 1: choose a user', () {
    testWidgets('lists the other users', (tester) async {
      await pumpApp(tester, newServer());
      await openCreate(tester);

      expect(find.text('새 거래'), findsWidgets);
      expect(byId('user-list-item-u2'), findsOneWidget);
      expect(byId('user-list-item-u3'), findsOneWidget);
      expect(find.text('Bob Test'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      // The tab bar is not shown on this full screen.
      expect(byId('sidenav-home'), findsNothing);
    });

    testWidgets('search narrows the list (after a short wait)', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openCreate(tester);

      await search(tester, 'cara');

      expect(server.userQueries, ['', 'cara']);
      expect(byId('user-list-item-u3'), findsOneWidget);
      expect(byId('user-list-item-u2'), findsNothing);
    });

    testWidgets('typing fast sends only one search', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openCreate(tester);

      final field = find.descendant(of: byId('user-list-search-input'), matching: find.byType(TextField));
      await tester.enterText(field, 'c');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'ca');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'car');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(server.userQueries, ['', 'car']);
    });

    testWidgets('no match says so', (tester) async {
      await pumpApp(tester, newServer());
      await openCreate(tester);

      await search(tester, 'zzz');

      expect(byId('user-list-empty'), findsOneWidget);
      expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    });

    testWidgets('a failed load shows an error with retry', (tester) async {
      final server = newServer()..failUsers = true;
      await pumpApp(tester, server);
      await openCreate(tester);

      expect(byId('user-list-error'), findsOneWidget);

      server.failUsers = false;
      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(byId('user-list-item-u2'), findsOneWidget);
    });
  });

  group('step 2: amount and note', () {
    Future<void> toStep2(WidgetTester tester, FakeServer server) async {
      await pumpApp(tester, server);
      await openCreate(tester);
      await tapId(tester, 'user-list-item-u2');
    }

    testWidgets('shows the chosen user and the form', (tester) async {
      await toStep2(tester, newServer());

      expect(byId('transaction-create-form'), findsOneWidget);
      expect(find.descendant(of: byId('transaction-create-receiver-name'), matching: find.text('Bob Test')), findsOneWidget);
      expect(byId('transaction-create-submit-payment'), findsOneWidget);
      expect(byId('transaction-create-submit-request'), findsOneWidget);
    });

    testWidgets('checks the form before sending', (tester) async {
      final server = newServer();
      await toStep2(tester, server);

      await tapId(tester, 'transaction-create-submit-payment');
      expect(find.text('금액을 입력하세요.'), findsOneWidget);
      expect(find.text('메모를 입력하세요.'), findsOneWidget);

      await fillForm(tester, amount: '0');
      await tapId(tester, 'transaction-create-submit-payment');
      expect(find.text('금액은 1달러 이상이어야 합니다.'), findsOneWidget);

      await fillForm(tester, amount: '12.5');
      await tapId(tester, 'transaction-create-submit-payment');
      expect(find.textContaining('숫자로 입력하세요'), findsOneWidget);

      await fillForm(tester, amount: '10000000');
      await tapId(tester, 'transaction-create-submit-payment');
      expect(find.textContaining('9999999달러 이하'), findsOneWidget);

      expect(server.calls, isNot(contains('POST /transactions')));
    });

    testWidgets('Back goes to step 1, not out of the screen', (tester) async {
      await toStep2(tester, newServer());

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(byId('user-list-item-u2'), findsOneWidget);
      expect(byId('transaction-create-form'), findsNothing);
    });

    testWidgets('a refusal shows an error and stays on the form', (tester) async {
      final server = newServer()..createTransactionStatus = 500;
      await toStep2(tester, server);

      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-payment');

      expect(byId('transaction-create-error'), findsOneWidget);
      expect(find.text('결제하지 못했습니다. 입력한 내용을 확인해 주세요.'), findsOneWidget);
      expect(byId('transaction-create-form'), findsOneWidget);
    });

    testWidgets('a failed request says 요청, not 결제', (tester) async {
      final server = newServer()..createTransactionStatus = 500;
      await toStep2(tester, server);

      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-request');

      expect(find.text('요청하지 못했습니다. 입력한 내용을 확인해 주세요.'), findsOneWidget);
    });
  });

  group('step 3: done', () {
    testWidgets('a payment is sent, shown, and changes the balance', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openCreate(tester);
      await tapId(tester, 'user-list-item-u2');

      await fillForm(tester, amount: '25', note: 'Lunch');
      await tapId(tester, 'transaction-create-submit-payment');

      expect(server.bodies['POST /transactions'], {
        'transactionType': 'payment',
        'receiverId': 'u2',
        'description': 'Lunch',
        'amount': 25,
      });
      expect(find.text('결제 완료'), findsOneWidget);
      expect(find.text('Bob Test님에게 \$25.00를 결제했습니다.'), findsOneWidget);
      expect(find.text('메모: Lunch'), findsOneWidget);

      // The app already knows the new balance, before the 내 계좌 tab is opened.
      final container = ProviderScope.containerOf(tester.element(find.byType(App)));
      expect(container.read(sessionProvider).user!['balance'], 7500);

      await tapId(tester, 'new-transaction-return-to-transactions');
      expect(byId('nav-transaction-tabs'), findsOneWidget);

      // The balance is new: $100.00 - $25.00
      await tapId(tester, 'sidenav-my-account');
      expect(find.descendant(of: byId('sidenav-user-balance'), matching: find.text('\$75.00')), findsOneWidget);
    });

    testWidgets('a request is sent as a request', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openCreate(tester);
      await tapId(tester, 'user-list-item-u3');

      await fillForm(tester, amount: '8', note: 'Coffee');
      await tapId(tester, 'transaction-create-submit-request');

      expect((server.bodies['POST /transactions'] as Map)['transactionType'], 'request');
      expect(find.text('요청 완료'), findsOneWidget);
      expect(find.text('Cara Test님에게 \$8.00를 요청했습니다.'), findsOneWidget);
    });

    testWidgets('the new transaction shows in the 내 거래 list after returning', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openCreate(tester);
      await tapId(tester, 'user-list-item-u2');
      await fillForm(tester, amount: '25', note: 'Lunch');
      await tapId(tester, 'transaction-create-submit-payment');
      await tapId(tester, 'new-transaction-return-to-transactions');

      await tapId(tester, 'nav-personal-tab');

      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('"다른 거래 만들기" starts again at step 1', (tester) async {
      await pumpApp(tester, newServer());
      await openCreate(tester);
      await tapId(tester, 'user-list-item-u2');
      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-payment');

      await tapId(tester, 'new-transaction-create-another-transaction');

      expect(byId('user-list-item-u2'), findsOneWidget);
      expect(byId('transaction-create-result'), findsNothing);
    });

    testWidgets('opening the screen again starts at step 1', (tester) async {
      await pumpApp(tester, newServer());
      await openCreate(tester);
      await tapId(tester, 'user-list-item-u2');
      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-payment');
      await tapId(tester, 'new-transaction-return-to-transactions');

      await openCreate(tester);

      expect(byId('user-list-item-u2'), findsOneWidget);
      expect(byId('transaction-create-result'), findsNothing);
    });
  });

  group('내 계좌 tab and the ... menu', () {
    testWidgets('the 4th tab is 내 계좌 and shows the balance', (tester) async {
      await pumpApp(tester, newServer());

      expect(find.text('내 계좌'), findsWidgets);
      expect(find.text('설정'), findsNothing);

      await tapId(tester, 'sidenav-my-account');

      expect(find.descendant(of: byId('sidenav-user-balance'), matching: find.text('\$100.00')), findsOneWidget);
      expect(find.text('내 계좌 잔액'), findsOneWidget);
      expect(find.descendant(of: byId('my-account-full-name'), matching: find.text('Ada Kim')), findsOneWidget);
      expect(find.descendant(of: byId('my-account-username'), matching: find.text('@tester')), findsOneWidget);
    });

    testWidgets('opening the tab loads the balance again', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      server.balance = 4250; // changed on the server
      await tapId(tester, 'sidenav-my-account');

      expect(find.descendant(of: byId('sidenav-user-balance'), matching: find.text('\$42.50')), findsOneWidget);
    });

    testWidgets('pulling down on 내 계좌 loads the balance again', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-my-account');

      server.balance = 777;
      await tester.drag(find.byType(ListView).last, const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.descendant(of: byId('sidenav-user-balance'), matching: find.text('\$7.77')), findsOneWidget);
    });

    testWidgets('settings is in the ... menu', (tester) async {
      await pumpApp(tester, newServer());

      await tapId(tester, 'sidenav-more');
      expect(byId('sidenav-user-settings'), findsOneWidget);
      expect(byId('sidenav-signout'), findsOneWidget);

      await tapId(tester, 'sidenav-user-settings');

      expect(find.text('설정 화면'), findsOneWidget);
    });
  });
}
