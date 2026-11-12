import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';
import '../support/transfer_helpers.dart';

/// A signed-in user with two bank accounts and two other users.
/// First Bank holds $200.00, Small Bank holds $5.00.
FakeServer newServer({List<Map<String, dynamic>>? accounts}) => FakeServer(
      signedIn: true,
      accounts: accounts ??
          [
            testAccount('b1', bank: 'First Bank', balance: 20000),
            testAccount('b2', bank: 'Small Bank', balance: 500),
          ],
    )
      ..balance = 20500
      ..users.addAll([
        testOtherUser('u2', 'Bob', 'Test', username: 'bob'),
        testOtherUser('u3', 'Cara', 'Test', username: 'cara'),
      ]);

Future<void> toForm(WidgetTester tester, FakeServer server, {String userId = 'u2'}) async {
  await pumpApp(tester, server);
  await tapId(tester, 'sidenav-my-account');
  await tapId(tester, 'my-account-transfer');
  await tapId(tester, 'user-list-item-$userId');
}

Future<void> fillForm(WidgetTester tester, {String amount = '25', String note = 'Lunch'}) async {
  await enter(tester, 'transaction-create-amount-input', amount);
  await enter(tester, 'transaction-create-description-input', note);
}

Future<void> pickMine(WidgetTester tester, String id) => tapId(tester, 'transaction-create-my-account-account-$id');

