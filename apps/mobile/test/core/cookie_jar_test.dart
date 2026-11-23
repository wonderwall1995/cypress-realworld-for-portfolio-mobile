import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/secure_cookie_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _url = 'http://api.test/api';
final _uri = Uri.parse(_url);

/// The secure storage of a device: a map, and ways to fail.
class _Device extends FlutterSecureStorage {
  _Device();

  final values = <String, String>{};
  bool broken = false;
  bool silent = false;

  /// Reads wait for this.
  Completer<void>? gate;

  Future<T> _answer<T>(T Function() action) async {
    if (silent) await Completer<void>().future;
    if (broken) throw PlatformException(code: 'KeyStoreException', message: 'connect.sid=secret');
    return action();
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await gate?.future;
    return _answer(() => values[key]);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _answer(() => values[key] = value!);

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _answer(() => values.remove(key));

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _answer(values.clear);
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// The web keeps a login for 30 days only when "Remember me" is checked.
/// The app uses the same cookie rules: only a cookie with an expiry survives.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late _Device device;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cookie_jar_test');
    PathProviderPlatform.instance = _Paths(dir.path);
    device = _Device();
  });
  tearDown(() => dir.delete(recursive: true));

  /// A new jar over the same device: this is what an app restart does.
  Future<CookieJar> start() => createPersistentCookieJar(
        _url,
        storage: SecureCookieStorage(storage: device, timeout: const Duration(milliseconds: 100)),
      );

  Cookie remembered([String value = 'b']) =>
      Cookie('connect.sid', value)..expires = DateTime.now().add(const Duration(days: 30));

  Future<List<String>> cookiesOf(CookieJar jar) async =>
      [for (final c in await jar.loadForRequest(_uri)) '${c.name}=${c.value}'];

  test('only a cookie with an expiry survives a restart', () async {
    await (await start()).saveFromResponse(_uri, [Cookie('session-only', 'a'), remembered()]);

    expect(await cookiesOf(await start()), ['connect.sid=b']);
  });

  test('nothing is written to a file', () async {
    await (await start()).saveFromResponse(_uri, [remembered()]);

    expect(dir.listSync(recursive: true), isEmpty);
    expect(device.values, isNotEmpty);
  });

  test('signing out leaves no cookie on the device, also one that is not in the list', () async {
    final jar = await start();
    await jar.saveFromResponse(_uri, [remembered()]);
    device.values['cookies:other.host'] = 'old';
    await jar.deleteAll();

    expect(device.values, isEmpty);
    expect(await cookiesOf(await start()), isEmpty);
  });

  test('the plain file of an earlier version is deleted', () async {
    final old = Directory('${dir.path}${Platform.pathSeparator}cookies');
    final before = PersistCookieJar(persistSession: false, storage: FileStorage(old.path));
    await before.saveFromResponse(_uri, [remembered()]);
    expect(old.listSync(recursive: true), isNotEmpty);

    expect(await cookiesOf(await start()), isEmpty);
    expect(old.existsSync(), isFalse);
  });

  test('a storage that fails: not signed in, and signing in still works until the app is closed', () async {
    await (await start()).saveFromResponse(_uri, [remembered()]);
    device.broken = true;

    final jar = await start();
    expect(await cookiesOf(jar), isEmpty);
    await jar.saveFromResponse(_uri, [remembered('new')]);
    expect(await cookiesOf(jar), ['connect.sid=new']);
    await jar.deleteAll();
    expect(await cookiesOf(jar), isEmpty);
  });

  test('a storage that failed once keeps what it holds', () async {
    await (await start()).saveFromResponse(_uri, [remembered()]);
    device.broken = true;
    await start();
    device.broken = false;

    expect(await cookiesOf(await start()), ['connect.sid=b']);
  });

  test('a storage that never answers does not stop the app', () async {
    device.silent = true;

    expect(await cookiesOf(await start().timeout(const Duration(seconds: 3))), isEmpty);
  });

  test('what is not a cookie is thrown away', () async {
    await (await start()).saveFromResponse(_uri, [remembered()]);
    device.values['cookies:api.test'] = 'not json';

    expect(await cookiesOf(await start()), isEmpty);
    expect(device.values.values, isNot(contains('not json')));
  });

  test('a slow read of the old cookies does not overwrite a new one', () async {
    await (await start()).saveFromResponse(_uri, [remembered('old')]);
    final jar = await start();
    device.gate = Completer<void>();
    // The request that checks the sign-in reads while the sign-in saves.
    final reading = jar.loadForRequest(_uri);
    final saving = jar.saveFromResponse(_uri, [remembered('new')]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    device.gate!.complete();
    await Future.wait([reading, saving]);

    expect(await cookiesOf(jar), ['connect.sid=new']);
  });

  test('a failure says nothing about what was stored', () async {
    final said = <String>[];
    await runZoned(
      () async {
        device.broken = true;
        await (await start()).saveFromResponse(_uri, [remembered('secret-value')]);
      },
      zoneSpecification: ZoneSpecification(print: (_, __, ___, line) => said.add(line)),
    );
    expect(said, isNotEmpty);
    expect(said.join(), isNot(contains('secret')));
  });
}
