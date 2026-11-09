import 'package:cypress_realworld_for_personal_portfolio_mobile/app.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';

Future<void> pumpApp(WidgetTester tester, FakeHandler handler) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(fakeClient(handler))],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no session: shows the sign-in placeholder', (tester) async {
    await pumpApp(tester, (_) => jsonBody(401, {'error': 'User is unauthorized'}));

    expect(find.byKey(const ValueKey('signin-placeholder')), findsOneWidget);
    expect(find.text('서버에 연결되었습니다. 로그인이 필요합니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('sidenav-home')), findsNothing);
  });

  testWidgets('server not reachable: tells the user', (tester) async {
    await pumpApp(
      tester,
      (o) => throw DioException.connectionError(requestOptions: o, reason: 'down'),
    );

    expect(find.byKey(const ValueKey('signin-placeholder')), findsOneWidget);
    expect(find.text('서버에 연결할 수 없습니다.'), findsOneWidget);
  });

  testWidgets('valid session: shows the tabs and moves between them', (tester) async {
    await pumpApp(
      tester,
      (_) => jsonBody(200, {
        'user': {'id': 'u1', 'username': 'tester'},
      }),
    );

    expect(find.byKey(const ValueKey('signin-placeholder')), findsNothing);
    expect(find.text('홈 화면'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidenav-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('알림 화면'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidenav-bankaccounts')));
    await tester.pumpAndSettle();
    expect(find.text('은행 계좌 화면'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidenav-user-settings')));
    await tester.pumpAndSettle();
    expect(find.text('설정 화면'), findsOneWidget);
  });
}
