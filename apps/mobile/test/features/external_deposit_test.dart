import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction.dart';
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
    );

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
    testWidgets('전체 shows the deposit as 외부 입금 with a plus sign, in green, with a bank icon', (tester) async {
      final server = newServer()..everyone.addAll([depositItem('d1'), testTransaction('a', description: 'Plain')]);
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('transaction-sender-d1'), matching: find.text('외부 입금')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-receiver-d1'), matching: find.text('Kim Ada')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-action-d1'), matching: find.text('입금')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-amount-d1'), matching: find.text('+\$7.00')), findsOneWidget);
      expect(colorOf(tester, 'd1'), Colors.green.shade700);
      // A bank icon, not the letter 외.
      expect(inRow('d1', find.byIcon(Icons.account_balance)), findsOneWidget);
      expect(inRow('d1', find.text('외')), findsNothing);
    });

    testWidgets('an ordinary payment still has a letter avatar, a minus sign and red', (tester) async {
      final server = newServer()..everyone.addAll([depositItem('d1'), testTransaction('a', amount: 2000)]);
      await pumpApp(tester, server);

      expect(inRow('a', find.byIcon(Icons.account_balance)), findsNothing);
      expect(inRow('a', find.text('A')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-amount-a'), matching: find.text('-\$20.00')), findsOneWidget);
      expect(colorOf(tester, 'a'), Colors.red.shade700);
      expect(find.descendant(of: byId('transaction-action-a'), matching: find.text('결제')), findsOneWidget);
    });

    testWidgets('내 거래 shows it, and 친구 does not (the server decides what each tab holds)', (tester) async {
      final server = newServer()
        ..mine.add(depositItem('d1'))
        ..friends.add(testTransaction('f', description: 'Friend item'));
      await pumpApp(tester, server);

      await tapId(tester, 'nav-personal-tab');
      expect(byId('transaction-item-d1'), findsOneWidget);

      await tapId(tester, 'nav-contacts-tab');
      expect(byId('transaction-item-d1'), findsNothing);
      expect(find.text('Friend item'), findsOneWidget);
    });
  });

  group('depositing', () {
    testWidgets('a deposit shows up in 전체 and 내 거래 at once, and not in 친구', (tester) async {
      final server = newServer()..friends.add(testTransaction('f', description: 'Friend item'));
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

      await tapId(tester, 'nav-contacts-tab');
      expect(byId('transaction-item-$id'), findsNothing);
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
      expect(find.descendant(of: byId('transaction-action-d1'), matching: find.text('입금')), findsOneWidget);
      // Nothing to accept or reject.
      expect(byId('transaction-accept-request-d1'), findsNothing);
    });
  });
}
