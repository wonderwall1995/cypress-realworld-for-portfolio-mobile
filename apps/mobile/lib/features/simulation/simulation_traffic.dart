import 'package:dio/dio.dart';

/// Tracks requests launched by real UI callbacks too. A stop waits for these
/// before signing out; otherwise a late /login could restore the old cookie.
class SimulationTraffic extends Interceptor {
  final _pending = <RequestOptions>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.responseType != ResponseType.stream) _pending.add(options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _pending.remove(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _pending.remove(err.requestOptions);
    handler.next(err);
  }

  Future<void> drain() async {
    // A response can cause another read in a UI callback. Require a quiet window
    // rather than returning in between a mutation and its follow-up refresh.
    var quiet = 0;
    while (quiet < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      quiet = _pending.isEmpty ? quiet + 1 : 0;
    }
  }
}