void main() {
  group('the accounts on the form', () {
    testWidgets('shows my accounts with the money in each, and the accounts of the other user', (tester) async {
      await toForm(tester, newServer());

      expect(byId('transaction-create-my-account-account-b1'), findsOneWidget);
      expect(byId('transaction-create-my-account-account-b2'), findsOneWidget);
      // Left: the bank and the last 4 digits. Right: the balance (mine only).
      expect(find.text('First Bank ****6789'), findsOneWidget);
      expect(find.text('\$200.00'), findsOneWidget);
      expect(find.text('\$5.00'), findsOneWidget);
      expect(byId('transaction-create-other-account-account-o-u2'), findsOneWidget);
      expect(find.text('Other Bank ****5555'), findsOneWidget);
      // The left part is 60% and the right part 40% of the row.
      final row = tester.getRect(find.descendant(of: byId('transaction-create-my-account-account-b1'), matching: find.byType(Row)).first);
      final left = tester.getRect(find.text('First Bank ****6789'));
      final right = tester.getRect(find.text('\$200.00'));
      expect(left.left, lessThan(right.left));
      expect(right.right, closeTo(row.right, 40));
    });

    testWidgets('choosing an account that holds less says so, and the 이체 button is off', (tester) async {
      await toForm(tester, newServer());

      await fillForm(tester, amount: '10');
      await tester.pump();
      await pickMine(tester, 'b2');
      expect(find.text('선택한 계좌의 잔액이 부족합니다.'), findsOneWidget);
      final off = tester.widget<FilledButton>(
        find.descendant(of: byId('transaction-create-submit-payment'), matching: find.byType(FilledButton)),
      );
      expect(off.onPressed, isNull);

      await fillForm(tester, amount: '3');
      await tester.pump();
      expect(find.text('선택한 계좌의 잔액이 부족합니다.'), findsNothing);
    });

    testWidgets('with one account of each there is nothing to choose', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);

      await fillForm(tester);
      await payNow(tester);

      expect((server.bodies['POST /transactions'] as Map)['myAccountId'], 'b1');
      expect((server.bodies['POST /transactions'] as Map)['otherAccountId'], 'o-u2');
    });

    testWidgets('with two accounts, one must be chosen before paying', (tester) async {
      final server = newServer();
      await toForm(tester, server);
      await fillForm(tester);

      await tapId(tester, 'transaction-create-submit-payment');

      expect(find.text('출금할 내 계좌를 선택하세요.'), findsOneWidget);
      expect(byId('transfer-confirm-dialog'), findsNothing);
      expect(server.calls.where((c) => c.contains('POST')).where((c) => c != 'POST /login'), isEmpty);
    });

    testWidgets('the other user\'s account must be chosen when there are two', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])
        ..otherAccounts['u2'] = [
          {'id': 'x1', 'bankName': 'Bank X', 'accountNumberLast4': '1111'},
          {'id': 'x2', 'bankName': 'Bank Y', 'accountNumberLast4': '2222'},
        ];
      await toForm(tester, server);
      await fillForm(tester);

      await tapId(tester, 'transaction-create-submit-payment');
      expect(find.text('상대의 계좌를 선택하세요.'), findsOneWidget);
      expect(byId('transfer-confirm-dialog'), findsNothing);

      await tapId(tester, 'transaction-create-other-account-account-x2');
      await payNow(tester);
      expect((server.bodies['POST /transactions'] as Map)['otherAccountId'], 'x2');
    });

    testWidgets('an account that became too small after it was chosen is refused', (tester) async {
      final server = newServer();
      await toForm(tester, server);
      await fillForm(tester, amount: '3');
      await pickMine(tester, 'b2');

      await enter(tester, 'transaction-create-amount-input', '10');
      await tapId(tester, 'transaction-create-submit-payment');

      expect(find.text('선택한 계좌의 잔액이 부족합니다.'), findsOneWidget);
      expect(byId('transfer-confirm-dialog'), findsNothing);
      expect(server.calls, isNot(contains('POST /transactions')));
    });

    testWidgets('a user without bank accounts cannot be paid', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])
        ..otherAccounts['u2'] = [];
      await toForm(tester, server);
      await fillForm(tester);

      expect(find.textContaining('상대에게 은행 계좌가 없어 이체할 수 없습니다'), findsOneWidget);
      await tapId(tester, 'transaction-create-submit-payment');
      expect(byId('transfer-confirm-dialog'), findsNothing);
      expect(server.calls, isNot(contains('POST /transactions')));
    });

    testWidgets('the 이체 button is off while the chosen account holds too little', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 1000)]);
      await toForm(tester, server);
      await fillForm(tester, amount: '500');

      final button = tester.widget<FilledButton>(
        find.descendant(of: byId('transaction-create-submit-payment'), matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNull);

      await enter(tester, 'transaction-create-amount-input', '5');
      await tester.pump();
      final again = tester.widget<FilledButton>(
        find.descendant(of: byId('transaction-create-submit-payment'), matching: find.byType(FilledButton)),
      );
      expect(again.onPressed, isNotNull);
    });
  });

  group('the password step', () {
    testWidgets('asks the question and shows what will happen; 취소 sends nothing', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);
      await fillForm(tester, amount: '25');

      await tapId(tester, 'transaction-create-submit-payment');

      expect(byId('transfer-confirm-dialog'), findsOneWidget);
      expect(find.text('정말 이체하겠습니까?'), findsOneWidget);
      expect(find.text('자신의 계정 비밀번호를 입력해주세요.'), findsOneWidget);
      final summary = tester
          .widget<Text>(find.descendant(of: byId('transfer-confirm-summary'), matching: find.byType(Text)))
          .data!
          .split('\n');
      expect(summary, [
        'First Bank ****6789 → Test Bob님 Other Bank ****5555',
        '금액 \$25.00',
      ]);

      await tapId(tester, 'transfer-confirm-cancel');

      expect(byId('transfer-confirm-dialog'), findsNothing);
      expect(byId('transaction-create-form'), findsOneWidget);
      expect(server.calls, isNot(contains('POST /users/verifyPassword')));
      expect(server.calls, isNot(contains('POST /transactions')));
    });

    testWidgets('a wrong password keeps the dialog open with a message and sends no payment', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);
      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-payment');

      await confirmTransfer(tester, password: 'not-the-password');

      expect(byId('transfer-confirm-dialog'), findsOneWidget);
      expect(find.text('비밀번호가 맞지 않습니다'), findsOneWidget);
      expect(server.calls, contains('POST /users/verifyPassword'));
      expect(server.calls, isNot(contains('POST /transactions')));

      // The right password goes on.
      await confirmTransfer(tester);
      expect(byId('transfer-confirm-dialog'), findsNothing);
      expect(find.text('이체 완료'), findsOneWidget);
    });

    testWidgets('the confirm button is off until a password is typed', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);
      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-payment');

      FilledButton button() => tester.widget<FilledButton>(
            find.descendant(of: byId('transfer-confirm-submit'), matching: find.byType(FilledButton)),
          );
      expect(button().onPressed, isNull);

      await enterIn(tester, 'transfer-confirm-password-input', 'x');
      await tester.pump();
      expect(button().onPressed, isNotNull);
      expect(server.calls, isNot(contains('POST /users/verifyPassword')));
    });

    testWidgets('the password is checked first, then the payment is sent with it', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);
      await fillForm(tester);

      await payNow(tester);

      final verify = server.calls.indexOf('POST /users/verifyPassword');
      final create = server.calls.indexOf('POST /transactions');
      expect(verify, greaterThanOrEqualTo(0));
      expect(create, greaterThan(verify));
      expect((server.bodies['POST /transactions'] as Map)['password'], 'pw-1234');
    });

    testWidgets('the password field hides what is typed', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);
      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-payment');

      final field = tester.widget<TextField>(find.descendant(of: byId('transfer-confirm-password-input'), matching: find.byType(TextField)));
      expect(field.obscureText, isTrue);
    });

    testWidgets('a payment lowers the money of the account and of 내 계좌', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])..balance = 20000;
      await toForm(tester, server);
      await fillForm(tester, amount: '25');
      await payNow(tester);

      await tapId(tester, 'new-transaction-return-to-transactions');
      await tapId(tester, 'sidenav-bankaccounts');
      expect(find.text('계좌 번호 ****6789 · 잔액 \$175.00'), findsOneWidget);
      await tapId(tester, 'sidenav-my-account');
      expect(find.descendant(of: byId('sidenav-user-balance'), matching: find.text('\$175.00')), findsOneWidget);
    });
  });

  group('the privacy of the new transaction', () {
    testWidgets('is the default of the settings', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])
        ..profile['defaultPrivacyLevel'] = 'private';
      await toForm(tester, server);
      await fillForm(tester);

      await payNow(tester);

      expect((server.bodies['POST /transactions'] as Map)['privacyLevel'], 'private');
    });

    testWidgets('is public when the user has not chosen', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);
      await fillForm(tester);

      await payNow(tester);

      expect((server.bodies['POST /transactions'] as Map)['privacyLevel'], 'public');
    });
  });

  group('the privacy of old data', () {
    testWidgets('a saved "contacts" (the server no longer accepts it) is sent as public', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])
        ..profile['defaultPrivacyLevel'] = 'contacts';
      await toForm(tester, server);
      await fillForm(tester);

      await payNow(tester);

      expect((server.bodies['POST /transactions'] as Map)['privacyLevel'], 'public');
    });
  });
}
