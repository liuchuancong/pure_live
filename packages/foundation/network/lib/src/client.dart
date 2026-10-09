// Module: lib/src/client.dart
// Purpose: A Dio-backed HTTP client with timeouts, bounded retries, size ceilings and honest failure types.
// Author: liuchuancong
// Created: 2026-10-08
//
// Why a wrapper: every site adapter needs the same three things (a timeout that actually fires, a retry
// that does not hammer a 429, and a failure it can switch on). Leaving each adapter to rediscover that is
// how v1 ended up with thirty private copies of retry logic.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pure_live_logging/pure_live_logging.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'failure.dart';

/// How a client behaves. Defaults are the values the site adapters agreed on.
final class NetworkSettings {
  const NetworkSettings({
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.sendTimeout = const Duration(seconds: 15),
    this.attempts = 3,
    this.retryDelay = const Duration(milliseconds: 300),
    this.maxResponseBytes = 32 * 1024 * 1024,
    this.userAgent,
    this.defaultHeaders = const <String, String>{},
    this.followRedirects = true,
    this.maxRedirects = 5,
  });

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Total attempts including the first.
  final int attempts;
  final Duration retryDelay;

  /// A body larger than this aborts the request instead of exhausting memory.
  final int maxResponseBytes;
  final String? userAgent;
  final Map<String, String> defaultHeaders;
  final bool followRedirects;
  final int maxRedirects;
}

