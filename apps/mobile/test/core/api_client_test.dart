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
