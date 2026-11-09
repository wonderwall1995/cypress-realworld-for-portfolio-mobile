import 'package:cypress_realworld_for_personal_portfolio_mobile/app.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

final _year = DateTime.now().year;

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

Future<void> setDates(WidgetTester tester) async {
  containerOf(tester)
      .read(transactionFiltersProvider.notifier)
      .setDate(DateTime(_year, 3, 5), DateTime(_year, 3, 9));
  await tester.pumpAndSettle();
}

Map<String, dynamic> lastQuery(FakeServer s) => s.feedQueries.last;

void main() {
  group('the chips', () {
    testWidgets('start with 날짜 and 금액, nothing to clear, and no filter sent', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('transaction-list-filter-date-range-button'), matching: find.text('날짜')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-list-filter-amount-range-button'), matching: find.text('금액')), findsOneWidget);
      expect(byId('transaction-list-filter-date-clear-button'), findsNothing);
      expect(byId('transaction-list-filter-amount-clear-button'), findsNothing);
      expect(server.feedQueries.single, {'page': 1, 'limit': 10});
      expect(find.text('All A'), findsOneWidget);
    });

    testWidgets('sit under the tabs, not inside a list', (tester) async {
      await pumpApp(tester, newServer());

      final tabs = tester.getBottomLeft(byId('nav-transaction-tabs'));
      final chip = tester.getTopLeft(byId('transaction-list-filter-date-range-button'));
      expect(chip.dy, greaterThanOrEqualTo(tabs.dy));
    });
  });

  group('date', () {
    testWidgets('the chip shows the days, the list is loaded again with the filter, and x clears it',
        (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await setDates(tester);

      expect(find.descendant(of: byId('transaction-list-filter-date-range-button'), matching: find.text('3/5 - 3/9')), findsOneWidget);
      expect(lastQuery(server)['dateRangeStart'], DateTime(_year, 3, 5).toUtc().toIso8601String());
      expect(lastQuery(server)['dateRangeEnd'], DateTime(_year, 3, 9, 23, 59, 59, 999).toUtc().toIso8601String());
      expect(find.text('Only A'), findsOneWidget);
      expect(find.text('All B'), findsNothing);

      await tapId(tester, 'transaction-list-filter-date-clear-button');

      expect(lastQuery(server).containsKey('dateRangeStart'), isFalse);
      expect(find.text('All B'), findsOneWidget);
      expect(byId('transaction-list-filter-date-clear-button'), findsNothing);
    });

    testWidgets('tapping the chip opens the date range picker, and closing it changes nothing',
        (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await tapId(tester, 'transaction-list-filter-date-range-button');
      expect(find.text('기간 선택'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('기간 선택'), findsNothing);
      expect(server.feedQueries, hasLength(1));
    });

    testWidgets('picking two days in the picker sets the filter', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      await tapId(tester, 'transaction-list-filter-date-range-button');
      // The picker lists several months, top down. The first one is this month.
      await tester.tap(find.text('5').first);
      await tester.pump();
      await tester.tap(find.text('9').first);
      await tester.pump();
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(find.descendant(of: byId('transaction-list-filter-date-range-button'), matching: find.text('${now.month}/5 - ${now.month}/9')), findsOneWidget);
      expect(lastQuery(server)['dateRangeStart'], DateTime(now.year, now.month, 5).toUtc().toIso8601String());
    });
  });

  group('amount', () {
    testWidgets('the sheet starts at the whole range', (tester) async {
      await pumpApp(tester, newServer());

      await tapId(tester, 'transaction-list-filter-amount-range-button');

      expect(find.descendant(of: byId('transaction-list-filter-amount-range-text'), matching: find.text('금액 범위: \$0 - \$1,000')), findsOneWidget);
      expect(byId('transaction-list-filter-amount-range-slider'), findsOneWidget);
    });

    testWidgets('moving the slider changes the text; 적용 sets the filter in cents', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await tapId(tester, 'transaction-list-filter-amount-range-button');

      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(const RangeValues(2, 5));
      await tester.pump();
      expect(find.text('금액 범위: \$20 - \$50'), findsOneWidget);
      expect(server.feedQueries, hasLength(1)); // nothing is sent before 적용

      await tapId(tester, 'transaction-list-filter-amount-sheet-apply');

      expect(lastQuery(server)['amountMin'], '2000');
      expect(lastQuery(server)['amountMax'], '5000');
      expect(find.descendant(of: byId('transaction-list-filter-amount-range-button'), matching: find.text('\$20 - \$50')), findsOneWidget);
      expect(find.text('Only A'), findsOneWidget);
    });

    testWidgets('opening the sheet again shows the chosen range', (tester) async {
      await pumpApp(tester, newServer());
      await tapId(tester, 'transaction-list-filter-amount-range-button');
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(const RangeValues(2, 5));
      await tester.pump();
      await tapId(tester, 'transaction-list-filter-amount-sheet-apply');

      await tapId(tester, 'transaction-list-filter-amount-range-button');

      expect(find.text('금액 범위: \$20 - \$50'), findsOneWidget);
    });

    testWidgets('지우기 in the sheet and the x on the chip both clear it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      containerOf(tester).read(transactionFiltersProvider.notifier).setAmount(2, 5);
      await tester.pumpAndSettle();

      await tapId(tester, 'transaction-list-filter-amount-clear-button');
      expect(lastQuery(server).containsKey('amountMin'), isFalse);
      expect(find.text('All B'), findsOneWidget);

      containerOf(tester).read(transactionFiltersProvider.notifier).setAmount(1, 2);
      await tester.pumpAndSettle();
      await tapId(tester, 'transaction-list-filter-amount-range-button');
      await tapId(tester, 'transaction-list-filter-amount-sheet-clear');
      expect(lastQuery(server).containsKey('amountMin'), isFalse);
      expect(byId('transaction-list-filter-amount-clear-button'), findsNothing);
    });

    testWidgets('a minimum of 0 is sent as it is', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await tapId(tester, 'transaction-list-filter-amount-range-button');
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(const RangeValues(0, 5));
      await tester.pump();
      await tapId(tester, 'transaction-list-filter-amount-sheet-apply');

      expect(lastQuery(server)['amountMin'], '0');
      expect(lastQuery(server)['amountMax'], '5000');
    });
  });

  group('the three lists share the filters', () {
    testWidgets('another tab is loaded with the same filter', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await setDates(tester);

      await tapId(tester, 'nav-contacts-tab');

      final q = server.feedQueries.last;
      expect(server.feedRequests.last, '/transactions/contacts:1');
      expect(q['dateRangeStart'], DateTime(_year, 3, 5).toUtc().toIso8601String());
      // The chips are the same on this tab.
      expect(find.descendant(of: byId('transaction-list-filter-date-range-button'), matching: find.text('3/5 - 3/9')), findsOneWidget);
    });

    testWidgets('changing a filter loads the open list from the first page', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      final before = server.feedRequests.length;

      await setDates(tester);

      expect(server.feedRequests.length, before + 1);
      expect(server.feedRequests.last, '/transactions/public:1');
    });

    testWidgets('"load more" keeps the filter', (tester) async {
      final server = newServer()
        ..filtered.clear()
        ..filtered.addAll([for (var i = 1; i <= 12; i++) testTransaction('f$i', description: 'Match $i')]);
      await pumpApp(tester, server, size: const Size(800, 600));
      await setDates(tester);

      await tester.drag(byId('transaction-list'), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.drag(byId('transaction-list'), const Offset(0, -3000));
      await tester.pumpAndSettle();

      final page2 = server.feedQueries.where((q) => q['page'] == 2).toList();
      expect(page2, hasLength(1));
      expect(page2.single['dateRangeStart'], DateTime(_year, 3, 5).toUtc().toIso8601String());
    });
  });

  group('nothing matches', () {
    testWidgets('says so, offers 필터 지우기 (not 거래 만들기), and the button brings the list back',
        (tester) async {
      final server = newServer()..filtered.clear();
      await pumpApp(tester, server);

      await setDates(tester);

      expect(find.text('조건에 맞는 거래가 없습니다.'), findsOneWidget);
      expect(byId('transaction-list-filter-clear-all'), findsOneWidget);
      expect(byId('transaction-list-empty-create-transaction-button'), findsNothing);

      await tapId(tester, 'transaction-list-filter-clear-all');

      expect(find.text('All A'), findsOneWidget);
      expect(byId('transaction-list-filter-date-clear-button'), findsNothing);
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
      await setDates(tester);
      expect(byId('transaction-list-filter-date-clear-button'), findsOneWidget);

      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      await enter(tester, 'signin-username', 'someone');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');

      expect(byId('transaction-list-filter-date-clear-button'), findsNothing);
      expect(server.feedQueries.last.containsKey('dateRangeStart'), isFalse);
    });
  });
}
