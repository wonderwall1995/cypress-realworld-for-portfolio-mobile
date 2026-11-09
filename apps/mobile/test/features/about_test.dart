import 'dart:io';

import 'package:cypress_realworld_for_personal_portfolio_mobile/features/about/mit_license.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

FakeServer newServer() => FakeServer(signedIn: true, accounts: [testAccount('b1')]);

Future<void> openAbout(WidgetTester tester) async {
  await tapId(tester, 'sidenav-more');
  await tapId(tester, 'sidenav-about');
}

void main() {
  testWidgets('the ... menu has 앱 정보', (tester) async {
    await pumpApp(tester, newServer());

    await tapId(tester, 'sidenav-more');

    expect(byId('sidenav-about'), findsOneWidget);
    expect(find.text('앱 정보'), findsOneWidget);
  });

  testWidgets('says it is unofficial and that Cypress.io owns the original work', (tester) async {
    await pumpApp(tester, newServer());
    await openAbout(tester);

    expect(byId('about-app-name'), findsOneWidget);
    expect(find.descendant(of: byId('about-app-name'), matching: find.text(appDisplayName)), findsOneWidget);
    final notice = tester.widget<Text>(find.descendant(of: byId('about-notice'), matching: find.byType(Text)));
    expect(notice.data, contains('비공식'));
    expect(notice.data, contains('Cypress.io'));
    expect(notice.data, contains('제휴'));
    expect(notice.data, contains('원저작권은 모두 Cypress.io 팀에게 있습니다'));
  });

  testWidgets('shows the original MIT license and where the project is', (tester) async {
    await pumpApp(tester, newServer());
    await openAbout(tester);

    final license = tester.widget<SelectableText>(
      find.descendant(of: byId('about-license-text'), matching: find.byType(SelectableText)),
    );
    expect(license.data, contains('MIT License'));
    expect(license.data, contains('Copyright (c) 2020 Cypress.io'));
    expect(
      find.descendant(of: byId('about-original-project'), matching: find.textContaining(originalProjectUrl)),
      findsOneWidget,
    );
  });

  testWidgets('the licenses of the packages open in Flutter\'s license page', (tester) async {
    await pumpApp(tester, newServer());
    await openAbout(tester);

    await tester.tap(byId('about-open-licenses-button'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('the app can be left again with Back', (tester) async {
    await pumpApp(tester, newServer());
    await openAbout(tester);

    await goBack(tester);

    expect(byId('nav-transaction-tabs'), findsOneWidget);
  });

  test('the text in the app is the same as the LICENSE file of this repository', () {
    // The tests run in apps/mobile.
    final file = File('../../LICENSE');
    expect(file.existsSync(), isTrue, reason: 'LICENSE not found at ${file.absolute.path}');
    String normalize(String s) => s.replaceAll('\r\n', '\n').trim();
    expect(normalize(originalProjectLicense), normalize(file.readAsStringSync()));
  });
}
