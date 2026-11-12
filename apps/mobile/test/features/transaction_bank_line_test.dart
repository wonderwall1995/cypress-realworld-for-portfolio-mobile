import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// The signed-in user is `u1`. [myAccount] is what the server adds for the
/// user's own account.
Map<String, dynamic> item(
  String id, {
  String sender = 'u1',
  String receiver = 'u2',
  String? requestStatus,
  String status = 'complete',
  int amount = 3000,
  Map<String, dynamic>? myAccount,
}) =>
    testTransaction(
      id,
      senderId: sender,
      receiverId: receiver,
      requestStatus: requestStatus,
      status: status,
      amount: amount,
    )..addAll({if (myAccount != null) 'myAccount': myAccount});

FakeServer serverWith(List<Map<String, dynamic>> items) =>
    FakeServer(signedIn: true, accounts: [testAccount('b1')])..everyone.addAll(items);

Map<String, dynamic> account(String bank, [int? balanceAfter]) => {
      'bankName': bank,
      if (balanceAfter != null) 'balanceAfter': balanceAfter,
    };

Finder text(String id, String what) => find.descendant(of: byId(id), matching: find.text(what));

Color wordColor(WidgetTester tester, String id) =>
    tester.widget<Text>(find.descendant(of: byId('transaction-bank-move-$id'), matching: find.byType(Text))).style!.color!;

