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
  int? balance,
}) =>
    {
      'id': id,
      'bankName': bank,
      'accountNumber': number,
      'isDeleted': isDeleted,
      if (balance != null) 'balance': balance,
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
  String? senderId,
  String? receiverId,
  List<String>? likedBy,
  List<String>? commentTexts,
}) =>
    {
      'id': id,
      'senderId': senderId ?? 's-$id',
      'receiverId': receiverId ?? 'r-$id',
      'senderName': sender,
      'receiverName': receiver,
      'description': description,
      'amount': amount,
      'status': status,
      // A payment has no requestStatus at all, as on the real server.
      if (requestStatus != null) 'requestStatus': requestStatus,
      'likes': likedBy != null
          ? [for (var i = 0; i < likedBy.length; i++) {'id': 'l$i', 'userId': likedBy[i]}]
          : List<Map<String, dynamic>>.generate(likes, (i) => {'id': 'l$i', 'userId': 'other$i'}),
      'comments': commentTexts != null
          ? [
              for (var i = 0; i < commentTexts.length; i++)
                {
                  'id': 'c$i',
                  'content': commentTexts[i],
                  'userId': 'u2',
                  'createdAt': '2026-11-09T18:51:10.224Z',
                }
            ]
          : List<Map<String, dynamic>>.generate(
              comments, (i) => {'id': 'c$i', 'content': 'Comment $i', 'userId': 'u2'}),
    };

/// A notification as the server sends it. [kind] is `requested`, `received`,
/// `like` or `comment`.
Map<String, dynamic> testNotification(
  String id,
  String kind, {
  String name = 'Bob Test',
  String transactionId = 't1',
}) =>
    {
      'id': id,
      'userId': 'u1',
      'transactionId': transactionId,
      'isRead': false,
      'userFullName': name,
      if (kind == 'like') 'likeId': 'like-$id',
      if (kind == 'comment') 'commentId': 'comment-$id',
      if (kind == 'requested' || kind == 'received') 'status': kind,
    };

/// Another user, as the server sends it in the user list.
Map<String, dynamic> testOtherUser(String id, String first, String last, {String? username}) => {
      'id': id,
      'firstName': first,
      'lastName': last,
      'username': username ?? first.toLowerCase(),
    };

