import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/error_text.dart';
import '../../../core/providers.dart';
import '../../../core/test_id.dart';
import '../../auth/auth_widgets.dart';

/// The last step before money moves: "정말 이체하겠습니까?", what will happen, and
/// "자신의 계정 비밀번호를 입력해주세요." Shows what is about to happen ([lines]), asks for the user's own
/// password, and checks it on the server first.
///
/// The server must approve before anything else happens: the password is checked,
/// then [send] runs (the transfer itself). The dialog closes only when both
/// succeeded, with `true`. When the server refuses, the dialog stays open and says
/// why, so the user can try again. Returns null when the user cancels.
Future<bool?> askPasswordAndSend(
  BuildContext context, {
  required String question,
  required List<String> lines,
  required String confirmLabel,
  required Future<void> Function(String password) send,
  String idPrefix = 'transfer-confirm',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordConfirmDialog(
      question: question,
      lines: lines,
      confirmLabel: confirmLabel,
      send: send,
      idPrefix: idPrefix,
    ),
  );
}

class _PasswordConfirmDialog extends ConsumerStatefulWidget {
  const _PasswordConfirmDialog({
    required this.question,
    required this.lines,
    required this.confirmLabel,
    required this.send,
    required this.idPrefix,
  });

  final String question;
  final List<String> lines;
  final String confirmLabel;
  final Future<void> Function(String password) send;
  final String idPrefix;

  @override
  ConsumerState<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends ConsumerState<_PasswordConfirmDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    // A second tap in the same frame must not send a second request.
    if (_busy) return;
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _error = '비밀번호를 입력하세요.');
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).verifyPassword(password);
      await widget.send(password);
      navigator.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 403 && !e.message.contains('balance')
            ? '비밀번호가 맞지 않습니다'
            : serverRefusalText(e, base: '이체하지 못했습니다');
        // A refused password is typed again; any other reason keeps what was typed
        // so the user can try again at once.
        if (e.statusCode == 403) _password.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefix = widget.idPrefix;
    return TestId(
      '$prefix-dialog',
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
                child: Text(widget.lines.join('\n'), style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: 8),
              Text('자신의 계정 비밀번호를 입력해주세요.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (_error != null) ...[
                FormErrorBanner(id: '$prefix-error', message: _error!),
                const SizedBox(height: 8),
              ],
              TestId(
                '$prefix-password-input',
                child: TextField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirm(),
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
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
              child: const Text('취소'),
            ),
          ),
          TestId(
            '$prefix-submit',
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
    );
  }
}
