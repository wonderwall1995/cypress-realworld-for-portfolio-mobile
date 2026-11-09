import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';
import '../bank_accounts/bank_account_form.dart';
import '../bank_accounts/bank_accounts_controller.dart';
import 'onboarding_controller.dart';

/// The first-time setup: welcome, create a bank account, finished.
/// Full screen. The only way out besides finishing is to sign out.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(onboardingProvider);

    final title = switch (step) {
      OnboardingStep.welcome || OnboardingStep.done => '시작하기',
      OnboardingStep.createAccount => '은행 계좌 만들기',
      OnboardingStep.finished => '완료',
    };

    return PopScope(
      canPop: false,
      child: TestId(
        'user-onboarding-dialog',
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: TestId('user-onboarding-dialog-title', child: Text(title)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TestId(
                    'user-onboarding-dialog-content',
                    child: switch (step) {
                      OnboardingStep.welcome || OnboardingStep.done => const Text(
                          '이 앱에서 거래를 하려면 은행 계좌가 필요합니다.\n\n'
                          '[다음]을 눌러 은행 계좌 등록을 시작하세요.',
                        ),
                      OnboardingStep.createAccount => BankAccountForm(
                          onSubmit: ({
                            required bankName,
                            required routingNumber,
                            required accountNumber,
                          }) async {
                            await ref.read(bankAccountsProvider.notifier).create(
                                  bankName: bankName,
                                  routingNumber: routingNumber,
                                  accountNumber: accountNumber,
                                );
                            ref.read(onboardingProvider.notifier).next();
                          },
                        ),
                      OnboardingStep.finished => const Text(
                          '모든 준비가 끝났습니다!\n\n'
                          '함께하게 되어 기쁩니다.',
                        ),
                    },
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TestId(
                    'user-onboarding-logout',
                    child: TextButton(
                      onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                      child: const Text('로그아웃'),
                    ),
                  ),
                  if (step != OnboardingStep.createAccount)
                    TestId(
                      'user-onboarding-next',
                      child: FilledButton(
                        onPressed: () => ref.read(onboardingProvider.notifier).next(),
                        child: Text(step == OnboardingStep.finished ? '완료' : '다음'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
