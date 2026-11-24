import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')])
  ..everyone.add(testTransaction('t1', description: 'Dinner'));

int count(FakeServer s) => s.calls.where((c) => c == 'GET /notifications').length;

void main() {
  group('badge', () {
    testWidgets('shows how many are unread', (tester) async {
      final server = newServer()
        ..notifications.addAll([
          testNotification('n1', 'like'),
          testNotification('n2', 'comment'),
          testNotification('n3', 'received'),
        ]);
      await pumpApp(tester, server);

      expect(byId('nav-top-notifications-count'), findsOneWidget);
      expect(find.descendant(of: byId('nav-top-notifications-count'), matching: find.text('3')), findsOneWidget);
    });

    testWidgets('is hidden when everything is read', (tester) async {
      await pumpApp(tester, newServer());

      expect(byId('nav-top-notifications-count'), findsNothing);
    });

    testWidgets('shows 99+ for a long list', (tester) async {
      final server = newServer()
        ..notifications.addAll([for (var i = 0; i < 120; i++) testNotification('n$i', 'like')]);
      await pumpApp(tester, server);

      expect(find.descendant(of: byId('nav-top-notifications-count'), matching: find.text('99+')), findsOneWidget);
    });

    testWidgets('goes down when one is marked read', (tester) async {
      final server = newServer()
        ..notifications.addAll([testNotification('n1', 'like'), testNotification('n2', 'comment')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      await tapId(tester, 'notification-mark-read-n1');

      expect(find.descendant(of: byId('nav-top-notifications-count'), matching: find.text('1')), findsOneWidget);
    });
  });

  group('list', () {
    testWidgets('shows each kind in Korean, with a 읽음 button', (tester) async {
      final server = newServer()
        ..notifications.addAll([
          testNotification('n2', 'received', name: 'Ada Kim'),
          testNotification('n3', 'like', name: 'Cara Test'),
          testNotification('n4', 'comment', name: 'Dan Test'),
        ]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      expect(byId('notifications-list'), findsOneWidget);
      expect(find.text('Ada Kim님이 이체했습니다.'), findsOneWidget);
      expect(find.text('Cara Test님이 거래에 좋아요를 눌렀습니다.'), findsOneWidget);
      expect(find.text('Dan Test님이 거래에 댓글을 남겼습니다.'), findsOneWidget);
      for (final id in ['n2', 'n3', 'n4']) {
        expect(byId('notification-list-item-$id'), findsOneWidget, reason: id);
        expect(byId('notification-mark-read-$id'), findsOneWidget, reason: id);
      }
    });

    testWidgets('an empty list says so', (tester) async {
      await pumpApp(tester, newServer());
      await tapId(tester, 'sidenav-notifications');

      expect(byId('notifications-empty'), findsOneWidget);
      expect(find.text('새 알림이 없습니다.'), findsOneWidget);
    });

    testWidgets('a notification of an unknown kind is left out', (tester) async {
      final server = newServer()
        ..notifications.addAll([
          testNotification('n1', 'like'),
          {...testNotification('n2', 'like'), 'likeId': null, 'status': 'something-new'},
        ]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      expect(byId('notification-list-item-n1'), findsOneWidget);
      expect(byId('notification-list-item-n2'), findsNothing);
    });
  });

  group('refresh', () {
    testWidgets('loaded once at start, and again when the tab is opened', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      expect(count(server), 1);

      server.notifications.add(testNotification('n1', 'like'));
      await tapId(tester, 'sidenav-notifications');

      expect(count(server), 2);
      expect(byId('notification-list-item-n1'), findsOneWidget);
      expect(find.descendant(of: byId('nav-top-notifications-count'), matching: find.text('1')), findsOneWidget);
    });

    testWidgets('pull down loads again', (tester) async {
      final server = newServer()..notifications.add(testNotification('n1', 'like'));
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');
      final before = count(server);

      server.notifications.add(testNotification('n2', 'comment'));
      await tester.drag(byId('notifications-list'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(count(server), before + 1);
      expect(byId('notification-list-item-n2'), findsOneWidget);
    });

    testWidgets('a failed pull down keeps the list and tells the user', (tester) async {
      final server = newServer()..notifications.add(testNotification('n1', 'like'));
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      server.failNotifications = true;
      await tester.drag(byId('notifications-list'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(byId('notification-list-item-n1'), findsOneWidget);
      expect(byId('alert-bar-error'), findsOneWidget);
    });

    testWidgets('a failed first load shows an error with retry', (tester) async {
      final server = newServer()
        ..notifications.add(testNotification('n1', 'like'))
        ..failNotifications = true;
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      expect(byId('notifications-load-error'), findsOneWidget);

      server.failNotifications = false;
      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(byId('notification-list-item-n1'), findsOneWidget);
    });
  });

  group('actions', () {
    double opacityOf(WidgetTester tester, String id) =>
        tester.widget<Opacity>(find.descendant(of: byId('notification-list-item-$id'), matching: find.byType(Opacity))).opacity;

    testWidgets('확인 marks it read: it stays, paler, without the button, and the badge goes down', (tester) async {
      final server = newServer()..notifications.addAll([testNotification('n1', 'like'), testNotification('n2', 'comment')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');
      expect(find.text('확인'), findsNWidgets(2));
      expect(opacityOf(tester, 'n1'), 1);

      await tapId(tester, 'notification-mark-read-n1');

      expect(server.bodies['PATCH /notifications/n1'], {'isRead': true});
      expect(byId('notification-list-item-n1'), findsOneWidget);
      expect(byId('notification-mark-read-n1'), findsNothing);
      expect(opacityOf(tester, 'n1'), lessThan(1));
      expect(opacityOf(tester, 'n2'), 1);
      expect(find.descendant(of: byId('nav-top-notifications-count'), matching: find.text('1')), findsOneWidget);
    });

    testWidgets('read ones are still there after loading again, and are not counted', (tester) async {
      final server = newServer()
        ..notifications.addAll([
          {...testNotification('old', 'received', name: 'Kim A'), 'isRead': true},
          testNotification('n1', 'like'),
        ]);
      await pumpApp(tester, server);
      expect(find.descendant(of: byId('nav-top-notifications-count'), matching: find.text('1')), findsOneWidget);
      await tapId(tester, 'sidenav-notifications');
      await tapId(tester, 'sidenav-home');
      await tapId(tester, 'sidenav-notifications');
      expect(byId('notification-list-item-old'), findsOneWidget);
      expect(byId('notification-mark-read-old'), findsNothing);
    });

    testWidgets('only read ones: no badge', (tester) async {
      final server = newServer()..notifications.add({...testNotification('old', 'like'), 'isRead': true});
      await pumpApp(tester, server);
      expect(byId('nav-top-notifications-count'), findsNothing);
    });

    testWidgets('a server that does not know the history still works', (tester) async {
      final server = newServer()
        ..oldNotificationServer = true
        ..notifications.addAll([
          {...testNotification('old', 'like'), 'isRead': true},
          testNotification('n1', 'like'),
        ]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');
      expect(byId('notification-list-item-old'), findsNothing);
      await tapId(tester, 'notification-mark-read-n1');
      expect(byId('nav-top-notifications-count'), findsNothing);
      await tapId(tester, 'sidenav-notifications');
      expect(byId('notifications-empty'), findsOneWidget);
    });

    testWidgets('a failed 읽음 keeps the item and tells the user', (tester) async {
      final server = newServer()
        ..notifications.add(testNotification('n1', 'like'))
        ..failMarkRead = true;
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      await tapId(tester, 'notification-mark-read-n1');

      expect(find.text('읽음 처리하지 못했습니다.'), findsOneWidget);
      expect(byId('notification-list-item-n1'), findsOneWidget);
    });

    testWidgets('tapping the row opens the transaction and does not mark it read', (tester) async {
      final server = newServer()..notifications.add(testNotification('n1', 'like', transactionId: 't1'));
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      await tester.tap(find.text('Bob Test님이 거래에 좋아요를 눌렀습니다.'));
      await tester.pumpAndSettle();

      expect(byId('transaction-detail-header'), findsOneWidget);
      expect(server.calls, contains('GET /transactions/t1'));
      expect(server.calls.where((c) => c.startsWith('PATCH /notifications')), isEmpty);

      await goBack(tester);
      await tester.pumpAndSettle();
      expect(byId('notification-list-item-n1'), findsOneWidget);
    });
  });

  group('sign out and in', () {
    testWidgets('the next user does not see the old notifications', (tester) async {
      final server = newServer()..notifications.add(testNotification('n1', 'like'));
      await pumpApp(tester, server);
      expect(byId('nav-top-notifications-count'), findsOneWidget);

      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      expect(byId('signin-submit'), findsOneWidget);

      server.notifications.clear(); // the next user has none
      await enter(tester, 'signin-username', 'someone');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');

      expect(byId('nav-top-notifications-count'), findsNothing);
    });
  });
}
