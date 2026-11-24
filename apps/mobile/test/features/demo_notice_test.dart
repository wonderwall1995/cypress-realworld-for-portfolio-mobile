import 'package:cypress_realworld_for_personal_portfolio_mobile/core/demo_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// People who try the app are told, next to the fields, not to type anything real.
void main() {
  Finder notice(String id, String text) => find.descendant(of: byId(id), matching: find.text(text));

  InputDecoration decoration(WidgetTester tester, String id) => tester
      .widget<TextField>(find.descendant(of: byId(id), matching: find.byType(TextField)))
      .decoration!;

  FakeServer signedOut() => FakeServer(accounts: [testAccount('b1', balance: 20000)]);
  FakeServer signedIn() => FakeServer(
        signedIn: true,
        accounts: [testAccount('b1', balance: 20000)],
      )
        ..users.add(testOtherUser('u2', 'Bob', 'Test'))
        ..everyone.add(testTransaction('t1'));

  Future<void> openSettings(WidgetTester tester) async {
    await tapId(tester, 'sidenav-more');
    await tapId(tester, 'sidenav-user-settings');
  }

  testWidgets('signing in: above the ID and the password', (tester) async {
    await pumpApp(tester, signedOut());

    expect(notice('signin-demo-notice', signInDemoNotice), findsOneWidget);
    expect(
      tester.getBottomLeft(byId('signin-demo-notice')).dy,
      lessThan(tester.getTopLeft(byId('signin-username')).dy),
    );
  });

  testWidgets('signing up: above the form, and in the ID, the phone number and the password', (tester) async {
    await pumpApp(tester, signedOut());
    await tapId(tester, 'signup');

    expect(notice('signup-demo-notice', signUpDemoNotice), findsOneWidget);
    expect(
      tester.getBottomLeft(byId('signup-demo-notice')).dy,
      lessThan(tester.getTopLeft(byId('signup-last-name')).dy),
    );
    expect(decoration(tester, 'signup-username').hintText, '평소 쓰시는 ID는 넣지 마세요!');
    expect(decoration(tester, 'signup-phone-number').hintText, contains('진짜 연락처는 넣지 마세요'));
    expect(decoration(tester, 'signup-password').hintText, contains('자신이 쓰던 것을 쓰면 안 됩니다'));
  });

  testWidgets('settings: above the name, the email and the phone number', (tester) async {
    await pumpApp(tester, signedIn());
    await openSettings(tester);

    expect(notice('user-settings-demo-notice', settingsDemoNotice), findsOneWidget);
    expect(
      tester.getBottomLeft(byId('user-settings-demo-notice')).dy,
      lessThan(tester.getTopLeft(byId('user-settings-lastName-input')).dy),
    );
  });

  for (final (name, size, scale) in [
    ('a small phone', const Size(320, 568), 1.0),
    ('a small phone with letters twice as big', const Size(320, 568), 2.0),
  ]) {
    testWidgets('$name: nothing runs out of the screen, and the form can be reached', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester, signedOut(), size: size);
      expect(tester.takeException(), isNull, reason: 'sign in');
      await tester.ensureVisible(byId('signin-submit'));
      await tester.pumpAndSettle();
      expect(byId('signin-submit').hitTestable(), findsOneWidget);
      await tester.ensureVisible(byId('signup'));
      await tester.pumpAndSettle();
      await tapId(tester, 'signup');
      expect(tester.takeException(), isNull, reason: 'sign up');
      await tester.ensureVisible(byId('signup-submit'));
      await tester.pumpAndSettle();
      expect(byId('signup-submit').hitTestable(), findsOneWidget);
    });

    testWidgets('$name: the comment field with the keyboard open', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      // The home list of big letters is longer than a small phone: open it on a tall one.
      await pumpApp(tester, signedIn(), size: Size(size.width, 2000));
      await tapId(tester, 'transaction-item-t1');
      expect(byId('transaction-detail-header'), findsOneWidget);
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(byId('transaction-comment-input-t1').hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(byId('transaction-comment-input-t1')).dy, lessThanOrEqualTo(size.height - 260));
    });

    testWidgets('$name: the settings', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpApp(tester, signedIn(), size: size);
      await openSettings(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(byId('user-settings-submit'));
      await tester.pumpAndSettle();
      expect(byId('user-settings-submit').hitTestable(), findsOneWidget);
    });
  }
}
