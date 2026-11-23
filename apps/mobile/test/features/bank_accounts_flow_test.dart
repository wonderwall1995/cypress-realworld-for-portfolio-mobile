import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

Future<void> fillAccountForm(
  WidgetTester tester, {
  String bank = 'Test Bank Two',
  String number = '555666777',
}) async {
  await enter(tester, 'bankaccount-bankName-input', bank);
  await enter(tester, 'bankaccount-accountNumber-input', number);
}

/// The "은행 계좌 만들기" screen, from the tab.
Future<void> openNewAccount(WidgetTester tester) async {
  await tapId(tester, 'sidenav-bankaccounts');
  await tapId(tester, 'bankaccount-new');
}

Finder get yellowMenu => byId('sidenav-bankaccounts-warning');

void main() {
  group('a user without a bank account', () {
    testWidgets('is not stopped: home, the tabs, the settings and sign-out work', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);

      expect(byId('nav-transaction-tabs'), findsOneWidget);
      await tapId(tester, 'sidenav-notifications');
      expect(byId('notifications-empty'), findsOneWidget);
      await tapId(tester, 'sidenav-my-account');
      expect(byId('sidenav-user-balance'), findsOneWidget);
      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      expect(byId('signin-submit'), findsOneWidget);
    });

    testWidgets('the 은행 계좌 menu is yellow, without text, until there is an account', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);

      expect(yellowMenu, findsOneWidget);
      final box = tester.widget<Container>(yellowMenu).decoration! as BoxDecoration;
      expect(box.color, const Color(0xFFFFD54F));
      expect(find.text('계좌가 없습니다.'), findsNothing);

      await openNewAccount(tester);
      await fillAccountForm(tester);
      await tapId(tester, 'bankaccount-submit');

      expect(server.bodies['POST /bankAccounts'], {
        'bankName': 'Test Bank Two',
        'accountNumber': '555666777',
      });
      // Back on the list, which has the new account.
      expect(find.text('Test Bank Two'), findsOneWidget);
      expect(yellowMenu, findsNothing);
    });

    testWidgets('the menu still opens its tab when it is yellow', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true));
      await tapId(tester, 'sidenav-bankaccounts');
      expect(find.text('등록된 은행 계좌가 없습니다.'), findsOneWidget);
    });

    testWidgets('a list that cannot be read is not "no account"', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true)..failAccountList = true);

      expect(byId('nav-transaction-tabs'), findsOneWidget);
      expect(yellowMenu, findsNothing);
      await tapId(tester, 'sidenav-bankaccounts');
      expect(byId('bankaccount-load-error'), findsOneWidget);
    });

    testWidgets('it is read once, not again and again', (tester) async {
      final server = FakeServer(signedIn: true)..failAccountList = true;
      await pumpApp(tester, server);
      await tester.pump(const Duration(seconds: 60));
      expect(server.calls.where((c) => c == 'GET /bankAccounts'), hasLength(1));
    });

    testWidgets('only deleted accounts count as none', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true, accounts: [testAccount('b1', isDeleted: true)]));
      expect(yellowMenu, findsOneWidget);
    });

    testWidgets('with an account the menu is not yellow', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true, accounts: [testAccount('b1')]));
      expect(yellowMenu, findsNothing);
    });

    testWidgets('이체 says an account is needed and leads to making one', (tester) async {
      final server = FakeServer(signedIn: true)..users.add(testOtherUser('u2', 'Bob', 'Test'));
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-transfer');
      await tapId(tester, 'user-list-item-u2');

      expect(byId('transaction-create-no-account'), findsOneWidget);
      await tapId(tester, 'transaction-create-make-account');
      await fillAccountForm(tester);
      await tapId(tester, 'bankaccount-submit');

      // Back on the transfer, which has the account now.
      expect(byId('transaction-create-no-account'), findsNothing);
      expect(find.textContaining('Test Bank Two'), findsOneWidget);
    });

    testWidgets('making one can be cancelled', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true));
      await openNewAccount(tester);
      await goBack(tester);
      expect(byId('sidenav-home'), findsOneWidget);
    });
  });

  group('making an account', () {
    testWidgets('a second tap sends nothing', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await openNewAccount(tester);
      await fillAccountForm(tester);
      await tester.tap(byId('bankaccount-submit'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(server.calls.where((c) => c == 'POST /bankAccounts'), hasLength(1));
    });

    testWidgets('leaving while it is on its way closes no other screen', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await openNewAccount(tester);
      await fillAccountForm(tester);
      final hold = Completer<void>();
      server.gate = (key) => key == 'POST /bankAccounts' ? hold.future : null;
      await tester.tap(byId('bankaccount-submit'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.byType(BackButton));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tapId(tester, 'sidenav-more'); // a sheet that must stay open
      hold.complete();
      await tester.pumpAndSettle();

      expect(byId('sidenav-signout'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('60 accounts: cannot make another, and says why', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [for (var i = 0; i < 60; i++) testAccount('b$i')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      expect(find.descendant(of: byId('bankaccount-limit'), matching: find.text('은행 계좌는 최대 60개까지 만들 수 있습니다.')), findsOneWidget);
      final button = tester.widget<TextButton>(find.descendant(of: byId('bankaccount-new'), matching: find.bySubtype<TextButton>()));
      expect(button.onPressed, isNull);
    });

    testWidgets('59 accounts: can', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [for (var i = 0; i < 59; i++) testAccount('b$i')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');
      expect(byId('bankaccount-limit'), findsNothing);
      await tapId(tester, 'bankaccount-new');
      expect(byId('bankaccount-form'), findsOneWidget);
    });

    testWidgets('checks the form with the web rules', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await openNewAccount(tester);

      await tapId(tester, 'bankaccount-submit');
      expect(find.text('은행 이름을 입력하세요.'), findsOneWidget);
      expect(find.text('계좌 번호를 입력하세요.'), findsOneWidget);

      await fillAccountForm(tester, bank: 'Bank', number: '12345678');
      await tapId(tester, 'bankaccount-submit');
      // The bank name has no length rule any more: 'Bank' is accepted.
      expect(find.text('은행 이름은 5자 이상이어야 합니다.'), findsNothing);
      expect(find.text('계좌 번호는 9자리 이상이어야 합니다.'), findsOneWidget);

      await fillAccountForm(tester, number: '1234567890123');
      await tapId(tester, 'bankaccount-submit');
      expect(find.text('계좌 번호는 12자리 이하여야 합니다.'), findsOneWidget);

      expect(server.calls, isNot(contains('POST /bankAccounts')));
    });

    testWidgets('the account number must be digits only', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await openNewAccount(tester);

      // The right length, but letters: this passed before the digit check.
      await fillAccountForm(tester, number: 'abcdefghij');
      await tapId(tester, 'bankaccount-submit');
      expect(find.text('계좌 번호는 숫자만 입력하세요.'), findsOneWidget);

      // A space or a sign in the middle is not a digit either.
      await fillAccountForm(tester, number: '-12345678');
      await tapId(tester, 'bankaccount-submit');
      expect(find.text('계좌 번호는 숫자만 입력하세요.'), findsOneWidget);

      expect(server.calls, isNot(contains('POST /bankAccounts')));
    });

    testWidgets('the list shows the money in each account when the server sends it', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [
        testAccount('b1', bank: 'Rich Bank', balance: 123456),
        testAccount('b2', bank: 'Plain Bank'),
      ]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      expect(find.descendant(of: byId('bankaccount-balance-b1'), matching: find.text('잔액 \$1,234.56')), findsOneWidget);
      expect(find.descendant(of: byId('bankaccount-account-number-b2'), matching: find.text('계좌 번호 ····6789')), findsOneWidget);
      expect(byId('bankaccount-balance-b2'), findsNothing); // not sent: not guessed
    });

    testWidgets('there is no routing number field, and none is sent', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await openNewAccount(tester);

      expect(byId('bankaccount-routingNumber-input'), findsNothing);
      expect(find.text('라우팅 번호'), findsNothing);

      await fillAccountForm(tester);
      await tapId(tester, 'bankaccount-submit');

      expect((server.bodies['POST /bankAccounts'] as Map).containsKey('routingNumber'), isFalse);
    });

    testWidgets('a short bank name is saved (there is no minimum length)', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await openNewAccount(tester);

      await fillAccountForm(tester, bank: 'K');
      await tapId(tester, 'bankaccount-submit');

      expect(server.bodies['POST /bankAccounts'], containsPair('bankName', 'K'));
    });

    testWidgets('an empty bank name is still refused', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await openNewAccount(tester);

      await fillAccountForm(tester, bank: '   ');
      await tapId(tester, 'bankaccount-submit');

      expect(find.text('은행 이름을 입력하세요.'), findsOneWidget);
      expect(server.calls, isNot(contains('POST /bankAccounts')));
    });

    testWidgets('the account number rule is shown as a hint inside the field', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true));
      await openNewAccount(tester);

      String? hintOf(String id) => tester
          .widget<TextField>(find.descendant(of: byId(id), matching: find.byType(TextField)))
          .decoration!
          .hintText;
      expect(hintOf('bankaccount-accountNumber-input'), '9~12자리 숫자');
      expect(hintOf('bankaccount-bankName-input'), isNull);
      // The hint is visible without focusing the field.
      final account = tester.widget<TextField>(find.descendant(of: byId('bankaccount-accountNumber-input'), matching: find.byType(TextField)));
      expect(account.decoration!.floatingLabelBehavior, FloatingLabelBehavior.always);
    });

    testWidgets('the form warns not to enter a real account', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true));
      await openNewAccount(tester);

      expect(
        find.descendant(of: byId('bankaccount-demo-warning'), matching: find.text('진짜 자신의 계좌를 만들진 말아주세요! 이건 데모 앱입니다.')),
        findsOneWidget,
      );
    });

    testWidgets('the same warning is on the add-account screen', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true, accounts: [testAccount('b1')]));
      await tapId(tester, 'sidenav-bankaccounts');
      await tapId(tester, 'bankaccount-new');

      expect(
        find.descendant(of: byId('bankaccount-demo-warning'), matching: find.text('진짜 자신의 계좌를 만들진 말아주세요! 이건 데모 앱입니다.')),
        findsOneWidget,
      );
    });

    testWidgets('a server refusal shows an error and stays on the form', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true)..failAccountCreate = true);
      await openNewAccount(tester);

      await fillAccountForm(tester);
      await tapId(tester, 'bankaccount-submit');

      expect(byId('bankaccount-error'), findsOneWidget);
      expect(byId('bankaccount-form'), findsOneWidget);
    });
  });

  group('bank account tab', () {
    FakeServer twoAccounts() => FakeServer(
          signedIn: true,
          accounts: [
            testAccount('b1', bank: 'First Test Bank', number: '111122223333'),
            testAccount('b2', bank: 'Second Test Bank', number: '444455556666'),
          ],
        );

    testWidgets('the next user does not see the previous user\'s accounts', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [testAccount('a1', bank: 'Old Test Bank')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');
      expect(find.text('Old Test Bank'), findsOneWidget);

      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      server.accounts
        ..clear()
        ..add(testAccount('b1', bank: 'New Test Bank'));
      await enter(tester, 'signin-username', 'someone');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');
      await tapId(tester, 'sidenav-bankaccounts');

      expect(find.text('New Test Bank'), findsOneWidget);
      expect(find.text('Old Test Bank'), findsNothing);
    });

    testWidgets('lists the accounts with the last 4 digits only', (tester) async {
      await pumpApp(tester, twoAccounts());
      await tapId(tester, 'sidenav-bankaccounts');

      expect(byId('bankaccount-list'), findsOneWidget);
      expect(byId('bankaccount-list-item-b1'), findsOneWidget);
      expect(byId('bankaccount-list-item-b2'), findsOneWidget);
      expect(find.text('First Test Bank'), findsOneWidget);
      expect(find.text('계좌 번호 ····3333'), findsOneWidget);
      expect(find.textContaining('111122223333'), findsNothing);
    });

    testWidgets('does not show deleted accounts, also after loading again', (tester) async {
      final server = FakeServer(
        signedIn: true,
        accounts: [
          testAccount('b1', bank: 'Live Test Bank'),
          testAccount('b2', bank: 'Gone Test Bank', isDeleted: true),
        ],
      );
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      expect(byId('bankaccount-list-item-b1'), findsOneWidget);
      expect(byId('bankaccount-list-item-b2'), findsNothing);
      expect(find.text('Gone Test Bank'), findsNothing);

      // Delete the live one, then load the list again from the server. The
      // server still returns both (both are marked deleted now).
      await tester.tap(byId('bankaccount-delete'));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');
      expect(server.accounts, hasLength(2));
      expect(find.text('Live Test Bank'), findsNothing);
      expect(find.text('Gone Test Bank'), findsNothing);
    });

    testWidgets('delete asks first; cancel keeps the account', (tester) async {
      final server = twoAccounts();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      await tester.tap(find.descendant(of: byId('bankaccount-list-item-b1'), matching: byId('bankaccount-delete')));
      await tester.pumpAndSettle();
      expect(find.text('"First Test Bank" 계좌를 삭제하시겠습니까?'), findsOneWidget);
      expect(server.calls, isNot(contains('DELETE /bankAccounts/b1')));

      await tapId(tester, 'bankaccount-delete-cancel');

      expect(byId('bankaccount-list-item-b1'), findsOneWidget);
      expect(server.calls, isNot(contains('DELETE /bankAccounts/b1')));
    });

    testWidgets('delete after confirm removes the account', (tester) async {
      final server = twoAccounts();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      await tester.tap(find.descendant(of: byId('bankaccount-list-item-b1'), matching: byId('bankaccount-delete')));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      expect(server.calls, contains('DELETE /bankAccounts/b1'));
      expect(byId('bankaccount-list-item-b1'), findsNothing);
      expect(byId('bankaccount-list-item-b2'), findsOneWidget);
    });

    testWidgets('the last account can be deleted and the app goes on', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [testAccount('b1')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      await tester.tap(byId('bankaccount-delete'));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      expect(server.activeAccounts, isEmpty);
      expect(find.text('등록된 은행 계좌가 없습니다.'), findsOneWidget);
      expect(yellowMenu, findsOneWidget);
      await tapId(tester, 'sidenav-home');
      expect(byId('nav-transaction-tabs'), findsOneWidget);
    });

    testWidgets('an account already deleted somewhere else goes away, with the reason', (tester) async {
      final server = twoAccounts()
        ..accountDeleteStatus = 404
        ..accountDeleteMessage = 'bank account not found';
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');
      server.accounts.removeWhere((a) => a['id'] == 'b1');

      await tester.tap(find.descendant(of: byId('bankaccount-list-item-b1'), matching: byId('bankaccount-delete')));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      expect(find.text('은행 계좌를 찾을 수 없습니다'), findsOneWidget);
      expect(byId('bankaccount-list-item-b1'), findsNothing);

      // Opening the tab again clears the old reason.
      await tapId(tester, 'sidenav-home');
      await tapId(tester, 'sidenav-bankaccounts');
      expect(byId('bankaccount-notice'), findsNothing);
    });

    testWidgets('a failed delete keeps the account and tells the user', (tester) async {
      final server = twoAccounts()..failAccountDelete = true;
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      await tester.tap(find.descendant(of: byId('bankaccount-list-item-b1'), matching: byId('bankaccount-delete')));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      // The account stays, and the reason is above the list (not a snack bar).
      expect(byId('bankaccount-list-item-b1'), findsOneWidget);
      expect(find.descendant(of: byId('bankaccount-notice'), matching: find.text('응답을 받지 못해 처리 결과를 확인할 수 없습니다.')), findsOneWidget);
      expect(tester.getRect(byId('bankaccount-notice')).bottom, lessThanOrEqualTo(tester.getRect(byId('bankaccount-list')).top));
      expect(byId('alert-bar-error'), findsNothing);
    });

    testWidgets('create adds an account and returns to the list', (tester) async {
      final server = twoAccounts();
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      await tapId(tester, 'bankaccount-new');
      expect(byId('bankaccount-form'), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing); // a full screen, no tab bar

      await fillAccountForm(tester, bank: 'Third Test Bank');
      await tapId(tester, 'bankaccount-submit');

      expect(byId('bankaccount-form'), findsNothing);
      expect(find.text('Third Test Bank'), findsOneWidget);
      expect(byId('alert-bar-success'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
    });

    testWidgets('retry loads the list again', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [testAccount('b1')])
        ..failAccountList = true;
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');
      expect(byId('bankaccount-load-error'), findsOneWidget);

      server.failAccountList = false;
      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(byId('bankaccount-load-error'), findsNothing);
      expect(byId('bankaccount-list-item-b1'), findsOneWidget);
    });
  });
  group('the newer server answer (visible instead of isDeleted)', () {
    Map<String, dynamic> newShape(String id, {String bank = 'New Shape Bank', bool visible = true}) => {
          'id': id,
          'bankName': bank,
          'accountNumber': '123456789',
          'visible': visible,
        };

    testWidgets('the list shows such accounts and hides the ones with visible: false', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [newShape('n1'), newShape('n2', bank: 'Hidden Bank', visible: false)]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      expect(find.text('New Shape Bank'), findsOneWidget);
      expect(find.text('Hidden Bank'), findsNothing);
    });
  });
}
