import 'dart:math';

import 'package:cypress_realworld_for_personal_portfolio_mobile/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final l = [a.computeLuminance(), b.computeLuminance()];
  return (l.reduce(max) + 0.05) / (l.reduce(min) + 0.05);
}

void main() {
  test('text is readable on every colour it is put on (4.5 or more)', () {
    final s = appColorScheme;
    final pairs = <String, (Color, Color)>{
      'link on the background': (s.primary, s.surface),
      'chosen text on the background': (s.onSurface, s.surface),
      'small text on the background': (s.onSurfaceVariant, s.surface),
      'small text on the bar': (s.onSurfaceVariant, s.surfaceContainer),
      'small text on a dialog': (s.onSurfaceVariant, s.surfaceContainerHigh),
      'cancel on a dialog': (s.primary, s.surfaceContainerHigh),
      'a filled button': (AppColors.ink, AppColors.button),
      'chosen': (s.onSecondaryContainer, s.secondaryContainer),
      'letters in a circle': (s.onPrimaryContainer, s.primaryContainer),
      'the deposit icon': (s.onTertiaryContainer, s.tertiaryContainer),
      'error on the background': (s.error, s.surface),
      'in': (Colors.green.shade800, s.surface),
      'out': (Colors.red.shade700, s.surface),
    };
    final low = {
      for (final e in pairs.entries)
        if (contrast(e.value.$1, e.value.$2) < 4.5) e.key: contrast(e.value.$1, e.value.$2).toStringAsFixed(2),
    };
    expect(low, isEmpty);
  });

  test('the button is lighter than the blue of the web', () {
    expect(AppColors.button.computeLuminance(), greaterThan(AppColors.blue.computeLuminance()));
  });
}
