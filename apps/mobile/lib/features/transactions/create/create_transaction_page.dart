import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/test_id.dart';
import '../../auth/auth_widgets.dart';
import '../../bank_accounts/account_pickers.dart';
import '../../bank_accounts/bank_account.dart';
import '../../bank_accounts/bank_accounts_controller.dart';
import '../../bank_accounts/other_account.dart';
import '../amount_input.dart';
import '../transaction.dart';
import '../transaction_widgets.dart';
import 'create_transaction_controller.dart';
import 'password_confirm_dialog.dart';
import 'user_summary.dart';

/// "새 거래": choose a user, enter the amount and note, then done.
class CreateTransactionPage extends ConsumerWidget {
  const CreateTransactionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createTransactionProvider);
    final controller = ref.read(createTransactionProvider.notifier);

    return PopScope(
      // On step 2, Back goes to step 1. On the other steps it leaves the screen.
      canPop: state.step != CreateStep.payment,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.step == CreateStep.payment) {
          controller.backToContacts();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('새 거래'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: _StepHeader(step: state.step),
          ),
        ),
        body: switch (state.step) {
          CreateStep.selectContact => const _SelectContactStep(),
          CreateStep.payment => _PaymentStep(receiver: state.receiver!),
          CreateStep.complete => _CompleteStep(created: state.created!),
        },
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final CreateStep step;

  @override
  Widget build(BuildContext context) {
    const labels = ['연락처 선택', '이체', '완료'];
    final theme = Theme.of(context);
    return TestId(
      'transaction-create-steps',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < labels.length; i++)
              Text(
                '${i + 1}. ${labels[i]}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: i == step.index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: i == step.index
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Step 1: choose a user ------------------------------------------------

class _SelectContactStep extends ConsumerStatefulWidget {
  const _SelectContactStep();

  @override
  ConsumerState<_SelectContactStep> createState() => _SelectContactStepState();
}

class _SelectContactStepState extends ConsumerState<_SelectContactStep> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Search 200 ms after the user stops typing (same as the web).
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TestId(
            'user-list-search-input',
            child: TextField(
              controller: _search,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '이름 또는 전화번호로 검색...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        Expanded(
          child: users.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: TestId(
                'user-list-error',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('사용자를 불러오지 못했습니다.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(usersProvider(_query)),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? const Center(
                    child: TestId(
                      'user-list-empty',
                      child: Text('검색 결과가 없습니다.'),
                    ),
                  )
                : TestId(
                    'user-list',
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _UserTile(user: list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TestId(
      'user-list-item-${user.id}',
      child: ListTile(
        leading: InitialAvatar(user.fullName),
        title: Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('@${user.username}'),
        onTap: () =>
            ref.read(createTransactionProvider.notifier).selectReceiver(user),
      ),
    );
  }
}

// ---- Step 2: amount and note -----------------------------------------------

String transactionErrorMessage(ApiException e) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  if (e.statusCode == 403) return '비밀번호가 올바르지 않거나 이 계좌를 쓸 수 없습니다.';
  if (e.statusCode == 400 && e.message.contains('not enough balance')) {
    return '선택한 계좌의 잔액이 부족합니다.';
  }
  return '이체하지 못했습니다. 입력한 내용을 확인해 주세요.';
}

class _PaymentStep extends ConsumerStatefulWidget {
  const _PaymentStep({required this.receiver});

  final UserSummary receiver;

  @override
  ConsumerState<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<_PaymentStep> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _myAccountId;
  String? _otherAccountId;
  String? _myAccountError;
  String? _otherAccountError;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  /// The typed amount in cents, or null while it is not a valid amount.
  int? get _amountCents {
    final text = _amount.text.trim();
    if (validateDollars(text) != null) return null;
    return int.parse(text) * 100;
  }

  /// With one account there is nothing to choose, so it counts as chosen.
  String? _selectedMine(List<BankAccount> accounts) =>
      _myAccountId ?? (accounts.length == 1 ? accounts.single.id : null);

  String? _selectedOther(List<OtherAccount> accounts) =>
      _otherAccountId ?? (accounts.length == 1 ? accounts.single.id : null);

  /// The button stays off while the chosen account holds less than the amount.
  bool _canSubmit(List<BankAccount> mine) {
    final cents = _amountCents;
    final account = mine.where((a) => a.id == _selectedMine(mine)).firstOrNull;
    if (cents == null || account == null) return true;
    return MyAccountPicker.isEnough(account, cents);
  }

  Future<void> _submit() async {
    final mine = ref.read(bankAccountsProvider).value ?? const <BankAccount>[];
    final others =
        ref.read(otherAccountsProvider(widget.receiver.id)).value ??
        const <OtherAccount>[];
    final formOk = _formKey.currentState!.validate();
    final myId = _selectedMine(mine);
    final otherId = _selectedOther(others);
    final cents = _amountCents;
    final myAccount = mine.where((a) => a.id == myId).firstOrNull;

    String? myError;
    String? otherError;
    if (myId == null) {
      myError = '출금할 내 계좌를 선택하세요.';
    } else if (cents != null && !MyAccountPicker.isEnough(myAccount!, cents)) {
      myError = '선택한 계좌의 잔액이 부족합니다.';
    }
    if (others.isEmpty) {
      otherError = '상대에게 은행 계좌가 없어 이체할 수 없습니다.';
    } else if (otherId == null) {
      otherError = '상대의 계좌를 선택하세요.';
    }
    setState(() {
      _myAccountError = myError;
      _otherAccountError = otherError;
    });
    if (!formOk || myError != null || otherError != null) return;

    // The last step: the user's own password, checked before any money moves.
    final other = others.where((a) => a.id == otherId).firstOrNull;
    // The dialog checks the password and sends the transfer. It closes, and the
    // "이체 완료" screen opens, only after the server approved. A refusal stays in
    // the dialog with its reason.
    final controller = ref.read(createTransactionProvider.notifier);
    final dollars = int.parse(_amount.text.trim());
    final description = _description.text.trim();
    await askPasswordAndSend(
      context,
      question: '정말 이체하겠습니까?',
      lines: [
        '${myAccount!.bankName} ${myAccount.maskedAccountNumber} → '
            '${widget.receiver.fullName}님 ${other == null ? '' : '${other.bankName} ****${other.last4}'}',
        '금액 ${formatUsd(cents!)}',
      ],
      confirmLabel: '이체하기',
      send: (password) => controller.submit(
        type: 'payment',
        dollars: dollars,
        description: description,
        myAccountId: myId!,
        otherAccountId: otherId,
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(bankAccountsProvider).value ?? const <BankAccount>[];
    final others = ref.watch(otherAccountsProvider(widget.receiver.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TestId(
            'transaction-create-form',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      InitialAvatar(widget.receiver.fullName, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TestId(
                              'transaction-create-receiver-name',
                              child: Text(
                                widget.receiver.fullName,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('@${widget.receiver.username}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TestId(
                    'transaction-create-amount-input',
                    child: TextFormField(
                      controller: _amount,
                      decoration: const InputDecoration(
                        labelText: '금액',
                        prefixText: '\$ ',
                        helperText: '달러 단위로 입력합니다.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      validator: validateDollars,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TestId(
                    'transaction-create-description-input',
                    child: TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: '메모',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '메모를 입력하세요.' : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // My account: the money leaves it.
                  // An account that holds less than the amount cannot be chosen.
                  MyAccountPicker(
                    idPrefix: 'transaction-create-my-account',
                    title: '내 계좌 (출금)',
                    accounts: mine,
                    selectedId: _selectedMine(mine),
                    requiredCents: _amountCents,
                    errorText: _myAccountError,
                    onChanged: (id) => setState(() {
                      _myAccountId = id;
                      _myAccountError = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  others.when(
                    skipLoadingOnReload: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => TestId(
                      'transaction-create-other-accounts-error',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('상대의 은행 계좌를 불러오지 못했습니다.'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => ref.invalidate(
                              otherAccountsProvider(widget.receiver.id),
                            ),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                    data: (list) => list.isEmpty
                        ? TestId(
                            'transaction-create-other-no-account',
                            child: Text(
                              _otherAccountError ??
                                  '상대에게 은행 계좌가 없어 이체할 수 없습니다.',
                              style: _otherAccountError == null
                                  ? Theme.of(context).textTheme.bodySmall
                                  : TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                            ),
                          )
                        : OtherAccountPicker(
                            idPrefix: 'transaction-create-other-account',
                            title: '상대 계좌',
                            accounts: list,
                            selectedId: _selectedOther(list),
                            errorText: _otherAccountError,
                            onChanged: (id) => setState(() {
                              _otherAccountId = id;
                              _otherAccountError = null;
                            }),
                          ),
                  ),
                  const SizedBox(height: 24),
                  TestId(
                    'transaction-create-submit-payment',
                    child: BusyFilledButton(
                      label: '이체',
                      busy: false,
                      onPressed: _canSubmit(mine) ? () => _submit() : null,
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

// ---- Step 3: done -----------------------------------------------------------

class _CompleteStep extends ConsumerWidget {
  const _CompleteStep({required this.created});

  final CreatedTransaction created;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const verb = '이체';
    final amount = formatUsd(created.dollars * 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              TestId(
                'transaction-create-result',
                child: Column(
                  children: [
                    Text('$verb 완료', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(
                      '${created.receiver.fullName}님에게 $amount를 $verb했습니다.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '메모: ${created.description}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TestId(
                'new-transaction-return-to-transactions',
                child: FilledButton(
                  // The home list, wherever the user came from (the 이체 button on
                  // 내 계좌 or the empty list).
                  onPressed: () => context.go('/'),
                  child: const Text('거래 목록으로 돌아가기'),
                ),
              ),
              const SizedBox(height: 12),
              TestId(
                'new-transaction-create-another-transaction',
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(createTransactionProvider.notifier).startOver(),
                  child: const Text('다른 거래 만들기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
