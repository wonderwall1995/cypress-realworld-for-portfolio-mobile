import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

/// An error from the API or from the connection to it.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isConnection = false});

  factory ApiException.fromDio(DioException e) {
    final isConnection = e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    final data = e.response?.data;
    final serverMessage = data is Map ? data['error'] as String? : null;
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
        data: {'username': username, 'password': password, 'remember': remember},
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
  }) async {
    try {
      await dio.post<Object>(
        '/users',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'username': username,
          'password': password,
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
    required String routingNumber,
    required String accountNumber,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/bankAccounts',
        data: {
          'bankName': bankName,
          'routingNumber': routingNumber,
          'accountNumber': accountNumber,
        },
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
  /// `/transactions/contacts`, or `/transactions` (the user's own).
  Future<({List<Map<String, dynamic>> results, bool hasNextPages})> getTransactions(
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
      final results = (data['results'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      final pageData = data['pageData'] as Map<String, dynamic>?;
      return (results: results, hasNextPages: pageData?['hasNextPages'] == true);
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
          : await dio.get<Map<String, dynamic>>('/users/search', queryParameters: {'q': trimmed});
      final results = response.data?['results'] as List<dynamic>? ?? const [];
      return results.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Creates a payment or a request. [amount] is in whole dollars (the server
  /// multiplies by 100). [transactionType] is `payment` or `request`.
  Future<Map<String, dynamic>> createTransaction({
    required String transactionType,
    required String receiverId,
    required String description,
    required int amount,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/transactions',
        data: {
          'transactionType': transactionType,
          'receiverId': receiverId,
          'description': description,
          'amount': amount,
        },
      );
      return response.data!['transaction'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Accepts or rejects a request. [requestStatus] is `accepted` or `rejected`.
  /// The server answers 409 when the request was already resolved.
  Future<void> updateRequestStatus(String transactionId, String requestStatus) async {
    try {
      await dio.patch<Object>(
        '/transactions/$transactionId',
        data: {'requestStatus': requestStatus},
      );
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
      await dio.post<Object>('/comments/$transactionId', data: {'content': content});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// The signed-in user's unread notifications (the server sends only unread ones).
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
      await dio.patch<Object>('/notifications/$notificationId', data: {'isRead': true});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// The signed-in user's bank transfers (deposits and withdrawals), including
  /// the withdrawals the server makes by itself to cover a payment.
  Future<List<Map<String, dynamic>>> getBankTransfers() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/bankTransfers');
      final transfers = response.data?['transfers'] as List<dynamic>? ?? const [];
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
  /// [defaultPrivacyLevel] is `public`, `contacts` or `private`.
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
