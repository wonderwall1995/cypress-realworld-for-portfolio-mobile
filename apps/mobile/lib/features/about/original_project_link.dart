import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/test_id.dart';
import '../../core/toast.dart';
import 'mit_license.dart';

/// "본 레포의 원본은 Cypress.io 팀의 MIT 라이센스 배포 판 Realworld-app 입니다."
/// "Realworld-app" is a link to the original project; tapping it opens the page
/// in the phone's browser.
class OriginalProjectLink extends ConsumerWidget {
  const OriginalProjectLink({required this.id, super.key});

  /// The test id of the link.
  final String id;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    var opened = false;
    try {
      opened = await ref.read(urlOpenerProvider)(Uri.parse(originalProjectUrl));
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      showToast(overlay, message: '링크를 열 수 없습니다.', success: false);
    }
  }

  /// The sentence, in three parts. Only [linkText] is the link.
  static const before = '본 레포의 원본은 Cypress.io 팀의 MIT 라이센스 배포 판 ';
  static const linkText = 'Realworld-app';
  static const after = ' 입니다.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final base = theme.textTheme.bodyMedium;
    return TestId(
      '$id-notice',
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: before),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: TestId(
                id,
                child: Semantics(
                  link: true,
                  child: InkWell(
                    onTap: () => _open(context, ref),
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      linkText,
                      style: base?.copyWith(
                        color: color,
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const TextSpan(text: after),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
