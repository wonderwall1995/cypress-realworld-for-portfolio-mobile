import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/error_text.dart';
import '../../../core/providers.dart';
import '../../../core/test_id.dart';
import '../../auth/auth_widgets.dart';

/// How the last step ended.
enum ConfirmEnd {
  /// The server approved it.
  approved,

  /// The user goes back to choose the accounts again.
  reselect,

  /// No answer came. The user goes to look at the history.
  unknown,
}

/// The last step before money moves: "정말 이체하겠습니까?", what will happen
/// (the account the money leaves, the account it goes into, the [amount]), and the
/// user's own password.
///
/// Two things happen, one after the other, and the dialog says which one failed:
/// the password is checked (nothing is sent yet), then [send] runs (the transfer).
/// The dialog closes by itself only when the server approved. While a request is on
/// its way it cannot be closed: closing would not stop it.
///
/// - The server refuses: the reason is shown and the user can try again. When the
///   accounts are the reason, the user can also go back and choose again.
/// - No answer comes: nobody knows whether it was done, so it is not offered again.
///
/// Returns null when the user closes it.
Future<ConfirmEnd?> askPasswordAndSend(
  BuildContext context, {
  required String question,
  required String from,
  required String to,
  required String amount,
  required String confirmLabel,
  required Future<void> Function(String password) send,
  String idPrefix = 'transaction-confirm',
}) {
  return showDialog<ConfirmEnd>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordConfirmDialog(
      question: question,
      from: from,
      to: to,
      amount: amount,
      confirmLabel: confirmLabel,
      send: send,
      idPrefix: idPrefix,
    ),
  );
}

class _PasswordConfirmDialog extends ConsumerStatefulWidget {
  const _PasswordConfirmDialog({
    required this.question,
    required this.from,
    required this.to,
    required this.amount,
    required this.confirmLabel,
    required this.send,
    required this.idPrefix,
  });

  final String question;
  final String from;
  final String to;
  final String amount;
  final String confirmLabel;
  final Future<void> Function(String password) send;
  final String idPrefix;

  @override
  ConsumerState<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends ConsumerState<_PasswordConfirmDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _unknown = false;
  bool _canReselect = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    // A second tap in the same frame must not send a second request.
    if (_busy || _unknown) return;
    final password = _password.text;
    if (password.isEmpty) return;
    setState(() {
      _busy = true;
      _canReselect = false;
      _error = null;
    });
    try {
      if (!await _checkPassword(password)) return;
      await widget.send(password);
      if (mounted) _close(ConfirmEnd.approved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _unknown = e.resultUnknown;
        _error = serverRefusalText(e, base: '이체하지 못했습니다');
        if (isWrongPassword(e)) {
          _password.clear();
        } else {
          // 400, 403, 404: the accounts (their owner, their money) are the reason.
          // 429 is not about the accounts.
          _canReselect = e.failure == ApiFailure.refused && e.statusCode != 429;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Nothing has been sent when this fails.
  Future<bool> _checkPassword(String password) async {
    try {
      await ref.read(apiClientProvider).verifyPassword(password);
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() {
        if (e.statusCode == 403) {
          _error = '비밀번호가 맞지 않습니다';
          _password.clear();
        } else if (e.statusCode == 429) {
          _error = tooManyRequestsText;
        } else {
          _error = '비밀번호를 확인하지 못했습니다. 잠시 뒤 다시 시도하세요';
        }
      });
      return false;
    }
  }

  void _close(ConfirmEnd end) {
    setState(() => _busy = false);
    Navigator.of(context).pop(end);
  }

  @override
  Widget build(BuildContext context) {
    final prefix = widget.idPrefix;
    final small = Theme.of(context).textTheme.bodySmall;
    return TestId(
      '$prefix-dialog',
      child: PopScope(
        canPop: !_busy,
        child: AlertDialog(
        // No title: the question below is the heading, and the room is needed.
        scrollable: true,
        // Less room around the dialog, so the password field is still in view
        // when the keyboard is open.
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TestId(
                '$prefix-question',
                child: Text(widget.question, style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 6),
              TestId(
                '$prefix-summary',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TestId('$prefix-from', child: Text(widget.from, style: small)),
                    const Icon(Icons.arrow_downward, size: 16),
                    TestId('$prefix-to', child: Text(widget.to, style: small)),
                    const SizedBox(height: 4),
                    TestId(
                      '$prefix-amount',
                      child: Text(
                        widget.amount,
                        style: small?.copyWith(fontSize: (small.fontSize ?? 12) + 3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('계정의 비밀번호를 입력해주세요.', style: small),
              const SizedBox(height: 8),
              if (_error != null) ...[
                FormErrorBanner(id: '$prefix-error', message: _error!),
                const SizedBox(height: 8),
              ],
              if (_busy) ...[
                TestId('$prefix-busy', child: const Text('처리 중입니다.')),
                const SizedBox(height: 8),
              ],
              TestId(
                '$prefix-password',
                child: TextField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirm(),
                  decoration: const InputDecoration(
                    labelText: '계정의 비밀번호',
                    // No room for a notice: it is in the empty field.
                    hintText: '이 데모 앱의 비밀번호',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TestId(
            '$prefix-cancel',
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(_unknown ? '닫기' : '취소'),
            ),
          ),
          if (_canReselect)
            TestId(
              '$prefix-reselect',
              child: OutlinedButton(
                onPressed: _busy ? null : () => _close(ConfirmEnd.reselect),
                child: const Text('계좌 다시 선택'),
              ),
            ),
          if (_unknown)
            TestId(
              '$prefix-check-history',
              child: FilledButton(
                onPressed: () => _close(ConfirmEnd.unknown),
                child: const Text('내역 확인'),
              ),
            )
          else
            TestId(
              '$prefix-confirm',
              // Off until something is typed.
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _password,
                builder: (context, value, _) => BusyFilledButton(
                  label: widget.confirmLabel,
                  busy: _busy,
                  onPressed: value.text.isEmpty ? null : _confirm,
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
