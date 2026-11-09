import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'test_id.dart';
import 'toast.dart';

/// The two small lines at the right end of a header.
///
/// Line 1 says the original copyright is Cypress.io's. It is a link to the
/// original project. Line 2 says Claude made the app. The font sizes keep the
/// ratio 6 : 4, and both lines use the system's monospace font.
class HeaderCredit extends ConsumerWidget {
  const HeaderCredit({super.key});

  static const copyrightLine = '© Cypress.io';
  static const madeByLine = 'made by Claude';

  /// The original project. (Cypress.io has no public live demo of the app; its
  /// repository is where the code and the MIT License text are.)
  static final copyrightUrl = Uri.parse('https://github.com/cypress-io/cypress-realworld-app');

  // Ratio 6 : 4.
  static const copyrightFontSize = 12.0;
  static const madeByFontSize = 8.0;

  /// Line 2 is fainter than line 1.
  static const madeByOpacity = 0.5;

  static const fontFamily = 'monospace';

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    var opened = false;
    try {
      opened = await ref.read(urlOpenerProvider)(copyrightUrl);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      showToast(overlay, message: '링크를 열 수 없습니다.', success: false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: TestId(
        'header-credit',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TestId(
              'header-credit-copyright',
              child: Semantics(
                link: true,
                child: InkWell(
                  onTap: () => _open(context, ref),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      copyrightLine,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: copyrightFontSize,
                        height: 1.1,
                        color: color,
                        decoration: TextDecoration.underline,
                        decorationColor: color.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TestId(
                'header-credit-made-by',
                child: Text(
                  madeByLine,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: madeByFontSize,
                    height: 1.1,
                    color: color.withValues(alpha: madeByOpacity),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
