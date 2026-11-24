import '../../core/header_credit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/error_text.dart';
import '../../core/session.dart';
import '../auth/auth_widgets.dart';
import '../../core/test_id.dart';
import '../settings/privacy.dart';
import '../transactions/transaction.dart';
import 'bank_account.dart';
import 'bank_accounts_controller.dart';

/// The "은행 계좌" tab: who can see the user's transfers, the list, delete
/// (with a confirm dialog), and a round button to add one.
class BankAccountsPage extends ConsumerWidget {
  const BankAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(bankAccountsProvider);
    final deleteError = ref.watch(bankAccountDeleteErrorProvider);
    // At the limit the server refuses a new account, so it is not offered.
    final atLimit = (accounts.value?.length ?? 0) >= maxBankAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('은행 계좌'),
        actions: const [HeaderCredit()],
      ),
      floatingActionButton: _NewButton(
        onPressed: atLimit ? null : () => context.push('/bankaccounts/new'),
      ),
      body: accounts.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          onRetry: () => ref.read(bankAccountsProvider.notifier).reload(),
        ),
        data: (list) => Column(
          children: [
            const _MyPrivacy(),
            const Divider(height: 1),
            if (atLimit)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TestId(
                  'bankaccount-limit',
                  child: Text('은행 계좌는 최대 $maxBankAccounts개까지 만들 수 있습니다.'),
                ),
              ),
            // The reason the server gave, above the list. The account stays in it.
            if (deleteError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FormErrorBanner(id: 'bankaccount-notice', message: deleteError),
              ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: TestId('bankaccount-list-empty', child: Text('등록된 은행 계좌가 없습니다.')),
                    )
                  : TestId(
                      'bankaccount-list',
                      child: ListView.separated(
                        // The last account can be scrolled clear of the round button.
                        padding: EdgeInsets.only(bottom: _NewButton.sizeOf(context) + 32),
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

/// "+" over "만들기", in a circle that is just big enough for the words.
class _NewButton extends StatelessWidget {
  const _NewButton({required this.onPressed});

  final VoidCallback? onPressed;

  static double sizeOf(BuildContext context) => MediaQuery.textScalerOf(context).scale(72);

  @override
  Widget build(BuildContext context) {
    return TestId(
      'bankaccount-new',
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          fixedSize: Size.square(sizeOf(context)),
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          elevation: 3,
        ),
        child: const Text('+\n만들기', semanticsLabel: '만들기', textAlign: TextAlign.center),
      ),
    );
  }
}

/// Who can see the transfers the user makes from now on (set in 설정).
class _MyPrivacy extends ConsumerWidget {
  const _MyPrivacy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(sessionProvider.select((s) => s.user?['defaultPrivacyLevel']));
    final public = privacyOf(saved) == 'public';
    return ListTile(
      leading: Icon(public ? Icons.public : Icons.lock_outline),
      title: TestId('bankaccount-privacy', child: Text('내 이체: ${privacyLabel(saved)}')),
      subtitle: Text(public ? '새 이체를 모든 사용자가 볼 수 있습니다.' : '새 이체를 나와 상대만 볼 수 있습니다.'),
      trailing: TestId(
        'bankaccount-privacy-change',
        child: TextButton(
          onPressed: () => context.push('/settings'),
          child: const Text('변경'),
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

class _BankAccountTile extends ConsumerStatefulWidget {
  const _BankAccountTile({required this.account});

  final BankAccount account;

  @override
  ConsumerState<_BankAccountTile> createState() => _BankAccountTileState();
}

class _BankAccountTileState extends ConsumerState<_BankAccountTile> {
  bool _busy = false;

  Future<void> _confirmAndDelete() async {
    if (_busy) return;
    final account = widget.account;
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
    if (confirmed != true || !mounted) return;

    final errors = ref.read(bankAccountDeleteErrorProvider.notifier);
    errors.set(null);
    setState(() => _busy = true);
    try {
      await ref.read(bankAccountsProvider.notifier).remove(account.id);
    } on ApiException catch (e) {
      // After a 401 the user is already somewhere else.
      if (mounted) errors.set(serverRefusalText(e, base: '은행 계좌를 삭제하지 못했습니다'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final hasMoney = (account.balance ?? 0) != 0;
    return TestId(
      'bankaccount-list-item-${account.id}',
      child: ListTile(
        leading: const Icon(Icons.account_balance_outlined),
        title: Text(account.bankName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TestId(
              'bankaccount-account-number-${account.id}',
              child: Text('계좌 번호 ${account.maskedAccountNumber}'),
            ),
            if (account.balance != null)
              TestId(
                'bankaccount-balance-${account.id}',
                child: Text('잔액 ${formatUsd(account.balance!)}'),
              ),
            if (hasMoney)
              const TestId('bankaccount-delete-locked', child: Text('잔액이 있는 계좌는 삭제할 수 없습니다.')),
          ],
        ),
        isThreeLine: account.balance != null,
        trailing: TestId(
          'bankaccount-delete',
          child: TextButton(
            // The server refuses to delete an account that holds money (400).
            onPressed: hasMoney || _busy ? null : _confirmAndDelete,
            child: const Text('삭제'),
          ),
        ),
      ),
    );
  }
}
