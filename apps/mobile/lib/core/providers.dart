import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'config.dart';

/// Set in `main()` (or in tests) with `overrideWithValue`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider is not set'),
);

/// Set in `main()` (or in tests) with `overrideWithValue`.
final cookieJarProvider = Provider<CookieJar>(
  (ref) => throw UnimplementedError('cookieJarProvider is not set'),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    cookieJar: ref.watch(cookieJarProvider),
  ),
);

/// Opens an address in the phone's browser. Tests replace it with a fake.
typedef UrlOpener = Future<bool> Function(Uri url);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);
