import 'package:flutter/material.dart';

/// The colours of the app: the web's blue (`#1976D2`), lighter.
///
/// Wide areas (buttons, the chosen tab, dialogs, the background) are pale. Text and
/// icons stay dark enough to read: every pair has a contrast of 4.5 or more, which
/// a test checks. Green (in), red (out) and yellow (no account) have their own
/// meaning and are not part of this.
abstract final class AppColors {
  /// The web's blue. Links, the chosen tab's text, the focused field.
  static const blue = Color(0xFF1976D2);

  /// Filled buttons, with [ink] on them.
  static const button = Color(0xFF90CAF9);

  /// Chosen things: the tab bar, chips, letters in circles.
  static const chosen = Color(0xFFD6EAFB);

  /// Dark blue text on [button] and [chosen].
  static const ink = Color(0xFF0B3A6F);

  static const background = Color(0xFFFCFDFF);
  static const bar = Color(0xFFEFF6FC);
  static const dialog = Color(0xFFFFFFFF);
}

final ColorScheme appColorScheme = ColorScheme.fromSeed(seedColor: AppColors.blue).copyWith(
  primary: AppColors.blue,
  onPrimary: Colors.white,
  primaryContainer: AppColors.chosen,
  onPrimaryContainer: AppColors.ink,
  secondaryContainer: AppColors.chosen,
  onSecondaryContainer: AppColors.ink,
  // The bank icon of an external deposit.
  tertiaryContainer: const Color(0xFFD5F0EE),
  onTertiaryContainer: const Color(0xFF0B4F4A),
  surface: AppColors.background,
  surfaceContainerLow: AppColors.dialog,
  surfaceContainer: AppColors.bar,
  surfaceContainerHigh: AppColors.dialog,
  surfaceContainerHighest: AppColors.bar,
);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: appColorScheme,
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      // Disabled buttons keep the default grey.
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : AppColors.button,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : AppColors.ink,
      ),
    ),
  ),
);
