import 'package:cypress_realworld_for_personal_portfolio_mobile/core/header_credit.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')])..balance = 10000;

Text lineOf(WidgetTester tester, String id) =>
    tester.widget<Text>(find.descendant(of: byId(id), matching: find.byType(Text)));

void main() {
  const tabs = [
    (tab: null, name: '홈'),
    (tab: 'sidenav-notifications', name: '알림'),
    (tab: 'sidenav-bankaccounts', name: '은행 계좌'),
    (tab: 'sidenav-my-account', name: '내 계좌'),
  ];

  for (final t in tabs) {
    testWidgets('the ${t.name} header has the two credit lines at its right end', (tester) async {
      await pumpApp(tester, newServer());
      if (t.tab != null) await tapId(tester, t.tab!);

      expect(byId('header-credit'), findsOneWidget);
      expect(lineOf(tester, 'header-credit-copyright').data, '© Cypress.io');
      expect(lineOf(tester, 'header-credit-made-by').data, 'made by Claude');

      // Two lines: the second one is under the first one.
      final first = tester.getRect(byId('header-credit-copyright'));
      final second = tester.getRect(byId('header-credit-made-by'));
      expect(second.top, greaterThanOrEqualTo(first.bottom - 1));
      // Right end: the right edge is near the screen's right edge, inside the header.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(screen.width - tester.getRect(byId('header-credit')).right, lessThan(24));
      expect(tester.getRect(byId('header-credit')).bottom, lessThan(kToolbarHeight + 40));
    });
  }

  testWidgets('the font sizes are 6 : 4, line 2 is fainter, both are monospace', (tester) async {
    await pumpApp(tester, newServer());

    final first = lineOf(tester, 'header-credit-copyright').style!;
    final second = lineOf(tester, 'header-credit-made-by').style!;

    expect(first.fontSize! / second.fontSize!, closeTo(6 / 4, 0.001));
    expect(second.fontSize, lessThan(first.fontSize!));
    expect(second.color!.a, lessThan(first.color!.a));
    expect(first.fontFamily, 'monospace');
    expect(second.fontFamily, 'monospace');
  });

  testWidgets('the credit does not hide the 만들기 button on the bank accounts header', (tester) async {
    await pumpApp(tester, newServer());
    await tapId(tester, 'sidenav-bankaccounts');

    final button = tester.getRect(byId('bankaccount-new'));
    final credit = tester.getRect(byId('header-credit'));
    expect(button.right, lessThanOrEqualTo(credit.left));
    // And the button still works.
    await tapId(tester, 'bankaccount-new');
    expect(byId('bankaccount-form'), findsOneWidget);
  });

  group('the Cypress.io line is a link', () {
    testWidgets('tapping it opens the original repository in the browser', (tester) async {
      final opened = <Uri>[];
      await pumpApp(tester, newServer(), overrides: [
        urlOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
      ]);

      await tester.tap(byId('header-credit-copyright'));
      await tester.pump();

      expect(opened, [Uri.parse('https://github.com/cypress-io/cypress-realworld-app')]);
      expect(byId('alert-bar-error'), findsNothing);
    });

    testWidgets('it is underlined and marked as a link', (tester) async {
      await pumpApp(tester, newServer());

      expect(lineOf(tester, 'header-credit-copyright').style!.decoration, TextDecoration.underline);
      expect(lineOf(tester, 'header-credit-made-by').style!.decoration, isNull);
      final semantics = tester.getSemantics(find.descendant(of: byId('header-credit-copyright'), matching: find.byType(Text)));
      expect(semantics.getSemanticsData().flagsCollection.isLink, isTrue);
    });

    testWidgets('when the browser cannot be opened, a pink toast says so', (tester) async {
      await pumpApp(tester, newServer(), overrides: [
        urlOpenerProvider.overrideWithValue((url) async => false),
      ]);

      await tester.tap(byId('header-credit-copyright'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('링크를 열 수 없습니다.'), findsOneWidget);
      expect(byId('alert-bar-error'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('an error from the launcher is handled the same way', (tester) async {
      await pumpApp(tester, newServer(), overrides: [
        urlOpenerProvider.overrideWithValue((url) async => throw Exception('no browser')),
      ]);

      await tester.tap(byId('header-credit-copyright'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(byId('alert-bar-error'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the second line is not a link', (tester) async {
      final opened = <Uri>[];
      await pumpApp(tester, newServer(), overrides: [
        urlOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
      ]);

      await tester.tap(byId('header-credit-made-by'), warnIfMissed: false);
      await tester.pump();

      expect(opened, isEmpty);
    });
  });

  test('the sizes in the constants keep the 6 : 4 ratio', () {
    expect(HeaderCredit.copyrightFontSize / HeaderCredit.madeByFontSize, closeTo(6 / 4, 0.001));
  });
}
