import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/test_id.dart';
import '../auth/auth_widgets.dart';

String bankAccountErrorMessage(ApiException e) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  return '은행 계좌를 저장하지 못했습니다. 입력한 내용을 확인해 주세요.';
}

typedef BankAccountSubmit = Future<void> Function({
  required String bankName,
  required String routingNumber,
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
  final _routing = TextEditingController();
  final _account = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _bankName.dispose();
    _routing.dispose();
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
        routingNumber: _routing.text.trim(),
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
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return '은행 이름을 입력하세요.';
                  if (value.length < 5) return '은행 이름은 5자 이상이어야 합니다.';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            TestId(
              'bankaccount-routingNumber-input',
              child: TextFormField(
                controller: _routing,
                decoration: const InputDecoration(
                  labelText: '라우팅 번호',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return '라우팅 번호를 입력하세요.';
                  if (value.length != 9) return '라우팅 번호는 9자리여야 합니다.';
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
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return '계좌 번호를 입력하세요.';
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
