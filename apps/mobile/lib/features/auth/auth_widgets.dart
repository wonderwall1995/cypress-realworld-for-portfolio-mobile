import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/test_id.dart';

/// Korean text for the errors the server sends in English.
String signInErrorMessage(ApiException e) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  if (e.statusCode == 401) return '아이디 또는 비밀번호가 올바르지 않습니다.';
  return '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

String signUpErrorMessage(ApiException e) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  return '회원가입에 실패했습니다. 입력한 내용을 확인해 주세요.';
}

/// An error box above a form. [id] is the web test id (for example `signin-error`).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({required this.id, required this.message, super.key});

  final String id;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TestId(
      id,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}

/// A button with a spinner while [busy].
class BusyFilledButton extends StatelessWidget {
  const BusyFilledButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
