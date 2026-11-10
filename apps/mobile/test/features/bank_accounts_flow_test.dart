import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

Future<void> fillAccountForm(
  WidgetTester tester, {
  String bank = 'Test Bank Two',
  String routing = '111222333',
  String number = '555666777',
}) async {
  await enter(tester, 'bankaccount-bankName-input', bank);
  await enter(tester, 'bankaccount-routingNumber-input', routing);
  await enter(tester, 'bankaccount-accountNumber-input', number);
}

void main() {
  group('first-time setup (no bank account)', () {
    testWidgets('is shown after sign-in and walks through 3 steps', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);

      // Step 1: welcome
      expect(byId('user-onboarding-dialog'), findsOneWidget);
      expect(find.descendant(of: byId('user-onboarding-dialog-title'), matching: find.text('시작하기')), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);

      await tapId(tester, 'user-onboarding-next');

      // Step 2: create the account. There is no "next" button here.
      expect(find.descendant(of: byId('user-onboarding-dialog-title'), matching: find.text('은행 계좌 만들기')), findsOneWidget);
      expect(byId('bankaccount-form'), findsOneWidget);
      expect(byId('user-onboarding-next'), findsNothing);

      await fillAccountForm(tester);
      await tapId(tester, 'bankaccount-submit');

      expect(server.bodies['POST /bankAccounts'], {
        'bankName': 'Test Bank Two',
        'routingNumber': '111222333',
        'accountNumber': '555666777',
      });

      // Step 3: finished
      expect(find.descendant(of: byId('user-onboarding-dialog-title'), matching: find.text('완료')), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);

      await tapId(tester, 'user-onboarding-next');

      // Home, with the new account in the list
      expect(byId('user-onboarding-dialog'), findsNothing);
      expect(byId('nav-transaction-tabs'), findsOneWidget);
      await tapId(tester, 'sidenav-bankaccounts');
      expect(find.text('Test Bank Two'), findsOneWidget);
    });

    testWidgets('checks the form with the web rules', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await tapId(tester, 'user-onboarding-next');

      await tapId(tester, 'bankaccount-submit');
      expect(find.text('은행 이름을 입력하세요.'), findsOneWidget);
      expect(find.text('라우팅 번호를 입력하세요.'), findsOneWidget);
      expect(find.text('계좌 번호를 입력하세요.'), findsOneWidget);

      await fillAccountForm(tester, bank: 'Bank', routing: '12345', number: '12345678');
      await tapId(tester, 'bankaccount-submit');
      // The bank name has no length rule any more: 'Bank' is accepted.
      expect(find.text('은행 이름은 5자 이상이어야 합니다.'), findsNothing);
      expect(find.text('라우팅 번호는 9자리여야 합니다.'), findsOneWidget);
      expect(find.text('계좌 번호는 9자리 이상이어야 합니다.'), findsOneWidget);

      await fillAccountForm(tester, number: '1234567890123');
      await tapId(tester, 'bankaccount-submit');
      expect(find.text('계좌 번호는 12자리 이하여야 합니다.'), findsOneWidget);

      expect(server.calls, isNot(contains('POST /bankAccounts')));
    });

    testWidgets('a short bank name is saved (there is no minimum length)', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await tapId(tester, 'user-onboarding-next');

      await fillAccountForm(tester, bank: 'K');
      await tapId(tester, 'bankaccount-submit');

      expect(server.bodies['POST /bankAccounts'], containsPair('bankName', 'K'));
    });

    testWidgets('an empty bank name is still refused', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await tapId(tester, 'user-onboarding-next');

      await fillAccountForm(tester, bank: '   ');
      await tapId(tester, 'bankaccount-submit');

      expect(find.text('은행 이름을 입력하세요.'), findsOneWidget);
      expect(server.calls, isNot(contains('POST /bankAccounts')));
    });

    testWidgets('the number rules are shown as hints inside the fields', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true));
      await tapId(tester, 'user-onboarding-next');

      String? hintOf(String id) => tester
          .widget<TextField>(find.descendant(of: byId(id), matching: find.byType(TextField)))
          .decoration!
          .hintText;
      expect(hintOf('bankaccount-routingNumber-input'), '9자리 숫자');
      expect(hintOf('bankaccount-accountNumber-input'), '9~12자리 숫자');
      expect(hintOf('bankaccount-bankName-input'), isNull);
      // The hint is visible without focusing the field.
      final routing = tester.widget<TextField>(find.descendant(of: byId('bankaccount-routingNumber-input'), matching: find.byType(TextField)));
      expect(routing.decoration!.floatingLabelBehavior, FloatingLabelBehavior.always);
    });

    testWidgets('the form warns not to enter a real account (first-time setup)', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true));
      await tapId(tester, 'user-onboarding-next');

      expect(
        find.descendant(of: byId('bankaccount-demo-notice'), matching: find.text('진짜 자신의 계좌를 만들진 말아주세요! 이건 데모 웹입니다.')),
        findsOneWidget,
      );
    });

    testWidgets('the same warning is on the add-account screen', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true, accounts: [testAccount('b1')]));
      await tapId(tester, 'sidenav-bankaccounts');
      await tapId(tester, 'bankaccount-new');

      expect(
        find.descendant(of: byId('bankaccount-demo-notice'), matching: find.text('진짜 자신의 계좌를 만들진 말아주세요! 이건 데모 웹입니다.')),
        findsOneWidget,
      );
    });

    testWidgets('a server refusal shows an error and stays on step 2', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true)..failAccountCreate = true);
      await tapId(tester, 'user-onboarding-next');

      await fillAccountForm(tester);
      await tapId(tester, 'bankaccount-submit');

      expect(byId('bankaccount-error'), findsOneWidget);
      expect(byId('bankaccount-form'), findsOneWidget);
      expect(find.descendant(of: byId('user-onboarding-dialog-title'), matching: find.text('완료')), findsNothing);
    });

    // The server keeps deleted accounts and returns them with isDeleted: true.
    testWidgets('is shown when the user has only deleted accounts', (tester) async {
      await pumpApp(
        tester,
        FakeServer(signedIn: true, accounts: [testAccount('b1', isDeleted: true)]),
      );

      expect(byId('user-onboarding-dialog'), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);
    });

    testWidgets('the logout button signs out', (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);

      await tapId(tester, 'user-onboarding-logout');

      expect(server.calls, contains('POST /logout'));
      expect(byId('signin-submit'), findsOneWidget);
    });

    testWidgets('is not shown when the user has a bank account', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true, accounts: [testAccount('b1')]));

      expect(byId('user-onboarding-dialog'), findsNothing);
      expect(byId('nav-transaction-tabs'), findsOneWidget);
    });

    testWidgets('is skipped when the account list cannot be loaded', (tester) async {
      await pumpApp(tester, FakeServer(signedIn: true)..failAccountList = true);

      expect(byId('user-onboarding-dialog'), findsNothing);
      expect(byId('nav-transaction-tabs'), findsOneWidget);

      await tapId(tester, 'sidenav-bankaccounts');
      expect(byId('bankaccount-load-error'), findsOneWidget);
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
      expect(find.text('계좌 번호 ****3333'), findsOneWidget);
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

    // Same as the web: the setup opens whenever the user has no bank account
    // and has not finished it in this session.
    testWidgets('deleting the last account opens the setup (same as the web)', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [testAccount('b1')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      await tester.tap(byId('bankaccount-delete'));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      expect(server.activeAccounts, isEmpty);
      expect(byId('user-onboarding-dialog'), findsOneWidget);
    });

    testWidgets('after finishing the setup, deleting the last account does not reopen it',
        (tester) async {
      final server = FakeServer(signedIn: true);
      await pumpApp(tester, server);
      await tapId(tester, 'user-onboarding-next');
      await fillAccountForm(tester);
      await tapId(tester, 'bankaccount-submit');
      await tapId(tester, 'user-onboarding-next'); // 완료

      await tapId(tester, 'sidenav-bankaccounts');
      await tester.tap(byId('bankaccount-delete'));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      expect(server.activeAccounts, isEmpty);
      expect(byId('user-onboarding-dialog'), findsNothing);
      expect(find.text('등록된 은행 계좌가 없습니다.'), findsOneWidget);
    });

    testWidgets('a failed delete keeps the account and tells the user', (tester) async {
      final server = twoAccounts()..failAccountDelete = true;
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-bankaccounts');

      await tester.tap(find.descendant(of: byId('bankaccount-list-item-b1'), matching: byId('bankaccount-delete')));
      await tester.pumpAndSettle();
      await tapId(tester, 'bankaccount-delete-confirm');

      expect(byId('bankaccount-list-item-b1'), findsOneWidget);
      expect(byId('alert-bar-error'), findsOneWidget);
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
}
