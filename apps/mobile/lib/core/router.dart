import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/signin_page.dart';
import '../features/auth/signup_page.dart';
import '../features/auth/splash_page.dart';
import '../features/shell/home_shell.dart';
import '../features/shell/placeholder_page.dart';
import 'session.dart';

const _splash = '/splash';
const _signIn = '/signin';
const _signUp = '/signup';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(sessionProvider).status;
      final at = state.matchedLocation;
      switch (status) {
        case SessionStatus.unknown:
          return at == _splash ? null : _splash;
        case SessionStatus.unauthenticated:
          return (at == _signIn || at == _signUp) ? null : _signIn;
        case SessionStatus.authenticated:
          return (at == _splash || at == _signIn || at == _signUp) ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: _splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: _signIn, builder: (_, __) => const SignInPage()),
      GoRoute(path: _signUp, builder: (_, __) => const SignUpPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const PlaceholderPage(title: '홈'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, __) => const PlaceholderPage(title: '알림'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bankaccounts',
              builder: (_, __) => const PlaceholderPage(title: '은행 계좌'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const PlaceholderPage(title: '설정'),
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
