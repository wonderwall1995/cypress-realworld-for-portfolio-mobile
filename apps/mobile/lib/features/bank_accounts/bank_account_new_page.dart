import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/test_id.dart';
import 'bank_account_form.dart';
import 'bank_accounts_controller.dart';

/// Add one more bank account (outside the first-time setup).
class BankAccountNewPage extends ConsumerWidget {
  const BankAccountNewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('은행 계좌 만들기')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BankAccountForm(
                onSubmit: ({
                  required bankName,
                  required routingNumber,
                  required accountNumber,
                }) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final router = GoRouter.of(context);
                  await ref.read(bankAccountsProvider.notifier).create(
                        bankName: bankName,
                        routingNumber: routingNumber,
                        accountNumber: accountNumber,
                      );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: TestId('alert-bar-success', child: Text('은행 계좌를 만들었습니다.')),
                    ),
                  );
                  router.pop();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
