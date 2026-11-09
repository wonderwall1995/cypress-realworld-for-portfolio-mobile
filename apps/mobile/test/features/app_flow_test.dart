import 'package:cypress_realworld_for_personal_portfolio_mobile/app.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';

const _user = {'id': 'u1', 'firstName': 'Ada', 'lastName': 'Kim', 'username': 'tester'};

/// Finds the widget with a test id (the web `data-testid` name).
Finder byId(String id) => find.byKey(ValueKey<String>(id));

/// Finds the text field inside a test id.
Finder fieldIn(String id) =>
    find.descendant(of: byId(id), matching: find.byType(TextFormField));

Future<void> pumpApp(WidgetTester tester, FakeHandler handler) async {
  // A tall screen, so the whole form is visible.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fakeClient(handler))],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

ResponseBody unauthorized(RequestOptions o) =>
    jsonBody(401, {'error': 'User is unauthorized'});

void main() {
  group('start', () {
    testWidgets('no session: shows the sign-in form', (tester) async {
      await pumpApp(tester, unauthorized);

      expect(byId('signin-username'), findsOneWidget);
      expect(byId('signin-password'), findsOneWidget);
      expect(byId('signin-remember-me'), findsOneWidget);
      expect(byId('signin-submit'), findsOneWidget);
      expect(byId('signup'), findsOneWidget);
      expect(byId('signin-error'), findsNothing);
      expect(byId('sidenav-home'), findsNothing);
    });

    testWidgets('server not reachable: tells the user', (tester) async {
      await pumpApp(
        tester,
        (o) => throw DioException.connectionError(requestOptions: o, reason: 'down'),
      );

      expect(byId('signin-error'), findsOneWidget);
      expect(find.text('서버에 연결할 수 없습니다.'), findsOneWidget);
    });

    testWidgets('valid session: shows the tabs and moves between them', (tester) async {
      await pumpApp(tester, (_) => jsonBody(200, {'user': _user}));

      expect(byId('signin-username'), findsNothing);
      expect(find.text('홈 화면'), findsOneWidget);

      await tester.tap(byId('sidenav-notifications'));
      await tester.pumpAndSettle();
      expect(find.text('알림 화면'), findsOneWidget);

      await tester.tap(byId('sidenav-bankaccounts'));
      await tester.pumpAndSettle();
      expect(find.text('은행 계좌 화면'), findsOneWidget);

      await tester.tap(byId('sidenav-user-settings'));
      await tester.pumpAndSettle();
      expect(find.text('설정 화면'), findsOneWidget);
    });
  });

  group('sign in', () {
    testWidgets('empty form shows messages and sends nothing', (tester) async {
      final paths = <String>[];
      await pumpApp(tester, (o) {
        paths.add(o.path);
        return unauthorized(o);
      });

      await tester.tap(byId('signin-submit'));
      await tester.pumpAndSettle();

      expect(find.text('아이디를 입력하세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력하세요.'), findsOneWidget);
      expect(paths, ['/checkAuth']);
    });

    testWidgets('wrong password shows a Korean error', (tester) async {
      await pumpApp(tester, (o) {
        if (o.path == '/login') return jsonBody(401, 'Unauthorized');
        return unauthorized(o);
      });

      await tester.enterText(fieldIn('signin-username'), 'tester');
      await tester.enterText(fieldIn('signin-password'), 'wrong-pw');
      await tester.tap(byId('signin-submit'));
      await tester.pumpAndSettle();

      expect(find.text('아이디 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);
    });

    testWidgets('going to sign-up and back clears the old error and password', (tester) async {
      await pumpApp(tester, (o) {
        if (o.path == '/login') return jsonBody(401, 'Unauthorized');
        return unauthorized(o);
      });

      await tester.enterText(fieldIn('signin-username'), 'tester');
      await tester.enterText(fieldIn('signin-password'), 'wrong-pw');
      await tester.tap(byId('signin-submit'));
      await tester.pumpAndSettle();
      expect(byId('signin-error'), findsOneWidget);

      await tester.tap(byId('signup'));
      await tester.pumpAndSettle();
      expect(byId('signup-title'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(byId('signin-error'), findsNothing);
      expect(tester.widget<TextFormField>(fieldIn('signin-password')).controller!.text, '');
      expect(tester.widget<TextFormField>(fieldIn('signin-username')).controller!.text, 'tester');
    });

    testWidgets('success goes to home and sends the remember flag', (tester) async {
      Object? loginBody;
      await pumpApp(tester, (o) {
        if (o.path == '/login') {
          loginBody = o.data;
          return jsonBody(200, {'user': _user});
        }
        return unauthorized(o);
      });

      await tester.enterText(fieldIn('signin-username'), 'tester');
      await tester.enterText(fieldIn('signin-password'), 'pw-1234');
      await tester.tap(byId('signin-remember-me'));
      await tester.tap(byId('signin-submit'));
      await tester.pumpAndSettle();

      expect(loginBody, {'username': 'tester', 'password': 'pw-1234', 'remember': true});
      expect(find.text('홈 화면'), findsOneWidget);
      expect(byId('signin-username'), findsNothing);
    });
  });

  group('sign up', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await tester.tap(byId('signup'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens from the sign-in link', (tester) async {
      await pumpApp(tester, unauthorized);
      await openSignUp(tester);

      expect(byId('signup-title'), findsOneWidget);
      expect(byId('signup-first-name'), findsOneWidget);
      expect(byId('signup-last-name'), findsOneWidget);
      expect(byId('signup-username'), findsOneWidget);
      expect(byId('signup-password'), findsOneWidget);
      expect(byId('signup-confirmPassword'), findsOneWidget);
      expect(byId('signup-submit'), findsOneWidget);
    });

    testWidgets('checks the form before sending', (tester) async {
      final paths = <String>[];
      await pumpApp(tester, (o) {
        paths.add(o.path);
        return unauthorized(o);
      });
      await openSignUp(tester);

      await tester.tap(byId('signup-submit'));
      await tester.pumpAndSettle();
      expect(find.text('이름을 입력하세요.'), findsOneWidget);
      expect(find.text('성을 입력하세요.'), findsOneWidget);
      expect(find.text('아이디를 입력하세요.'), findsOneWidget);

      await tester.enterText(fieldIn('signup-first-name'), 'Ada');
      await tester.enterText(fieldIn('signup-last-name'), 'Kim');
      await tester.enterText(fieldIn('signup-username'), 'ada');
      await tester.enterText(fieldIn('signup-password'), 'abcd');
      await tester.enterText(fieldIn('signup-confirmPassword'), 'abce');
      await tester.tap(byId('signup-submit'));
      await tester.pumpAndSettle();

      expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
      expect(paths, ['/checkAuth']);
    });

    testWidgets('success returns to sign-in with a message', (tester) async {
      Object? body;
      await pumpApp(tester, (o) {
        if (o.path == '/users') {
          body = o.data;
          return jsonBody(201, {'user': _user});
        }
        return unauthorized(o);
      });
      await openSignUp(tester);

      await tester.enterText(fieldIn('signup-first-name'), 'Ada');
      await tester.enterText(fieldIn('signup-last-name'), 'Kim');
      await tester.enterText(fieldIn('signup-username'), 'ada');
      await tester.enterText(fieldIn('signup-password'), 'abcd');
      await tester.enterText(fieldIn('signup-confirmPassword'), 'abcd');
      await tester.tap(byId('signup-submit'));
      await tester.pumpAndSettle();

      expect(body, {
        'firstName': 'Ada',
        'lastName': 'Kim',
        'username': 'ada',
        'password': 'abcd',
      });
      expect(byId('signup-title'), findsNothing);
      expect(byId('signin-submit'), findsOneWidget);
      expect(byId('alert-bar-success'), findsOneWidget);
    });

    testWidgets('server refusal shows an error and stays', (tester) async {
      await pumpApp(tester, (o) {
        if (o.path == '/users') return jsonBody(400, {'error': 'bad'});
        return unauthorized(o);
      });
      await openSignUp(tester);

      await tester.enterText(fieldIn('signup-first-name'), 'Ada');
      await tester.enterText(fieldIn('signup-last-name'), 'Kim');
      await tester.enterText(fieldIn('signup-username'), 'ada');
      await tester.enterText(fieldIn('signup-password'), 'abcd');
      await tester.enterText(fieldIn('signup-confirmPassword'), 'abcd');
      await tester.tap(byId('signup-submit'));
      await tester.pumpAndSettle();

      expect(byId('signup-error'), findsOneWidget);
      expect(byId('signup-title'), findsOneWidget);
    });
  });

  group('sign out', () {
    testWidgets('the ... menu shows the user and signs out', (tester) async {
      final calls = <String>[];
      await pumpApp(tester, (o) {
        calls.add('${o.method} ${o.path}');
        if (o.path == '/logout') {
          return ResponseBody.fromString('', 302);
        }
        return jsonBody(200, {'user': _user});
      });

      await tester.tap(byId('sidenav-more'));
      await tester.pumpAndSettle();

      expect(find.text('Ada Kim'), findsOneWidget);
      expect(find.text('@tester'), findsOneWidget);
      // The ... button opens a menu. It does not change the tab.
      expect(find.text('홈 화면'), findsOneWidget);

      await tester.tap(byId('sidenav-signout'));
      await tester.pumpAndSettle();

      expect(calls, contains('POST /logout'));
      expect(byId('signin-submit'), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);
    });
  });
}
