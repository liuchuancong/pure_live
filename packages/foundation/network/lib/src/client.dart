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
    _log?.debug(
      'request completed',
      fields: <String, Object?>{
        'method': method,
        'playUrl': url,
        'status': status,
        'elapsedMs': _clock().difference(started).inMilliseconds,
      },
    );
    return response;
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
