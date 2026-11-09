import 'package:cookie_jar/cookie_jar.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';

void main() {
  test('checkAuth returns the user on 200', () async {
    final client = fakeClient((o) {
      expect(o.uri.toString(), 'http://api.test/api/checkAuth');
      return jsonBody(200, {
        'user': {'id': 'u1', 'username': 'tester'},
      });
    });
    final user = await client.checkAuth();
    expect(user?['username'], 'tester');
  });

  test('checkAuth returns null on 401', () async {
    final client = fakeClient(
      (_) => jsonBody(401, {'error': 'User is unauthorized'}),
    );
    expect(await client.checkAuth(), isNull);
  });

  test('checkAuth reports a connection error', () async {
    final client = fakeClient(
      (o) => throw DioException.connectionError(
        requestOptions: o,
        reason: 'no route to host',
      ),
    );
    await expectLater(
      client.checkAuth(),
      throwsA(isA<ApiException>().having((e) => e.isConnection, 'isConnection', true)),
    );
  });

  test('login posts the credentials and returns the user', () async {
    late RequestOptions seen;
    final client = fakeClient((o) {
      seen = o;
      return jsonBody(200, {
        'user': {'id': 'u1', 'username': 'tester'},
      });
    });
    final user = await client.login(username: 'tester', password: 'pw', remember: false);
    expect(user['username'], 'tester');
    expect(seen.method, 'POST');
    expect(seen.uri.toString(), 'http://api.test/api/login');
    expect(seen.data, {'username': 'tester', 'password': 'pw', 'remember': false});
  });

  test('login reports 401 as an ApiException', () async {
    final client = fakeClient((_) => jsonBody(401, 'Unauthorized'));
    await expectLater(
      client.login(username: 'tester', password: 'bad', remember: false),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('signUp posts the new user to /users', () async {
    late RequestOptions seen;
    final client = fakeClient((o) {
      seen = o;
      return jsonBody(201, {'user': {}});
    });
    await client.signUp(
      firstName: 'Ada',
      lastName: 'Kim',
      username: 'ada',
      password: 'abcd',
    );
    expect(seen.uri.toString(), 'http://api.test/api/users');
    expect(seen.data, {
      'firstName': 'Ada',
      'lastName': 'Kim',
      'username': 'ada',
      'password': 'abcd',
    });
  });

  test('getBankAccounts returns the list from "results"', () async {
    late RequestOptions seen;
    final client = fakeClient((o) {
      seen = o;
      return jsonBody(200, {
        'results': [
          {'id': 'b1', 'bankName': 'Test Bank One'},
        ],
      });
    });
    final list = await client.getBankAccounts();
    expect(list.single['id'], 'b1');
    expect(seen.method, 'GET');
    expect(seen.uri.toString(), 'http://api.test/api/bankAccounts');
  });

  test('createBankAccount posts the fields and returns the account', () async {
    late RequestOptions seen;
    final client = fakeClient((o) {
      seen = o;
      return jsonBody(200, {
        'account': {'id': 'b9', 'bankName': 'Test Bank One'},
      });
    });
    final account = await client.createBankAccount(
      bankName: 'Test Bank One',
      routingNumber: '123456789',
      accountNumber: '987654321',
    );
    expect(account['id'], 'b9');
    expect(seen.method, 'POST');
    expect(seen.data, {
      'bankName': 'Test Bank One',
      'routingNumber': '123456789',
      'accountNumber': '987654321',
    });
  });

  test('deleteBankAccount calls DELETE with the id', () async {
    late RequestOptions seen;
    final client = fakeClient((o) {
      seen = o;
      return jsonBody(200, {'account': {}});
    });
    await client.deleteBankAccount('b1');
    expect(seen.method, 'DELETE');
    expect(seen.uri.toString(), 'http://api.test/api/bankAccounts/b1');
  });

  test('logout removes the cookie even when the server is down', () async {
    final jar = CookieJar();
    final uri = Uri.parse('http://api.test/api/');
    await jar.saveFromResponse(uri, [Cookie('connect.sid', 'abc')]);
    final client = ApiClient(
      baseUrl: 'http://api.test/api',
      cookieJar: jar,
      adapter: FakeAdapter(
        (o) => throw DioException.connectionError(requestOptions: o, reason: 'down'),
      ),
    );

    await expectLater(client.logout(), throwsA(isA<ApiException>()));
    expect(await jar.loadForRequest(uri), isEmpty);
  });

  test('checkAuth reports a server error that is not a connection error', () async {
    final client = fakeClient((_) => jsonBody(500, {'error': 'boom'}));
    await expectLater(
      client.checkAuth(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isConnection, 'isConnection', false)
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'boom'),
      ),
    );
  });
}
