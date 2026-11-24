import 'package:cookie_jar/cookie_jar.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/api_client.dart';

import 'fake_api.dart';

/// In-memory API fixture shared by independent clients. Used to run the real
/// widgets and native scenarios together, without touching a user's server.
/// This checks UI/orchestration integration, not correctness of the real API.
class SimulationServer {
  final users = <Map<String, dynamic>>[];
  final accounts = <Map<String, dynamic>>[];
  final transactions = <Map<String, dynamic>>[];
  final notifications = <Map<String, dynamic>>[];
  final requests = <String>[];
  var _serial = 0;
  String next() => 'fixture-${++_serial}';

  List<Map<String, dynamic>> banks(String? who) => accounts
      .where((a) => a['userId'] == who && a['visible'] == true)
      .toList();
  int balance(String? who) =>
      banks(who).fold(0, (sum, a) => sum + (a['balance'] as int));
  String name(String id) {
    final u = users.singleWhere((u) => u['id'] == id);
    return '${u['lastName']} ${u['firstName']}';
  }

  Map<String, dynamic> user(Map<String, dynamic> u) => {
    ...u,
    'balance': balance(u['id'] as String),
    'hasBankAccount': banks(u['id'] as String).isNotEmpty,
  };

  void notice(
    String who,
    String actor,
    String transactionId,
    Map<String, dynamic> kind,
  ) {
    notifications.insert(0, {
      'id': next(),
      'userId': who,
      'userFullName': name(actor),
      'transactionId': transactionId,
      'isRead': false,
      ...kind,
    });
  }

