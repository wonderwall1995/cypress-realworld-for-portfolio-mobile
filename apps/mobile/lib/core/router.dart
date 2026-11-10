import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_page.dart';
import '../features/account/my_account_page.dart';
import '../features/auth/signin_page.dart';
import '../features/auth/signup_page.dart';
import '../features/auth/splash_page.dart';
import '../features/bank_accounts/bank_account_new_page.dart';
import '../features/bank_accounts/bank_accounts_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/home_shell.dart';
import '../features/transactions/create/create_transaction_page.dart';
import '../features/transactions/transaction_detail_page.dart';
import '../features/transactions/transactions_page.dart';
import 'app_gate.dart';

const _splash = '/splash';
const _signIn = '/signin';
const _signUp = '/signup';
const _onboarding = '/onboarding';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  // Only a change of the gate moves the router. Other changes (for example a
  // new bank account) must not, or they can undo a pop in progress.
  ref.listen(appGateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final at = state.matchedLocation;
      switch (ref.read(appGateProvider)) {
        case AppGate.checking:
          return at == _splash ? null : _splash;
        case AppGate.signedOut:
          return (at == _signIn || at == _signUp) ? null : _signIn;
        case AppGate.onboarding:
          return at == _onboarding ? null : _onboarding;
        case AppGate.ready:
          const authOnly = {_splash, _signIn, _signUp, _onboarding};
          return authOnly.contains(at) ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: _splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: _signIn, builder: (_, __) => const SignInPage()),
      GoRoute(path: _signUp, builder: (_, __) => const SignUpPage()),
      GoRoute(path: _onboarding, builder: (_, __) => const OnboardingPage()),
      GoRoute(
        path: '/bankaccounts/new',
        builder: (_, __) => const BankAccountNewPage(),
      ),
      GoRoute(
        path: '/transaction/new',
        builder: (_, __) => const CreateTransactionPage(),
      ),
      GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: '/transaction/:transactionId',
        builder: (_, state) =>
            TransactionDetailPage(transactionId: state.pathParameters['transactionId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const TransactionsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, __) => const NotificationsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bankaccounts',
              builder: (_, __) => const BankAccountsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/my-account',
              builder: (_, __) => const MyAccountPage(),
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
