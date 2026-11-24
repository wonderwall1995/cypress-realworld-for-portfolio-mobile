import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

/// The phone's own buttons (back, home, recent apps) lie over the app: below it, or
/// at a side when the phone is turned. Nothing of the app that can be touched may be
/// under them. Each screen is scrolled to its end first, as a user would do.
const _bar = 48.0;

/// Taps, text fields and everything built on them.
bool _canTouch(Widget w) => switch (w) {
  InkResponse(:final onTap) => onTap != null,
  EditableText() => true,
  _ => false,
};

void _expectClear(WidgetTester tester, Size size, EdgeInsets bars, String screen) {
  final safe = Rect.fromLTRB(bars.left, 0, size.width - bars.right, size.height - bars.bottom);
  var seen = 0;
  for (final element in find.byWidgetPredicate(_canTouch).hitTestable().evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    seen++;
    // At a side nothing may even reach under the buttons. Below, what is still to be
    // scrolled is cut off at the edge of the list, so there the middle counts.
    final clear = rect.left >= safe.left && rect.right <= safe.right && rect.center.dy < safe.bottom;
    expect(clear, isTrue, reason: '$screen: ${element.widget} at $rect is under the phone\'s buttons ($safe)');
  }
  expect(seen, greaterThan(0), reason: screen);
}

FakeServer _server() => FakeServer(
  signedIn: true,
  accounts: [for (var i = 0; i < 12; i++) testAccount('b$i', balance: i.isEven ? 0 : 20000)],
)
  ..users.addAll([for (var i = 2; i < 30; i++) testOtherUser('u$i', 'Bob$i', 'Test')])
  ..notifications.addAll([for (var i = 0; i < 20; i++) testNotification('n$i', 'like')])
  ..everyone.addAll([for (var i = 0; i < 20; i++) testTransaction('t$i', commentTexts: ['a', 'b'])]);

void main() {
  final turns = {
    'upright': (const Size(360, 640), const EdgeInsets.only(bottom: _bar)),
    'turned, buttons right': (const Size(740, 360), const EdgeInsets.only(right: _bar)),
    'turned, buttons left': (const Size(740, 360), const EdgeInsets.only(left: _bar)),
  };

  for (final MapEntry(key: turn, value: (size, bars)) in turns.entries) {
    Future<void> open(WidgetTester tester, {FakeServer? server}) async {
      await pumpApp(tester, server ?? _server(), size: size);
      final padding = FakeViewPadding(left: bars.left, right: bars.right, bottom: bars.bottom);
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      await tester.pumpAndSettle();
    }

    Future<void> check(WidgetTester tester, String screen) async {
      _expectClear(tester, size, bars, screen);
      final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).hitTestable();
      for (final element in lists.evaluate().toList()) {
        final position = (element as StatefulElement).state as ScrollableState;
        if (position.position.hasContentDimensions) position.position.jumpTo(position.position.maxScrollExtent);
      }
      await tester.pumpAndSettle();
      _expectClear(tester, size, bars, '$screen, at the end');
    }

    group(turn, () {
      testWidgets('sign in, sign up', (tester) async {
        await open(tester, server: FakeServer());
        await check(tester, 'sign in');
        await tester.ensureVisible(byId('signup'));
        await tapId(tester, 'signup');
        await check(tester, 'sign up');
      });

      testWidgets('the tabs', (tester) async {
        await open(tester);
        await check(tester, 'home');
        for (final tab in ['sidenav-notifications', 'sidenav-bankaccounts', 'sidenav-my-account']) {
          await tapId(tester, tab);
          await check(tester, tab);
        }
      });

      testWidgets('the menu, settings, about', (tester) async {
        await open(tester);
        await tapId(tester, 'sidenav-more');
        await check(tester, 'menu');
        await tapId(tester, 'sidenav-user-settings');
        await check(tester, 'settings');
        await goBack(tester);
        await tapId(tester, 'sidenav-more');
        await tester.ensureVisible(byId('sidenav-about'));
        await tapId(tester, 'sidenav-about');
        await check(tester, 'about');
      });

      testWidgets('the menu with letters twice as big can be scrolled to 로그아웃', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        // The home screen itself is not what is looked at here.
        await pumpApp(tester, _server(), size: Size(size.width, 1600));
        await tapId(tester, 'sidenav-my-account');
        tester.view.physicalSize = size;
        final padding = FakeViewPadding(left: bars.left, right: bars.right, bottom: bars.bottom);
        tester.view.padding = padding;
        tester.view.viewPadding = padding;
        await tester.pumpAndSettle();
        await tapId(tester, 'sidenav-more');
        expect(tester.takeException(), isNull);
        await check(tester, 'menu, big letters');
        expect(byId('sidenav-signout').hitTestable(), findsOneWidget);
      });

      testWidgets('a new bank account', (tester) async {
        await open(tester);
        await tapId(tester, 'sidenav-bankaccounts');
        await tapId(tester, 'bankaccount-new');
        await check(tester, 'new account');
      });

      testWidgets('the detail', (tester) async {
        // The list is short on a turned phone: open the detail on a tall one.
        await pumpApp(tester, _server());
        await tapId(tester, 'transaction-item-t0');
        tester.view.physicalSize = size;
        final padding = FakeViewPadding(left: bars.left, right: bars.right, bottom: bars.bottom);
        tester.view.padding = padding;
        tester.view.viewPadding = padding;
        await tester.pumpAndSettle();
        await check(tester, 'detail');
      });

      testWidgets('the transfer: who, how much, the password, done', (tester) async {
        await open(tester);
        await tapId(tester, 'sidenav-my-account');
        await tester.ensureVisible(byId('sidenav-transfer'));
        await tester.pumpAndSettle();
        await tapId(tester, 'sidenav-transfer');
        await check(tester, 'who');
        await tester.enterText(
          find.descendant(of: byId('user-list-search-input'), matching: find.byType(TextField)),
          'bob2',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        await tapId(tester, 'user-list-item-u2');
        await check(tester, 'how much');
        await enter(tester, 'transaction-create-amount-input', '5');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(byId('transaction-create-my-account-b1'));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: byId('transaction-create-my-account-b1'), matching: find.byType(Radio<String>)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(byId('transaction-create-submit-payment'));
        await tester.pumpAndSettle();
        await tapId(tester, 'transaction-create-submit-payment');
        expect(byId('transaction-confirm-dialog'), findsOneWidget);
        await check(tester, 'password');
        await tester.enterText(
          find.descendant(of: byId('transaction-confirm-password'), matching: find.byType(TextField)),
          'pw-1234',
        );
        await tester.pump();
        await tapId(tester, 'transaction-confirm-confirm');
        expect(byId('transaction-create-result'), findsOneWidget);
        await check(tester, 'done');
      });

      testWidgets('the deposit and the amount filter', (tester) async {
        await open(tester);
        await tapId(tester, 'transaction-list-filter-deposit-button');
        await check(tester, 'amount filter');
        await tester.ensureVisible(byId('transaction-list-filter-deposit-close-button'));
        await tapId(tester, 'transaction-list-filter-deposit-close-button');
        await tapId(tester, 'sidenav-my-account');
        await tester.ensureVisible(byId('sidenav-deposit'));
        await tester.pumpAndSettle();
        await tapId(tester, 'sidenav-deposit');
        await check(tester, 'deposit');
      });
    });
  }
}
