import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/test_id.dart';
import '../auth/auth_widgets.dart';

String bankAccountErrorMessage(ApiException e) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  return '은행 계좌를 저장하지 못했습니다. 입력한 내용을 확인해 주세요.';
}

/// Shown above the form: the user must not type a real bank account.
const bankAccountDemoNotice = '진짜 자신의 계좌를 만들진 말아주세요! 이건 데모 앱입니다.';

/// The number rule, shown as the hint inside the field. The check below uses
/// the same numbers.
const accountNumberHint = '9~12자리 숫자';

final _digitsOnly = RegExp(r'^[0-9]+$');

typedef BankAccountSubmit = Future<void> Function({
  required String bankName,
  required String accountNumber,
});

/// The form to create a bank account. Used in the first-time setup and in the
/// bank account screen. Same rules as the web form.
class BankAccountForm extends StatefulWidget {
  const BankAccountForm({required this.onSubmit, super.key});

  /// Throw [ApiException] to show an error above the form.
  final BankAccountSubmit onSubmit;

  @override
  State<BankAccountForm> createState() => _BankAccountFormState();
}

class _BankAccountFormState extends State<BankAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _bankName = TextEditingController();
  final _account = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _bankName.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        bankName: _bankName.text.trim(),
        accountNumber: _account.text.trim(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = bankAccountErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TestId(
      'bankaccount-form',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DemoNotice(),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FormErrorBanner(id: 'bankaccount-error', message: _error!),
              const SizedBox(height: 16),
            ],
            TestId(
              'bankaccount-bankName-input',
              child: TextFormField(
                controller: _bankName,
                decoration: const InputDecoration(
                  labelText: '은행 이름',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return '은행 이름을 입력하세요.';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            TestId(
              'bankaccount-accountNumber-input',
              child: TextFormField(
                controller: _account,
                decoration: const InputDecoration(
                  labelText: '계좌 번호',
                  hintText: accountNumberHint,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return '계좌 번호를 입력하세요.';
                  if (!_digitsOnly.hasMatch(value)) return '계좌 번호는 숫자만 입력하세요.';
                  if (value.length < 9) return '계좌 번호는 9자리 이상이어야 합니다.';
                  if (value.length > 12) return '계좌 번호는 12자리 이하여야 합니다.';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            TestId(
              'bankaccount-submit',
              child: BusyFilledButton(label: '저장', busy: _busy, onPressed: _submit),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short warning above the form. It is not an error, so it is not red.
class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TestId(
      'bankaccount-demo-notice',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: colors.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                bankAccountDemoNotice,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
