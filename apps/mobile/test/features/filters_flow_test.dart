import 'package:cypress_realworld_for_personal_portfolio_mobile/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// Everyone has "All A" and "All B". With a filter, the server returns "Only A".
FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')])
  ..everyone.addAll([
    testTransaction('a', description: 'All A'),
    testTransaction('b', description: 'All B'),
  ])
  ..friends.add(testTransaction('f', description: 'Friend item'))
  ..filtered.add(testTransaction('a', description: 'Only A'));

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(App)));

Map<String, dynamic> lastQuery(FakeServer s) => s.feedQueries.last;

const _date = 'transaction-list-filter-date';

String _id(String box, String part) => '$_date-$box-$part';

/// Types a day into one of the two boxes. [box] is `start` or `end`.
Future<void> typeDay(WidgetTester tester, String box, String year, String month, String day) async {
  await enter(tester, _id(box, 'year'), year);
  await enter(tester, _id(box, 'month'), month);
  await enter(tester, _id(box, 'day'), day);
}

/// The date filter is applied a moment (400 ms) after the boxes are right.
Future<void> waitForApply(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String id) =>
    tester.widget<TextFormField>(fieldIn(id)).controller!.text;

Finder chipLabel(String kind, String label) =>
    find.descendant(of: byId('transaction-list-filter-$kind-button'), matching: find.text(label));

Future<void> openSheet(WidgetTester tester, String kind) => tapId(tester, 'transaction-list-filter-$kind-button');

Future<void> fillSheet(WidgetTester tester, String kind, {String min = '', String max = ''}) async {
  await enter(tester, 'transaction-list-filter-$kind-min', min);
  await enter(tester, 'transaction-list-filter-$kind-max', max);
  await tester.pump();
}

Future<void> applySheet(WidgetTester tester, String kind) =>
    tapId(tester, 'transaction-list-filter-$kind-apply-button');

bool applyEnabled(WidgetTester tester, String kind) => tester
    .widget<FilledButton>(find.descendant(of: byId('transaction-list-filter-$kind-apply-button'), matching: find.byType(FilledButton)))
    .onPressed != null;

String sheetMessage(WidgetTester tester, String kind) => tester
    .widget<Text>(find.descendant(of: byId('transaction-list-filter-$kind-message'), matching: find.byType(Text)))
    .data!
    .trim();

/// A valid range in the boxes, applied.
Future<void> applyDates(WidgetTester tester) async {
  await typeDay(tester, 'start', '2026', '03', '05');
  await typeDay(tester, 'end', '2026', '03', '09');
  await waitForApply(tester);
}

