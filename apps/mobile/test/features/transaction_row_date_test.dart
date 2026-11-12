import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// The day as the phone shows it: the time converted to the local time zone.
String localDay(String iso) {
  final t = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)}';
}

Map<String, dynamic> depositItem(String id, String createdAt) => testTransaction(
      id,
      sender: '외부 입금',
      receiver: 'Kim Ada',
      description: '외부 입금',
      amount: 700,
      senderId: 'external-deposit',
      receiverId: 'u1',
      createdAt: createdAt,
    )..['source'] = 'b1';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')]);

TextStyle styleOf(WidgetTester tester, Finder f) => tester.widget<Text>(f).style ?? const TextStyle();

void main() {
  group('Transaction.dateLabel', () {
    test('is the day as YYYY/MM/DD on the phone calendar', () {
      for (final iso in ['2026-11-10T03:04:05.000Z', '2026-01-02T12:00:00.000Z', '2025-12-31T23:30:00.000Z']) {
        expect(Transaction.fromJson(testTransaction('a', createdAt: iso)).dateLabel, localDay(iso), reason: iso);
      }
    });

    test('has two digits for the month and the day', () {
      final label = Transaction.fromJson(testTransaction('a', createdAt: '2026-03-05T12:00:00.000Z')).dateLabel!;
      expect(RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(label), isTrue, reason: label);
    });

    test('is null when the server sends no time', () {
      final json = testTransaction('a')..remove('createdAt');
      expect(Transaction.fromJson(json).dateLabel, isNull);
      expect(Transaction.fromJson({...json, 'createdAt': 'not a date'}).dateLabel, isNull);
    });
  });

  group('the row in the home list', () {
    testWidgets('an ordinary row: the day first, then the name line, then the description', (tester) async {
      const iso = '2026-03-05T12:00:00.000Z';
      final server = newServer()..everyone.add(testTransaction('a', description: 'Lunch', createdAt: iso));
      await pumpApp(tester, server);

      final date = tester.getTopLeft(byId('transaction-date-a')).dy;
      final name = tester.getTopLeft(byId('transaction-title-a')).dy;
      final description = tester.getTopLeft(find.descendant(of: byId('transaction-item-a'), matching: find.text('Lunch'))).dy;
      expect(date, lessThan(name));
      expect(name, lessThan(description));
      expect(find.descendant(of: byId('transaction-date-a'), matching: find.text(localDay(iso))), findsOneWidget);
    });

    testWidgets('a deposit row: the day, then 외부 입금, then the bank sentence, then the likes', (tester) async {
      const iso = '2026-11-10T03:04:05.000Z';
      final server = newServer()..everyone.add(depositItem('d1', iso));
      await pumpApp(tester, server);

      final date = tester.getTopLeft(byId('transaction-date-d1')).dy;
      final name = tester.getTopLeft(byId('transaction-sender-d1')).dy;
      final sentence = tester.getTopLeft(byId('transaction-bank-sentence-d1')).dy;
      final likes = tester.getTopLeft(find.descendant(of: byId('transaction-item-d1'), matching: find.byIcon(Icons.favorite_border))).dy;
      expect(date, lessThan(name));
      expect(name, lessThan(sentence));
      expect(sentence, lessThan(likes));
      expect(find.descendant(of: byId('transaction-date-d1'), matching: find.text(localDay(iso))), findsOneWidget);
    });

    testWidgets('the day is 1.3 times the small text; the name stays the biggest', (tester) async {
      final server = newServer()..everyone.add(depositItem('d1', '2026-11-10T03:04:05.000Z'));
      await pumpApp(tester, server);

      final theme = Theme.of(tester.element(byId('transaction-item-d1')));
      final small = theme.textTheme.bodySmall!.fontSize!;
      final dateSize = styleOf(tester, find.descendant(of: byId('transaction-date-d1'), matching: find.byType(Text))).fontSize!;
      final nameSize = styleOf(tester, find.descendant(of: byId('transaction-sender-d1'), matching: find.byType(Text))).fontSize
          ?? theme.textTheme.titleMedium!.fontSize!;
      final sentenceSize = theme.textTheme.bodyMedium!.fontSize!;

      expect(dateSize, closeTo(small * 1.3, 0.01));
      expect(nameSize, greaterThan(dateSize));
      expect(dateSize, greaterThan(sentenceSize));
    });

    testWidgets('every row has its own day, also ordinary payments', (tester) async {
      final server = newServer()
        ..everyone.addAll([
          testTransaction('a', createdAt: '2026-03-05T12:00:00.000Z'),
          testTransaction('b', createdAt: '2026-04-06T12:00:00.000Z'),
        ]);
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('transaction-date-a'), matching: find.text(localDay('2026-03-05T12:00:00.000Z'))), findsOneWidget);
      expect(find.descendant(of: byId('transaction-date-b'), matching: find.text(localDay('2026-04-06T12:00:00.000Z'))), findsOneWidget);
    });

    testWidgets('a row without a time from the server has no day line', (tester) async {
      final item = testTransaction('a')..remove('createdAt');
      final server = newServer()..everyone.add(item);
      await pumpApp(tester, server);

      expect(byId('transaction-item-a'), findsOneWidget);
      expect(byId('transaction-date-a'), findsNothing);
    });

    testWidgets('the same on the 내 거래 tab', (tester) async {
      const iso = '2026-07-08T12:00:00.000Z';
      final server = newServer()..mine.add(depositItem('d2', iso));
      await pumpApp(tester, server);

      await tapId(tester, 'nav-personal-tab');

      expect(find.descendant(of: byId('transaction-date-d2'), matching: find.text(localDay(iso))), findsOneWidget);
    });
  });
}
