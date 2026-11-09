import 'package:cypress_realworld_for_personal_portfolio_mobile/core/api_client.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import 'fake_api.dart';

const testUser = {
  'id': 'u1',
  'firstName': 'Ada',
  'lastName': 'Kim',
  'username': 'tester',
};

Map<String, dynamic> testAccount(
  String id, {
  String bank = 'Test Bank One',
  String number = '123456789',
  bool isDeleted = false,
}) =>
    {
      'id': id,
      'bankName': bank,
      'routingNumber': '987654321',
      'accountNumber': number,
      'isDeleted': isDeleted,
    };

/// A small in-memory copy of the web API. No network is used.
/// Set the flags to make a request fail.
class FakeServer {
  FakeServer({
    this.signedIn = false,
    List<Map<String, dynamic>> accounts = const [],
  }) : accounts = [...accounts];

  bool signedIn;
  bool loginOk = true;
  bool down = false;
  bool failSignUp = false;
  bool failAccountList = false;
  bool failAccountCreate = false;
  bool failAccountDelete = false;

  /// All accounts the server holds. Like the real server, a deleted account
  /// stays here with `isDeleted: true` and is still returned by the list call.
  final List<Map<String, dynamic>> accounts;

  /// The accounts that are not deleted.
  List<Map<String, dynamic>> get activeAccounts =>
      accounts.where((a) => a['isDeleted'] != true).toList();

  /// Every request, as `METHOD /path`.
  final List<String> calls = [];

  /// The last body sent to each `METHOD /path`.
  final Map<String, Object?> bodies = {};

  int _nextId = 1;

  ApiClient client() => ApiClient(
        baseUrl: 'http://api.test/api',
        cookieJar: CookieJar(),
        adapter: FakeAdapter(handle),
      );

  ResponseBody handle(RequestOptions o) {
    final key = '${o.method} ${o.path}';
    calls.add(key);
    bodies[key] = o.data;
    if (down) {
      throw DioException.connectionError(requestOptions: o, reason: 'down');
    }

    switch (key) {
      case 'GET /checkAuth':
        return signedIn
            ? jsonBody(200, {'user': testUser})
            : jsonBody(401, {'error': 'User is unauthorized'});
      case 'POST /login':
        if (!loginOk) return jsonBody(401, 'Unauthorized');
        signedIn = true;
        return jsonBody(200, {'user': testUser});
      case 'POST /users':
        return failSignUp
            ? jsonBody(400, {'error': 'bad'})
            : jsonBody(201, {'user': testUser});
      case 'POST /logout':
        signedIn = false;
        return ResponseBody.fromString('', 302);
      case 'GET /bankAccounts':
        return failAccountList
            ? jsonBody(500, {'error': 'boom'})
            : jsonBody(200, {'results': accounts});
      case 'POST /bankAccounts':
        if (failAccountCreate) return jsonBody(400, {'error': 'bad'});
        final body = o.data as Map<String, dynamic>;
        final account = {'id': 'new${_nextId++}', ...body, 'isDeleted': false};
        accounts.add(account);
        return jsonBody(200, {'account': account});
    }
    if (o.method == 'DELETE' && o.path.startsWith('/bankAccounts/')) {
      if (failAccountDelete) return jsonBody(500, {'error': 'boom'});
      final id = o.path.substring('/bankAccounts/'.length);
      for (final a in accounts.where((a) => a['id'] == id)) {
        a['isDeleted'] = true; // soft delete, as on the real server
      }
      return jsonBody(200, {'account': {'id': id}});
    }
    return jsonBody(404, {'error': 'not found: $key'});
  }
}