void main() {
  group('the filter bar', () {
    testWidgets('starts with two date boxes and two chips on 전체, and no filter sent', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      expect(byId('$_date-start-box'), findsOneWidget);
      expect(byId('$_date-end-box'), findsOneWidget);
      expect(chipLabel('deposit', '입금 금액: 전체'), findsOneWidget);
      expect(chipLabel('withdrawal', '출금 금액: 전체'), findsOneWidget);
      for (final id in ['$_date-clear-button', 'transaction-list-filter-deposit-clear-button', 'transaction-list-filter-withdrawal-clear-button']) {
        expect(byId(id), findsNothing, reason: id);
      }
      expect(server.feedQueries.single, {'page': 1, 'limit': 10});
      expect(find.text('All A'), findsOneWidget);
    });

    testWidgets('has no calendar and no slider any more', (tester) async {
      await pumpApp(tester, newServer());

      expect(byId('transaction-list-filter-date-range-button'), findsNothing);
      expect(byId('transaction-list-filter-amount-range-button'), findsNothing);
      expect(find.byType(RangeSlider), findsNothing);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
    });

    testWidgets('sits under the tabs, in one outlined group', (tester) async {
      await pumpApp(tester, newServer());

      final tabs = tester.getBottomLeft(byId('nav-transaction-tabs'));
      final group = tester.getRect(byId('transaction-list-filters'));
      expect(group.top, greaterThanOrEqualTo(tabs.dy));
      for (final id in ['$_date-start-box', '$_date-end-box', 'transaction-list-filter-deposit-button', 'transaction-list-filter-withdrawal-button']) {
        final r = tester.getRect(byId(id));
        expect(group.contains(r.topLeft) && group.contains(r.bottomRight), isTrue, reason: id);
      }
    });
  });

  group('date boxes', () {
    testWidgets('a valid range is applied after a moment, sent as exact moments; 초기화 clears it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      final before = server.feedRequests.length;

      await typeDay(tester, 'start', '2026', '03', '05');
      await typeDay(tester, 'end', '2026', '03', '09');
      await tester.pump(const Duration(milliseconds: 300));
      // Not yet: it waits 400 ms after the last key.
      expect(server.feedRequests.length, before);

      await waitForApply(tester);

      expect(server.feedRequests.length, before + 1);
      expect(lastQuery(server)['dateRangeStart'], DateTime(2026, 3, 5).toUtc().toIso8601String());
      expect(lastQuery(server)['dateRangeEnd'], DateTime(2026, 3, 9, 23, 59, 59, 999).toUtc().toIso8601String());
      expect(find.text('Only A'), findsOneWidget);
      expect(find.text('All B'), findsNothing);
      expect(byId('$_date-message'), findsNothing);

      await tester.tap(byId('$_date-clear-button'));
      await waitForApply(tester);

      expect(lastQuery(server).containsKey('dateRangeStart'), isFalse);
      expect(lastQuery(server).containsKey('dateRangeEnd'), isFalse);
      expect(find.text('All B'), findsOneWidget);
      expect(byId('$_date-clear-button'), findsNothing);
      expect(textOf(tester, _id('start', 'year')), '');
      expect(textOf(tester, _id('end', 'day')), '');
    });

    testWidgets('only a start day means from that day on', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await typeDay(tester, 'start', '2026', '03', '05');
      await waitForApply(tester);

      expect(lastQuery(server)['dateRangeStart'], DateTime(2026, 3, 5).toUtc().toIso8601String());
      expect(lastQuery(server).containsKey('dateRangeEnd'), isFalse);
      expect(byId('$_date-message'), findsNothing);
    });

    testWidgets('only an end day means up to that day', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await typeDay(tester, 'end', '2026', '03', '09');
      await waitForApply(tester);

      expect(lastQuery(server).containsKey('dateRangeStart'), isFalse);
      expect(lastQuery(server)['dateRangeEnd'], DateTime(2026, 3, 9, 23, 59, 59, 999).toUtc().toIso8601String());
    });

    testWidgets('the same day in both boxes is one whole day and is allowed', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await typeDay(tester, 'start', '2026', '03', '05');
      await typeDay(tester, 'end', '2026', '03', '05');
      await waitForApply(tester);

      expect(byId('$_date-message'), findsNothing);
      expect(lastQuery(server)['dateRangeStart'], DateTime(2026, 3, 5).toUtc().toIso8601String());
      expect(lastQuery(server)['dateRangeEnd'], DateTime(2026, 3, 5, 23, 59, 59, 999).toUtc().toIso8601String());
    });

    testWidgets('a start after the end is refused with a message, and the filter on stays', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await applyDates(tester);
      final count = server.feedRequests.length;

      await typeDay(tester, 'start', '2026', '03', '10');
      await waitForApply(tester);

      expect(find.descendant(of: byId('$_date-message'), matching: find.text('시작일이 종료일보다 늦을 수 없습니다')), findsOneWidget);
      expect(server.feedRequests.length, count);
      expect(find.text('Only A'), findsOneWidget);

      // Fixing it applies the new range and removes the message.
      await typeDay(tester, 'start', '2026', '03', '08');
      await waitForApply(tester);
      expect(byId('$_date-message'), findsNothing);
      expect(lastQuery(server)['dateRangeStart'], DateTime(2026, 3, 8).toUtc().toIso8601String());
    });

    testWidgets('a box with only some fields says what is missing and sends nothing', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      final count = server.feedRequests.length;

      await enter(tester, _id('start', 'year'), '2026');
      await waitForApply(tester);

      expect(find.text('시작일의 연·월·일을 모두 입력하세요'), findsOneWidget);
      expect(server.feedRequests.length, count);
    });

    testWidgets('a day that does not exist is refused', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      final count = server.feedRequests.length;

      await typeDay(tester, 'end', '2026', '02', '30');
      await waitForApply(tester);

      expect(find.text('종료일: 존재하지 않는 날짜입니다'), findsOneWidget);
      expect(server.feedRequests.length, count);
    });

    testWidgets('a year with fewer than 4 digits is refused', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      final count = server.feedRequests.length;

      await typeDay(tester, 'start', '26', '03', '05');
      await waitForApply(tester);

      expect(find.text('시작일: 연도는 4자리, 월·일은 1~2자리 숫자로 입력하세요'), findsOneWidget);
      expect(server.feedRequests.length, count);
    });

    testWidgets('only digits are accepted, and each field has a length limit', (tester) async {
      await pumpApp(tester, newServer());

      await enter(tester, _id('start', 'year'), '20a2b6c7');
      await enter(tester, _id('start', 'month'), '1234');
      expect(textOf(tester, _id('start', 'year')), '2026');
      expect(textOf(tester, _id('start', 'month')), '12');
      await enter(tester, _id('start', 'day'), 'ab');
      expect(textOf(tester, _id('start', 'day')), '');
    });

    testWidgets('a pasted date fills the three fields', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await enter(tester, _id('start', 'year'), '2026/3/5');
      await waitForApply(tester);

      expect(textOf(tester, _id('start', 'year')), '2026');
      expect(textOf(tester, _id('start', 'month')), '03');
      expect(textOf(tester, _id('start', 'day')), '05');
      expect(lastQuery(server)['dateRangeStart'], DateTime(2026, 3, 5).toUtc().toIso8601String());
    });

    testWidgets('a pasted date with hyphens or dots works too', (tester) async {
      await pumpApp(tester, newServer());

      await enter(tester, _id('end', 'year'), '2026-11-09');
      expect([textOf(tester, _id('end', 'year')), textOf(tester, _id('end', 'month')), textOf(tester, _id('end', 'day'))], ['2026', '11', '09']);
      await enter(tester, _id('end', 'year'), '2027.01.02');
      expect([textOf(tester, _id('end', 'year')), textOf(tester, _id('end', 'month')), textOf(tester, _id('end', 'day'))], ['2027', '01', '02']);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('one digit in the month shows as two digits when the cursor leaves', (tester) async {
      await pumpApp(tester, newServer());

      await enter(tester, _id('start', 'month'), '3');
      await tester.tap(fieldIn(_id('start', 'day')));
      await tester.pump();

      expect(textOf(tester, _id('start', 'month')), '03');
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('a full field moves the cursor on', (tester) async {
      await pumpApp(tester, newServer());

      await enter(tester, _id('start', 'year'), '2026');
      await tester.pump();

      final month = tester.widget<TextFormField>(fieldIn(_id('start', 'month')));
      final node = tester.widget<EditableText>(find.descendant(of: fieldIn(_id('start', 'month')), matching: find.byType(EditableText))).focusNode;
      expect(month, isNotNull);
      expect(node.hasFocus, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('a wrong box is marked, the other box is not', (tester) async {
      await pumpApp(tester, newServer());

      await typeDay(tester, 'end', '2026', '02', '30');
      await tester.pump();

      Color borderOf(String box) {
        final container = tester.widget<Container>(find.descendant(of: byId('$_date-$box-box'), matching: find.byType(Container)).first);
        return ((container.decoration! as BoxDecoration).border! as Border).top.color;
      }

      final colors = Theme.of(tester.element(byId('$_date-end-box'))).colorScheme;
      expect(borderOf('end'), colors.error);
      expect(borderOf('start'), isNot(colors.error));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('emptying the boxes by hand removes the filter', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await applyDates(tester);

      for (final box in ['start', 'end']) {
        for (final part in ['year', 'month', 'day']) {
          await enter(tester, _id(box, part), '');
        }
      }
      await waitForApply(tester);

      expect(lastQuery(server).containsKey('dateRangeStart'), isFalse);
      expect(find.text('All B'), findsOneWidget);
    });
  });

  group('amount chips', () {
    testWidgets('a chip opens a sheet that says what the amount means', (tester) async {
      await pumpApp(tester, newServer());

      await openSheet(tester, 'deposit');
      expect(byId('transaction-list-filter-deposit'), findsOneWidget);
      final sheet = byId('transaction-list-filter-deposit');
      expect(find.descendant(of: sheet, matching: find.textContaining('입금 금액 (내가 받은 돈)', findRichText: true)), findsOneWidget);
      expect(byId('transaction-list-filter-deposit-min'), findsOneWidget);
      expect(byId('transaction-list-filter-deposit-max'), findsOneWidget);
      expect(find.text('입금과 출금을 둘 다 켜면, 둘 중 하나에 맞는 거래가 보입니다.'), findsOneWidget);

      await tapId(tester, 'transaction-list-filter-deposit-close-button');
      await openSheet(tester, 'withdrawal');
      expect(find.descendant(of: byId('transaction-list-filter-withdrawal'), matching: find.textContaining('출금 금액 (내가 보낸 돈)', findRichText: true)), findsOneWidget);
    });

    testWidgets('the boxes hint 0 and 제한 없음', (tester) async {
      await pumpApp(tester, newServer());
      await openSheet(tester, 'deposit');

      String? hint(String id) => tester.widget<TextField>(find.descendant(of: byId(id), matching: find.byType(TextField))).decoration!.hintText;
      expect(hint('transaction-list-filter-deposit-min'), '0');
      expect(hint('transaction-list-filter-deposit-max'), '제한 없음');
    });

    testWidgets('a minimum above the maximum (1000 ~ 100) is refused and 적용 is off', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSheet(tester, 'deposit');
      final count = server.feedRequests.length;

      await fillSheet(tester, 'deposit', min: '1000', max: '100');

      expect(sheetMessage(tester, 'deposit'), '최소 금액이 최대 금액보다 클 수 없습니다');
      expect(applyEnabled(tester, 'deposit'), isFalse);
      await tester.tap(byId('transaction-list-filter-deposit-apply-button'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(server.feedRequests.length, count);
      expect(byId('transaction-list-filter-deposit'), findsOneWidget); // still open
    });

    testWidgets('the same number twice (100 ~ 100) is allowed and means exactly that amount', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSheet(tester, 'deposit');

      await fillSheet(tester, 'deposit', min: '100', max: '100');
      expect(sheetMessage(tester, 'deposit'), '');
      expect(applyEnabled(tester, 'deposit'), isTrue);
      await applySheet(tester, 'deposit');

      expect(lastQuery(server)['depositMin'], '10000');
      expect(lastQuery(server)['depositMax'], '10000');
      expect(chipLabel('deposit', '입금 금액: \$100'), findsOneWidget);
      expect(byId('transaction-list-filter-deposit'), findsNothing); // closed
      expect(find.text('Only A'), findsOneWidget);
    });

    testWidgets('an empty minimum means 0: "0 ... maximum"', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSheet(tester, 'withdrawal');

      await fillSheet(tester, 'withdrawal', max: '50');
      await applySheet(tester, 'withdrawal');

      expect(lastQuery(server)['withdrawalMin'], '0');
      expect(lastQuery(server)['withdrawalMax'], '5000');
      expect(chipLabel('withdrawal', '출금 금액: \$0 ~ \$50'), findsOneWidget);
    });

    testWidgets('only a minimum has no upper limit', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSheet(tester, 'deposit');

      await fillSheet(tester, 'deposit', min: '5');
      await applySheet(tester, 'deposit');

      expect(lastQuery(server)['depositMin'], '500');
      expect(lastQuery(server).containsKey('depositMax'), isFalse);
      expect(chipLabel('deposit', '입금 금액: \$5 이상'), findsOneWidget);
    });

    testWidgets('a range shows on the chip, with thousands separators', (tester) async {
      await pumpApp(tester, newServer());
      await openSheet(tester, 'deposit');

      await fillSheet(tester, 'deposit', min: '1,000', max: '2500');
      await applySheet(tester, 'deposit');

      expect(chipLabel('deposit', '입금 금액: \$1,000 ~ \$2,500'), findsOneWidget);
    });

    testWidgets('letters, decimals and signs are refused', (tester) async {
      await pumpApp(tester, newServer());
      await openSheet(tester, 'deposit');

      for (final bad in ['abc', '1.5', '-5', '0x10']) {
        await fillSheet(tester, 'deposit', min: bad);
        expect(sheetMessage(tester, 'deposit'), '숫자(정수)만 입력하세요', reason: bad);
        expect(applyEnabled(tester, 'deposit'), isFalse, reason: bad);
      }
    });

    testWidgets('above 21,474,836 dollars is refused; that number itself is fine', (tester) async {
      await pumpApp(tester, newServer());
      await openSheet(tester, 'deposit');

      await fillSheet(tester, 'deposit', max: '21474837');
      expect(sheetMessage(tester, 'deposit'), '21,474,836 이하로 입력하세요');
      expect(applyEnabled(tester, 'deposit'), isFalse);

      await fillSheet(tester, 'deposit', max: '21474836');
      expect(sheetMessage(tester, 'deposit'), '');
      expect(applyEnabled(tester, 'deposit'), isTrue);
    });

    testWidgets('both boxes empty and 적용 removes the filter', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '5', max: '9');
      await applySheet(tester, 'deposit');
      expect(chipLabel('deposit', '입금 금액: \$5 ~ \$9'), findsOneWidget);

      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit');
      await applySheet(tester, 'deposit');

      expect(chipLabel('deposit', '입금 금액: 전체'), findsOneWidget);
      expect(lastQuery(server).containsKey('depositMin'), isFalse);
    });

    testWidgets('the sheet starts from what is applied, and an empty minimum stays empty', (tester) async {
      await pumpApp(tester, newServer());
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', max: '50');
      await applySheet(tester, 'deposit');

      await openSheet(tester, 'deposit');

      expect(textOf(tester, 'transaction-list-filter-deposit-min'), '');
      expect(textOf(tester, 'transaction-list-filter-deposit-max'), '50');
    });

    testWidgets('초기화 in the sheet and the x on the chip both clear it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '1', max: '2');
      await applySheet(tester, 'deposit');

      await openSheet(tester, 'deposit');
      await tapId(tester, 'transaction-list-filter-deposit-reset-button');
      expect(chipLabel('deposit', '입금 금액: 전체'), findsOneWidget);
      expect(byId('transaction-list-filter-deposit'), findsNothing);

      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '1', max: '2');
      await applySheet(tester, 'deposit');
      await tapId(tester, 'transaction-list-filter-deposit-clear-button');
      expect(chipLabel('deposit', '입금 금액: 전체'), findsOneWidget);
      expect(byId('transaction-list-filter-deposit-clear-button'), findsNothing);
      expect(lastQuery(server).containsKey('depositMin'), isFalse);
    });

    testWidgets('닫기 closes the sheet and changes nothing', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      final count = server.feedRequests.length;
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '1', max: '2');

      await tapId(tester, 'transaction-list-filter-deposit-close-button');

      expect(byId('transaction-list-filter-deposit'), findsNothing);
      expect(chipLabel('deposit', '입금 금액: 전체'), findsOneWidget);
      expect(server.feedRequests.length, count);
    });

    testWidgets('deposit and withdrawal are separate, and both are sent together', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '10', max: '20');
      await applySheet(tester, 'deposit');
      await openSheet(tester, 'withdrawal');
      await fillSheet(tester, 'withdrawal', min: '30', max: '40');
      await applySheet(tester, 'withdrawal');

      expect(lastQuery(server), containsPair('depositMin', '1000'));
      expect(lastQuery(server), containsPair('depositMax', '2000'));
      expect(lastQuery(server), containsPair('withdrawalMin', '3000'));
      expect(lastQuery(server), containsPair('withdrawalMax', '4000'));

      // Clearing one keeps the other.
      await tapId(tester, 'transaction-list-filter-deposit-clear-button');
      expect(lastQuery(server).containsKey('depositMin'), isFalse);
      expect(lastQuery(server), containsPair('withdrawalMin', '3000'));
      expect(chipLabel('withdrawal', '출금 금액: \$30 ~ \$40'), findsOneWidget);
    });

    testWidgets('the old amountMin and amountMax are never sent', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '1', max: '2');
      await applySheet(tester, 'deposit');

      expect(server.feedQueries.every((q) => !q.keys.any((k) => k.startsWith('amount'))), isTrue);
    });

    testWidgets('dates and amounts work together', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await applyDates(tester);

      await openSheet(tester, 'withdrawal');
      await fillSheet(tester, 'withdrawal', min: '1', max: '2');
      await applySheet(tester, 'withdrawal');

      expect(lastQuery(server), containsPair('dateRangeStart', DateTime(2026, 3, 5).toUtc().toIso8601String()));
      expect(lastQuery(server), containsPair('withdrawalMax', '200'));
    });
  });

  group('lists', () {
    testWidgets('another tab is loaded with the same filter', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await applyDates(tester);
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '1', max: '2');
      await applySheet(tester, 'deposit');

      await tapId(tester, 'nav-contacts-tab');

      expect(server.feedRequests.last, '/transactions/contacts:1');
      expect(lastQuery(server)['dateRangeStart'], DateTime(2026, 3, 5).toUtc().toIso8601String());
      expect(lastQuery(server)['depositMax'], '200');
      // The boxes and chips are the same on this tab.
      expect(textOf(tester, _id('start', 'year')), '2026');
      expect(chipLabel('deposit', '입금 금액: \$1 ~ \$2'), findsOneWidget);
    });

    testWidgets('changing a filter loads the open list from the first page', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      final before = server.feedRequests.length;

      await applyDates(tester);

      expect(server.feedRequests.length, before + 1);
      expect(server.feedRequests.last, '/transactions/public:1');
    });

    testWidgets('"load more" keeps the filter', (tester) async {
      final server = newServer()
        ..filtered.clear()
        ..filtered.addAll([for (var i = 1; i <= 12; i++) testTransaction('f$i', description: 'Match $i')]);
      await pumpApp(tester, server, size: const Size(800, 600));
      await applyDates(tester);

      await tester.drag(byId('transaction-list'), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.drag(byId('transaction-list'), const Offset(0, -3000));
      await tester.pumpAndSettle();

      final page2 = server.feedQueries.where((q) => q['page'] == 2).toList();
      expect(page2, hasLength(1));
      expect(page2.single['dateRangeStart'], DateTime(2026, 3, 5).toUtc().toIso8601String());
    });
  });

  group('nothing matches', () {
    testWidgets('says so, offers 필터 지우기 (not 거래 만들기), and the button brings the list back and empties the boxes', (tester) async {
      final server = newServer()..filtered.clear();
      await pumpApp(tester, server);

      await applyDates(tester);

      expect(find.text('조건에 맞는 거래가 없습니다.'), findsOneWidget);
      expect(byId('transaction-list-filter-clear-all'), findsOneWidget);
      expect(byId('transaction-list-empty-create-transaction-button'), findsNothing);

      await tapId(tester, 'transaction-list-filter-clear-all');

      expect(find.text('All A'), findsOneWidget);
      expect(byId('$_date-clear-button'), findsNothing);
      expect(textOf(tester, _id('start', 'year')), '');
      expect(textOf(tester, _id('end', 'day')), '');
      expect(lastQuery(server).containsKey('dateRangeStart'), isFalse);
    });

    testWidgets('필터 지우기 also clears the amount chips', (tester) async {
      final server = newServer()..filtered.clear();
      await pumpApp(tester, server);
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '1', max: '2');
      await applySheet(tester, 'deposit');
      expect(find.text('조건에 맞는 거래가 없습니다.'), findsOneWidget);

      await tapId(tester, 'transaction-list-filter-clear-all');

      expect(chipLabel('deposit', '입금 금액: 전체'), findsOneWidget);
      expect(find.text('All A'), findsOneWidget);
    });

    testWidgets('an empty list without filters still offers 거래 만들기', (tester) async {
      final server = FakeServer(signedIn: true, accounts: [testAccount('b1')]);
      await pumpApp(tester, server);

      expect(find.text('거래가 없습니다.'), findsOneWidget);
      expect(byId('transaction-list-empty-create-transaction-button'), findsOneWidget);
      expect(byId('transaction-list-filter-clear-all'), findsNothing);
    });
  });

  group('another user', () {
    testWidgets('the filters start again after signing out and in', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await applyDates(tester);
      await openSheet(tester, 'deposit');
      await fillSheet(tester, 'deposit', min: '1', max: '2');
      await applySheet(tester, 'deposit');
      expect(byId('$_date-clear-button'), findsOneWidget);

      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      await enter(tester, 'signin-username', 'someone');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');

      expect(byId('$_date-clear-button'), findsNothing);
      expect(textOf(tester, _id('start', 'year')), '');
      expect(chipLabel('deposit', '입금 금액: 전체'), findsOneWidget);
      expect(server.feedQueries.last.keys.where((k) => k.startsWith('dateRange') || k.startsWith('deposit')), isEmpty);
    });
  });
}
