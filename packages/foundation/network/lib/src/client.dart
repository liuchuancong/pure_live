// Module: lib/src/client.dart
// Purpose: A Dio-backed HTTP client with timeouts, retries that obey the server, byte ceilings, concurrency
// bounds, per-host spacing, every verb a spider meets and a ranged download that reports progress.
// Author: liuchuancong
// Created: 2026-10-08
//
// Why a wrapper: every site adapter needs the same six things - a timeout that actually fires, a retry that
// does not hammer a 429, a size ceiling, a concurrency bound, an honest failure type and a body encoding that
// matches the endpoint. Leaving each adapter to rediscover that is how v1 ended up with thirty private copies
// of retry logic, none of which read Retry-After.
//
// Two surfaces sit on one send path. [get], [post], [getJson] and [sendBytes] return Dio's own response types
// because the providers were written against them; [getText], [requestJson], [put], [patch], [delete], [head]
// and [download] return this package's types, which carry the answering url, the redacted headers and the
// elapsed time. New code should use the second set.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live_logging/pure_live_logging.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'classification.dart';
import 'failure.dart';
import 'headers.dart';
import 'limiter.dart';
import 'request_body.dart';
import 'responses.dart';
import 'settings.dart';
import 'url_reference.dart';

/// Performs requests and reports failures as [NetworkFailure].
final class NetworkClient {
  NetworkClient({
    NetworkSettings settings = const NetworkSettings(),
    BaseOptions? options,
    HttpClientAdapter? adapter,
    Logger? logger,
    Clock? clock,
    ConcurrencyLimiter? limiter,
    HostThrottle? throttle,
  }) : _settings = settings,
       _log = logger,
       _clock = clock ?? systemClock,
       _limiter = limiter ?? _limiterFor(settings),
       _throttle = throttle ?? _throttleFor(settings, clock) {
    _dio = Dio(
      options ??
          BaseOptions(
            connectTimeout: settings.connectTimeout,
            receiveTimeout: settings.receiveTimeout,
            sendTimeout: settings.sendTimeout,
            headers: settings.headersFor(null),
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

  static ConcurrencyLimiter? _limiterFor(NetworkSettings settings) {
    final max = settings.maxConcurrent;
    return max == null ? null : ConcurrencyLimiter(maxConcurrent: max);
  }

  static HostThrottle? _throttleFor(NetworkSettings settings, Clock? clock) {
    final spacing = settings.hostMinSpacing;
    return spacing == null ? null : HostThrottle(minimumInterval: spacing, clock: clock);
  }

  final NetworkSettings _settings;
  final Logger? _log;
  final Clock _clock;
  final ConcurrencyLimiter? _limiter;
  final HostThrottle? _throttle;
  late final Dio _dio;

  /// The knobs this client was built with.
  NetworkSettings get settings => _settings;

  /// Requests currently running through this client. Zero when no bound was configured.
  int get requestsInFlight => _limiter?.inFlight ?? 0;

  /// Closes the underlying transport and refuses queued work.
  void close({bool force = false}) {
    _limiter?.close();
    _dio.close(force: force);
  }

  /// Adds or replaces a default header on every request.
  void setDefaultHeader(String name, String value) {
    _dio.options.headers[name.toLowerCase()] = value;
  }

  // ---------------------------------------------------------------------------
  // The package-owned surface.
  // ---------------------------------------------------------------------------

  /// GET returning the body as text, with the answering url and redacted headers attached.
  Future<TextResponse> getText(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    final started = _clock();
    final response = await _string(
      url,
      method: 'GET',
      headers: <String, String>{'accept': 'text/plain, */*;q=0.5', ...?headers},
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
      cancelToken: cancelToken,
    );
    return TextResponse(
      statusCode: response.statusCode ?? 0,
      uri: response.realUri,
      requestedUri: Uri.parse(url),
      body: response.data ?? '',
      bag: _bagOf(response),
      elapsed: _clock().difference(started),
    );
  }

  /// GET that decodes a JSON object.
  Future<Map<String, Object?>> requestJson(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    final response = await _string(
      url,
      method: 'GET',
      headers: <String, String>{'accept': 'application/json', ...?headers},
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
      cancelToken: cancelToken,
    );
    return decodeJsonObject(response.data ?? '', url: response.realUri.toString());
  }

  /// GET that decodes a JSON array, for the list-shaped endpoints.
  Future<List<Object?>> requestJsonArray(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final response = await _string(
      url,
      method: 'GET',
      headers: <String, String>{'accept': 'application/json', ...?headers},
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    return decodeJsonList(response.data ?? '', url: response.realUri.toString());
  }

  /// Sends [body] and decodes a JSON object response.
  Future<Map<String, Object?>> submitJson(
    String url,
    RequestBody body, {
    String method = 'POST',
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    final response = await _string(
      url,
      method: method,
      body: body,
      headers: <String, String>{'accept': 'application/json', ...?headers},
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
      cancelToken: cancelToken,
    );
    return decodeJsonObject(response.data ?? '', url: response.realUri.toString());
  }

  /// POSTs an url-encoded form. The encoding is explicit because the default transformer's guess is what
  /// turns a Chinese field into mojibake.
  Future<TextResponse> postForm(
    String url,
    Map<String, Object?> fields, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) {
    return _text(
      url,
      method: 'POST',
      body: RequestBody.form(fields),
      headers: headers,
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
      cancelToken: cancelToken,
    );
  }

  /// POSTs a JSON body.
  Future<TextResponse> postJson(
    String url,
    Object? data, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) {
    return _text(
      url,
      method: 'POST',
      body: RequestBody.json(data),
      headers: headers,
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
      cancelToken: cancelToken,
    );
  }

  /// One request, any verb and body, returning the package's text response.
  Future<TextResponse> _text(
    String url, {
    required String method,
    RequestBody? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    final started = _clock();
    final response = await _string(
      url,
      method: method,
      body: body,
      headers: headers,
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
      cancelToken: cancelToken,
    );
    return TextResponse(
      statusCode: response.statusCode ?? 0,
      uri: response.realUri,
      requestedUri: Uri.parse(url),
      body: response.data ?? '',
      bag: _bagOf(response),
      elapsed: _clock().difference(started),
    );
  }

  /// PUT.
  Future<TextResponse> put(
    String url, {
    RequestBody? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => _text(
    url,
    method: 'PUT',
    body: body,
    headers: headers,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
  );

  /// PATCH.
  Future<TextResponse> patch(
    String url, {
    RequestBody? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => _text(
    url,
    method: 'PATCH',
    body: body,
    headers: headers,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
  );

  /// DELETE, with the optional body some sites use for a batch of ids.
  Future<TextResponse> delete(
    String url, {
    RequestBody? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) => _text(
    url,
    method: 'DELETE',
    body: body,
    headers: headers,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
  );

  /// HEAD: the size and type a url claims, without paying for the body.
  Future<HeadResponse> head(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final started = _clock();
    final response = await _string(
      url,
      method: 'HEAD',
      headers: headers,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    return HeadResponse(
      statusCode: response.statusCode ?? 0,
      uri: response.realUri,
      requestedUri: Uri.parse(url),
      bag: _bagOf(response),
      elapsed: _clock().difference(started),
    );
  }

  /// GET keeping the body as bytes.
  Future<RawResponse> requestBytes(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    final started = _clock();
    final response = await _bytes(
      url,
      method: 'GET',
      headers: headers,
      queryParameters: queryParameters,
      receiveTimeout: receiveTimeout,
      cancelToken: cancelToken,
    );
    return _rawOf(response, url: url, started: started);
  }

  /// Reads a body to the end under [NetworkSettings.maxResponseBytes], reporting progress.
  ///
  /// The ceiling is enforced *while reading*, not only against `content-length`: a chunked response declares
  /// nothing, and a lying CDN that says 1 KB and sends 1 GB is the case the read-time check exists for.
  /// [startBytes] sends a `Range` header, which is how an interrupted segment or an update package resumes
  /// instead of restarting on a metered connection.
  Future<DownloadResult> download(
    String url, {
    int? startBytes,
    int? endBytes,
    int? maxBytes,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    ProgressReporter? onProgress,
    CancelToken? cancelToken,
  }) async {
    final ceiling = maxBytes ?? _settings.maxResponseBytes;
    final started = _clock();
    final token = CancelToken();
    _linkCancellation(cancelToken, token);
    final response = await _attempt<Response<ResponseBody>>(
      url,
      'GET',
      () => _onceStream(
        url,
        headers: headers,
        queryParameters: queryParameters,
        startBytes: startBytes,
        endBytes: endBytes,
        receiveTimeout: receiveTimeout,
        cancelToken: token,
      ),
    );
    final body = response.data;
    final declared = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '');
    if (declared != null && declared > ceiling) {
      throw NetworkFailure(
        kind: NetworkFailureKind.responseTooLarge,
        method: 'GET',
        url: url,
        statusCode: response.statusCode,
        cause: 'content-length $declared exceeds $ceiling',
      );
    }
    final collected = <int>[];
    if (body != null) {
      await for (final chunk in body.stream) {
        collected.addAll(chunk);
        if (collected.length > ceiling) {
          // Stop the transfer rather than finish it and then throw: the point of the ceiling is the memory the
          // rest of the body would have taken.
          token.cancel('response exceeded $ceiling bytes');
          throw NetworkFailure(
            kind: NetworkFailureKind.responseTooLarge,
            method: 'GET',
            url: url,
            statusCode: response.statusCode,
            cause: 'body passed $ceiling bytes while reading',
          );
        }
        onProgress?.call(collected.length, declared);
      }
    }
    return DownloadResult(
      statusCode: response.statusCode ?? 0,
      uri: response.realUri,
      requestedUri: Uri.parse(url),
      bytes: Uint8List.fromList(collected),
      bag: HttpHeaderBag(body?.headers ?? _flatPairs(response)),
      expectedTotal: declared,
      elapsed: _clock().difference(started),
    );
  }

  // ---------------------------------------------------------------------------
  // The Dio-shaped surface the providers were written against.
  // ---------------------------------------------------------------------------

  /// GET returning the raw Dio response.
  Future<Response<String>> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _string(url, method: 'GET', headers: headers, queryParameters: queryParameters, cancelToken: cancelToken);
  }

  /// GET that decodes a JSON object, failing with [NetworkFailureKind.parse] on a malformed body.
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

  /// POST with a body; a Map is sent as JSON, a String is sent untouched, and anything else should have come
  /// in as a [RequestBody].
  Future<Response<String>> post(
    String url, {
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _string(
      url,
      method: 'POST',
      rawBody: body,
      headers: headers,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
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
  }) async {
    final started = _clock();
    final response = await _bytes(
      url,
      method: method,
      rawBody: body,
      headers: headers,
      queryParameters: queryParameters,
      receiveTimeout: timeout,
      cancelToken: cancelToken,
    );
    return _rawOf(response, url: url, started: started);
  }

  // ---------------------------------------------------------------------------
  // Internals: one send path behind both surfaces.
  // ---------------------------------------------------------------------------

  Future<Response<String>> _string(
    String url, {
    required String method,
    RequestBody? body,
    Object? rawBody,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) {
    return _attempt<Response<String>>(url, method, () async {
      final prepared = _prepare(url, method, body, rawBody, headers);
      final response = await _once<String>(
        url,
        method: method,
        data: prepared.data,
        headers: prepared.headers,
        queryParameters: queryParameters,
        receiveTimeout: receiveTimeout,
        cancelToken: cancelToken,
        responseType: ResponseType.plain,
      );
      _checkString(response, method: method, url: url);
      return response;
    });
  }

  Future<Response<List<int>>> _bytes(
    String url, {
    required String method,
    RequestBody? body,
    Object? rawBody,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) {
    return _attempt<Response<List<int>>>(url, method, () async {
      final prepared = _prepare(url, method, body, rawBody, headers);
      return _once<List<int>>(
        url,
        method: method,
        data: prepared.data,
        headers: prepared.headers,
        queryParameters: queryParameters,
        receiveTimeout: receiveTimeout,
        cancelToken: cancelToken,
        responseType: ResponseType.bytes,
      );
    });
  }

  /// Runs [action] inside the concurrency bound and the retry policy.
  ///
  /// One slot covers the whole retry sequence: a request that retries four times is one logical request, and
  /// releasing the slot between attempts would let a fan-out search start four times as many requests as the
  /// bound allows.
  Future<T> _attempt<T>(String url, String method, Future<T> Function() action) {
    final retrying = () => retryAsync<T>(
      action,
      attempts: _settings.retry.attempts,
      delay: _settings.retry.baseDelay,
      backoff: _settings.retry.backoff,
      maxDelay: _settings.retry.maxDelay,
      shouldRetry: (error) => error is NetworkFailure && error.retryable,
      delayFor: _settings.retry.asDelayFor,
      onRetry: (error, wait) => _log?.warning(
        'retrying request',
        fields: <String, Object?>{
          'method': method,
          'playUrl': redact(url),
          'waitMs': wait.inMilliseconds,
          'cause': error is NetworkFailure ? error.code : '$error',
        },
      ),
    );
    final limiter = _limiter;
    return limiter == null ? retrying() : limiter.run(retrying);
  }

  Future<Response<T>> _once<T>(
    String url, {
    required String method,
    Object? data,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
    required ResponseType responseType,
  }) async {
    await _space(url, method, cancelToken);
    try {
      final response = await _dio.request<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(method: method, headers: headers, responseType: responseType, receiveTimeout: receiveTimeout),
      );
      _refuseOriginChange(response, method: method, url: url);
      return response;
    } on DioException catch (error) {
      throw classifyDioException(error, method: method, url: url, maxBytes: _settings.maxResponseBytes);
    }
  }

  Future<Response<ResponseBody>> _onceStream(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    int? startBytes,
    int? endBytes,
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    if (startBytes != null && startBytes < 0) {
      throw ArgumentError.value(startBytes, 'startBytes', 'cannot be negative');
    }
    if (endBytes != null && startBytes != null && endBytes < startBytes) {
      throw ArgumentError.value(endBytes, 'endBytes', 'must not precede startBytes');
    }
    final ranged = <String, String>{
      if (startBytes != null || endBytes != null) 'range': 'bytes=${startBytes ?? 0}-${endBytes ?? ''}',
    };
    await _space(url, 'GET', cancelToken);
    try {
      final response = await _dio.request<ResponseBody>(
        url,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: 'GET',
          headers: <String, String>{...?headers, ...ranged},
          responseType: ResponseType.stream,
          receiveTimeout: receiveTimeout,
        ),
      );
      _refuseOriginChange(response, method: 'GET', url: url);
      return response;
    } on DioException catch (error) {
      throw classifyDioException(error, method: 'GET', url: url, maxBytes: _settings.maxResponseBytes);
    }
  }

  /// Waits for this host's turn, and gives up immediately if the caller already cancelled.
  Future<void> _space(String url, String method, CancelToken? cancelToken) async {
    _requireLive(method, url, cancelToken);
    final throttle = _throttle;
    if (throttle == null) {
      return;
    }
    final host = urlHostOf(url);
    if (host.isEmpty) {
      return;
    }
    await throttle.waitFor(host);
    // A cancellation that arrived during the spacing wait must not turn into a request the caller stopped
    // asking for; Dio only notices a token that is handed to it, and the socket is already ours by then.
    _requireLive(method, url, cancelToken);
  }

  void _requireLive(String method, String url, CancelToken? cancelToken) {
    if (cancelToken != null && cancelToken.isCancelled) {
      throw NetworkFailure(
        kind: NetworkFailureKind.cancelled,
        method: method,
        url: url,
        cause: cancelToken.cancelError?.message ?? 'cancelled',
      );
    }
  }

  _Prepared _prepare(String url, String method, RequestBody? body, Object? rawBody, Map<String, String>? headers) {
    final effective = body ?? (rawBody == null ? RequestBody.empty() : RequestBody.asIs(rawBody));
    final length = effective.declaredLength;
    if (length != null && length > _settings.maxRequestBytes) {
      throw NetworkFailure(
        kind: NetworkFailureKind.requestTooLarge,
        method: method,
        url: url,
        cause: 'a $length byte request body exceeds ${_settings.maxRequestBytes}',
      );
    }
    return _Prepared(effective.value, _settings.headersFor(<String, String>{...effective.headers, ...?headers}));
  }

  /// Rejects an oversized or failed response before a caller sees the body.
  ///
  /// The size test reads `content-length` rather than the decoded bytes on purpose: the point is to refuse the
  /// download, and waiting for 200 MB to arrive to measure it defeats that. A body without a declared length
  /// is measured after decode, which is late but better than nothing.
  void _checkString(Response<String> response, {required String method, required String url}) {
    final declared = int.tryParse(response.headers.value('content-length') ?? '');
    final tooBig = oversizeFailure(
      declared,
      maxBytes: _settings.maxResponseBytes,
      method: method,
      url: url,
      statusCode: response.statusCode,
    );
    if (tooBig != null) {
      throw tooBig;
    }
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw failureForStatus(
        status,
        method: method,
        url: url,
        headers: _flatOf(response),
        actualUri: response.realUri,
        now: _clock(),
      );
    }
    _log?.debug(
      'request completed',
      fields: <String, Object?>{'method': method, 'playUrl': redact(url), 'status': status},
    );
  }

  void _refuseOriginChange(Response<dynamic> response, {required String method, required String url}) {
    if (!_settings.refuseOriginChange) {
      return;
    }
    final answered = response.realUri;
    if (sameOrigin(url, answered)) {
      return;
    }
    throw NetworkFailure(
      kind: NetworkFailureKind.redirectRefused,
      method: method,
      url: url,
      statusCode: response.statusCode,
      cause: 'the request left ${urlHostOf(url)} for ${answered.host}',
      actualUri: answered,
    );
  }

  RawResponse _rawOf(Response<List<int>> response, {required String url, required DateTime started}) {
    final declared = int.tryParse(response.headers.value('content-length') ?? '');
    final tooBig = oversizeFailure(
      declared,
      maxBytes: _settings.maxResponseBytes,
      method: 'GET',
      url: url,
      statusCode: response.statusCode,
    );
    if (tooBig != null) {
      throw tooBig;
    }
    final bytes = response.data ?? const <int>[];
    if (bytes.length > _settings.maxResponseBytes) {
      throw NetworkFailure(
        kind: NetworkFailureKind.responseTooLarge,
        method: 'GET',
        url: url,
        statusCode: response.statusCode,
        cause: 'body of ${bytes.length} bytes exceeds ${_settings.maxResponseBytes}',
      );
    }
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw failureForStatus(
        status,
        method: 'GET',
        url: url,
        headers: _flatOf(response),
        actualUri: response.realUri,
        now: _clock(),
      );
    }
    return RawResponse(
      statusCode: status,
      uri: response.realUri,
      requestedUri: Uri.parse(url),
      headers: _flatOf(response),
      bytes: bytes,
      elapsed: _clock().difference(started),
    );
  }

  HttpHeaderBag _bagOf(Response<dynamic> response) {
    final bag = HttpHeaderBag();
    response.headers.forEach((name, values) {
      for (final value in values) {
        bag.add(name, value);
      }
    });
    return bag;
  }

  Map<String, String> _flatOf(Response<dynamic> response) {
    return response.headers.map.map((name, values) => MapEntry<String, String>(name, values.join(', ')));
  }

  Map<String, List<String>> _flatPairs(Response<dynamic> response) => response.headers.map;
}

/// A Dio token does not compose: a caller that cancels the token it holds must stop the read Dio is doing on
/// the internal one, and Dio only watches the token it was handed. The link is one-way and outlives the
/// request it was made for - cancelling a finished request is a no-op in Dio, so there is nothing to detach.
void _linkCancellation(CancelToken? outer, CancelToken inner) {
  if (outer == null) {
    return;
  }
  unawaited(
    outer.whenCancel.then((reason) {
      if (!inner.isCancelled) {
        inner.cancel(reason);
      }
    }),
  );
}

/// A prepared body and the headers to send with it.
final class _Prepared {
  const _Prepared(this.data, this.headers);

  final Object? data;
  final Map<String, String> headers;
}
