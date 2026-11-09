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
