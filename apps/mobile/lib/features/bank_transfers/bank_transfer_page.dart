import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/test_id.dart';
import '../auth/auth_widgets.dart';
import '../bank_accounts/bank_account.dart';
import '../bank_accounts/bank_accounts_controller.dart';
import '../transactions/amount_input.dart';
import '../transactions/transaction.dart';
import 'bank_transfer.dart';
import 'bank_transfers_controller.dart';

/// Deposit (bank account to balance) or withdraw (balance to bank account).
/// One screen: choose an account, enter whole dollars, press the button.
class BankTransferPage extends ConsumerStatefulWidget {
  const BankTransferPage({required this.isDeposit, super.key});

  final bool isDeposit;

  @override
  ConsumerState<BankTransferPage> createState() => _BankTransferPageState();
}

class _BankTransferPageState extends ConsumerState<BankTransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _accountId;
  bool _busy = false;
  String? _error;

  String get _verb => widget.isDeposit ? '입금' : '출금';

  /// The account the user chose. With only one account there is nothing to
  /// choose, so it counts as chosen.
  String? _selectedId(List<BankAccount> accounts) =>
      _accountId ?? (accounts.length == 1 ? accounts.single.id : null);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // A second tap in the same frame must not send a second request.
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    final dollars = int.parse(_amount.text.trim());
    final accountId = _selectedId(ref.read(bankAccountsProvider).value ?? const []);
    if (accountId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).moveMoney(
            bankAccountId: accountId,
            amount: dollars,
            type: widget.isDeposit ? 'deposit' : 'withdrawal',
          );
      // The balance and the history have changed.
      ref.invalidate(bankTransfersProvider);
      await ref.read(sessionProvider.notifier).refreshUser();
      messenger.showSnackBar(
        SnackBar(
          content: TestId(
            'alert-bar-success',
            child: Text('${formatUsd(dollars * 100)}를 $_verb했습니다.'),
          ),
        ),
      );
      router.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = bankTransferErrorMessage(e, isDeposit: widget.isDeposit));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(bankAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_verb)),
      body: SafeArea(
        child: accounts.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TestId(
              'bank-transfer-accounts-error',
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
          ),
          data: (list) => list.isEmpty ? _NoAccount(verb: _verb) : _buildForm(list),
        ),
      ),
    );
  }

  Widget _buildForm(List<BankAccount> accounts) {
    final selected = _selectedId(accounts);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isDeposit ? '은행 계좌에서 내 계좌로 옮깁니다.' : '내 계좌에서 은행 계좌로 옮깁니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  FormErrorBanner(id: 'bank-transfer-error', message: _error!),
                  const SizedBox(height: 16),
                ],
                Text('은행 계좌', style: Theme.of(context).textTheme.titleSmall),
                FormField<String>(
                  initialValue: selected,
                  validator: (_) => selected == null ? '은행 계좌를 선택하세요.' : null,
                  builder: (field) => TestId(
                    'bank-transfer-accounts',
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
                              'bank-transfer-account-${account.id}',
                              child: RadioListTile<String>(
                                value: account.id,
                                title: Text(account.bankName),
                                subtitle: Text('계좌 번호 ${account.maskedAccountNumber}'),
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
                  'bank-transfer-amount-input',
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
                const SizedBox(height: 24),
                TestId(
                  'bank-transfer-submit',
                  child: BusyFilledButton(
                    label: '$_verb하기',
                    busy: _busy,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoAccount extends StatelessWidget {
  const _NoAccount({required this.verb});

  final String verb;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TestId(
          'bank-transfer-no-account',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$verb하려면 은행 계좌가 필요합니다.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TestId(
                'bank-transfer-create-account',
                child: FilledButton(
                  onPressed: () => context.push('/bankaccounts/new'),
                  child: const Text('은행 계좌 만들기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
