import 'package:cypress_realworld_for_personal_portfolio_mobile/app.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

/// Finds the widget with a test id (the web `data-testid` name).
Finder byId(String id) => find.byKey(ValueKey<String>(id));

/// Finds the text field inside a test id.
Finder fieldIn(String id) =>
    find.descendant(of: byId(id), matching: find.byType(TextFormField));

Future<void> pumpApp(WidgetTester tester, FakeServer server) async {
  // A tall screen, so the whole form is visible.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(server.client())],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapId(WidgetTester tester, String id) async {
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String id, String text) =>
    tester.enterText(fieldIn(id), text);
