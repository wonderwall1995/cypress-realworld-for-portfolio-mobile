import '../../core/header_credit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/error_text.dart';
import '../auth/auth_widgets.dart';
import '../../core/test_id.dart';
import 'bank_account.dart';
import 'bank_accounts_controller.dart';

/// The "은행 계좌" tab: the list, delete (with a confirm dialog), and a button
/// to add one.
class BankAccountsPage extends ConsumerWidget {
  const BankAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(bankAccountsProvider);
    final deleteError = ref.watch(bankAccountDeleteErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('은행 계좌'),
        actions: [
          TestId(
            'bankaccount-new',
            child: TextButton.icon(
              onPressed: () => context.push('/bankaccounts/new'),
              icon: const Icon(Icons.add),
              label: const Text('만들기'),
            ),
          ),
          const SizedBox(width: 8),
          const HeaderCredit(),
        ],
      ),
      body: accounts.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          onRetry: () => ref.read(bankAccountsProvider.notifier).reload(),
        ),
        data: (list) => Column(
          children: [
            // The reason the server gave, above the list. The account stays in it.
            if (deleteError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FormErrorBanner(id: 'bankaccount-delete-error', message: deleteError),
              ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('등록된 은행 계좌가 없습니다.'))
                  : TestId(
                      'bankaccount-list',
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _BankAccountTile(account: list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TestId(
        'bankaccount-load-error',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('은행 계좌를 불러오지 못했습니다.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

class _BankAccountTile extends ConsumerWidget {
  const _BankAccountTile({required this.account});

  final BankAccount account;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('은행 계좌 삭제'),
        content: Text('"${account.bankName}" 계좌를 삭제하시겠습니까?'),
        actions: [
          TestId(
            'bankaccount-delete-cancel',
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
          ),
          TestId(
            'bankaccount-delete-confirm',
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('삭제'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final errors = ref.read(bankAccountDeleteErrorProvider.notifier);
    errors.set(null);
    try {
      await ref.read(bankAccountsProvider.notifier).remove(account.id);
    } on ApiException catch (e) {
      errors.set(serverRefusalText(e, base: '은행 계좌를 삭제하지 못했습니다'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMoney = (account.balance ?? 0) != 0;
    return TestId(
      'bankaccount-list-item-${account.id}',
      child: ListTile(
        leading: const Icon(Icons.account_balance_outlined),
        title: Text(account.bankName),
        subtitle: hasMoney
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.describe),
                  const TestId('bankaccount-delete-locked', child: Text('잔액이 있는 계좌는 삭제할 수 없습니다.')),
                ],
              )
            : Text(account.describe),
        isThreeLine: hasMoney,
        trailing: TestId(
          'bankaccount-delete',
          child: TextButton(
            // The server refuses to delete an account that holds money (400).
            onPressed: hasMoney ? null : () => _confirmAndDelete(context, ref),
            child: const Text('삭제'),
          ),
        ),
      ),
    );
  }
}
