import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')])
  ..everyone.add(testTransaction('t1', description: 'Dinner'));

int calls(FakeServer s, String key) => s.calls.where((c) => c == key).length;

/// Lets the stream and the futures run.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Finder badge(String n) => find.descendant(of: byId('nav-top-notifications-count'), matching: find.text(n));

void main() {
  group('the live connection', () {
    testWidgets('opens the stream and reads the list once to catch up', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      expect(calls(server, 'GET /notifications/stream'), 1);
      // One read when the app started, one more when the stream opened.
      expect(calls(server, 'GET /notifications'), 2);
      expect(server.streams, hasLength(1));
    });

    testWidgets('a pushed notification shows in the badge and the list at once', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      server.push(testNotification('n1', 'like', name: 'Cara Lee'));
      await settle(tester);

      expect(badge('1'), findsOneWidget);
      // No read of the list was needed for it.
      expect(calls(server, 'GET /notifications'), 2);
    });

    testWidgets('the same notification twice is counted once', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      server.push(testNotification('n1', 'like'));
      server.push(testNotification('n1', 'like'));
      await settle(tester);

      expect(badge('1'), findsOneWidget);
    });

    testWidgets('a ping changes nothing', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      server.ping();
      await settle(tester);

      expect(byId('nav-top-notifications-count'), findsNothing);
      expect(byId('amounts-changed-notice'), findsNothing);
    });
  });

  group('the money notice', () {
    testWidgets('a new "received" notification shows it, with a refresh button', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      expect(byId('amounts-changed-notice'), findsNothing);

      server.push(testNotification('n1', 'received', name: 'Kim Cheolsu'));
      await settle(tester);

      expect(find.text('금액 변동이 생겼어요. 새로고침을 해주세요.'), findsOneWidget);
      expect(byId('amounts-changed-reload'), findsOneWidget);
    });

    testWidgets('a like or a comment does not show it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      server.push(testNotification('n1', 'like'));
      server.push(testNotification('n2', 'comment'));
      await settle(tester);

      expect(badge('2'), findsOneWidget);
      expect(byId('amounts-changed-notice'), findsNothing);
    });

    testWidgets('notifications that were there when the app opened do not show it', (tester) async {
      final server = newServer()..notifications.add(testNotification('n1', 'received'));
      await pumpApp(tester, server, live: true);
      await settle(tester);

      expect(badge('1'), findsOneWidget);
      expect(byId('amounts-changed-notice'), findsNothing);
    });

    testWidgets('one that was already read on the web when the app sees it does not show it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.closeStreams();
      await settle(tester);
      server.notifications.add({...testNotification('n9', 'received'), 'isRead': true});
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      expect(byId('amounts-changed-notice'), findsNothing);
    });

    testWidgets('one that arrived while the stream was down shows it after reconnecting', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      server.closeStreams();
      await settle(tester);
      server.notifications.add(testNotification('n9', 'received'));
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      expect(byId('amounts-changed-notice'), findsOneWidget);
    });

    testWidgets('the refresh button reads the account, the bank accounts and the list, and hides the notice', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.push(testNotification('n1', 'received'));
      await settle(tester);
      final auth = calls(server, 'GET /checkAuth');
      final accounts = calls(server, 'GET /bankAccounts');
      final feed = server.calls.where((c) => c.startsWith('GET /transactions')).length;

      await tapId(tester, 'amounts-changed-reload');
      await settle(tester);

      expect(calls(server, 'GET /checkAuth'), greaterThan(auth));
      expect(calls(server, 'GET /bankAccounts'), greaterThan(accounts));
      expect(server.calls.where((c) => c.startsWith('GET /transactions')).length, greaterThan(feed));
      expect(byId('amounts-changed-notice'), findsNothing);
    });

    testWidgets('the notice comes back for the next received notification', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.push(testNotification('n1', 'received'));
      await settle(tester);
      await tapId(tester, 'amounts-changed-reload');
      await settle(tester);

      server.push(testNotification('n2', 'received'));
      await settle(tester);

      expect(byId('amounts-changed-notice'), findsOneWidget);
    });
  });

  group('when the stream fails', () {
    testWidgets('it opens again after 5 seconds', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      server.closeStreams();
      await settle(tester);
      expect(calls(server, 'GET /notifications/stream'), 1);
      await tester.pump(const Duration(seconds: 4));
      expect(calls(server, 'GET /notifications/stream'), 1);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      expect(calls(server, 'GET /notifications/stream'), 2);
    });

    testWidgets('after 3 failures in a row it asks for the list every 10 seconds instead', (tester) async {
      final server = newServer()..streamStatus = 404;
      await pumpApp(tester, server, live: true);
      await settle(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      expect(calls(server, 'GET /notifications/stream'), 3);
      final reads = calls(server, 'GET /notifications');

      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      await settle(tester);

      expect(calls(server, 'GET /notifications'), reads + 2);
      expect(calls(server, 'GET /notifications/stream'), 3); // no more tries
    });

    testWidgets('a notification found by that polling is shown', (tester) async {
      final server = newServer()..streamStatus = 404;
      await pumpApp(tester, server, live: true);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      server.notifications.add(testNotification('n1', 'received'));
      await tester.pump(const Duration(seconds: 10));
      await settle(tester);

      expect(badge('1'), findsOneWidget);
      expect(byId('amounts-changed-notice'), findsOneWidget);
    });
  });

  group('only while the app is in view', () {
    testWidgets('going to the background stops it; coming back opens it again', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);
      server.closeStreams();
      await tester.pump(const Duration(seconds: 30));
      expect(calls(server, 'GET /notifications/stream'), 1); // no reconnect in the background

      for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);

      expect(calls(server, 'GET /notifications/stream'), 2);
    });

    testWidgets('with the live connection off nothing is opened', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await tester.pump(const Duration(seconds: 30));

      expect(calls(server, 'GET /notifications/stream'), 0);
      expect(calls(server, 'GET /notifications'), 1);
    });

    testWidgets('signing out closes it (no connection for the next user)', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      await tapId(tester, 'sidenav-more');
      await tapId(tester, 'sidenav-signout');
      await settle(tester);
      server.closeStreams();
      await tester.pump(const Duration(seconds: 30));

      expect(calls(server, 'GET /notifications/stream'), 1);
    });
  });

  group('coming back to the app', () {
    Future<void> leaveAndReturn(WidgetTester tester, {Future<void> Function()? meanwhile}) async {
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);
      await meanwhile?.call();
      for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);
    }

    testWidgets('reads the money, also without an unread notification', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      // A deposit on another device; its notification (if any) was read on the web.
      await leaveAndReturn(tester, meanwhile: () async => server.balance = 4200);
      await tapId(tester, 'sidenav-my-account');
      expect(find.textContaining('\$42'), findsWidgets);
      expect(byId('amounts-changed-notice'), findsNothing);
    });

    testWidgets('says so when it cannot', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      await leaveAndReturn(tester, meanwhile: () async => server.failAccountList = true);
      expect(find.text('최신 잔액을 불러오지 못했습니다.'), findsOneWidget);

      server.failAccountList = false;
      await tapId(tester, 'amounts-changed-reload');
      expect(byId('amounts-changed-notice'), findsNothing);
    });

    testWidgets('a moment of "inactive" (the notification shade) does not read it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      final before = calls(server, 'GET /bankAccounts');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(calls(server, 'GET /bankAccounts'), before);
    });
  });

  group('the refresh button', () {
    testWidgets('keeps the notice while it reads and when it fails', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.push(testNotification('n1', 'received'));
      await settle(tester);

      final hold = Completer<void>();
      server.gate = (key) => key == 'GET /bankAccounts' ? hold.future : null;
      await tester.tap(byId('amounts-changed-reload'));
      await settle(tester);
      expect(find.text('잔액을 불러오는 중입니다.'), findsOneWidget);
      final asked = calls(server, 'GET /bankAccounts');
      await tester.tap(byId('amounts-changed-reload')); // again: does not ask twice
      await settle(tester);
      expect(calls(server, 'GET /bankAccounts'), asked);
      server.gate = null;
      hold.complete();
      await settle(tester);
      expect(byId('amounts-changed-notice'), findsNothing);

      server.push(testNotification('n2', 'received'));
      await settle(tester);
      server.failPages.add(1); // only the transaction list fails
      await tapId(tester, 'amounts-changed-reload');
      expect(find.text('최신 잔액을 불러오지 못했습니다.'), findsOneWidget);
    });

    testWidgets('money that arrives while it reads shows the notice again', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.push(testNotification('n1', 'received'));
      await settle(tester);
      final hold = Completer<void>();
      server.gate = (key) => key == 'GET /bankAccounts' ? hold.future : null;
      await tester.tap(byId('amounts-changed-reload'));
      await settle(tester);
      server.push(testNotification('n2', 'received'));
      await settle(tester);
      hold.complete();
      await settle(tester);
      expect(find.text('금액 변동이 생겼어요. 새로고침을 해주세요.'), findsOneWidget);
    });
  });

  group('the sign-in is over', () {
    testWidgets('the stream answers 401: sign-in screen, no more connections and no polling', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.sessionLost = true;
      server.closeStreams();
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(byId('signin-submit'), findsOneWidget);

      final stream = calls(server, 'GET /notifications/stream');
      final list = calls(server, 'GET /notifications');
      await tester.pump(const Duration(seconds: 60));
      expect(calls(server, 'GET /notifications/stream'), stream);
      expect(calls(server, 'GET /notifications'), list);
    });
  });

  group('what happens while the list is on its way', () {
    testWidgets('a 읽음 is not undone by an older list', (tester) async {
      final server = newServer()..notifications.addAll([testNotification('n1', 'like'), testNotification('n2', 'like')]);
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');

      final hold = Completer<void>();
      server.gate = (key) => key == 'GET /notifications' ? hold.future : null;
      await tester.tap(byId('sidenav-notifications')); // asks for the list
      await settle(tester);
      server.gate = null;
      await tester.tap(byId('notification-mark-read-n1'));
      await settle(tester);
      expect(byId('notification-mark-read-n1'), findsNothing);

      hold.complete(); // the old list still has n1
      await settle(tester);
      expect(byId('notification-mark-read-n1'), findsNothing);
      expect(byId('notification-mark-read-n2'), findsOneWidget);
      expect(badge('1'), findsOneWidget);
    });

    testWidgets('a pushed notification is not lost to an older list', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      final hold = Completer<void>();
      server.gate = (key) => key == 'GET /notifications' ? hold.future : null;
      await tester.tap(byId('sidenav-notifications'));
      await settle(tester);
      server.push(testNotification('n1', 'like'));
      await settle(tester);
      expect(badge('1'), findsOneWidget);

      hold.complete();
      await settle(tester);
      expect(badge('1'), findsOneWidget);
    });

    testWidgets('two quick taps on 읽음 send one request', (tester) async {
      final server = newServer()..notifications.add(testNotification('n1', 'like'));
      await pumpApp(tester, server);
      await tapId(tester, 'sidenav-notifications');
      await tester.tap(byId('notification-mark-read-n1'));
      await tester.tap(byId('notification-mark-read-n1'));
      await settle(tester);
      expect(calls(server, 'PATCH /notifications/n1'), 1);
    });

    testWidgets('an event that cannot be read is skipped, and the next one still works', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.push({'id': 5, 'status': 'received'});
      server.push(testNotification('n1', 'like'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(badge('1'), findsOneWidget);
    });
  });
}