/// A bank transfer as the server sends it. Amounts are in cents. An empty
/// [source] and a [transactionId] mean the server made it to cover a payment.
Map<String, dynamic> testTransfer(
  String id,
  String type,
  int amount, {
  String source = 'b1',
  String? transactionId,
  int balanceBefore = 0,
  int balanceAfter = 0,
  String createdAt = '2026-11-09T18:21:22.378Z',
}) =>
    {
      'id': id,
      'userId': 'u1',
      'source': source,
      'amount': amount,
      'type': type,
      'status': 'completed',
      'transactionId': transactionId,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'createdAt': createdAt,
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

  /// The signed-in user's balance in cents. Payments and accepted requests change it.
  int balance = 0;

  /// What the user saved in 설정 (email, phone, name, privacy...). Shown on top of testUser.
  final Map<String, dynamic> profile = {};

  /// Status code for  (null = it works and answers 204).
  int? updateUserStatus;

  Map<String, dynamic> get user => {...testUser, ...profile, 'balance': balance};

  /// Other users for the "새 거래" list. `GET /users/search?q=` filters them.
  final List<Map<String, dynamic>> users = [];
  final List<String> userQueries = [];

  bool failUsers = false;

  /// The signed-in user's deposits and withdrawals.
  final List<Map<String, dynamic>> transfers = [];
  bool failTransfers = false;

  /// Status code for `POST /bankTransfers` (null = the real rules below).
  int? moveMoneyStatus;

  /// Unread notifications. Marking one as read removes it from the list.
  final List<Map<String, dynamic>> notifications = [];
  bool failNotifications = false;
  bool failMarkRead = false;
  bool failLike = false;
  bool failComment = false;

  Map<String, dynamic>? _transaction(String id) {
    final all = [...everyone, ...friends, ...mine];
    final found = all.where((t) => t['id'] == id);
    return found.isEmpty ? null : found.first;
  }

  /// Status code for `POST /transactions` (null = success).
  int? createTransactionStatus;

  /// Status code for `PATCH /transactions/:id` (null = the real rules: 409 if resolved).
  int? updateTransactionStatus;

  /// Page numbers (1, 2, ...) for which a list request fails.
  final Set<int> failPages = {};
  bool failTransactionDetail = false;

  /// Every list request, as `/path:page`.
  final List<String> feedRequests = [];

  /// The query of every list request (page, limit, and the filters if any).
  final List<Map<String, dynamic>> feedQueries = [];

  /// What the server returns when a request has a date or amount filter.
  final List<Map<String, dynamic>> filtered = [];

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
            ? jsonBody(200, {'user': user})
            : jsonBody(401, {'error': 'User is unauthorized'});
      case 'POST /login':
        if (!loginOk) return jsonBody(401, 'Unauthorized');
        signedIn = true;
        return jsonBody(200, {'user': user});
      case 'POST /users':
        if (failSignUp) return jsonBody(400, {'error': 'bad'});
        // Like the real server: a phone number is required at sign-up.
        final phone = (o.data as Map<String, dynamic>)['phoneNumber'];
        if (phone is! String || !RegExp(r'^\+?\d[\d\s()-]{5,18}\d$').hasMatch(phone.trim())) {
          return jsonBody(422, {
            'errors': [
              {'msg': 'phoneNumber is required and must be a valid phone number', 'param': 'phoneNumber', 'location': 'body'},
            ],
          });
        }
        return jsonBody(201, {'user': testUser});
      case 'GET /users':
        userQueries.add('');
        return failUsers
            ? jsonBody(500, {'error': 'boom'})
            : jsonBody(200, {'results': users});
      case 'GET /users/search':
        final q = '${o.queryParameters['q'] ?? ''}'.toLowerCase();
        userQueries.add(q);
        if (failUsers) return jsonBody(500, {'error': 'boom'});
        final found = users.where((u) =>
            '${u['firstName']} ${u['lastName']} ${u['username']}'.toLowerCase().contains(q));
        return jsonBody(200, {'results': found.toList()});
      case 'POST /transactions':
        if (createTransactionStatus != null) {
          return jsonBody(createTransactionStatus!, {'error': 'refused'});
        }
        final body = o.data as Map<String, dynamic>;
        final receiver = users.firstWhere((u) => u['id'] == body['receiverId']);
        final isRequest = body['transactionType'] == 'request';
        final created = testTransaction(
          'new${_nextId++}',
          sender: 'Ada Kim',
          receiver: '${receiver['firstName']} ${receiver['lastName']}',
          description: body['description'] as String,
          amount: (body['amount'] as int) * 100,
          requestStatus: isRequest ? 'pending' : null,
          status: isRequest ? 'pending' : 'complete',
          senderId: 'u1',
          receiverId: receiver['id'] as String,
        );
        mine.insert(0, created);
        if (!isRequest) balance -= created['amount'] as int;
        return jsonBody(200, {'transaction': created});
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
        final account = {'id': 'new${_nextId++}', ...body, 'isDeleted': false, 'balance': 0};
        accounts.add(account);
        return jsonBody(200, {'account': account});
    }
    final feed = _feeds[o.path];
    if (o.method == 'GET' && feed != null) {
      final page = int.parse('${o.queryParameters['page'] ?? 1}');
      final limit = int.parse('${o.queryParameters['limit'] ?? 10}');
      feedRequests.add('${o.path}:$page');
      feedQueries.add({...o.queryParameters});
      final hasFilter = o.queryParameters.keys
          .any((k) => k.startsWith('dateRange') || k.startsWith('deposit') || k.startsWith('withdrawal'));
      final source = hasFilter ? filtered : feed;
      if (failPages.contains(page)) return jsonBody(500, {'error': 'boom'});
      final start = (page - 1) * limit;
      final end = start + limit;
      final results = source.skip(start).take(limit).toList();
      return jsonBody(200, {
        'pageData': {
          'page': page,
          'limit': limit,
          'hasNextPages': end < source.length,
          'totalPages': (source.length / limit).ceil(),
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
    if (o.method == 'PATCH' && o.path.startsWith('/users/')) {
      if (updateUserStatus != null) return jsonBody(updateUserStatus!, {'error': 'refused'});
      // Like the real server: the id in the path is not compared with the signed-in user.
      profile.addAll((o.data as Map<String, dynamic>));
      return ResponseBody.fromString('', 204);
    }
    if (o.method == 'GET' && o.path == '/bankTransfers') {
      return failTransfers
          ? jsonBody(500, {'error': 'boom'})
          : jsonBody(200, {'transfers': [...transfers]});
    }
    if (o.method == 'POST' && o.path == '/bankTransfers') {
      if (moveMoneyStatus != null) return jsonBody(moveMoneyStatus!, {'error': 'refused'});
      final body = o.data as Map<String, dynamic>;
      final amount = body['amount'];
      // The real rules (see the web repo's banktransfer-service).
      if (amount is! int || amount < 1) {
        return jsonBody(422, {
          'errors': [
            {'msg': 'Invalid value', 'param': 'amount', 'location': 'body'},
          ],
        });
      }
      final type = body['type'];
      if (type != 'deposit' && type != 'withdrawal') {
        return jsonBody(400, {'error': 'type must be deposit or withdrawal'});
      }
      final account = accounts.where((a) => a['id'] == body['bankAccountId']);
      if (account.isEmpty) return jsonBody(404, {'error': 'bank account not found'});
      if (account.first['isDeleted'] == true) {
        return jsonBody(400, {'error': 'this bank account was deleted'});
      }
      final cents = amount * 100;
      // Like the newer server: a deposit goes into the bank account (its own
      // balance); a withdrawal comes out of the balance of the user.
      final held = account.first['balance'] as int? ?? 0;
      final before = type == 'deposit' ? held : balance;
      final after = type == 'deposit' ? before + cents : before - cents;
      if (type == 'withdrawal' && after < 0) {
        return jsonBody(400, {'error': 'not enough balance'});
      }
      if (after > 2147483647) {
        return jsonBody(400, {'error': 'the balance would be too large'});
      }
      final transfer = testTransfer(
        'tr${_nextId++}',
        type as String,
        cents,
        source: body['bankAccountId'] as String,
        balanceBefore: before,
        balanceAfter: after,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      if (type == 'deposit') {
        account.first['balance'] = after;
        // Like the newer server: a deposit also makes an "외부 입금" transaction. It is
        // in everyone's list (only the user's own deposits) and in the user's own,
        // never in the friends' list.
        final deposit = testTransaction(
          'dep${_nextId++}',
          sender: '외부 입금',
          receiver: 'Kim Ada',
          description: '외부 입금',
          amount: cents,
          senderId: 'external-deposit',
          receiverId: 'u1',
        );
        everyone.insert(0, deposit);
        mine.insert(0, deposit);
      } else {
        balance = after;
      }
      transfers.add(transfer);
      return jsonBody(201, {'transfer': transfer});
    }
    if (o.method == 'GET' && o.path == '/notifications') {
      return failNotifications
          ? jsonBody(500, {'error': 'boom'})
          : jsonBody(200, {'results': [...notifications]});
    }
    if (o.method == 'PATCH' && o.path.startsWith('/notifications/')) {
      if (failMarkRead) return jsonBody(500, {'error': 'boom'});
      final id = o.path.substring('/notifications/'.length);
      notifications.removeWhere((n) => n['id'] == id);
      return ResponseBody.fromString('', 204);
    }
    if (o.method == 'POST' && o.path.startsWith('/likes/')) {
      if (failLike) return jsonBody(500, {'error': 'boom'});
      final t = _transaction(o.path.substring('/likes/'.length));
      if (t == null) return jsonBody(404, {'error': 'not found'});
      // Like the real server: no check for a second like from the same user.
      (t['likes'] as List).add({'id': 'new${_nextId++}', 'userId': 'u1'});
      return ResponseBody.fromString('OK', 200);
    }
    if (o.method == 'POST' && o.path.startsWith('/comments/')) {
      if (failComment) return jsonBody(500, {'error': 'boom'});
      final t = _transaction(o.path.substring('/comments/'.length));
      if (t == null) return jsonBody(404, {'error': 'not found'});
      (t['comments'] as List).add({
        'id': 'new${_nextId++}',
        'content': (o.data as Map<String, dynamic>)['content'],
        'userId': 'u1',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      return ResponseBody.fromString('OK', 200);
    }
    if (o.method == 'PATCH' && o.path.startsWith('/transactions/')) {
      if (updateTransactionStatus != null) {
        return jsonBody(updateTransactionStatus!, {'error': 'refused'});
      }
      final id = o.path.substring('/transactions/'.length);
      final all = [...everyone, ...friends, ...mine];
      final found = all.where((t) => t['id'] == id);
      if (found.isEmpty) return jsonBody(404, {'error': 'not found'});
      final t = found.first;
      // The real rule: a request can be resolved once.
      if (t['requestStatus'] != 'pending') {
        return jsonBody(409, {'error': 'this request is already ${t['requestStatus']}'});
      }
      final status = (o.data as Map<String, dynamic>)['requestStatus'] as String;
      t['requestStatus'] = status;
      if (status == 'accepted') {
        t['status'] = 'complete';
        balance -= t['amount'] as int; // the receiver (the signed-in user) pays
      }
      return ResponseBody.fromString('', 204);
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
