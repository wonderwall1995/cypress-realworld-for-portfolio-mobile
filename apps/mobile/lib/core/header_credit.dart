import 'package:flutter/material.dart';

import 'test_id.dart';

/// The two small lines at the right end of a header.
///
/// Line 1 says the original copyright is Cypress.io's. Line 2 says Claude made
/// the app. The font sizes keep the ratio 7 : 3, and both lines use the
/// system's monospace font.
class HeaderCredit extends StatelessWidget {
  const HeaderCredit({super.key});

  static const copyrightLine = '© Cypress.io';
  static const madeByLine = 'made by Claude';

  // Ratio 7 : 3.
  static const copyrightFontSize = 14.0;
  static const madeByFontSize = 6.0;

  /// Line 2 is fainter than line 1.
  static const madeByOpacity = 0.45;

  static const fontFamily = 'monospace';

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: TestId(
        'header-credit',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TestId(
              'header-credit-copyright',
              child: Text(
                copyrightLine,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: copyrightFontSize,
                  height: 1.1,
                  color: color,
                ),
              ),
            ),
            TestId(
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
          ],
        ),
      ),
    );
  }
}
