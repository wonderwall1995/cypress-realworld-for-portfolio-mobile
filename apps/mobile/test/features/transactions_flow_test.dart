import 'dart:async';

import 'package:cypress_realworld_for_personal_portfolio_mobile/app.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/transactions/transaction_feed_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// A signed-in user who has a bank account (so no first-time setup).
FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')]);

/// Twelve payments: more than one page of 10.
List<Map<String, dynamic>> twelve() => [
      for (var i = 1; i <= 12; i++)
        testTransaction('t$i', description: 'Payment $i', amount: i * 100),
    ];

const _small = Size(800, 600);

Future<void> scrollList(WidgetTester tester, double dy) async {
  await tester.drag(byId('transaction-list'), Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  group('tabs', () {
    testWidgets('home shows 3 tabs and loads only the first list', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);

      expect(byId('nav-transaction-tabs'), findsOneWidget);
      for (final id in ['nav-public-tab', 'nav-contacts-tab', 'nav-personal-tab']) {
        expect(byId(id), findsOneWidget, reason: id);
      }
      expect(find.text('전체'), findsOneWidget);
      expect(find.text('친구'), findsOneWidget);
      expect(find.text('내 거래'), findsOneWidget);
      expect(server.feedRequests, ['/transactions/public:1']);
    });

    testWidgets('each tab loads its own list, once', (tester) async {
      final server = newServer()
        ..everyone.add(testTransaction('e1', description: 'Everyone item'))
        ..friends.add(testTransaction('f1', description: 'Friends item'))
        ..mine.add(testTransaction('m1', description: 'Mine item'));
      await pumpApp(tester, server);
      expect(find.text('Everyone item'), findsOneWidget);

      await tapId(tester, 'nav-contacts-tab');
      expect(find.text('Friends item'), findsOneWidget);

      await tapId(tester, 'nav-personal-tab');
      expect(find.text('Mine item'), findsOneWidget);

      // Back to the first tab: the list is kept, not loaded again.
      await tapId(tester, 'nav-public-tab');
      expect(find.text('Everyone item'), findsOneWidget);
      expect(server.feedRequests, [
        '/transactions/public:1',
        '/transactions/contacts:1',
        '/transactions:1',
      ]);
    });
  });

  group('list item', () {
    testWidgets('shows names, action, amount and counts like the web', (tester) async {
      final server = newServer()
        ..everyone.addAll([
          testTransaction('p1', sender: 'Alice Test', receiver: 'Bob Test',
              description: 'Dinner', amount: 123456, likes: 2, comments: 3),
          testTransaction('r1', sender: 'Bob Test', receiver: 'Alice Test',
              description: 'Please pay', amount: 700, requestStatus: 'pending', status: 'pending'),
          testTransaction('r2', sender: 'Cara Test', receiver: 'Alice Test',
              description: 'Charged one', amount: 250, requestStatus: 'accepted'),
        ]);
      await pumpApp(tester, server);

      // A payment: "-" and the "결제" word, amount with a thousands separator.
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.descendant(of: byId('transaction-amount-p1'), matching: find.text('-\$1,234.56')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-action-p1'), matching: find.text('결제')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-sender-p1'), matching: find.text('Alice Test')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-receiver-p1'), matching: find.text('Bob Test')), findsOneWidget);
      final p1 = byId('transaction-item-p1');
      expect(find.descendant(of: p1, matching: find.text('2')), findsOneWidget); // likes
      expect(find.descendant(of: p1, matching: find.text('3')), findsOneWidget); // comments

      // A pending request: "+" and "요청".
      expect(find.descendant(of: byId('transaction-amount-r1'), matching: find.text('+\$7.00')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-action-r1'), matching: find.text('요청')), findsOneWidget);

      // An accepted request: "청구" (the web says "charged").
      expect(find.descendant(of: byId('transaction-action-r2'), matching: find.text('청구')), findsOneWidget);
    });

    testWidgets('an empty list says so', (tester) async {
      await pumpApp(tester, newServer());

      expect(byId('transaction-list-empty'), findsOneWidget);
      expect(find.text('거래가 없습니다.'), findsOneWidget);
    });
  });

  group('loading', () {
    testWidgets('scrolling to the end loads the next 10', (tester) async {
      final server = newServer()..everyone.addAll(twelve());
      await pumpApp(tester, server, size: _small);

      expect(byId('transaction-item-t1'), findsOneWidget);
      expect(byId('transaction-item-t12'), findsNothing);
      expect(server.feedRequests, ['/transactions/public:1']);

      await scrollList(tester, -3000); // reach the end: the footer starts page 2
      await scrollList(tester, -3000);

      expect(server.feedRequests, ['/transactions/public:1', '/transactions/public:2']);
      expect(byId('transaction-item-t12'), findsOneWidget);
    });

    testWidgets('two "load more" calls at once load the page only once', (tester) async {
      final server = newServer()..everyone.addAll(twelve());
      await pumpApp(tester, server, size: _small);

      final container = ProviderScope.containerOf(tester.element(find.byType(App)));
      final notifier = container.read(transactionFeedProvider(TransactionFeed.everyone).notifier);
      // Do not await here: in a widget test, async work only moves on `pump`.
      unawaited(notifier.loadMore());
      unawaited(notifier.loadMore());
      // A fixed number of frames with time passing (the HTTP layer uses timers).
      // pumpAndSettle is not used: it could wait forever if the guard breaks.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(server.feedRequests, ['/transactions/public:1', '/transactions/public:2']);
      expect(container.read(transactionFeedProvider(TransactionFeed.everyone)).value!.items, hasLength(12));
    });

    testWidgets('a failed "load more" shows a retry button; it works after the server is back', (tester) async {
      final server = newServer()
        ..everyone.addAll(twelve())
        ..failPages.add(2);
      await pumpApp(tester, server, size: _small);

      await scrollList(tester, -3000);
      expect(byId('transaction-list-load-more-error'), findsOneWidget);
      // The first 10 are still there.
      expect(byId('transaction-item-t10'), findsOneWidget);
      final requestsBefore = server.feedRequests.length;

      server.failPages.clear();
      await tapId(tester, 'transaction-list-load-more-error');
      await scrollList(tester, -3000);

      expect(server.feedRequests.length, greaterThan(requestsBefore));
      expect(byId('transaction-list-load-more-error'), findsNothing);
      expect(byId('transaction-item-t12'), findsOneWidget);
    });

    testWidgets('pull down loads the list again from the start', (tester) async {
      final server = newServer()..everyone.add(testTransaction('t1', description: 'Old item'));
      await pumpApp(tester, server);
      expect(find.text('Old item'), findsOneWidget);

      server.everyone.insert(0, testTransaction('t0', description: 'New item'));
      await tester.drag(byId('transaction-list'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(server.feedRequests, ['/transactions/public:1', '/transactions/public:1']);
      expect(find.text('New item'), findsOneWidget);
      expect(find.text('Old item'), findsOneWidget);
    });

    testWidgets('a failed pull down keeps the list and tells the user', (tester) async {
      final server = newServer()..everyone.add(testTransaction('t1', description: 'Old item'));
      await pumpApp(tester, server);

      server.failPages.add(1);
      await tester.drag(byId('transaction-list'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text('Old item'), findsOneWidget);
      expect(byId('alert-bar-error'), findsOneWidget);
    });

    testWidgets('a failed first load shows an error with retry', (tester) async {
      final server = newServer()
        ..everyone.add(testTransaction('t1', description: 'Item'))
        ..failPages.add(1);
      await pumpApp(tester, server);

      expect(byId('transaction-list-load-error'), findsOneWidget);
      expect(byId('transaction-list'), findsNothing);

      server.failPages.clear();
      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(byId('transaction-list-load-error'), findsNothing);
      expect(find.text('Item'), findsOneWidget);
    });
  });

  group('another user', () {
    testWidgets('the next user does not see the previous user\'s lists', (tester) async {
      final server = newServer()..everyone.add(testTransaction('old1', description: 'Old item'));
      await pumpApp(tester, server);
      expect(find.text('Old item'), findsOneWidget);

      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      server.everyone
        ..clear()
        ..add(testTransaction('new1', description: 'New item'));
      await enter(tester, 'signin-username', 'someone');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');

      expect(find.text('New item'), findsOneWidget);
      expect(find.text('Old item'), findsNothing);
    });
  });

  group('detail', () {
    testWidgets('opens from the list, shows the transaction, and goes back', (tester) async {
      final server = newServer()
        ..everyone.add(testTransaction('t1',
            description: 'Dinner', amount: 2500, likes: 1, comments: 2));
      await pumpApp(tester, server);

      await tapId(tester, 'transaction-item-t1');

      expect(byId('transaction-detail-header'), findsOneWidget);
      expect(find.text('거래 상세'), findsOneWidget);
      expect(find.descendant(of: byId('transaction-description'), matching: find.text('Dinner')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-amount-t1'), matching: find.text('-\$25.00')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-status'), matching: find.text('결제 완료')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-like-count-t1'), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: byId('transaction-comment-count-t1'), matching: find.text('2')), findsOneWidget);
      expect(byId('transaction-sender-avatar'), findsOneWidget);
      expect(byId('transaction-receiver-avatar'), findsOneWidget);
      expect(server.calls, contains('GET /transactions/t1'));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(byId('transaction-detail-header'), findsNothing);
      expect(byId('transaction-list'), findsOneWidget);
    });

    testWidgets('shows where a request stands', (tester) async {
      final server = newServer()
        ..everyone.addAll([
          testTransaction('a', requestStatus: 'pending', status: 'pending'),
          testTransaction('b', requestStatus: 'accepted'),
          testTransaction('c', requestStatus: 'rejected'),
        ]);
      await pumpApp(tester, server);

      for (final (id, label) in [
        ('a', '요청 대기 중'),
        ('b', '수락됨'),
        ('c', '거절됨'),
      ]) {
        await tapId(tester, 'transaction-item-$id');
        expect(
          find.descendant(of: byId('transaction-status'), matching: find.text(label)),
          findsOneWidget,
          reason: id,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a failed load shows an error with retry', (tester) async {
      final server = newServer()
        ..everyone.add(testTransaction('t1', description: 'Dinner'))
        ..failTransactionDetail = true;
      await pumpApp(tester, server);

      await tapId(tester, 'transaction-item-t1');
      expect(byId('transaction-detail-error'), findsOneWidget);

      server.failTransactionDetail = false;
      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(byId('transaction-detail-error'), findsNothing);
      expect(find.descendant(of: byId('transaction-description'), matching: find.text('Dinner')), findsOneWidget);
    });
  });
}
