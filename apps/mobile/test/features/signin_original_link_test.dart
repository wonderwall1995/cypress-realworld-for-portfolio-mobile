import 'package:cypress_realworld_for_personal_portfolio_mobile/core/header_credit.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

const repoUrl = 'https://github.com/cypress-io/cypress-realworld-app';

FakeServer signedOutServer() => FakeServer(signedIn: false, accounts: [testAccount('b1')]);

void main() {
  testWidgets('the sign-in screen says where the original comes from, under the title', (tester) async {
    await pumpApp(tester, signedOutServer());

    final sentence = tester.widget<Text>(
      find.descendant(of: byId('signin-original-link-notice'), matching: find.byType(Text)).first,
    );
    // The link sits between the two plain parts.
    expect(
      sentence.textSpan!.toPlainText(includePlaceholders: false),
      '본 레포의 원본은 Cypress.io 팀의 MIT 라이센스 배포 판  입니다.',
    );
    expect(find.descendant(of: byId('signin-original-link'), matching: find.text('Realworld-app')), findsOneWidget);
    // Under the "로그인" title and above the first field.
    final title = tester.getRect(find.text('로그인').first);
    final notice = tester.getRect(byId('signin-original-link-notice'));
    final username = tester.getRect(byId('signin-username'));
    expect(notice.top, greaterThanOrEqualTo(title.bottom - 1));
    expect(notice.bottom, lessThanOrEqualTo(username.top));
  });

  testWidgets('tapping Realworld-app opens the repository in the browser', (tester) async {
    final opened = <Uri>[];
    await pumpApp(tester, signedOutServer(), overrides: [
      urlOpenerProvider.overrideWithValue((url) async {
        opened.add(url);
        return true;
      }),
    ]);

    await tester.tap(byId('signin-original-link'));
    await tester.pump();

    expect(opened, [Uri.parse(repoUrl)]);
    expect(byId('alert-bar-error'), findsNothing);
  });

  testWidgets('it is the same address as the header credit link', (tester) async {
    expect(HeaderCredit.copyrightUrl, Uri.parse(repoUrl));
  });

  testWidgets('when the browser cannot be opened, a pink toast says so', (tester) async {
    await pumpApp(tester, signedOutServer(), overrides: [
      urlOpenerProvider.overrideWithValue((url) async => false),
    ]);

    await tester.tap(byId('signin-original-link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(byId('alert-bar-error'), findsOneWidget);
    expect(find.text('링크를 열 수 없습니다.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('it is underlined and marked as a link', (tester) async {
    await pumpApp(tester, signedOutServer());

    final text = tester.widget<Text>(find.descendant(of: byId('signin-original-link'), matching: find.byType(Text)));
    expect(text.data, 'Realworld-app');
    expect(text.style?.decoration, TextDecoration.underline);
    final semantics = tester.getSemantics(find.descendant(of: byId('signin-original-link'), matching: find.byType(Text)));
    expect(semantics.getSemanticsData().flagsCollection.isLink, isTrue);
  });

  testWidgets('the sign-up screen says it too, under the title', (tester) async {
    await pumpApp(tester, signedOutServer());
    await tapId(tester, 'signup');
    await tester.pumpAndSettle();

    final title = tester.getRect(byId('signup-title'));
    final notice = tester.getRect(byId('signup-original-link-notice'));
    expect(notice.top, greaterThanOrEqualTo(title.bottom - 1));
    expect(find.descendant(of: byId('signup-original-link'), matching: find.text('Realworld-app')), findsOneWidget);
  });
}
