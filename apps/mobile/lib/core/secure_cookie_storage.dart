import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the cookies in the secure storage of the device (on Android encrypted with a
/// key of the Android Keystore) instead of a plain file.
///
/// The storage can fail (a key that is lost, a device that does not answer). The app
/// must still work: a cookie that cannot be read is a user who is not signed in, and one
/// that cannot be written is a sign-in that is not remembered.
class SecureCookieStorage implements Storage {
  const SecureCookieStorage({
    this.storage = const FlutterSecureStorage(),
    this.timeout = const Duration(seconds: 5),
  });

  final FlutterSecureStorage storage;

  /// The app must not wait for ever for a storage that does not answer.
  final Duration timeout;

  static const _prefix = 'cookies:';

  Future<T?> _try<T>(Future<T?> Function() action) async {
    try {
      return await action().timeout(timeout);
    } catch (e) {
      // Only the kind of the error: its text could hold what was stored.
      debugPrint('Secure storage failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _try(() => storage.read(key: '$_prefix$key'));

  @override
  Future<void> write(String key, String value) =>
      _try(() => storage.write(key: '$_prefix$key', value: value));

  @override
  Future<void> delete(String key) => _try(() => storage.delete(key: '$_prefix$key'));

  /// The app keeps nothing else in the secure storage, so everything goes, also a
  /// cookie that [keys] does not name.
  @override
  Future<void> deleteAll(List<String> keys) => _try(storage.deleteAll);
}

/// Cookie storage that follows the web rule for "Remember me".
///
/// A cookie with an expiry date (Remember me checked, 30 days) is saved on the device.
/// A session cookie (no expiry) stays in memory and is lost on restart.
///
/// The cookies of [baseUrl] are read before the app starts: a first answer must not be
/// overwritten by a slow read of the old ones.
Future<CookieJar> createPersistentCookieJar(
  String baseUrl, {
  SecureCookieStorage storage = const SecureCookieStorage(),
}) async {
  await deletePlainCookies();
  final jar = PersistCookieJar(persistSession: false, storage: storage);
  try {
    await jar.loadForRequest(Uri.parse(baseUrl));
  } catch (_) {
    // What was saved is not readable as cookies. The jar has thrown it away.
  }
  return jar;
}

/// Earlier versions kept the cookies in a plain file. Nothing may stay there; the user
/// signs in once more.
Future<void> deletePlainCookies() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final old = Directory('${dir.path}${Platform.pathSeparator}cookies');
    if (await old.exists()) await old.delete(recursive: true);
  } catch (e) {
    // Tried again at the next start.
    debugPrint('Old cookies were not deleted: ${e.runtimeType}');
  }
}
