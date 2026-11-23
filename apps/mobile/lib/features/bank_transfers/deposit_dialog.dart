import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/test_id.dart';
import '../auth/auth_widgets.dart';
import '../bank_accounts/bank_account.dart';
import '../bank_accounts/bank_accounts_controller.dart';
import '../money/money_status.dart';
import '../money/unconfirmed.dart';
import '../transactions/amount_input.dart';
import '../transactions/transaction.dart';
import 'bank_transfer.dart';

/// Opens the deposit dialog over the current screen.
Future<void> showDepositDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const DepositDialog(),
  );
}

/// 입금: the user chooses one of their own bank accounts and enters whole
/// dollars. The amount goes into that bank account (its balance goes up).
///
/// While the request is on its way the dialog cannot be closed: closing it would
/// not stop the deposit. When no answer comes, nobody knows whether it was done, so
/// the dialog does not offer to send it again; it offers the history.
///
/// With only one bank account there is nothing to choose, so it counts as chosen.
/// With no bank account, the dialog says so and offers to create one.
class DepositDialog extends ConsumerStatefulWidget {
  const DepositDialog({super.key});

  @override
  ConsumerState<DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends ConsumerState<DepositDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _accountId;
  bool _busy = false;
  bool _unknown = false;
  String? _error;

  /// An account that is gone (deleted somewhere else) is not chosen any more.
  String? _selectedId(List<BankAccount> accounts) {
    if (accounts.any((a) => a.id == _accountId)) return _accountId;
    return accounts.length == 1 ? accounts.single.id : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // A second tap in the same frame must not send a second request.
    if (_busy || _unknown) return;
    if (!_formKey.currentState!.validate()) return;
    final dollars = int.parse(_amount.text.trim());
    final bankAccounts = ref.read(bankAccountsProvider).value ?? const <BankAccount>[];
    final accountId = _selectedId(bankAccounts);
    if (accountId == null) return;
    final bankName = bankAccounts.where((a) => a.id == accountId).firstOrNull?.bankName;
    switch (await askBeforeSending(context, ref, MoneyKind.deposit)) {
      case BeforeSending.send:
        break;
      case BeforeSending.history:
        if (mounted) _checkHistory();
        return;
      case BeforeSending.cancel:
        return;
    }
    if (!mounted || _busy) return;
    // Keep these before the await: the dialog may be gone after it.
    final messenger = ScaffoldMessenger.of(context);
    final money = ref.read(moneyStatusProvider.notifier);
    final unconfirmed = ref.read(unconfirmedMoneyProvider.notifier);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).moveMoney(
            bankAccountId: accountId,
            amount: dollars,
            type: 'deposit',
          );
      // Approved. Reading the money again is a separate thing: when it fails the
      // deposit is still done, and only the reading is offered again.
      unawaited(money.refresh(afterWrite: true));
      messenger.showSnackBar(
        SnackBar(
          content: TestId(
            'alert-bar-success',
            child: Text(
              bankName == null
                  ? '${formatUsd(dollars * 100)}를 입금했습니다.'
                  : '$bankName 계좌에 ${formatUsd(dollars * 100)}를 입금했습니다.',
            ),
          ),
        ),
      );
      if (mounted) _close();
    } on ApiException catch (e) {
      if (e.resultUnknown) {
        unconfirmed.add(
          MoneyKind.deposit,
          '${bankName ?? '은행 계좌'}에 입금 ${formatUsd(dollars * 100)}',
        );
      }
      if (!mounted) return;
      setState(() {
        _error = bankTransferErrorMessage(e, isDeposit: true);
        _unknown = e.resultUnknown;
      });
      // The refusal may mean that the list on the screen is old.
      if (!e.isConnection) unawaited(ref.read(bankAccountsProvider.notifier).reload());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  void _checkHistory() {
    final router = GoRouter.of(context);
    unawaited(ref.read(moneyStatusProvider.notifier).refresh());
    _close();
    router.go('/my-account');
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(bankAccountsProvider);

    return TestId(
      'deposit-dialog',
      // Cancel, a tap outside and the Back button all follow this.
      child: PopScope(
        canPop: !_busy,
        child: AlertDialog(
        title: const Text('입금'),
        scrollable: true,
        content: SizedBox(
          width: 400,
          child: accounts.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => TestId(
              'deposit-accounts-error',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('은행 계좌를 불러오지 못했습니다.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.read(bankAccountsProvider.notifier).reload(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
            data: (list) => list.isEmpty ? const _NoAccount() : _form(list),
          ),
        ),
        actions: [
          TestId(
            'deposit-cancel-button',
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(_unknown ? '닫기' : '취소'),
            ),
          ),
          if (_unknown)
            TestId(
              'deposit-check-history',
              child: FilledButton(onPressed: _checkHistory, child: const Text('내역 확인')),
            )
          else if (accounts.value?.isNotEmpty ?? false)
            TestId(
              'deposit-submit-button',
              child: BusyFilledButton(label: '입금하기', busy: _busy, onPressed: _submit),
            ),
        ],
      ),
      ),
    );
  }

  Widget _form(List<BankAccount> accounts) {
    final selected = _selectedId(accounts);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '선택한 내 은행 계좌에 입금합니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            FormErrorBanner(id: 'deposit-error', message: _error!),
            const SizedBox(height: 16),
          ],
          if (_busy) ...[
            const TestId('deposit-busy', child: Text('처리 중입니다.')),
            const SizedBox(height: 16),
          ],
          Text('은행 계좌', style: Theme.of(context).textTheme.titleSmall),
          FormField<String>(
            initialValue: selected,
            validator: (_) => selected == null ? '은행 계좌를 선택하세요.' : null,
            builder: (field) => TestId(
              'deposit-account-select',
              child: RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) {
                  setState(() => _accountId = v);
                  field.didChange(v);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final account in accounts)
                      TestId(
                        'deposit-account-${account.id}',
                        child: RadioListTile<String>(
                          value: account.id,
                          title: Text(account.bankName),
                          subtitle: Text(account.describe),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (field.errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        child: Text(
                          field.errorText!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TestId(
            'deposit-amount-input',
            child: TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: '금액',
                prefixText: '\$ ',
                helperText: '달러 단위로 입력합니다.',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: validateDollars,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAccount extends StatelessWidget {
  const _NoAccount();

  @override
  Widget build(BuildContext context) {
    return TestId(
      'deposit-no-account',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('입금하려면 은행 계좌가 필요합니다.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TestId(
            'deposit-go-bankaccounts-button',
            child: FilledButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push('/bankaccounts/new');
              },
              child: const Text('은행 계좌 만들기'),
            ),
          ),
        ],
      ),
    );
  }
}
