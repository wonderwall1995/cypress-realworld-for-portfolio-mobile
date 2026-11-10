import '../../core/person_name.dart';
import '../../core/header_credit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/test_id.dart';
import '../bank_accounts/bank_accounts_controller.dart';
import '../bank_transfers/bank_transfer.dart';
import '../bank_transfers/deposit_dialog.dart';
import '../bank_transfers/bank_transfers_controller.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_widgets.dart';

/// The "내 계좌" tab: who the user is, the balance, [입금] (a dialog) and [이체]
/// (the new transaction screen), and the history of deposits and withdrawals.
/// Pull down to load again.
class MyAccountPage extends ConsumerWidget {
  const MyAccountPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(sessionProvider.notifier).refreshUser(),
      ref.read(bankTransfersProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final fullName = koreanFullName(
      firstName: user?['firstName'] as String?,
      lastName: user?['lastName'] as String?,
    );
    final username = user?['username'] as String?;
    final balance = (user?['balance'] as num?)?.toInt() ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('내 계좌'), actions: const [HeaderCredit()]),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                InitialAvatar(fullName, radius: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TestId(
                        'my-account-full-name',
                        child: Text(fullName, style: theme.textTheme.titleMedium),
                      ),
                      TestId(
                        'my-account-username',
                        child: Text(username == null ? '' : '@$username'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 계좌 잔액', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TestId(
                      'sidenav-user-balance',
                      child: Text(formatUsd(balance), style: theme.textTheme.headlineMedium),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TestId(
                            'my-account-deposit',
                            child: FilledButton(
                              onPressed: () => showDepositDialog(context),
                              child: const Text('입금'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TestId(
                            'my-account-transfer',
                            child: OutlinedButton(
                              onPressed: () => context.push('/transaction/new'),
                              child: const Text('이체'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('입출금 내역', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const _TransferHistory(),
          ],
        ),
      ),
    );
  }
}

class _TransferHistory extends ConsumerWidget {
  const _TransferHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(bankTransfersProvider);

    return transfers.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => TestId(
        'bank-transfers-load-error',
        child: Column(
          children: [
            const Text('입출금 내역을 불러오지 못했습니다.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(bankTransfersProvider.notifier).retry(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
      data: (list) => list.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: TestId('bank-transfers-empty', child: Text('입출금 내역이 없습니다.')),
              ),
            )
          : TestId(
              'bank-transfers-list',
              child: Column(
                children: [
                  for (final transfer in list) _TransferTile(transfer: transfer),
                ],
              ),
            ),
    );
  }
}

class _TransferTile extends ConsumerWidget {
  const _TransferTile({required this.transfer});

  final BankTransfer transfer;

  /// For example `11/9 18:21`, in the phone's time zone.
  static String _time(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(bankAccountsProvider).value ?? const [];
    final accountId = transfer.bankAccountId;
    final account = accountId == null ? null : accounts.where((a) => a.id == accountId).firstOrNull;
    final accountText = accountId == null
        ? '은행 계좌 없음'
        : account?.bankName ?? '삭제된 은행 계좌';
    final sign = transfer.isDeposit ? '+' : '-';
    final color = transfer.isDeposit ? Colors.green.shade700 : Colors.red.shade700;

    return TestId(
      'bank-transfer-list-item-${transfer.id}',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(transfer.isDeposit ? Icons.south_west : Icons.north_east),
        title: Text('${transfer.label} · $accountText'),
        subtitle: Text(
          // A deposit changes the bank account's balance, a withdrawal the balance of 내 계좌.
          '${_time(transfer.createdAt)}  ·  ${transfer.isDeposit ? '계좌 잔액' : '잔액'} ${formatUsd(transfer.balanceBefore)} → ${formatUsd(transfer.balanceAfter)}',
        ),
        trailing: TestId(
          'bank-transfer-amount-${transfer.id}',
          child: Text(
            '$sign${formatUsd(transfer.amount)}',
            style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