  ApiClient client() {
    Map<String, dynamic>? signedIn;
    return ApiClient(
      baseUrl: 'http://simulation.test/api',
      cookieJar: CookieJar(),
      adapter: FakeAdapter((o) {
        requests.add('${o.method} ${o.path}');
        final data = o.data is Map
            ? Map<String, dynamic>.from(o.data as Map)
            : <String, dynamic>{};
        final path = o.path;
        final method = o.method;
        final who = signedIn?['id'] as String?;
        if (path == '/users' && method == 'POST') {
          if (users.any((u) => u['username'] == data['username'])) {
            return jsonBody(409, {'error': 'this username is already taken'});
          }
          final u = {'id': next(), ...data};
          users.add(u);
          return jsonBody(201, {'user': user(u)});
        }
        if (path == '/login') {
          final matches = users.where(
            (u) =>
                u['username'] == data['username'] &&
                u['password'] == data['password'],
          );
          if (matches.isEmpty) return jsonBody(401, {'error': 'Unauthorized'});
          signedIn = matches.single;
          return jsonBody(200, {'user': user(signedIn!)});
        }
        if (path == '/logout') {
          signedIn = null;
          return jsonBody(200, {});
        }
        if (who == null) return jsonBody(401, {'error': 'Unauthorized'});
        if (path == '/checkAuth') {
          return jsonBody(200, {'user': user(signedIn!)});
        }
        if (path == '/users/verifyPassword') {
          return jsonBody(
            data['password'] == signedIn!['password'] ? 204 : 403,
            {'error': 'the password is not correct'},
          );
        }
        if (path.startsWith('/users/') && method == 'PATCH') {
          if (data['firstName'] == '' ||
              data['email'] == 'not-an-email' ||
              data['phoneNumber'] == 'abc') {
            return jsonBody(422, {});
          }
          signedIn!.addAll(data);
          return jsonBody(204, {});
        }
        if ((path == '/users' || path == '/users/search') && method == 'GET') {
          final q = '${o.queryParameters['q'] ?? ''}';
          return jsonBody(200, {
            'results': users
                .where((u) => u['id'] != who && '${u['username']}'.contains(q))
                .map(user)
                .toList(),
          });
        }
        if (path == '/demo/bankaccounts/count') {
          final all = accounts.where((a) => a['userId'] == who).length;
          return jsonBody(200, {
            'total': all,
            'visible': banks(who).length,
            'hidden': all - banks(who).length,
          });
        }
        if (path == '/demo/bankaccounts' && method == 'DELETE') {
          final before = accounts.length;
          accounts.removeWhere((a) => a['userId'] == who);
          return jsonBody(200, {'deleted': before - accounts.length});
        }
        if (path == '/bankAccounts') {
          if (method == 'GET') return jsonBody(200, {'results': banks(who)});
          if (banks(who).length >= 60) return jsonBody(400, {});
          final account = {
            'id': next(),
            'userId': who,
            'visible': true,
            'balance': 0,
            ...data,
          };
          accounts.add(account);
          return jsonBody(200, {'account': account});
        }
        if (path.startsWith('/bankAccounts/of-user/')) {
          return jsonBody(200, {
            'results': banks(path.split('/').last)
                .map(
                  (a) => {...a, 'last4': '${a['accountNumber']}'.substring(5)},
                )
                .toList(),
          });
        }
        if (path.startsWith('/bankAccounts/') && method == 'DELETE') {
          final a = accounts.singleWhere(
            (a) => a['id'] == path.split('/').last && a['userId'] == who,
          );
          if (a['balance'] != 0) {
            return jsonBody(400, {'error': 'bank account still has a balance'});
          }
          a['visible'] = false;
          return jsonBody(200, {});
        }
        if (path == '/bankTransfers') {
          if (method == 'GET') return jsonBody(200, {'results': <Object>[]});
          final amount = data['amount'];
          if (amount is! int || amount < 1) return jsonBody(422, {});
          if (amount > 21474836 || balance(who) + amount * 100 > 2147483647) {
            return jsonBody(400, {'error': 'balance limit exceeded'});
          }
          final account = banks(
            who,
          ).singleWhere((a) => a['id'] == data['bankAccountId']);
          account['balance'] = (account['balance'] as int) + amount * 100;
          final tx = _transaction(
            'external-deposit',
            who,
            amount * 100,
            '',
            'public',
            source: account['id'] as String,
          );
          transactions.insert(0, tx);
          return jsonBody(200, {
            'transfer': {'id': next()},
          });
        }
        if (path == '/transactions' && method == 'POST') {
          final amount = data['amount'];
          final dollars = int.tryParse('$amount');
          if (dollars == null || dollars < 1 || dollars > 21474836) {
            return jsonBody(422, {});
          }
          if (data['password'] != signedIn!['password']) {
            return jsonBody(403, {'error': 'the password is not correct'});
          }
          final from = banks(
            who,
          ).singleWhere((a) => a['id'] == data['myAccountId']);
          if ((from['balance'] as int) < dollars * 100) {
            return jsonBody(400, {});
          }
          final to = accounts.singleWhere(
            (a) => a['id'] == data['otherAccountId'],
          );
          from['balance'] = (from['balance'] as int) - dollars * 100;
          to['balance'] = (to['balance'] as int) + dollars * 100;
          final tx = _transaction(
            who,
            data['receiverId'] as String,
            dollars * 100,
            data['description'] as String,
            data['privacyLevel'] as String? ??
                signedIn!['defaultPrivacyLevel'] as String? ??
                'public',
          );
          transactions.insert(0, tx);
          notice(data['receiverId'] as String, who, tx['id'] as String, {
            'status': 'received',
          });
          return jsonBody(200, {'transaction': tx});
        }
        if (method == 'GET' &&
            (path == '/transactions' || path == '/transactions/public')) {
          final q = o.queryParameters;
          if (q['withdrawalMin'] == '10.5' ||
              q['withdrawalMin'] == 2147483700 ||
              (q['withdrawalMin'] == 10000 && q['withdrawalMax'] == 5000) ||
              q['dateRangeStart'] == '2027-02-30' ||
              q['dateRangeStart'] == '2027-03-02') {
            return jsonBody(422, {});
          }
          var list = transactions.where(
            (t) =>
                _visible(t, who) &&
                (path.endsWith('/public') ||
                    t['senderId'] == who ||
                    t['receiverId'] == who),
          );
          final hasMoney = q.keys.any(
            (k) => k.startsWith('deposit') || k.startsWith('withdrawal'),
          );
          if (hasMoney) {
            list = list.where((t) {
              bool matches(String kind, bool personMatches) {
                if (!q.containsKey('${kind}Min') &&
                    !q.containsKey('${kind}Max')) {
                  return false;
                }
                final min = int.tryParse('${q['${kind}Min']}') ?? 0;
                final max = int.tryParse('${q['${kind}Max']}') ?? 2147483647;
                return personMatches &&
                    (t['amount'] as int) >= min &&
                    (t['amount'] as int) <= max;
              }

              return matches('deposit', t['receiverId'] == who) ||
                  matches('withdrawal', t['senderId'] == who);
            });
          }
          for (final item in [
            ('dateRangeStart', true),
            ('dateRangeEnd', false),
          ]) {
            final date = DateTime.tryParse('${q[item.$1]}');
            if (date != null) {
              list = list.where(
                (t) => item.$2
                    ? !DateTime.parse(t['createdAt'] as String).isBefore(date)
                    : !DateTime.parse(t['createdAt'] as String).isAfter(date),
              );
            }
          }
          final page = int.parse('${q['page'] ?? 1}');
          final limit = int.parse('${q['limit'] ?? 10}');
          final all = list.toList();
          return jsonBody(200, {
            'results': all.skip((page - 1) * limit).take(limit).toList(),
            'pageData': {'hasNextPages': page * limit < all.length},
          });
        }
        if (path.startsWith('/transactions/')) {
          final tx = transactions.singleWhere(
            (t) => t['id'] == path.split('/').last,
          );
          return _visible(tx, who)
              ? jsonBody(200, {'transaction': tx})
              : jsonBody(404, {});
        }
        if (path.startsWith('/likes/') || path.startsWith('/comments/')) {
          final tx = transactions.singleWhere(
            (t) => t['id'] == path.split('/').last,
          );
          final kind = path.startsWith('/likes/') ? 'likes' : 'comments';
          final list = tx[kind] as List<dynamic>;
          if (method == 'GET') return jsonBody(200, {kind: list});
          if (kind == 'likes' && list.any((l) => l['userId'] == who)) {
            return jsonBody(409, {});
          }
          if (kind == 'comments' && '${data['content']}'.trim().isEmpty) {
            return jsonBody(422, {});
          }
          final item = {
            'id': next(),
            'userId': who,
            'userFullName': name(who),
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            ...data,
          };
          list.add(item);
          for (final target in {
            tx['senderId'],
            tx['receiverId'],
          }.where((id) => id != who)) {
            notice(target as String, who, tx['id'] as String, {
              kind == 'likes' ? 'likeId' : 'commentId': item['id'],
            });
          }
          return jsonBody(200, {});
        }
        if (path == '/notifications') {
          return jsonBody(200, {
            'results': notifications
                .where(
                  (n) =>
                      n['userId'] == who &&
                      (o.queryParameters['include'] == 'read' ||
                          n['isRead'] == false),
                )
                .toList(),
          });
        }
        if (path.startsWith('/notifications/') && method == 'PATCH') {
          notifications.singleWhere(
            (n) => n['id'] == path.split('/').last,
          )['isRead'] = true;
          return jsonBody(204, {});
        }
        throw StateError('Unhandled simulation fixture request: $method $path');
      }),
    );
  }

  bool _visible(Map<String, dynamic> t, String who) =>
      t['privacyLevel'] == 'public' ||
      t['senderId'] == who ||
      t['receiverId'] == who;

  Map<String, dynamic> _transaction(
    String from,
    String to,
    int cents,
    String memo,
    String privacy, {
    String? source,
  }) => {
    'id': next(),
    'senderId': from,
    'receiverId': to,
    'senderName': from == 'external-deposit' ? '' : name(from),
    'receiverName': name(to),
    'amount': cents,
    'description': memo,
    'status': 'complete',
    'privacyLevel': privacy,
    'likes': <Object>[],
    'comments': <Object>[],
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    if (source != null) 'source': source,
  };
}
