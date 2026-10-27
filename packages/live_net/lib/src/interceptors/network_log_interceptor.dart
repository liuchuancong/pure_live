import 'package:dio/dio.dart' as dio;
import 'package:live_log/live_log.dart' show LiveLog, LogLevel;

/// Dio interceptor feeding the request pipeline into [LiveLog].
///
/// Every record carries a request id, method, redacted URL and, depending
/// on the phase, duration, status code or error category. Bodies,
/// headers and credentials are never logged here; URL signatures and
/// cookies are redacted again at the `LiveLog` emit boundary (defence in
/// depth — this interceptor only ever builds lines that are safe to keep).
final class NetworkLogInterceptor extends dio.Interceptor {
  /// Logs through [log] at [level] for successful phases and for a caller's
  /// own cancellation; other failures log at warning.
  new(this.log, {this.level = LogLevel.debug});

  /// The tree view network traffic is reported under.
  final LiveLog log;

  /// Level used for request/response lines; errors are always warnings.
  final LogLevel level;

  static const String _idKey = 'live_net.requestId';
  static const String _startedKey = 'live_net.startedAt';

  int _nextId = 0;

  @override
  void onRequest(dio.RequestOptions options, dio.RequestInterceptorHandler handler) {
    final id = _nextId++;
    options.extra[_idKey] = id;
    options.extra[_startedKey] = DateTime.now();
    log.log(level, '→ [#$id] ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(dio.Response<dynamic> response, dio.ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    final started = options.extra[_startedKey] as DateTime?;
    final elapsed = started == null ? null : DateTime.now().difference(started).inMilliseconds;
    log.log(
      level,
      '← [#${options.extra[_idKey]}] ${response.statusCode}'
      '${elapsed == null ? '' : ' ${elapsed}ms'} ${options.method} ${options.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(dio.DioException err, dio.ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    // A caller's own cancellation stops work on purpose (a download the
    // viewer cancelled); it is not a fault, so it stays out of the error
    // report and carries no stack.
    final cancelled = err.type == dio.DioExceptionType.cancel;
    log.log(
      cancelled ? level : LogLevel.warning,
      '✕ [#${options.extra[_idKey]}] ${options.method} '
      '${_category(err)} ${options.uri}',
      error: cancelled ? null : err,
    );
    handler.next(err);
  }

  /// Stable short category of a transport error, e.g. `connectionTimeout`.
  static String _category(dio.DioException err) => err.type.name;
}