/// Performs requests and reports failures as [NetworkFailure].
final class NetworkClient {
  NetworkClient({
    NetworkSettings settings = const NetworkSettings(),
    BaseOptions? options,
    HttpClientAdapter? adapter,
    Logger? logger,
    Clock? clock,
  }) : _settings = settings,
       _log = logger,
       _clock = clock ?? systemClock {
    _dio = Dio(
      options ??
          BaseOptions(
            connectTimeout: settings.connectTimeout,
            receiveTimeout: settings.receiveTimeout,
            sendTimeout: settings.sendTimeout,
            headers: <String, String>{
              if (settings.userAgent != null) 'user-agent': settings.userAgent!,
              ...settings.defaultHeaders,
            },
            followRedirects: settings.followRedirects,
            maxRedirects: settings.maxRedirects,
            // Status handling is ours: Dio throwing on 4xx would hide the classification.
            validateStatus: _alwaysValid,
          ),
    );
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
    }
  }

  static bool _alwaysValid(int? status) => true;

  final NetworkSettings _settings;
  final Logger? _log;
  final Clock _clock;
  late final Dio _dio;

  /// Closes the underlying transport.
  void close({bool force = false}) => _dio.close(force: force);

  /// GET returning the raw response.
  Future<Response<String>> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _send(url, method: 'GET', headers: headers, queryParameters: queryParameters, cancelToken: cancelToken);
  }

  /// GET that decodes a JSON object, failing with [NetworkFailureKind.unknown] on a malformed body.
  Future<Map<String, Object?>> getJson(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final response = await get(
      url,
      headers: <String, String>{'accept': 'application/json', ...?headers},
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    return decodeJsonObject(response.data ?? '', url: url);
  }

  /// POST with a body; Dio encodes maps as JSON and leaves a String body untouched.
  Future<Response<String>> post(
    String url, {
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _send(
      url,
      method: 'POST',
      body: body,
      headers: headers,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
  }

  Future<Response<String>> _send(
    String url, {
    required String method,
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return retryAsync<Response<String>>(
      () => _once(
        url,
        method: method,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
      attempts: _settings.attempts,
      delay: _settings.retryDelay,
      shouldRetry: (error) => error is NetworkFailure && error.retryable,
      onRetry: (error, wait) => _log?.warning(
        'retrying request',
        fields: <String, Object?>{'method': method, 'playUrl': url, 'waitMs': wait.inMilliseconds},
      ),
    );
  }

  Future<Response<String>> _once(
    String url, {
    required String method,
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final started = _clock();
    try {
      final response = await _dio.request<String>(
        url,
        data: body,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(method: method, headers: headers, responseType: ResponseType.plain),
      );
      return _check(response, method: method, url: url, started: started);
    } on DioException catch (error) {
      throw _classify(error, method: method, url: url);
    }
  }

  Response<String> _check(
    Response<String> response, {
    required String method,
    required String url,
    required DateTime started,
  }) {
    _validate(response, method: method, url: url);
    _log?.debug(
      'request completed',
      fields: <String, Object?>{
        'method': method,
        'playUrl': url,
        'status': response.statusCode,
        'elapsedMs': _clock().difference(started).inMilliseconds,
      },
    );
    return response;
  }

  /// Rejects an oversized or failed response before a caller sees the body.
  ///
  /// The size test reads `content-length` rather than the decoded bytes on purpose: the point is to refuse
  /// the download, and waiting for 200 MB to arrive to measure it defeats that.
  void _validate(Response<dynamic> response, {required String method, required String url}) {
    final lengthHeader = response.headers.value('content-length');
    final length = int.tryParse(lengthHeader ?? '');
    if (length != null && length > _settings.maxResponseBytes) {
      throw NetworkFailure(
        kind: NetworkFailureKind.responseTooLarge,
        method: method,
        url: url,
        statusCode: response.statusCode,
        cause: 'content-length $length exceeds ${_settings.maxResponseBytes}',
      );
    }
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw NetworkFailure(
        kind: _kindForStatus(status),
        method: method,
        url: url,
        statusCode: status,
        retryable: _isRetryableStatus(status),
      );
    }
  }

  /// Performs a request and keeps the body as bytes.
  ///
  /// This exists for bodies that must not be decoded as text: a media segment, a protobuf spider payload, or
  /// a repository file whose encoding the site never declares. The url in the result is the one that actually
  /// answered, which is the only way a caller can notice a redirect that left the host it was granted.
  Future<RawResponse> sendBytes(
    String url, {
    String method = 'GET',
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
    CancelToken? cancelToken,
  }) {
    return retryAsync<RawResponse>(
      () => _onceBytes(
        url,
        method: method,
        body: body,
        headers: headers,
        queryParameters: queryParameters,
        timeout: timeout,
        cancelToken: cancelToken,
      ),
      attempts: _settings.attempts,
      delay: _settings.retryDelay,
      shouldRetry: (error) => error is NetworkFailure && error.retryable,
      onRetry: (error, wait) => _log?.warning(
        'retrying request',
        fields: <String, Object?>{'method': method, 'playUrl': url, 'waitMs': wait.inMilliseconds},
      ),
    );
  }

  Future<RawResponse> _onceBytes(
    String url, {
    required String method,
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request<List<int>>(
        url,
        data: body,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(method: method, headers: headers, responseType: ResponseType.bytes, receiveTimeout: timeout),
      );
      _validate(response, method: method, url: url);
      final actual = response.realUri;
      final bytes = response.data ?? const <int>[];
      if (bytes.length > _settings.maxResponseBytes) {
        throw NetworkFailure(
          kind: NetworkFailureKind.responseTooLarge,
          method: method,
          url: url,
          statusCode: response.statusCode,
          cause: 'body of ${bytes.length} bytes exceeds ${_settings.maxResponseBytes}',
        );
      }
      return RawResponse(
        statusCode: response.statusCode ?? 0,
        uri: actual,
        headers: response.headers.map.map((name, values) => MapEntry<String, String>(name, values.join(', '))),
        bytes: bytes,
      );
    } on DioException catch (error) {
      throw _classify(error, method: method, url: url);
    }
  }

  NetworkFailure _classify(DioException error, {required String method, required String url}) {
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => NetworkFailureKind.timeout,
      DioExceptionType.cancel => NetworkFailureKind.cancelled,
      DioExceptionType.badCertificate || DioExceptionType.connectionError => NetworkFailureKind.unreachable,
      _ => error.error is NetworkFailure ? (error.error as NetworkFailure).kind : NetworkFailureKind.unreachable,
    };
    return NetworkFailure(
      kind: kind,
      method: method,
      url: url,
      statusCode: error.response?.statusCode,
      cause: error.message ?? error.error,
      // A timeout may be transient; an explicit cancellation never is.
      retryable: kind == NetworkFailureKind.timeout || kind == NetworkFailureKind.unreachable,
    );
  }

  static NetworkFailureKind _kindForStatus(int status) {
    if (status == 401 || status == 403) {
      return NetworkFailureKind.forbidden;
    }
    if (status == 429) {
      return NetworkFailureKind.rateLimited;
    }
    return NetworkFailureKind.httpStatus;
  }

  static bool _isRetryableStatus(int status) => status == 429 || status >= 500;
}

/// Decodes a JSON object body, reporting the url that failed rather than throwing a bare FormatException.
Map<String, Object?> decodeJsonObject(String body, {required String url}) {
  if (body.trim().isEmpty) {
    throw NetworkFailure(kind: NetworkFailureKind.unknown, method: 'GET', url: url, cause: 'empty body');
  }
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw NetworkFailure(
      kind: NetworkFailureKind.unknown,
      method: 'GET',
      url: url,
      cause: 'expected a JSON object, got ${decoded.runtimeType}',
    );
  }
  return Map<String, Object?>.from(decoded);
}

/// A response kept as bytes, with the identity of the url that answered.
///
/// [uri] is the *effective* location: a request granted for one host that was redirected to another is only
/// detectable from here, because the caller's own url is the one it already knew.
final class RawResponse {
  const RawResponse({required this.statusCode, required this.uri, required this.headers, required this.bytes});

  final int statusCode;
  final Uri uri;

  /// Repeated headers are joined with `, `, which is how HTTP spells them on the wire.
  final Map<String, String> headers;
  final List<int> bytes;

  int get size => bytes.length;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  @override
  String toString() => 'RawResponse($statusCode ${uri.host}, $size bytes)';
}