void main() {
  group('Transaction', () {
    test('MyAccountInfo reads the bank and the balance after (cents), which may be missing', () {
      final t = Transaction.fromJson(item('a', myAccount: account('국민은행', 7000)));
      expect(t.myAccount!.bankName, '국민은행');
      expect(t.myAccount!.balanceAfter, 7000);
      expect(Transaction.fromJson(item('a', myAccount: account('국민은행'))).myAccount!.balanceAfter, isNull);
      expect(Transaction.fromJson(item('a')).myAccount, isNull);
      expect(Transaction.fromJson(item('a')..['myAccount'] = null).myAccount, isNull);
    });

    test('money moved: a complete payment, an accepted request, an external deposit', () {
      expect(Transaction.fromJson(item('a')).moneyMoved, isTrue);
      expect(Transaction.fromJson(item('a', status: 'pending')).moneyMoved, isFalse);
      expect(Transaction.fromJson(item('a', requestStatus: 'accepted')).moneyMoved, isTrue);
      expect(Transaction.fromJson(item('a', requestStatus: 'pending', status: 'pending')).moneyMoved, isFalse);
      expect(Transaction.fromJson(item('a', requestStatus: 'rejected', status: 'complete')).moneyMoved, isFalse);
      expect(Transaction.fromJson(item('a', sender: 'external-deposit', receiver: 'u1')).moneyMoved, isTrue);
    });

    test('direction: the receiver of a payment received, its sender paid', () {
      expect(Transaction.fromJson(item('a', sender: 'u2', receiver: 'u1')).receivedBy('u1'), isTrue);
      expect(Transaction.fromJson(item('a', sender: 'u1', receiver: 'u2')).receivedBy('u1'), isFalse);
      expect(Transaction.fromJson(item('a', sender: 'u2', receiver: 'u3')).receivedBy('u1'), isNull);
      expect(Transaction.fromJson(item('a', sender: 'u1', receiver: 'u1')).receivedBy('u1'), isNull);
      expect(Transaction.fromJson(item('a')).receivedBy(null), isNull);
    });

    test('direction: for a request, the receiver pays and the sender (who asked) is paid', () {
      final asked = item('a', sender: 'u1', receiver: 'u2', requestStatus: 'accepted');
      final owe = item('b', sender: 'u2', receiver: 'u1', requestStatus: 'accepted');
      expect(Transaction.fromJson(asked).receivedBy('u1'), isTrue); // I asked, they paid me
      expect(Transaction.fromJson(owe).receivedBy('u1'), isFalse); // they asked, I paid
    });

    test('an external deposit is always received by its receiver', () {
      final t = Transaction.fromJson(item('a', sender: 'external-deposit', receiver: 'u1'));
      expect(t.receivedBy('u1'), isTrue);
      expect(t.receivedBy('u2'), isNull);
    });
  });

  group('the sentence in the home list', () {
    testWidgets('a payment I sent says 계좌에서 출금 되었습니다 with 출금 in red', (tester) async {
      final server = serverWith([item('p1', myAccount: account('국민은행', 7000))]);
      await pumpApp(tester, server);

      expect(text('transaction-bank-name-p1', '국민은행'), findsOneWidget);
      expect(find.descendant(of: byId('transaction-bank-sentence-p1'), matching: find.text(' 계좌에서')), findsOneWidget);
      expect(text('transaction-bank-move-p1', '출금'), findsOneWidget);
      expect(wordColor(tester, 'p1'), Colors.red.shade700);
      expect(find.descendant(of: byId('transaction-bank-sentence-p1'), matching: find.text(' 되었습니다.')), findsOneWidget);
    });

    testWidgets('a payment I received says 계좌로 입금 되었습니다 with 입금 in green', (tester) async {
      final server = serverWith([item('p2', sender: 'u2', receiver: 'u1', myAccount: account('신한은행', 3000))]);
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('transaction-bank-sentence-p2'), matching: find.text(' 계좌로')), findsOneWidget);
      expect(text('transaction-bank-move-p2', '입금'), findsOneWidget);
      expect(wordColor(tester, 'p2'), Colors.green.shade700);
    });

    testWidgets('the order is the title, the bank line, then the memo', (tester) async {
      final server = serverWith([item('p1', myAccount: account('국민은행', 7000))]);
      await pumpApp(tester, server);

      final title = tester.getTopLeft(byId('transaction-title-p1')).dy;
      final sentence = tester.getTopLeft(byId('transaction-bank-sentence-p1')).dy;
      final memoText = find.descendant(of: byId('transaction-item-p1'), matching: find.text(testTransaction('p1')['description'] as String));
      expect(title, lessThan(sentence));
      expect(sentence, lessThan(tester.getTopLeft(memoText).dy));

    });

    testWidgets('a request still waiting, or rejected, moved no money: no sentence and no balance', (tester) async {
      final server = serverWith([
        item('w1', requestStatus: 'pending', status: 'pending', myAccount: account('국민은행')),
        item('w2', requestStatus: 'rejected', status: 'complete', myAccount: account('국민은행', 5000)),
      ]);
      await pumpApp(tester, server);

      for (final id in ['w1', 'w2']) {
        expect(byId('transaction-bank-sentence-$id'), findsNothing, reason: id);
        expect(byId('transaction-balance-$id'), findsNothing, reason: id);
      }
    });

    testWidgets('an accepted request I asked for is 입금; one I paid is 출금', (tester) async {
      final server = serverWith([
        item('a1', sender: 'u1', receiver: 'u2', requestStatus: 'accepted', myAccount: account('국민은행', 9000)),
        item('a2', sender: 'u2', receiver: 'u1', requestStatus: 'accepted', myAccount: account('신한은행', 1000)),
      ]);
      await pumpApp(tester, server);

      expect(text('transaction-bank-move-a1', '입금'), findsOneWidget);
      expect(text('transaction-bank-move-a2', '출금'), findsOneWidget);
    });

    testWidgets('someone else\'s transaction has no account of mine: no sentence, no balance', (tester) async {
      final server = serverWith([item('o1', sender: 'u2', receiver: 'u3')]);
      await pumpApp(tester, server);

      expect(byId('transaction-item-o1'), findsOneWidget);
      expect(byId('transaction-bank-sentence-o1'), findsNothing);
      expect(byId('transaction-balance-o1'), findsNothing);
    });

    testWidgets('a payment of mine that came without my account says nothing about a bank', (tester) async {
      final server = serverWith([item('p9')]);
      await pumpApp(tester, server);

      expect(byId('transaction-bank-sentence-p9'), findsNothing);
    });
  });

  group('the balance under the amount', () {
    testWidgets('shows the bank and the money left, under the amount', (tester) async {
      final server = serverWith([item('p1', myAccount: account('국민은행', 7000))]);
      await pumpApp(tester, server);

      expect(text('transaction-balance-bank-p1', '국민은행'), findsOneWidget);
      expect(text('transaction-balance-amount-p1', ' 남은 잔액 \$70.00'), findsOneWidget);
      final amount = tester.getBottomLeft(byId('transaction-amount-p1')).dy;
      final balance = tester.getTopLeft(byId('transaction-balance-p1')).dy;
      expect(balance, greaterThanOrEqualTo(amount - 1));
      // On the right side, with the amount.
      expect(tester.getRect(byId('transaction-balance-p1')).right, closeTo(tester.getRect(byId('transaction-amount-p1')).right, 20));
    });

    testWidgets('has no balance line when the server does not say the balance', (tester) async {
      final server = serverWith([item('p1', myAccount: account('국민은행'))]);
      await pumpApp(tester, server);

      expect(byId('transaction-balance-p1'), findsNothing);
      // The sentence is still there: money moved.
      expect(byId('transaction-bank-sentence-p1'), findsOneWidget);
    });

    testWidgets('a long bank name gets an ellipsis and nothing runs out of a narrow screen', (tester) async {
      const long = 'The Very Long Named Savings And Loan Bank of Somewhere Far Away';
      final server = serverWith([
        item('p1', myAccount: account(long, 123456789)),
        item('p2', sender: 'u2', receiver: 'u1', myAccount: account(long, 5)),
      ]);
      await pumpApp(tester, server, size: const Size(360, 800));

      expect(tester.takeException(), isNull); // no overflow stripes
      final name = tester.widget<Text>(find.descendant(of: byId('transaction-balance-bank-p1'), matching: find.byType(Text)));
      expect(name.overflow, TextOverflow.ellipsis);
      expect(text('transaction-balance-amount-p1', ' 남은 잔액 \$1,234,567.89'), findsOneWidget);
      // The whole line stays inside the width of its column (170).
      expect(tester.getSize(byId('transaction-balance-p1')).width, lessThanOrEqualTo(170));
      expect(tester.getRect(byId('transaction-item-p1')).right, lessThanOrEqualTo(360));
    });

    testWidgets('an external deposit shows the balance of the account too', (tester) async {
      final deposit = item('d1', sender: 'external-deposit', receiver: 'u1', amount: 700, myAccount: account('국민은행', 700));
      final server = serverWith([deposit]);
      await pumpApp(tester, server);

      expect(text('transaction-balance-amount-d1', ' 남은 잔액 \$7.00'), findsOneWidget);
      expect(text('transaction-bank-move-d1', '입금'), findsOneWidget);
      // The bank name comes from the server's `myAccount`: the list of accounts is not needed.
      expect(text('transaction-bank-name-d1', '국민은행'), findsOneWidget);
    });
  });
  group('the amount follows my money (the rule of the web)', () {
    Color amountColor(WidgetTester tester, String id) =>
        tester.widget<Text>(find.descendant(of: byId('transaction-amount-$id'), matching: find.byType(Text))).style!.color!;

    testWidgets('money I received is green with +, money I paid is red with -', (tester) async {
      final server = serverWith([
        item('in1', sender: 'u2', receiver: 'u1', amount: 1000, myAccount: account('국민은행', 1000)),
        item('out1', sender: 'u1', receiver: 'u2', amount: 2000, myAccount: account('국민은행', 500)),
      ]);
      await pumpApp(tester, server);

      expect(text('transaction-amount-in1', '+\$10.00'), findsOneWidget);
      expect(amountColor(tester, 'in1'), Colors.green.shade700);
      expect(text('transaction-amount-out1', '-\$20.00'), findsOneWidget);
      expect(amountColor(tester, 'out1'), Colors.red.shade700);
    });

    testWidgets('a request still waiting is grey, with the sign it will have', (tester) async {
      final server = serverWith([
        item('q1', sender: 'u2', receiver: 'u1', requestStatus: 'pending', status: 'pending', amount: 700), // I will pay
        item('q2', sender: 'u1', receiver: 'u2', requestStatus: 'pending', status: 'pending', amount: 800), // I will be paid
      ]);
      await pumpApp(tester, server);
      final grey = Theme.of(tester.element(byId('transaction-item-q1'))).colorScheme.onSurfaceVariant;

      expect(text('transaction-amount-q1', '-\$7.00'), findsOneWidget);
      expect(text('transaction-amount-q2', '+\$8.00'), findsOneWidget);
      expect(amountColor(tester, 'q1'), grey);
      expect(amountColor(tester, 'q2'), grey);
    });

    testWidgets('a rejected request moved no money: grey', (tester) async {
      final server = serverWith([item('x1', sender: 'u2', receiver: 'u1', requestStatus: 'rejected', status: 'complete', amount: 900)]);
      await pumpApp(tester, server);
      final grey = Theme.of(tester.element(byId('transaction-item-x1'))).colorScheme.onSurfaceVariant;

      expect(amountColor(tester, 'x1'), grey);
    });

    testWidgets('the detail screen uses the same rule', (tester) async {
      final server = serverWith([item('d1', sender: 'u2', receiver: 'u1', amount: 1500, myAccount: account('국민은행', 1500))]);
      await pumpApp(tester, server);

      await tapId(tester, 'transaction-item-d1');

      expect(text('transaction-amount-d1', '+\$15.00'), findsOneWidget);
      expect(amountColor(tester, 'd1'), Colors.green.shade700);
    });
  });

  group('the bank name in the balance line', () {
    test('is said like on the web: 은행 is added unless the name already ends with 은행 or Bank', () {
      expect(BankMoveSentence.bankDisplayName('국민'), '국민 은행');
      expect(BankMoveSentence.bankDisplayName('국민은행'), '국민은행');
      expect(BankMoveSentence.bankDisplayName('  신한  '), '신한 은행');
      expect(BankMoveSentence.bankDisplayName('Test Bank'), 'Test Bank');
      expect(BankMoveSentence.bankDisplayName('test BANK'), 'test BANK');
      expect(BankMoveSentence.bankDisplayName('KB'), 'KB 은행');
    });

    testWidgets('shows 국민 은행 for a bank called 국민', (tester) async {
      final server = serverWith([item('p1', myAccount: account('국민', 7000))]);
      await pumpApp(tester, server);

      expect(text('transaction-balance-bank-p1', '국민 은행'), findsOneWidget);
    });
  });

  testWidgets('a long bank name is cut to 14 characters and ends with …', (tester) async {
    final server = serverWith([item('p1', myAccount: account('가나다라마바사아자차카타파하갸냐', 7000))]);
    await pumpApp(tester, server);

    expect(find.text('가나다라마바사아자차카타파하…'), findsNWidgets(2)); // the sentence and the balance line
    expect(BankMoveSentence.clipBankName('가나다라마바사아자차카타파하'), '가나다라마바사아자차카타파하'); // 14: kept
    expect(BankMoveSentence.clipBankName('가나다라마바사아자차카타파하갸'), '가나다라마바사아자차카타파하…');
  });
}
