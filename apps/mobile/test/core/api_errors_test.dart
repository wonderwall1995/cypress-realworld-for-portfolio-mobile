import 'package:cypress_realworld_for_personal_portfolio_mobile/core/api_client.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/error_text.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';

Future<ApiException> failureOf(FakeHandler handler) async {
  try {
    await fakeClient(handler).moveMoney(bankAccountId: 'b1', amount: 1, type: 'deposit');
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('it did not fail');
}

DioException dio(RequestOptions o, DioExceptionType type) => DioException(requestOptions: o, type: type);

void main() {
  group('what the failure means', () {
    test('not sent: nothing was done', () async {
      for (final type in [DioExceptionType.connectionError, DioExceptionType.connectionTimeout]) {
        final e = await failureOf((o) => throw dio(o, type));
        expect((e.failure, e.isConnection, e.resultUnknown), (ApiFailure.notSent, true, false), reason: '$type');
      }
    });

    test('sent, no answer: the result is unknown', () async {
      for (final type in [
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.unknown,
        DioExceptionType.badCertificate,
      ]) {
        final e = await failureOf((o) => throw dio(o, type));
        expect((e.failure, e.isConnection, e.resultUnknown), (ApiFailure.noAnswer, true, true), reason: '$type');
      }
    });

    test('4xx: refused, nothing was done', () async {
      final e = await failureOf((_) => jsonBody(400, {'error': 'not enough balance'}));
      expect((e.failure, e.resultUnknown, e.serverMessage), (ApiFailure.refused, false, 'not enough balance'));
    });

    test('5xx HTML: the result is unknown and the page is not kept as a message', () async {
      final e = await failureOf(
        (_) => ResponseBody.fromString('<html>secret</html>', 500, headers: {
          Headers.contentTypeHeader: ['text/html'],
        }),
      );
      expect((e.failure, e.resultUnknown, e.serverMessage), (ApiFailure.serverError, true, null));
    });

    test('a 200 that cannot be read: the result is unknown, not a crash', () async {
      for (final body in <Object>[{'transfer': 'text'}, {'other': 1}]) {
        final e = await failureOf((_) => jsonBody(200, body));
        expect((e.failure, e.resultUnknown), (ApiFailure.badResponse, true), reason: '$body');
      }
      final html = await failureOf((_) => ResponseBody.fromString('<html></html>', 200, headers: {
            Headers.contentTypeHeader: ['text/html'],
          }));
      expect(html.resultUnknown, isTrue);
    });

    test('422 names the field', () async {
      final e = await failureOf((_) => jsonBody(422, {
            'errors': [
              {'msg': 'Invalid value', 'param': 'amount', 'location': 'body'},
            ],
          }));
      expect(e.fieldErrors.single.field, 'amount');
      expect(serverRefusalText(e, base: '입금하지 못했습니다'), '금액이 올바르지 않습니다');
    });
  });

  group('the sentence', () {
    String text(int status, {String? server, List<FieldError> fields = const []}) => serverRefusalText(
          ApiException('m', statusCode: status, serverMessage: server, fieldErrors: fields),
          base: '하지 못했습니다',
        );

    test('a reason of the server that is not in the table is in brackets (like the web)', () {
      expect(text(400, server: 'something new'), '하지 못했습니다 (something new)');
      expect(text(400), '하지 못했습니다.');
      expect(text(422, server: 'Invalid value', fields: [(field: 'odd', message: 'Invalid value')]), '하지 못했습니다.');
    });

    test('a failure of the server is never shown', () {
      expect(text(500, server: 'Error: secret stack'), resultUnknownText);
    });

    test('the new refusals of the server', () {
      expect(text(400, server: 'a user can have at most 60 bank accounts'), '은행 계좌는 최대 60개까지 만들 수 있습니다');
      expect(text(409, server: 'you already like this transaction'), '이미 좋아요를 눌렀습니다');
      expect(text(404, server: 'transaction not found'), '거래를 찾을 수 없거나 볼 수 없습니다');
      expect(text(400, server: 'an account with a balance cannot be deleted'), '잔액이 있는 계좌는 삭제할 수 없습니다');
    });

    test('429: too many requests', () {
      expect(text(429), tooManyRequestsText);
      expect(text(429, server: 'slow down'), tooManyRequestsText); // never the English reason
    });

    test('403 is a wrong password only when the server says so', () {
      ApiException e(String m) => ApiException(m, statusCode: 403, serverMessage: m);
      expect(isWrongPassword(e('the password is not correct')), isTrue);
      expect(isWrongPassword(e("this is not my bank account")), isFalse);
      expect(serverRefusalText(e('this is not my bank account'), base: 'x'), '선택한 계좌를 사용할 수 없습니다');
      expect(serverRefusalText(e("this is not the receiver's bank account"), base: 'x'), '선택한 계좌를 사용할 수 없습니다');
    });
  });

  group('the session ends (401)', () {
    test('a protected request reports it; sign-in does not', () async {
      var ended = 0;
      final client = fakeClient((_) => jsonBody(401, {'error': 'Unauthorized'}))..onSessionExpired = () => ended++;
      await expectLater(client.login(username: 'a', password: 'b', remember: false), throwsA(isA<ApiException>()));
      expect(ended, 0);
      await expectLater(client.getBankAccounts(), throwsA(isA<ApiException>()));
      expect(ended, 1);
    });

    test('a late 401 of an earlier session does not end the new one', () async {
      var ended = 0;
      late ApiClient client;
      client = fakeClient((_) {
        client.sessionNumber++; // someone signed in while the answer was on its way
        return jsonBody(401, {'error': 'Unauthorized'});
      })
        ..onSessionExpired = () => ended++;
      await expectLater(client.getBankAccounts(), throwsA(isA<ApiException>()));
      expect(ended, 0);
    });
  });
}
