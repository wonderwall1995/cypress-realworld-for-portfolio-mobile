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
      expect(byId('money-change-notice'), findsNothing);
    });
  });

  group('the money notice', () {
    testWidgets('a new "received" notification shows it, with a refresh button', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      expect(byId('money-change-notice'), findsNothing);

      server.push(testNotification('n1', 'received', name: 'Kim Cheolsu'));
      await settle(tester);

      expect(find.text('금액 변동이 생겼어요. 새로고침을 해주세요.'), findsOneWidget);
      expect(byId('money-change-refresh'), findsOneWidget);
    });

    testWidgets('a like or a comment does not show it', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);

      server.push(testNotification('n1', 'like'));
      server.push(testNotification('n2', 'comment'));
      await settle(tester);

      expect(badge('2'), findsOneWidget);
      expect(byId('money-change-notice'), findsNothing);
    });

    testWidgets('notifications that were there when the app opened do not show it', (tester) async {
      final server = newServer()..notifications.add(testNotification('n1', 'received'));
      await pumpApp(tester, server, live: true);
      await settle(tester);

      expect(badge('1'), findsOneWidget);
      expect(byId('money-change-notice'), findsNothing);
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

      expect(byId('money-change-notice'), findsOneWidget);
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

      await tapId(tester, 'money-change-refresh');
      await settle(tester);

      expect(calls(server, 'GET /checkAuth'), greaterThan(auth));
      expect(calls(server, 'GET /bankAccounts'), greaterThan(accounts));
      expect(server.calls.where((c) => c.startsWith('GET /transactions')).length, greaterThan(feed));
      expect(byId('money-change-notice'), findsNothing);
    });

    testWidgets('the notice comes back for the next received notification', (tester) async {
      final server = newServer();
      await pumpApp(tester, server, live: true);
      await settle(tester);
      server.push(testNotification('n1', 'received'));
      await settle(tester);
      await tapId(tester, 'money-change-refresh');
      await settle(tester);

      server.push(testNotification('n2', 'received'));
      await settle(tester);

      expect(byId('money-change-notice'), findsOneWidget);
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
      expect(byId('money-change-notice'), findsOneWidget);
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
}
