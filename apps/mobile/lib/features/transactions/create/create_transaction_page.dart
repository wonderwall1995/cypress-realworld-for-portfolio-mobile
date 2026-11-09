import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/test_id.dart';
import '../../auth/auth_widgets.dart';
import '../transaction.dart';
import '../transaction_widgets.dart';
import 'create_transaction_controller.dart';
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
        if (!didPop && state.step == CreateStep.payment) controller.backToContacts();
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
    const labels = ['연락처 선택', '결제', '완료'];
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
                  fontWeight: i == step.index ? FontWeight.w700 : FontWeight.w400,
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
                hintText: '이름이나 아이디로 검색',
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
                    child: TestId('user-list-empty', child: Text('검색 결과가 없습니다.')),
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
        title: Text(user.fullName),
        subtitle: Text('@${user.username}'),
        onTap: () => ref.read(createTransactionProvider.notifier).selectReceiver(user),
      ),
    );
  }
}

// ---- Step 2: amount and note -----------------------------------------------

/// The largest amount in whole dollars. The server keeps cents in a 32-bit
/// number, so a bigger amount would fail there.
const maxDollars = 9999999;

String transactionErrorMessage(ApiException e, {required bool isPayment}) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  final what = isPayment ? '결제' : '요청';
  return '$what하지 못했습니다. 입력한 내용을 확인해 주세요.';
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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(String type) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(createTransactionProvider.notifier).submit(
            type: type,
            dollars: int.parse(_amount.text.trim()),
            description: _description.text.trim(),
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = transactionErrorMessage(e, isPayment: type == 'payment'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateAmount(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return '금액을 입력하세요.';
    final dollars = int.tryParse(text);
    if (dollars == null) return '금액은 숫자로 입력하세요. (달러 단위, 소수점 없음)';
    if (dollars < 1) return '금액은 1달러 이상이어야 합니다.';
    if (dollars > maxDollars) return '금액은 $maxDollars달러 이하여야 합니다.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                              ),
                            ),
                            Text('@${widget.receiver.username}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    FormErrorBanner(id: 'transaction-create-error', message: _error!),
                    const SizedBox(height: 16),
                  ],
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
                      validator: _validateAmount,
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TestId(
                          'transaction-create-submit-request',
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => _submit('request'),
                            child: const Text('요청'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TestId(
                          'transaction-create-submit-payment',
                          child: BusyFilledButton(
                            label: '결제',
                            busy: _busy,
                            onPressed: () => _submit('payment'),
                          ),
                        ),
                      ),
                    ],
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
    final verb = created.isPayment ? '결제' : '요청';
    final amount = formatUsd(created.dollars * 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.primary),
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
                    Text('메모: ${created.description}', textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TestId(
                'new-transaction-return-to-transactions',
                child: FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('거래 목록으로 돌아가기'),
                ),
              ),
              const SizedBox(height: 12),
              TestId(
                'new-transaction-create-another-transaction',
                child: OutlinedButton(
                  onPressed: () => ref.read(createTransactionProvider.notifier).startOver(),
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
