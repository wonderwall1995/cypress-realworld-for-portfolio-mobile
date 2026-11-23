import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/error_text.dart';
import '../../core/test_id.dart';

/// Korean text for the errors the server sends in English.
String signInErrorMessage(ApiException e) {
  if (e.isConnection) return '서버에 연결할 수 없습니다.';
  if (e.statusCode == 401) return '사용자 ID 또는 비밀번호가 올바르지 않습니다.';
  if (e.statusCode == 429) return tooManyRequestsText;
  return '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

String signUpErrorMessage(ApiException e) {
  if (e.failure == ApiFailure.notSent) return '서버에 연결할 수 없습니다.';
  if (e.statusCode == 409) return usernameTakenText;
  if (e.failure == ApiFailure.serverError) {
    // An older server answers an HTML 500 for an ID that is used, so it cannot be told
    // from another failure. A newer one answers 409 for that, and JSON for the rest.
    return e.serverMessage == null
        ? '회원가입에 실패했습니다. 이미 사용 중인 ID일 수 있습니다. 다른 ID로 다시 시도해 주세요.'
        : '회원가입에 실패했습니다. 잠시 뒤 다시 시도해 주세요.';
  }
  return serverRefusalText(e, base: '회원가입에 실패했습니다');
}

/// An error box above a form. [id] is the web test id (for example `signin-error`).
///
/// The button that was refused can be far below. When the box is not in view, the
/// screen moves until it is; when it is, nothing moves.
class FormErrorBanner extends StatefulWidget {
  const FormErrorBanner({required this.id, required this.message, super.key});

  final String id;
  final String message;

  @override
  State<FormErrorBanner> createState() => _FormErrorBannerState();
}

class _FormErrorBannerState extends State<FormErrorBanner> {
  @override
  void initState() {
    super.initState();
    _showIt();
  }

  @override
  void didUpdateWidget(FormErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) _showIt();
  }

  void _showIt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TestId(
      widget.id,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.message, style: TextStyle(color: colors.onErrorContainer)),
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
