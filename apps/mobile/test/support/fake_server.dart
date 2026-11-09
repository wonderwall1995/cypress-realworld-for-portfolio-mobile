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

/// A transaction as the server sends it. [amount] is in cents.
Map<String, dynamic> testTransaction(
  String id, {
  String sender = 'Alice Test',
  String receiver = 'Bob Test',
  String description = 'Test payment',
  int amount = 500,
  String? requestStatus,
  String status = 'complete',
  int likes = 0,
  int comments = 0,
}) =>
    {
      'id': id,
      'senderId': 's-$id',
      'receiverId': 'r-$id',
      'senderName': sender,
      'receiverName': receiver,
      'description': description,
      'amount': amount,
      'status': status,
      // A payment has no requestStatus at all, as on the real server.
      if (requestStatus != null) 'requestStatus': requestStatus,
      'likes': List.generate(likes, (i) => {'id': 'l$i'}),
      'comments': List.generate(comments, (i) => {'id': 'c$i'}),
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

  /// The three transaction lists (web tabs: Everyone, Friends, Mine).
  final List<Map<String, dynamic>> everyone = [];
  final List<Map<String, dynamic>> friends = [];
  final List<Map<String, dynamic>> mine = [];

  /// Page numbers (1, 2, ...) for which a list request fails.
  final Set<int> failPages = {};
  bool failTransactionDetail = false;

  /// Every list request, as `/path:page`.
  final List<String> feedRequests = [];

  Map<String, List<Map<String, dynamic>>> get _feeds => {
        '/transactions/public': everyone,
        '/transactions/contacts': friends,
        '/transactions': mine,
      };

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
    final feed = _feeds[o.path];
    if (o.method == 'GET' && feed != null) {
      final page = int.parse('${o.queryParameters['page'] ?? 1}');
      final limit = int.parse('${o.queryParameters['limit'] ?? 10}');
      feedRequests.add('${o.path}:$page');
      if (failPages.contains(page)) return jsonBody(500, {'error': 'boom'});
      final start = (page - 1) * limit;
      final end = start + limit;
      final results = feed.skip(start).take(limit).toList();
      return jsonBody(200, {
        'pageData': {
          'page': page,
          'limit': limit,
          'hasNextPages': end < feed.length,
          'totalPages': (feed.length / limit).ceil(),
        },
        'results': results,
      });
    }
    if (o.method == 'GET' && o.path.startsWith('/transactions/')) {
      if (failTransactionDetail) return jsonBody(500, {'error': 'boom'});
      final id = o.path.substring('/transactions/'.length);
      final all = [...everyone, ...friends, ...mine];
      final found = all.where((t) => t['id'] == id);
      return found.isEmpty
          ? jsonBody(404, {'error': 'not found'})
          : jsonBody(200, {'transaction': found.first});
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
