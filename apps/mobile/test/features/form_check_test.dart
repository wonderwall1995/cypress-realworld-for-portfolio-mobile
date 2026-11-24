import 'package:cypress_realworld_for_personal_portfolio_mobile/core/form_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// The button can be far below a wrong field: the topmost wrong one comes into view.
void main() {
  const size = Size(360, 400); // as when the keyboard is open, or with big letters

  Rect body(WidgetTester tester) =>
      Rect.fromLTRB(0, tester.getRect(find.byType(AppBar).last).bottom, size.width, size.height);

  void expectInView(WidgetTester tester, Finder what) {
    final rect = tester.getRect(what);
    expect(rect.top, greaterThanOrEqualTo(body(tester).top), reason: 'above');
    expect(rect.bottom, lessThanOrEqualTo(body(tester).bottom), reason: 'below');
  }

  testWidgets('sign up: the first of many wrong fields, and the only wrong one', (tester) async {
    final server = FakeServer(accounts: [testAccount('b1')]);
    await pumpApp(tester, server, size: size);
    await tester.ensureVisible(byId('signup'));
    await tester.pumpAndSettle();
    await tapId(tester, 'signup');

    await tester.ensureVisible(byId('signup-submit'));
    await tester.pumpAndSettle();
    await tapId(tester, 'signup-submit');
    expectInView(tester, find.text('성을 입력하세요.'));

    for (final (id, text) in [
      ('signup-last-name', '홍'),
      ('signup-first-name', '길동'),
      ('signup-username', 'free'),
      ('signup-phone-number', 'abc'),
      ('signup-password', 'pw-1234'),
      ('signup-confirmPassword', 'pw-1234'),
    ]) {
      await tester.ensureVisible(byId(id));
      await enter(tester, id, text);
    }
    // Or the field that was typed into last pulls the screen back.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(byId('signup-submit'));
    await tester.pumpAndSettle();
    await tapId(tester, 'signup-submit');
    expectInView(tester, find.textContaining('연락처가 올바르지 않습니다'));
    expect(server.calls.where((call) => call == 'POST /users'), isEmpty);
  });

  testWidgets('settings: an empty name at the top, saved from the bottom', (tester) async {
    final server = FakeServer(signedIn: true, accounts: [testAccount('b1')]);
    await pumpApp(tester, server, size: const Size(360, 800));
    await tapId(tester, 'sidenav-more');
    await tapId(tester, 'sidenav-user-settings');
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
    await tester.ensureVisible(byId('user-settings-lastName-input'));
    await enter(tester, 'user-settings-lastName-input', '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(byId('user-settings-submit'));
    await tester.pumpAndSettle();
    await tapId(tester, 'user-settings-submit');
    expectInView(tester, find.text('성을 입력하세요.'));
  });

  testWidgets('a wrong field that is in view moves nothing', (tester) async {
    await pumpApp(tester, FakeServer(accounts: [testAccount('b1')]), size: const Size(360, 1600));
    await tapId(tester, 'signup');
    final before = tester.getRect(byId('signup-submit'));
    await tapId(tester, 'signup-submit');
    expect(find.text('성을 입력하세요.'), findsOneWidget);
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, 0);
    expect(tester.getRect(byId('signup-submit')).top, greaterThanOrEqualTo(before.top));
  });

  testWidgets('a wrong field below the view comes up', (tester) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _LongForm(form: form))));
    expect(form.currentState, isNotNull);
    await tester.tap(find.byKey(const Key('top-button')));
    await tester.pumpAndSettle();
    expect(find.text('wrong').hitTestable(), findsOneWidget);
  });
}

class _LongForm extends StatelessWidget {
  const _LongForm({required this.form});
  final GlobalKey<FormState> form;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            children: [
              ElevatedButton(key: const Key('top-button'), onPressed: () => checkForm(form), child: const Text('go')),
              const SizedBox(height: 1500),
              TextFormField(validator: (_) => 'wrong'),
              const SizedBox(height: 1500),
            ],
          ),
        ),
      );
}
