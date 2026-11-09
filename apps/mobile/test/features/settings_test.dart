import 'package:cypress_realworld_for_personal_portfolio_mobile/features/settings/phone_rule.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')])..balance = 10000;

Future<void> openSettings(WidgetTester tester) async {
  await tapId(tester, 'sidenav-more');
  await tapId(tester, 'sidenav-user-settings');
}

Future<void> fill(WidgetTester tester, {
  String first = 'Ada',
  String last = 'Kim',
  String email = 'ada@example.test',
  String phone = '010-1234-5678',
}) async {
  await enter(tester, 'user-settings-firstName-input', first);
  await enter(tester, 'user-settings-lastName-input', last);
  await enter(tester, 'user-settings-email-input', email);
  await enter(tester, 'user-settings-phoneNumber-input', phone);
}

String textOf(WidgetTester tester, String id) =>
    tester.widget<TextFormField>(fieldIn(id)).controller!.text;

void main() {
  group('opening', () {
    testWidgets('the ... menu opens the settings form', (tester) async {
      await pumpApp(tester, newServer());
      await openSettings(tester);

      expect(byId('user-settings-form'), findsOneWidget);
      for (final id in [
        'user-settings-firstName-input',
        'user-settings-lastName-input',
        'user-settings-email-input',
        'user-settings-phoneNumber-input',
        'user-settings-submit',
        'user-settings-privacy',
      ]) {
        expect(byId(id), findsOneWidget, reason: id);
      }
      expect(find.descendant(of: byId('user-settings-username'), matching: find.text('@tester')), findsOneWidget);
    });

    testWidgets('starts with the saved values', (tester) async {
      final server = newServer()
        ..profile.addAll({
          'email': 'saved@example.test',
          'phoneNumber': '010-9999-8888',
          'defaultPrivacyLevel': 'contacts',
        });
      await pumpApp(tester, server);
      await openSettings(tester);

      expect(textOf(tester, 'user-settings-firstName-input'), 'Ada');
      expect(textOf(tester, 'user-settings-lastName-input'), 'Kim');
      expect(textOf(tester, 'user-settings-email-input'), 'saved@example.test');
      expect(textOf(tester, 'user-settings-phoneNumber-input'), '010-9999-8888');
      expect(tester.widget<ChoiceChip>(find.descendant(of: byId('user-settings-privacy-contacts'), matching: find.byType(ChoiceChip))).selected, isTrue);
    });

    testWidgets('a user with no saved privacy shows 공개', (tester) async {
      await pumpApp(tester, newServer());
      await openSettings(tester);

      bool selected(String v) => tester
          .widget<ChoiceChip>(find.descendant(of: byId('user-settings-privacy-$v'), matching: find.byType(ChoiceChip)))
          .selected;
      expect(selected('public'), isTrue);
      expect(selected('contacts'), isFalse);
      expect(selected('private'), isFalse);
    });
  });

  group('checks before saving', () {
    testWidgets('all four fields are required', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);

      await fill(tester, first: '', last: '', email: '', phone: '');
      await tapId(tester, 'user-settings-submit');

      expect(find.text('이름을 입력하세요.'), findsOneWidget);
      expect(find.text('성을 입력하세요.'), findsOneWidget);
      expect(find.text('이메일 주소를 입력하세요.'), findsOneWidget);
      expect(find.text('전화번호를 입력하세요.'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('PATCH /users')), isEmpty);
    });

    testWidgets('a bad email is refused', (tester) async {
      await pumpApp(tester, newServer());
      await openSettings(tester);

      await fill(tester, email: 'not-an-email');
      await tapId(tester, 'user-settings-submit');

      expect(find.text('올바른 이메일 주소를 입력하세요.'), findsOneWidget);
    });

    testWidgets('the phone rule is the web rule: no country code', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);

      await fill(tester, phone: '+82 10 1234 5678');
      await tapId(tester, 'user-settings-submit');

      expect(find.text('전화번호가 올바르지 않습니다.'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('PATCH /users')), isEmpty);
    });
  });

  group('saving', () {
    testWidgets('sends the five values to the user\'s own id, and shows a small toast', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);

      await fill(tester);
      await tapId(tester, 'user-settings-privacy-private');
      await tapId(tester, 'user-settings-submit');

      expect(server.calls, contains('PATCH /users/u1'));
      expect(server.bodies['PATCH /users/u1'], {
        'firstName': 'Ada',
        'lastName': 'Kim',
        'email': 'ada@example.test',
        'phoneNumber': '010-1234-5678',
        'defaultPrivacyLevel': 'private',
      });
      expect(byId('alert-bar-success'), findsOneWidget);
      final toast = tester.widget<Text>(find.descendant(of: byId('alert-bar-success'), matching: find.byType(Text)));
      expect(toast.data, '저장했습니다.');
      expect(toast.style?.fontSize, lessThan(14)); // a small text
      // It stays on the settings screen.
      expect(byId('user-settings-form'), findsOneWidget);
    });

    testWidgets('the new name shows on the 내 계좌 tab after saving', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);

      await fill(tester, first: 'Grace', last: 'Lee');
      await tapId(tester, 'user-settings-submit');
      await goBack(tester);
      await tapId(tester, 'sidenav-my-account');

      expect(find.descendant(of: byId('my-account-full-name'), matching: find.text('Grace Lee')), findsOneWidget);
    });

    testWidgets('the saved values come back when the screen is opened again', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);
      await fill(tester, email: 'new@example.test', phone: '02-555-0000');
      await tapId(tester, 'user-settings-submit');
      await goBack(tester);

      await openSettings(tester);

      expect(textOf(tester, 'user-settings-email-input'), 'new@example.test');
      expect(textOf(tester, 'user-settings-phoneNumber-input'), '02-555-0000');
    });

    testWidgets('two taps in one frame send one request', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);
      await fill(tester);

      await tester.tap(byId('user-settings-submit'));
      await tester.tap(byId('user-settings-submit'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(server.calls.where((c) => c == 'PATCH /users/u1'), hasLength(1));
    });

    testWidgets('a refusal shows an error and keeps what the user typed', (tester) async {
      final server = newServer()..updateUserStatus = 500;
      await pumpApp(tester, server);
      await openSettings(tester);

      await fill(tester, email: 'keep@example.test');
      await tapId(tester, 'user-settings-submit');

      expect(find.text('저장하지 못했습니다. 입력한 내용을 확인해 주세요.'), findsOneWidget);
      expect(byId('user-settings-error'), findsOneWidget);
      expect(textOf(tester, 'user-settings-email-input'), 'keep@example.test');
    });

    testWidgets('a server that cannot be reached says so', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);
      await fill(tester);

      server.down = true;
      await tapId(tester, 'user-settings-submit');

      expect(find.text('서버에 연결할 수 없습니다.'), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('going back without saving just leaves, and the changes are dropped', (tester) async {
      final server = newServer();
      await pumpApp(tester, server);
      await openSettings(tester);
      await fill(tester, email: 'unsaved@example.test');

      await goBack(tester);

      // No question was asked and nothing was sent.
      expect(find.byType(AlertDialog), findsNothing);
      expect(server.calls.where((c) => c.startsWith('PATCH /users')), isEmpty);
      await openSettings(tester);
      expect(textOf(tester, 'user-settings-email-input'), '');
    });
  });

  group('rules', () {
    test('email', () {
      expect(validateEmail('a@b.co'), isNull);
      expect(validateEmail('first.last+tag@sub.example.test'), isNull);
      expect(validateEmail(''), '이메일 주소를 입력하세요.');
      expect(validateEmail('a@'), '올바른 이메일 주소를 입력하세요.');
      expect(validateEmail('a b@c.de'), '올바른 이메일 주소를 입력하세요.');
    });

    // The same answers as the web regex gave when it was run from the web source file.
    test('phone: the web rule, copied', () {
      for (final ok in ['010-1234-5678', '01012345678', '650-555-1212', '1234567']) {
        expect(validatePhoneNumber(ok), isNull, reason: ok);
      }
      for (final bad in ['+82 10 1234 5678', '(02) 1234-5678', '+1 650 555 1212', '12', 'abc']) {
        expect(validatePhoneNumber(bad), '전화번호가 올바르지 않습니다.', reason: bad);
      }
      expect(validatePhoneNumber(''), '전화번호를 입력하세요.');
    });
  });
}
