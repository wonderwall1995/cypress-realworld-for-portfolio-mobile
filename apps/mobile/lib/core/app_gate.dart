import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/bank_accounts/bank_accounts_controller.dart';
import '../features/onboarding/onboarding_controller.dart';
import 'session.dart';

/// Which part of the app the user may see.
///
/// The router listens to this one value, so it only moves when this changes
/// (not every time a bank account is added or deleted).
enum AppGate {
  /// Asking the server (session or bank accounts). Show the splash screen.
  checking,

  /// Not signed in. Show sign-in and sign-up.
  signedOut,

  /// Signed in, but the first-time setup must be done.
  onboarding,

  /// Signed in and set up. Show the tabs.
  ready,
}

final appGateProvider = Provider<AppGate>((ref) {
  final status = ref.watch(sessionProvider.select((s) => s.status));
  switch (status) {
    case SessionStatus.unknown:
      return AppGate.checking;
    case SessionStatus.unauthenticated:
      return AppGate.signedOut;
    case SessionStatus.authenticated:
      final accounts = ref.watch(bankAccountsProvider);
      if (accounts.isLoading) return AppGate.checking;

      // Same rule as the web: the setup is shown when the user has no bank
      // account, and it stays open until the user reaches "완료".
      // If the list could not be loaded, do not block the user.
      final noAccounts =
          !accounts.hasError && accounts.hasValue && accounts.requireValue.isEmpty;
      final step = ref.watch(onboardingProvider);
      final needsOnboarding =
          step != OnboardingStep.done && (noAccounts || step != OnboardingStep.welcome);
      return needsOnboarding ? AppGate.onboarding : AppGate.ready;
  }
});
