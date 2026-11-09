import 'package:flutter/foundation.dart';

/// App settings. The server address is a setting, never a literal in code.
///
/// Run with `--dart-define-from-file=../../.env` (see `.env.example`).
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Reads the settings passed in at build or run time.
  ///
  /// A release build accepts only an `https://` address. (A debug build also
  /// accepts `http://`, for the emulator and the local server.)
  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    final problem = validateApiBaseUrl(apiBaseUrl, isRelease: kReleaseMode);
    if (problem != null) {
      throw StateError(problem);
    }
    return const AppConfig(apiBaseUrl: apiBaseUrl);
  }

  /// Base address of the API, including the `/api` prefix.
  final String apiBaseUrl;
}

/// Returns what is wrong with the server address, or null when it is fine.
///
/// The sign-in password is sent to this address, so a release build must not
/// use plain `http://`.
String? validateApiBaseUrl(String value, {required bool isRelease}) {
  if (value.isEmpty) {
    return 'API_BASE_URL is not set. Run with --dart-define-from-file=../../.env '
        '(copy .env.example to .env first).';
  }
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'API_BASE_URL is not a valid address: it must look like https://host/api.';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return 'API_BASE_URL must start with http:// or https://.';
  }
  if (isRelease && uri.scheme != 'https') {
    return 'A release build accepts only an https:// address in API_BASE_URL. '
        'The sign-in password would be sent as plain text.';
  }
  return null;
}
