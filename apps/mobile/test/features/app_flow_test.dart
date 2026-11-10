import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// A user who already has a bank account, so the first-time setup is skipped.
FakeServer serverWithAccount({bool signedIn = true}) =>
    FakeServer(signedIn: signedIn, accounts: [testAccount('b1')]);

void main() {
  group('start', () {
    testWidgets('no session: shows the sign-in form', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false));

      expect(byId('signin-username'), findsOneWidget);
      expect(byId('signin-password'), findsOneWidget);
      expect(byId('signin-remember-me'), findsOneWidget);
      expect(byId('signin-submit'), findsOneWidget);
      expect(byId('signup'), findsOneWidget);
      expect(byId('signin-error'), findsNothing);
      expect(byId('sidenav-home'), findsNothing);
    });

    testWidgets('server not reachable: tells the user', (tester) async {
      await pumpApp(tester, serverWithAccount()..down = true);

      expect(byId('signin-error'), findsOneWidget);
      expect(find.text('서버에 연결할 수 없습니다.'), findsOneWidget);
    });

    testWidgets('valid session: shows the tabs and moves between them', (tester) async {
      await pumpApp(tester, serverWithAccount());

      expect(byId('signin-username'), findsNothing);
      expect(byId('nav-transaction-tabs'), findsOneWidget);

      await tapId(tester, 'sidenav-notifications');
      expect(byId('notifications-empty'), findsOneWidget);

      await tapId(tester, 'sidenav-bankaccounts');
      expect(byId('bankaccount-list'), findsOneWidget);

      await tapId(tester, 'sidenav-my-account');
      expect(byId('sidenav-user-balance'), findsOneWidget);
    });
  });

  group('sign in', () {
    testWidgets('empty form shows messages and sends nothing', (tester) async {
      final server = serverWithAccount(signedIn: false);
      await pumpApp(tester, server);

      await tapId(tester, 'signin-submit');

      expect(find.text('아이디를 입력하세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력하세요.'), findsOneWidget);
      expect(server.calls, ['GET /checkAuth']);
    });

    testWidgets('wrong password shows a Korean error', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false)..loginOk = false);

      await enter(tester, 'signin-username', 'tester');
      await enter(tester, 'signin-password', 'wrong-pw');
      await tapId(tester, 'signin-submit');

      expect(find.text('아이디 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);
    });

    testWidgets('going to sign-up and back clears the old error and password', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false)..loginOk = false);

      await enter(tester, 'signin-username', 'tester');
      await enter(tester, 'signin-password', 'wrong-pw');
      await tapId(tester, 'signin-submit');
      expect(byId('signin-error'), findsOneWidget);

      await tapId(tester, 'signup');
      expect(byId('signup-title'), findsOneWidget);

      await goBack(tester);
      await tester.pumpAndSettle();

      expect(byId('signin-error'), findsNothing);
      expect(tester.widget<TextFormField>(fieldIn('signin-password')).controller!.text, '');
      expect(tester.widget<TextFormField>(fieldIn('signin-username')).controller!.text, 'tester');
    });

    testWidgets('success goes to home and sends the remember flag', (tester) async {
      final server = serverWithAccount(signedIn: false);
      await pumpApp(tester, server);

      await enter(tester, 'signin-username', 'tester');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-remember-me');
      await tapId(tester, 'signin-submit');

      expect(
        server.bodies['POST /login'],
        {'username': 'tester', 'password': 'pw-1234', 'remember': true},
      );
      expect(byId('nav-transaction-tabs'), findsOneWidget);
      expect(byId('signin-username'), findsNothing);
    });
  });

  group('sign up', () {
    Future<void> fillValid(WidgetTester tester) async {
      await enter(tester, 'signup-last-name', 'Kim');
      await enter(tester, 'signup-first-name', 'Ada');
      await enter(tester, 'signup-username', 'ada');
      await enter(tester, 'signup-phone-number', '010-1234-5678');
      await enter(tester, 'signup-password', 'abcd');
      await enter(tester, 'signup-confirmPassword', 'abcd');
    }

    testWidgets('opens from the sign-in link', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false));
      await tapId(tester, 'signup');

      for (final id in [
        'signup-title',
        'signup-last-name',
        'signup-first-name',
        'signup-username',
        'signup-phone-number',
        'signup-password',
        'signup-confirmPassword',
        'signup-submit',
      ]) {
        expect(byId(id), findsOneWidget, reason: id);
      }
    });

    testWidgets('checks the form before sending', (tester) async {
      final server = serverWithAccount(signedIn: false);
      await pumpApp(tester, server);
      await tapId(tester, 'signup');

      await tapId(tester, 'signup-submit');
      expect(find.text('이름을 입력하세요.'), findsOneWidget);
      expect(find.text('성을 입력하세요.'), findsOneWidget);
      expect(find.text('아이디를 입력하세요.'), findsOneWidget);
      expect(find.text('연락처를 입력하세요.'), findsOneWidget);

      await fillValid(tester);
      await enter(tester, 'signup-confirmPassword', 'abce');
      await tapId(tester, 'signup-submit');

      expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
      expect(server.calls, ['GET /checkAuth']);
    });

    testWidgets('the order is 성, 이름, 아이디, 연락처, 비밀번호, 비밀번호 확인', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false));
      await tapId(tester, 'signup');

      final ids = [
        'signup-last-name',
        'signup-first-name',
        'signup-username',
        'signup-phone-number',
        'signup-password',
        'signup-confirmPassword',
      ];
      final tops = [for (final id in ids) tester.getRect(byId(id)).top];
      expect(tops, [...tops]..sort());
      expect(tops.toSet().length, ids.length);
    });

    testWidgets('the phone number is required and checked like the server does', (tester) async {
      final server = serverWithAccount(signedIn: false);
      await pumpApp(tester, server);
      await tapId(tester, 'signup');

      await fillValid(tester);
      await enter(tester, 'signup-phone-number', '');
      await tapId(tester, 'signup-submit');
      expect(find.text('연락처를 입력하세요.'), findsOneWidget);

      for (final bad in ['12', 'abc', '010-12', '+', '1234567890123456789012']) {
        await enter(tester, 'signup-phone-number', bad);
        await tapId(tester, 'signup-submit');
        expect(find.text('연락처가 올바르지 않습니다. (예: 010-1234-5678)'), findsOneWidget, reason: bad);
      }
      expect(server.calls, isNot(contains('POST /users')));
    });

    testWidgets('a number with a country code or brackets is sent as typed', (tester) async {
      final server = serverWithAccount(signedIn: false);
      await pumpApp(tester, server);
      await tapId(tester, 'signup');

      await fillValid(tester);
      await enter(tester, 'signup-phone-number', '+82 10-1234-5678');
      await tapId(tester, 'signup-submit');

      expect(server.bodies['POST /users'], containsPair('phoneNumber', '+82 10-1234-5678'));
    });

    testWidgets('the phone field hints not to enter a real number', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false));
      await tapId(tester, 'signup');

      final field = tester.widget<TextField>(find.descendant(of: byId('signup-phone-number'), matching: find.byType(TextField)));
      expect(field.decoration!.labelText, '연락처');
      expect(field.decoration!.hintText, '데모 앱입니다. 진짜 연락처는 넣지 마세요!');
      expect(field.decoration!.floatingLabelBehavior, FloatingLabelBehavior.always);
    });

    testWidgets('the last name field is labeled 성 and the first name field 이름', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false));
      await tapId(tester, 'signup');

      String? label(String id) => tester
          .widget<TextField>(find.descendant(of: byId(id), matching: find.byType(TextField)))
          .decoration!
          .labelText;
      expect(label('signup-last-name'), '성');
      expect(label('signup-first-name'), '이름');
    });

    testWidgets('on a phone the fields keep 40 on each side', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false), size: const Size(400, 1600));
      await tapId(tester, 'signup');

      final rect = tester.getRect(byId('signup-username'));
      expect(rect.left, 40);
      expect(400 - rect.right, 40);
    });

    testWidgets('success returns to sign-in with a message', (tester) async {
      final server = serverWithAccount(signedIn: false);
      await pumpApp(tester, server);
      await tapId(tester, 'signup');

      await fillValid(tester);
      await tapId(tester, 'signup-submit');

      expect(server.bodies['POST /users'], {
        'firstName': 'Ada',
        'lastName': 'Kim',
        'username': 'ada',
        'password': 'abcd',
        'phoneNumber': '010-1234-5678',
      });
      expect(byId('signup-title'), findsNothing);
      expect(byId('signin-submit'), findsOneWidget);
      expect(byId('alert-bar-success'), findsOneWidget);
    });

    testWidgets('server refusal shows an error and stays', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false)..failSignUp = true);
      await tapId(tester, 'signup');

      await fillValid(tester);
      await tapId(tester, 'signup-submit');

      expect(byId('signup-error'), findsOneWidget);
      expect(byId('signup-title'), findsOneWidget);
    });
  });

  group('sign out', () {
    testWidgets('the ... menu shows the user and signs out', (tester) async {
      final server = serverWithAccount();
      await pumpApp(tester, server);

      await tapId(tester, 'sidenav-more');

      expect(find.text('Kim Ada'), findsOneWidget);
      expect(find.text('@tester'), findsOneWidget);
      // The ... button opens a menu. It does not change the tab.
      expect(byId('nav-transaction-tabs'), findsOneWidget);

      await tapId(tester, 'sidenav-signout');

      expect(server.calls, contains('POST /logout'));
      expect(byId('signin-submit'), findsOneWidget);
      expect(byId('sidenav-home'), findsNothing);
    });
  });
}
