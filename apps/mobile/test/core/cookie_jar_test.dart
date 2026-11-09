import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';

/// The web keeps a login for 30 days only when "Remember me" is checked.
/// The app uses the same cookie rules: only a cookie with an expiry survives.
void main() {
  test('only a cookie with an expiry survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp('cookie_jar_test');
    addTearDown(() => dir.delete(recursive: true));
    final uri = Uri.parse('http://api.test/api');

    final first = PersistCookieJar(
      persistSession: false,
      storage: FileStorage(dir.path),
    );
    await first.saveFromResponse(uri, [
      Cookie('session-only', 'a'),
      Cookie('remembered', 'b')..expires = DateTime.now().add(const Duration(days: 30)),
    ]);

    // New object, same folder: this is what an app restart does.
    final second = PersistCookieJar(
      persistSession: false,
      storage: FileStorage(dir.path),
    );
    final names = (await second.loadForRequest(uri)).map((c) => c.name).toList();
    expect(names, ['remembered']);
  });
}
