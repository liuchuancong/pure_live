import 'package:dio/dio.dart';
import 'package:pure_live/core/logging/app_log.dart';

class CustomLogInterceptor extends Interceptor {
  CustomLogInterceptor({void Function(String, StackTrace)? errorLogger}) : _errorLogger = errorLogger ?? Log.e;

  final void Function(String, StackTrace) _errorLogger;
  static const String _keyTimestamp = "ts";

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_keyTimestamp] = DateTime.now().millisecondsSinceEpoch;
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Diagnostics are never a second failure source. In particular, a request
    // rejected before onRequest has no timestamp, and the file logger may be
    // unavailable during startup/shutdown. Preserve Dio's original error.
    try {
      _errorLogger(formatHttpFailureDiagnostic(err), err.stackTrace);
    } catch (_) {
      // Do not recursively log a logger failure or block the error pipeline.
    }
    super.onError(err, handler);
  }
}

/// Structure-only diagnostics: signed CDN paths, URL queries, bodies,
/// cookies/headers and nested exception strings may all contain credentials.
/// A blacklist of a few token names misses new platform-specific fields.
String formatHttpFailureDiagnostic(DioException error) {
  final request = error.requestOptions;
  final now = DateTime.now().millisecondsSinceEpoch;
  final timestamp = request.extra['ts'];
  final elapsed = timestamp is int && timestamp >= 0 && timestamp <= now ? '${now - timestamp}ms' : 'unknown';
  final uri = request.uri;
  final origin = uri.hasAuthority
      ? Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null).toString()
      : '(relative)';
  return '''[HTTP Error] [${error.type.name}] [Time:$elapsed]
Underlying Type: ${error.error?.runtimeType ?? 'none'}
Request Method: ${request.method}
Response Code: ${error.response?.statusCode ?? 'none'}
Request Origin: $origin
Request Path Segments: ${uri.pathSegments.length}
Request Query Keys: ${_fieldNames(uri.queryParameters)}
Request Data Shape: ${_shape(request.data)}
Request Header Keys: ${_fieldNames(request.headers)}
Response Header Keys: ${_fieldNames(error.response?.headers.map ?? const {})}
Response Data Shape: ${_shape(error.response?.data)}''';
}

String _fieldNames(Map<dynamic, dynamic> data) {
  final names = data.keys
      .take(24)
      .map((key) {
        return key is String && RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,63}$').hasMatch(key) ? key : '(redacted-key)';
      })
      .join(',');
  return '[$names${data.length > 24 ? ',...' : ''}]';
}

String _shape(Object? value) {
  if (value == null) return 'null';
  if (value is Map) return 'object ${_fieldNames(value)}';
  if (value is List) return 'list(${value.length})';
  if (value is String) return 'text(${value.length})';
  if (value is FormData) {
    return 'multipart(fields=${value.fields.length},files=${value.files.length})';
  }
  return value.runtimeType.toString();
}
