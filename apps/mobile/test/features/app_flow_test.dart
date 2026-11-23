import 'dart:async';

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

    testWidgets('server not reachable: says so, and the saved sign-in works again', (tester) async {
      final server = serverWithAccount()..down = true;
      await pumpApp(tester, server);

      expect(byId('offline'), findsOneWidget);
      expect(find.text('서버에 연결할 수 없습니다.'), findsOneWidget);
      expect(byId('signin-submit'), findsNothing); // not signed out

      await tapId(tester, 'offline-retry'); // still down
      expect(byId('offline'), findsOneWidget);

      server.down = false;
      await tapId(tester, 'offline-retry');
      expect(byId('nav-transaction-tabs'), findsOneWidget);
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

      expect(find.text('사용자 ID를 입력하세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력하세요.'), findsOneWidget);
      expect(server.calls, ['GET /checkAuth']);
    });

    testWidgets('wrong password shows a Korean error', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false)..loginOk = false);

      await enter(tester, 'signin-username', 'tester');
      await enter(tester, 'signin-password', 'wrong-pw');
      await tapId(tester, 'signin-submit');

      expect(find.text('사용자 ID 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
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
      expect(find.text('사용자 ID를 입력하세요.'), findsOneWidget);
      expect(find.text('연락처를 입력하세요.'), findsOneWidget);

      await fillValid(tester);
      await enter(tester, 'signup-confirmPassword', 'abce');
      await tapId(tester, 'signup-submit');

      expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
      expect(server.calls, ['GET /checkAuth']);
    });

    testWidgets('warns about what is public and about the password', (tester) async {
      await pumpApp(tester, serverWithAccount(signedIn: false), size: const Size(360, 1400));
      await tapId(tester, 'signup');
      expect(find.descendant(of: byId('signup-name-notice'), matching: find.textContaining('공개됩니다')), findsOneWidget);
      expect(find.text('비밀번호는 자신이 쓰던 것을 쓰면 안 됩니다!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    Future<void> signUp(WidgetTester tester, FakeServer server, {String id = 'used'}) async {
      await pumpApp(tester, server);
      await tapId(tester, 'signup');
      await enter(tester, 'signup-last-name', '홍');
      await enter(tester, 'signup-first-name', '길동');
      await enter(tester, 'signup-username', id);
      await enter(tester, 'signup-phone-number', '010-1234-5678');
      await enter(tester, 'signup-password', 'pw-1234');
      await enter(tester, 'signup-confirmPassword', 'pw-1234');
      await tapId(tester, 'signup-submit');
    }

    Finder error(String text) => find.descendant(of: byId('signup-error'), matching: find.text(text));

    testWidgets('an ID that is used (409): says exactly that and keeps what was typed', (tester) async {
      final server = serverWithAccount(signedIn: false)..takenUsernames.add('used');
      await signUp(tester, server);
      expect(error('이미 사용 중인 사용자 ID입니다'), findsOneWidget);
      expect(find.text('used'), findsOneWidget);
      expect(find.textContaining('already taken'), findsNothing);

      await enter(tester, 'signup-username', 'free');
      await tapId(tester, 'signup-submit');
      expect(byId('signin-submit'), findsOneWidget);
    });

    testWidgets('the reason comes into view, also the second time, when the button is far below it', (tester) async {
      const size = Size(360, 640);
      final server = serverWithAccount(signedIn: false)..takenUsernames.add('used');
      await pumpApp(tester, server, size: size);
      await tapId(tester, 'signup');
      for (final (id, text) in [
        ('signup-last-name', '홍'),
        ('signup-first-name', '길동'),
        ('signup-username', 'used'),
        ('signup-phone-number', '010-1234-5678'),
        ('signup-password', 'pw-1234'),
        ('signup-confirmPassword', 'pw-1234'),
      ]) {
        await tester.ensureVisible(byId(id));
        await enter(tester, id, text);
      }
      for (var n = 0; n < 2; n++) {
        await tester.ensureVisible(byId('signup-submit'));
        await tester.pumpAndSettle();
        // The answer takes a moment, as on a real network: the box of the first try goes away.
        final answer = Completer<void>();
        server.gate = (_) => answer.future;
        await tester.tap(byId('signup-submit'));
        await tester.pump();
        expect(byId('signup-error'), findsNothing);
        answer.complete();
        await tester.pumpAndSettle();
        final box = tester.getRect(byId('signup-error'));
        expect(box.top, greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom), reason: 'try $n');
        expect(box.bottom, lessThanOrEqualTo(size.height));
        expect(find.descendant(of: byId('signup-error'), matching: find.byType(Text)).hitTestable(), findsOneWidget);
      }
    });

    testWidgets('a reason that is already in view moves nothing', (tester) async {
      final server = serverWithAccount(signedIn: false)..takenUsernames.add('used');
      await signUp(tester, server);
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, 0);
    });

    testWidgets('a 500 of the newer server (JSON) is not blamed on the ID', (tester) async {
      final server = serverWithAccount(signedIn: false)..signUpServerError = true;
      await signUp(tester, server);
      expect(error('회원가입에 실패했습니다. 잠시 뒤 다시 시도해 주세요.'), findsOneWidget);
      expect(find.textContaining('이미 사용 중'), findsNothing);
      expect(find.textContaining('internal'), findsNothing);
    });

    testWidgets('too many requests (the proxy, an HTML page): says so at sign-up and at sign-in', (tester) async {
      const text = '요청이 많습니다. 잠시 뒤 다시 시도하세요';
      final server = serverWithAccount(signedIn: false)..rateLimited.addAll({'POST /users', 'POST /login'});
      await signUp(tester, server);
      expect(error(text), findsOneWidget);
      await goBack(tester);
      await enter(tester, 'signin-username', 'tester');
      await enter(tester, 'signin-password', 'pw-1234');
      await tapId(tester, 'signin-submit');
      expect(find.descendant(of: byId('signin-error'), matching: find.text(text)), findsOneWidget);
      expect(find.textContaining('429'), findsNothing);
    });

    testWidgets('an older server (an HTML 500 for an ID that is used): says it may be that', (tester) async {
      final server = serverWithAccount(signedIn: false)..htmlError.add('POST /users');
      await pumpApp(tester, server);
      await tapId(tester, 'signup');
      await enter(tester, 'signup-last-name', '홍');
      await enter(tester, 'signup-first-name', '길동');
      await enter(tester, 'signup-username', 'used');
      await enter(tester, 'signup-phone-number', '(02) 123-4567');
      await enter(tester, 'signup-password', 'pw-1234');
      await enter(tester, 'signup-confirmPassword', 'pw-1234');
      await tapId(tester, 'signup-submit');
      expect(find.textContaining('이미 사용 중인 ID일 수 있습니다'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      expect((server.bodies['POST /users'] as Map)['phoneNumber'], '(02) 123-4567');
    });

    testWidgets('the order is 성, 이름, 사용자 ID, 연락처, 비밀번호, 비밀번호 확인', (tester) async {
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
