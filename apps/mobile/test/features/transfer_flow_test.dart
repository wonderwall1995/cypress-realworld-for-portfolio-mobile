import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  await tapId(tester, 'sidenav-transfer');
  await tapId(tester, 'user-list-item-$userId');
}

Future<void> fillForm(WidgetTester tester, {String amount = '25', String note = 'Lunch'}) async {
  await enter(tester, 'transaction-create-amount-input', amount);
  await enter(tester, 'transaction-create-description-input', note);
}

Future<void> pickMine(WidgetTester tester, String id) => tapId(tester, 'transaction-create-my-account-$id');

void main() {
  group('the accounts on the form', () {
    testWidgets('shows my accounts with the money in each, and the accounts of the other user', (tester) async {
      await toForm(tester, newServer());

      expect(byId('transaction-create-my-account-b1'), findsOneWidget);
      expect(byId('transaction-create-my-account-b2'), findsOneWidget);
      // The bank, the last 4 digits, and the balance (mine only).
      final mine = byId('transaction-create-my-account-b1');
      expect(find.descendant(of: mine, matching: find.text('First Bank')), findsOneWidget);
      expect(find.descendant(of: mine, matching: find.text('····6789')), findsOneWidget);
      expect(find.descendant(of: mine, matching: find.text('잔액 \$200')), findsOneWidget);
      expect(find.text('잔액 \$5'), findsOneWidget);
      final other = byId('transaction-create-other-account-o-u2');
      expect(find.descendant(of: other, matching: find.text('Other Bank')), findsOneWidget);
      expect(find.descendant(of: other, matching: find.text('····5555')), findsOneWidget);
      expect(find.descendant(of: other, matching: find.textContaining('잔액')), findsNothing);
    });

    testWidgets('choosing an account that holds less says so, and the 이체 button is off', (tester) async {
      await toForm(tester, newServer());

      await fillForm(tester, amount: '10');
      await tester.pump();
      await pickMine(tester, 'b2');
      expect(find.text('선택한 계좌의 잔액(\$5)이 부족합니다'), findsOneWidget);
      final off = tester.widget<FilledButton>(
        find.descendant(of: byId('transaction-create-submit-payment'), matching: find.byType(FilledButton)),
      );
      expect(off.onPressed, isNull);

      await fillForm(tester, amount: '3');
      await tester.pump();
      expect(find.text('선택한 계좌의 잔액(\$5)이 부족합니다'), findsNothing);
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
      expect(byId('transaction-confirm-dialog'), findsNothing);
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
      expect(byId('transaction-confirm-dialog'), findsNothing);

      await tapId(tester, 'transaction-create-other-account-x2');
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

      expect(find.text('선택한 계좌의 잔액(\$5)이 부족합니다'), findsOneWidget);
      expect(byId('transaction-confirm-dialog'), findsNothing);
      expect(server.calls, isNot(contains('POST /transactions')));
    });

    testWidgets('a user without bank accounts cannot be paid', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])
        ..otherAccounts['u2'] = [];
      await toForm(tester, server);
      await fillForm(tester);

      expect(find.textContaining('상대에게 은행 계좌가 없어 이체할 수 없습니다'), findsOneWidget);
      await tapId(tester, 'transaction-create-submit-payment');
      expect(byId('transaction-confirm-dialog'), findsNothing);
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

      expect(byId('transaction-confirm-dialog'), findsOneWidget);
      expect(find.text('정말 이체하겠습니까?'), findsOneWidget);
      expect(find.text('계정의 비밀번호를 입력해주세요.'), findsOneWidget);
      expect(find.text('이 데모 앱의 비밀번호'), findsOneWidget);
      final summary = tester
          .widgetList<Text>(find.descendant(of: byId('transaction-confirm-summary'), matching: find.byType(Text)))
          .map((t) => t.data);
      expect(summary, ['First Bank ····6789', 'Test Bob님 Other Bank ····5555', '\$25']);

      await tapId(tester, 'transaction-confirm-cancel');

      expect(byId('transaction-confirm-dialog'), findsNothing);
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

      expect(byId('transaction-confirm-dialog'), findsOneWidget);
      expect(find.text('비밀번호가 맞지 않습니다'), findsOneWidget);
      expect(server.calls, contains('POST /users/verifyPassword'));
      expect(server.calls, isNot(contains('POST /transactions')));

      // The right password goes on.
      await confirmTransfer(tester);
      expect(byId('transaction-confirm-dialog'), findsNothing);
      expect(find.text('이체 완료'), findsOneWidget);
    });

    testWidgets('the confirm button is off until a password is typed', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)]);
      await toForm(tester, server);
      await fillForm(tester);
      await tapId(tester, 'transaction-create-submit-payment');

      FilledButton button() => tester.widget<FilledButton>(
            find.descendant(of: byId('transaction-confirm-confirm'), matching: find.byType(FilledButton)),
          );
      expect(button().onPressed, isNull);

      await enterIn(tester, 'transaction-confirm-password', 'x');
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

      final field = tester.widget<TextField>(find.descendant(of: byId('transaction-confirm-password'), matching: find.byType(TextField)));
      expect(field.obscureText, isTrue);
    });

    testWidgets('a payment lowers the money of the account and of 내 계좌', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])..balance = 20000;
      await toForm(tester, server);
      await fillForm(tester, amount: '25');
      await payNow(tester);

      await tapId(tester, 'new-transaction-return-to-transactions');
      await tapId(tester, 'sidenav-bankaccounts');
      expect(find.descendant(of: byId('bankaccount-balance-b1'), matching: find.text('잔액 \$175')), findsOneWidget);
      await tapId(tester, 'sidenav-my-account');
      expect(find.descendant(of: byId('sidenav-user-balance'), matching: find.text('\$175')), findsOneWidget);
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
    testWidgets('a saved "contacts" is sent as private: never more public than the user chose', (tester) async {
      final server = newServer(accounts: [testAccount('b1', bank: 'First Bank', balance: 20000)])
        ..profile['defaultPrivacyLevel'] = 'contacts';
      await toForm(tester, server);
      await fillForm(tester);

      await payNow(tester);

      expect((server.bodies['POST /transactions'] as Map)['privacyLevel'], 'private');
    });
  });

  group('how the form looks (like the web)', () {
    testWidgets('two cards: what I send, and what the other user gets', (tester) async {
      await toForm(tester, newServer());
      expect(find.text('메모는 다른 사람에게 보일 수 있습니다. 개인 정보는 넣지 마세요.'), findsOneWidget);
      final send = byId('transaction-create-send-card');
      final receive = byId('transaction-create-receive-card');
      for (final id in ['transaction-create-amount-input', 'transaction-create-description-input', 'transaction-create-my-account']) {
        expect(find.descendant(of: send, matching: byId(id)), findsOneWidget, reason: id);
      }
      for (final id in ['transaction-create-receiver-name', 'transaction-create-other-account']) {
        expect(find.descendant(of: receive, matching: byId(id)), findsOneWidget, reason: id);
      }
      expect(tester.getTopLeft(send).dy, lessThan(tester.getTopLeft(receive).dy));
    });

    Future<void> longNames(WidgetTester tester, {double scale = 1, double width = 360}) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const long = '아주아주아주 긴 이름을 가진 어느 나라의 중앙 은행 강남 지점';
      final server = newServer(accounts: [testAccount('b1', bank: long, balance: 2147483600)]);
      await pumpApp(tester, server, size: Size(width, 3000));
      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'sidenav-transfer');
      await tapId(tester, 'user-list-item-u2');
    }

    testWidgets('a narrow screen: only the bank name is cut, the digits and the balance are whole', (tester) async {
      await longNames(tester);
      expect(tester.takeException(), isNull);
      final row = byId('transaction-create-my-account-b1');
      RenderParagraph text(String t) => tester.renderObject(
            find.descendant(of: find.descendant(of: row, matching: find.text(t)), matching: find.byType(RichText)),
          );
      expect(text('····6789').didExceedMaxLines, isFalse);
      expect(text('잔액 \$21,474,836').didExceedMaxLines, isFalse);
      expect(tester.getRect(find.descendant(of: row, matching: find.text('잔액 \$21,474,836'))).right, lessThanOrEqualTo(360));
      final name = tester.widget<Text>(find.descendant(of: byId('transaction-create-my-account-b1-row-bank-name'), matching: find.byType(Text)));
      expect((name.maxLines, name.overflow), (1, TextOverflow.ellipsis));
      expect(name.semanticsLabel, startsWith('아주아주아주')); // the whole name for a screen reader
    });

    testWidgets('with letters twice as big nothing runs out of the screen', (tester) async {
      // (The test font is twice as wide as a real one, so the screen is wider too.)
      await longNames(tester, scale: 2, width: 560);
      expect(tester.takeException(), isNull);
      expect(find.text('잔액 \$21,474,836'), findsOneWidget);
    });
  });
}
