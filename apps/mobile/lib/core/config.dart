/// App settings. The server address is a setting, never a literal in code.
///
/// Run with `--dart-define-from-file=../../.env` (see `.env.example`).
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Reads the settings passed in at build or run time.
  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not set. Run with --dart-define-from-file=../../.env '
        '(copy .env.example to .env first).',
      );
    }
    return const AppConfig(apiBaseUrl: apiBaseUrl);
  }

  /// Base address of the API, including the `/api` prefix.
  final String apiBaseUrl;
}
