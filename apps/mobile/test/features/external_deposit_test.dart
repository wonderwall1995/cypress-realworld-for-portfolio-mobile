import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// What the server sends for a deposit: a transaction from "external-deposit".
Map<String, dynamic> depositItem(String id, {int amount = 700}) => testTransaction(
      id,
      sender: '외부 입금',
      receiver: 'Kim Ada',
      description: '외부 입금',
      amount: amount,
      senderId: 'external-deposit',
      receiverId: 'u1',
    )..['source'] = 'b1';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1', bank: 'First Test Bank')]);

Finder inRow(String id, Finder what) => find.descendant(of: byId('transaction-item-$id'), matching: what);

Color colorOf(WidgetTester tester, String id) =>
    tester.widget<Text>(find.descendant(of: byId('transaction-amount-$id'), matching: find.byType(Text))).style!.color!;

void main() {
  group('Transaction', () {
    test('only a sender called external-deposit makes an external deposit', () {
      expect(Transaction.fromJson(depositItem('d')).isExternalDeposit, isTrue);
      expect(Transaction.fromJson(testTransaction('p')).isExternalDeposit, isFalse);
      expect(Transaction.fromJson(testTransaction('r', requestStatus: 'pending')).isExternalDeposit, isFalse);
    });

    test('it says 입금, not 결제', () {
      final t = Transaction.fromJson(depositItem('d'));
      expect(t.actionLabel, '입금');
      expect(t.statusLabel, '입금 완료');
      expect(Transaction.fromJson(testTransaction('p')).actionLabel, '결제');
      expect(Transaction.fromJson(testTransaction('p')).statusLabel, '결제 완료');
    });
  });

  group('the home lists', () {
    testWidgets('전체 shows the deposit as 외부 입금, the bank sentence, a plus sign in green, and a bank icon', (tester) async {
      final server = newServer()..everyone.addAll([depositItem('d1'), testTransaction('a', description: 'Plain')]);
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('transaction-sender-d1'), matching: find.text('외부 입금')), findsOneWidget);
      // "First Test Ban… 계좌로 입금 되었습니다." — the bank is found by the account of the deposit
      // (the name is 15 characters, so it is cut to 14 and ends with …).
      expect(find.descendant(of: byId('transaction-bank-name-d1'), matching: find.text('First Test Ban…')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-bank-sentence-d1'), matching: find.text(' 계좌로')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-bank-move-d1'), matching: find.text('입금')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-bank-sentence-d1'), matching: find.text(' 되었습니다.')), findsOneWidget);
      // The old receiver name and the 입금 badge are not in this row any more.
      expect(byId('transaction-receiver-d1'), findsNothing);
      expect(byId('transaction-action-d1'), findsNothing);
      expect(find.descendant(of: byId('transaction-amount-d1'), matching: find.text('+\$7.00')), findsOneWidget);
      expect(colorOf(tester, 'd1'), Colors.green.shade700);
      // A bank icon, not the letter 외.
      expect(inRow('d1', find.byIcon(Icons.account_balance)), findsOneWidget);
      expect(inRow('d1', find.text('외')), findsNothing);
    });

    testWidgets('the word 입금 is green', (tester) async {
      final server = newServer()..everyone.add(depositItem('d1'));
      await pumpApp(tester, server);

      final word = tester.widget<Text>(find.descendant(of: byId('transaction-bank-move-d1'), matching: find.byType(Text)));
      expect(word.style!.color, Colors.green.shade700);
    });

    testWidgets('a deposit into an account that is not in the list says only 은행 계좌로', (tester) async {
      final item = depositItem('d1')..['source'] = 'gone-account';
      final server = newServer()..everyone.add(item);
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('transaction-bank-name-d1'), matching: find.text('은행')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-bank-sentence-d1'), matching: find.text(' 계좌로')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-bank-move-d1'), matching: find.text('입금')), findsOneWidget);
    });

    testWidgets('a payment I made has a letter avatar, a minus sign and red', (tester) async {
      final server = newServer()
        ..everyone.addAll([
          depositItem('d1'),
          testTransaction('a', amount: 2000, senderId: 'u1', receiverId: 'u2'),
        ]);
      await pumpApp(tester, server);

      expect(inRow('a', find.byIcon(Icons.account_balance)), findsNothing);
      expect(inRow('a', find.text('A')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-amount-a'), matching: find.text('-\$20.00')), findsOneWidget);
      expect(colorOf(tester, 'a'), Colors.red.shade700);
      expect(find.descendant(of: byId('transaction-title-a'), matching: find.textContaining('님에게 이체했습니다')), findsOneWidget);
    });

    testWidgets('a payment between other people is grey and has no sign', (tester) async {
      final server = newServer()..everyone.add(testTransaction('o', amount: 2000)); // s-o pays r-o
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('transaction-amount-o'), matching: find.text('\$20.00')), findsOneWidget);
      final theme = Theme.of(tester.element(byId('transaction-item-o')));
      expect(colorOf(tester, 'o'), theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('내 거래 shows it', (tester) async {
      final server = newServer()..mine.add(depositItem('d1'));
      await pumpApp(tester, server);

      await tapId(tester, 'nav-personal-tab');
      expect(byId('transaction-item-d1'), findsOneWidget);
    });
  });

  group('depositing', () {
    testWidgets('a deposit shows up in 전체 and 내 거래 at once', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await tapId(tester, 'sidenav-my-account');
      await tapId(tester, 'my-account-deposit');
      await enter(tester, 'bank-transfer-amount-input', '7');
      await tapId(tester, 'bank-transfer-submit');

      await tapId(tester, 'sidenav-home');
      final id = server.everyone.first['id'] as String;
      expect(byId('transaction-item-$id'), findsOneWidget);
      expect(find.descendant(of: byId('transaction-amount-$id'), matching: find.text('+\$7.00')), findsOneWidget);

      await tapId(tester, 'nav-personal-tab');
      expect(byId('transaction-item-$id'), findsOneWidget);
    });
  });

  group('the detail screen', () {
    testWidgets('says 입금 완료, shows a bank icon and a plus amount', (tester) async {
      final server = newServer()..everyone.add(depositItem('d1', amount: 1250));
      await pumpApp(tester, server);

      await tapId(tester, 'transaction-item-d1');

      expect(find.descendant(of: byId('transaction-status'), matching: find.text('입금 완료')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-sender-avatar'), matching: find.byIcon(Icons.account_balance)), findsOneWidget);
      expect(find.descendant(of: byId('transaction-amount-d1'), matching: find.text('+\$12.50')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-sender-d1'), matching: find.text('외부 입금')), findsOneWidget);
      // Nothing to accept or reject.
      expect(byId('transaction-accept-request-d1'), findsNothing);
    });
  });
  group('BankMoveSentence', () {
    test('the bank label: 은행 is added unless the name already says it', () {
      expect(BankMoveSentence.bankLabel(null), '은행 계좌로');
      expect(BankMoveSentence.bankLabel('   '), '은행 계좌로');
      expect(BankMoveSentence.bankLabel('KB'), 'KB 은행 계좌로');
      expect(BankMoveSentence.bankLabel('국민'), '국민 은행 계좌로');
      expect(BankMoveSentence.bankLabel('국민은행'), '국민은행 계좌로');
      expect(BankMoveSentence.bankLabel('Test Bank'), 'Test Bank 계좌로');
      expect(BankMoveSentence.bankLabel('test BANK'), 'test BANK 계좌로');
    });

    Widget wrap(Widget child, {double width = 360}) => MaterialApp(
          home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
        );

    testWidgets('입금 is green and 출금 is red', (tester) async {
      await tester.pumpWidget(wrap(const Column(children: [
        BankMoveSentence(id: 'a', bankName: 'KB'),
        BankMoveSentence(id: 'b', bankName: 'KB', deposit: false),
      ])));

      Color colorOfWord(String id) =>
          tester.widget<Text>(find.descendant(of: byId('transaction-bank-move-$id'), matching: find.byType(Text))).style!.color!;
      expect(find.descendant(of: byId('transaction-bank-move-a'), matching: find.text('입금')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-bank-move-b'), matching: find.text('출금')), findsOneWidget);
      expect(colorOfWord('a'), Colors.green.shade700);
      expect(colorOfWord('b'), Colors.red.shade700);
    });

    testWidgets('a very long bank name gets an ellipsis and the rest of the sentence stays', (tester) async {
      await tester.pumpWidget(wrap(
        const BankMoveSentence(id: 'x', bankName: 'The Very Long Named Savings And Loan Bank of Somewhere Far Away'),
        width: 260,
      ));

      expect(tester.takeException(), isNull); // no overflow stripes
      final name = tester.widget<Text>(find.descendant(of: byId('transaction-bank-name-x'), matching: find.byType(Text)));
      expect(name.overflow, TextOverflow.ellipsis);
      expect(name.maxLines, 1);
      expect(find.text(' 계좌로'), findsOneWidget);
      expect(find.text('입금'), findsOneWidget);
      expect(find.text(' 되었습니다.'), findsOneWidget);
      // The whole sentence fits in the width it was given.
      expect(tester.getSize(byId('transaction-bank-sentence-x')).width, lessThanOrEqualTo(260));
    });

    testWidgets('a short name takes only the room it needs', (tester) async {
      await tester.pumpWidget(wrap(const BankMoveSentence(id: 's', bankName: 'KB')));

      final name = tester.getSize(byId('transaction-bank-name-s')).width;
      expect(name, lessThan(100)); // "KB 은행", not the whole line
    });
  });
}
