import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

/// An error from the API or from the connection to it.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isConnection = false,
  });

  factory ApiException.fromDio(DioException e) {
    final isConnection =
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    final data = e.response?.data;
    // REST sends {"error": "..."}; GraphQL sends {"errors": [{"message": "..."}]}.
    String? serverMessage;
    if (data is Map) {
      final error = data['error'];
      final errors = data['errors'];
      if (error is String) {
        serverMessage = error;
      } else if (errors is List && errors.isNotEmpty && errors.first is Map) {
        final m = (errors.first as Map)['message'];
        if (m is String) serverMessage = m;
      }
    }
    return ApiException(
      serverMessage ?? e.message ?? 'Request failed',
      statusCode: e.response?.statusCode,
      isConnection: isConnection,
    );
  }

  final String message;
  final int? statusCode;

  /// True when the server could not be reached at all.
  final bool isConnection;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Talks to the web server API. Keeps the session cookie in [cookieJar].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.cookieJar,
    HttpClientAdapter? adapter,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 15),
           headers: {'Accept': 'application/json'},
         ),
       ) {
    dio.interceptors.add(CookieManager(cookieJar));
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }
  }

  final Dio dio;
  final CookieJar cookieJar;

  /// Returns the signed-in user, or null when there is no valid session.
  Future<Map<String, dynamic>?> checkAuth() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/checkAuth',
        options: Options(validateStatus: (s) => s == 200 || s == 401),
      );
      if (response.statusCode == 401) {
        return null;
      }
      return response.data?['user'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Signs in. Returns the user. With [remember], the server keeps the
  /// session for 30 days (a cookie with an expiry); without it, until the app
  /// closes.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required bool remember,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/login',
        data: {
          'username': username,
          'password': password,
          'remember': remember,
        },
      );
      return response.data!['user'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Creates an account. Does not sign in (same as the web).
  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String username,
    required String password,
    required String phoneNumber,
  }) async {
    try {
      await dio.post<Object>(
        '/users',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'username': username,
          'password': password,
          'phoneNumber': phoneNumber,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// The signed-in user's bank accounts (deleted ones are not returned).
  Future<List<Map<String, dynamic>>> getBankAccounts() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/bankAccounts');
      final results = response.data?['results'] as List<dynamic>? ?? const [];
      return results.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createBankAccount({
    required String bankName,
    required String accountNumber,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/bankAccounts',
        data: {'bankName': bankName, 'accountNumber': accountNumber},
      );
      return response.data!['account'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteBankAccount(String id) async {
    try {
      await dio.delete<Object>('/bankAccounts/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// One page of a transaction list. [feedPath] is `/transactions/public`,
  /// or `/transactions` (the user's own).
  Future<({List<Map<String, dynamic>> results, bool hasNextPages})>
  getTransactions(
    String feedPath, {
    required int page,
    int limit = 10,
    Map<String, String> filters = const {},
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        feedPath,
        queryParameters: {'page': page, 'limit': limit, ...filters},
      );
      final data = response.data ?? const <String, dynamic>{};
      final results = (data['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final pageData = data['pageData'] as Map<String, dynamic>?;
      return (
        results: results,
        hasNextPages: pageData?['hasNextPages'] == true,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getTransaction(String id) async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/transactions/$id');
      return response.data!['transaction'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Other users, for choosing who to pay or to ask. [query] filters by name
  /// or user name. The signed-in user is not in the list.
  Future<List<Map<String, dynamic>>> getUsers({String? query}) async {
    try {
      final trimmed = query?.trim() ?? '';
      final response = trimmed.isEmpty
          ? await dio.get<Map<String, dynamic>>('/users')
          : await dio.get<Map<String, dynamic>>(
              '/users/search',
              queryParameters: {'q': trimmed},
            );
      final results = response.data?['results'] as List<dynamic>? ?? const [];
      return results.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Creates a payment (이체). [amount] is in whole dollars (the server
  /// multiplies by 100). [transactionType] is `payment` (requests are gone).
  /// It needs [myAccountId] (the account the money leaves), [otherAccountId]
  /// and the user's [password]. The server answers 403 for a wrong password and
  /// 400 when the account does not hold enough.
  Future<Map<String, dynamic>> createTransaction({
    required String transactionType,
    required String receiverId,
    required String description,
    required int amount,
    required String myAccountId,
    String? otherAccountId,
    String? password,
    String? privacyLevel,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/transactions',
        data: {
          'transactionType': transactionType,
          'receiverId': receiverId,
          'description': description,
          'amount': amount,
          'myAccountId': myAccountId,
          if (otherAccountId != null) 'otherAccountId': otherAccountId,
          if (password != null) 'password': password,
          if (privacyLevel != null) 'privacyLevel': privacyLevel,
        },
      );
      return response.data!['transaction'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Checks the user's own password (for the last step of a transfer). Returns
  /// normally for a right password (204); throws [ApiException] with status 403
  /// for a wrong one.
  Future<void> verifyPassword(String password) async {
    try {
      await dio.post<Object>(
        '/users/verifyPassword',
        data: {'password': password},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// The bank accounts of another user, to choose where a transfer goes. Only the
  /// id, the bank name and the last 4 digits of the number are sent.
  Future<List<Map<String, dynamic>>> getAccountsOfUser(String userId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/bankAccounts/of-user/$userId',
      );
      final results = response.data?['results'] as List<dynamic>? ?? const [];
      return results.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Likes a transaction. The server does not stop a second like from the same
  /// user, so the app must not send it twice.
  Future<void> likeTransaction(String transactionId) async {
    try {
      await dio.post<Object>('/likes/$transactionId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> postComment(String transactionId, String content) async {
    try {
      await dio.post<Object>(
        '/comments/$transactionId',
        data: {'content': content},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// The signed-in user's unread notifications (the server sends only unread ones).
  /// Opens the live stream of new notifications (`GET /notifications/stream`,
  /// Server-Sent Events). Each item is the JSON of one notification, the same
  /// shape as an item of [getNotifications]. The stream ends when the server or
  /// the connection closes it, and fails with [ApiException] when it cannot be
  /// opened (401 when not signed in). [onOpen] is called once the server has
  /// answered 200. Nothing is replayed: after (re)connecting,
  /// call [getNotifications] once to catch up.
  Stream<Map<String, dynamic>> openNotificationStream({
    CancelToken? cancelToken,
    void Function()? onOpen,
  }) async* {
    final Response<ResponseBody> response;
    try {
      response = await dio.get<ResponseBody>(
        '/notifications/stream',
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          // The server pings every 25 seconds; the normal 15 seconds of silence
          // would cut the stream.
          receiveTimeout: const Duration(seconds: 60),
          validateStatus: (status) => status == 200,
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(await _readStreamError(e));
    }
    onOpen?.call();
    try {
      yield* parseServerSentEvents(response.data!.stream.cast<List<int>>())
          .where((event) => event.name == 'notification')
          .map((event) => jsonDecode(event.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// The error body of a stream request is a stream too; read it so that the
  /// message of the server is not lost.
  Future<DioException> _readStreamError(DioException e) async {
    final body = e.response?.data;
    if (body is! ResponseBody) return e;
    try {
      final text = await utf8.decoder
          .bind(body.stream.cast<List<int>>())
          .join();
      return DioException(
        requestOptions: e.requestOptions,
        response: Response(
          requestOptions: e.requestOptions,
          statusCode: e.response?.statusCode,
          data: jsonDecode(text),
        ),
        type: e.type,
      );
    } catch (_) {
      return e;
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/notifications');
      final results = response.data?['results'] as List<dynamic>? ?? const [];
      return results.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await dio.patch<Object>(
        '/notifications/$notificationId',
        data: {'isRead': true},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// The signed-in user's bank transfers (deposits and withdrawals), including
  /// the withdrawals the server makes by itself to cover a payment.
  Future<List<Map<String, dynamic>>> getBankTransfers() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/bankTransfers');
      final transfers =
          response.data?['transfers'] as List<dynamic>? ?? const [];
      return transfers.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// A virtual deposit or withdrawal, done at once. [amount] is in whole dollars.
  /// [type] is `deposit` or `withdrawal`. The server answers 400 with
  /// `{"error": "..."}` when it refuses, and 422 for a badly formed request.
  Future<Map<String, dynamic>> moveMoney({
    required String bankAccountId,
    required int amount,
    required String type,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/bankTransfers',
        data: {'bankAccountId': bankAccountId, 'amount': amount, 'type': type},
      );
      return response.data!['transfer'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Saves the user's own profile. The server answers 204. [userId] must be the
  /// signed-in user's id: the server would also accept another user's id, but
  /// the app never sends one.
  /// [defaultPrivacyLevel] is `public` or `private` (the server refuses `contacts`).
  Future<void> updateUser(
    String userId, {
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String defaultPrivacyLevel,
  }) async {
    try {
      await dio.patch<Object>(
        '/users/$userId',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phoneNumber': phoneNumber,
          'defaultPrivacyLevel': defaultPrivacyLevel,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Signs out. The cookie on this device is removed even if the server
  /// cannot be reached.
  Future<void> logout() async {
    try {
      // The server answers with a redirect to "/". Do not follow it.
      await dio.post<Object>(
        '/logout',
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } finally {
      await cookieJar.deleteAll();
    }
  }
}

/// Cookie storage that follows the web rule for "Remember me".
///
/// A cookie with an expiry date (Remember me checked, 30 days) is saved to
/// disk. A session cookie (no expiry) stays in memory and is lost on restart.
Future<CookieJar> createPersistentCookieJar() async {
  final dir = await getApplicationSupportDirectory();
  return PersistCookieJar(
    persistSession: false,
    storage: FileStorage('${dir.path}${Platform.pathSeparator}cookies'),
  );
}

/// One event of a Server-Sent Events stream.
class ServerSentEvent {
  const ServerSentEvent(this.name, this.data);

  final String name;
  final String data;
}

/// Reads Server-Sent Events from raw bytes. A blank line ends an event. Lines that
/// start with ":" (the server's ping) and `retry:` lines are skipped. An event
/// with no `event:` line is called `message`.
Stream<ServerSentEvent> parseServerSentEvents(Stream<List<int>> bytes) async* {
  var name = 'message';
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield ServerSentEvent(name, data.join(String.fromCharCode(10)));
      }
      name = 'message';
      data.clear();
    } else if (line.startsWith(':')) {
      continue;
    } else {
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') {
        name = value;
      } else if (field == 'data') {
        data.add(value);
      }
    }
  }
}
