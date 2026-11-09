import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';

enum OnboardingStep { welcome, createAccount, finished, done }

/// Where the signed-in user is in the first-time setup.
///
/// Starts again at [OnboardingStep.welcome] when the signed-in user changes.
class OnboardingController extends Notifier<OnboardingStep> {
  @override
  OnboardingStep build() {
    ref.watch(sessionProvider.select((s) => s.user?['id']));
    return OnboardingStep.welcome;
  }

  void next() {
    state = switch (state) {
      OnboardingStep.welcome => OnboardingStep.createAccount,
      OnboardingStep.createAccount => OnboardingStep.finished,
      OnboardingStep.finished => OnboardingStep.done,
      OnboardingStep.done => OnboardingStep.done,
    };
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingStep>(OnboardingController.new);
