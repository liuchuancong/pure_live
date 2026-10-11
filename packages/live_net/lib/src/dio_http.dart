import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart' as dio;
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart' as h2;
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_net/src/client_profile.dart';
import 'package:live_net/src/interceptors/network_log_interceptor.dart';
import 'package:live_net/src/live_http.dart';
import 'package:live_net/src/proxy.dart';
import 'package:live_net/src/request.dart';
import 'package:live_net/src/response.dart';
import 'package:live_net/src/streamed_response.dart';
import 'package:live_net/src/transport_failure.dart';

/// The extras [DioLiveHttp] attaches to every dio request.
abstract final class RequestExtras {
  /// Marker written by the log interceptor, also the request id.
  static const String requestId = 'live_net.requestId';

  /// Wall-clock start of the whole call, retries included; the retry
  /// budget is measured against it.
  static const String startedAt = 'live_net.startedAt';

  /// Explicit idempotency opt-in from [LiveRequest.idempotent].
  static const String idempotent = 'live_net.idempotent';
}

/// Default budget for one call across all of its retry attempts.
const Duration _retryBudget = Duration(seconds: 15);

/// Exponential back-off schedule (with room for the retry budget).
const List<Duration> _retryDelays = [Duration(milliseconds: 500), Duration(seconds: 1), Duration(seconds: 2)];

/// [LiveHttp] implementation over a dio pipeline.
///
/// One dio instance is pooled per [ProxyRoute.key], so routing some sites
/// through a proxy never shares connections with direct traffic. The
/// pipeline order is: log → cookies → cache → retry → adapter. Error
/// statuses stay ordinary [LiveResponse]s; only transport breakdowns
/// throw, always as a [TransportFailure] subtype.
///
/// The instance is normally built by `DioFactory`, which derives the
/// interceptor configuration from a [ClientProfile]; constructing it
/// directly stays possible for tests and special cases.
final class DioLiveHttp implements LiveHttp {
  /// Creates a transport. All pipeline parts are optional: [log] adds the
  /// redacted network log, [cookieJar] cookie management, [cacheOptions]
  /// response caching (with per-request overrides from
  /// `LiveRequest.cache`) and [maxRetries] bounded retries with an
  /// exponential back-off and a total time budget. [adapterFactory]
  /// injects a platform-native HTTP stack for direct routes; returning
  /// null or leaving it unset keeps the built-in selection and falls
  /// back to the standard dart:io adapter when it is unavailable.
  new({
    this.proxyPolicy,
    Map<String, String> defaultHeaders = const {},
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.log,
    this.cacheOptions,
    this.cookieJar,
    this.maxRetries = 0,
    this.adapterFactory,
    this.useHttp2 = false,
  }) : _defaultHeaders = Map.of(defaultHeaders);

  /// Per-request routing decisions, consulted before every send.
  final ProxyPolicy? proxyPolicy;

  final Map<String, String> _defaultHeaders;

  /// Whether redirect responses are followed automatically.
  final bool followRedirects;

  /// Redirect budget per request when [followRedirects] is on.
  final int maxRedirects;

  /// Network log target, or null to keep the pipeline silent.
  final LiveLog? log;

  /// Baseline cache policy; per-request overrides ride in
  /// [LiveRequest.cache]. Null disables the cache interceptor.
  final CacheOptions? cacheOptions;

  /// Session cookie jar, or null to send no managed cookies.
  final CookieJar? cookieJar;

  /// Retry budget in attempts (0 disables retries).
  final int maxRetries;

  /// Whether direct routes should speak HTTP/2; proxy routes keep the
  /// standard dart:io adapter either way.
  final bool useHttp2;

  /// consulted for every pooled dio instance; see the constructor docs.
  final dio.HttpClientAdapter? Function(ProxyRoute route)? adapterFactory;

  final Map<String, dio.Dio> _instances = {};
  bool _closed = false;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final response = await _fetch<List<int>>(request, dio.ResponseType.bytes);
    return LiveResponse(
      statusCode: response.statusCode ?? 0,
      headers: _headersOf(response.headers),
      bodyBytes: Uint8List.fromList(response.data ?? const <int>[]),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    final response = await _fetch<dio.ResponseBody>(request, dio.ResponseType.stream);
    final body = response.data;
    if (body == null) {
      throw const ProtocolFailure('stream response without body');
    }
    return _DioStreamedResponse(
      statusCode: response.statusCode ?? 0,
      headers: _headersOf(response.headers),
      upstream: body.stream,
    );
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    for (final instance in _instances.values) {
      instance.close(force: true);
    }
    _instances.clear();
  }

  Future<dio.Response<T>> _fetch<T>(LiveRequest request, dio.ResponseType type) async {
    if (_closed) {
      throw StateError('DioLiveHttp is closed');
    }
    final instance = _dioFor(request);
    final options =
        dio.RequestOptions(
            path: request.url.toString(),
            method: request.method.toUpperCase(),
            data: request.body,
            headers: {
              ..._defaultHeaders,
              if (request.contentType != null) dio.Headers.contentTypeHeader: request.contentType,
              ...request.headers,
            },
            responseType: type,
            validateStatus: (status) => true,
            followRedirects: followRedirects,
            maxRedirects: maxRedirects,
            connectTimeout: request.timeout,
            sendTimeout: request.timeout,
            receiveTimeout: request.timeout,
            cancelToken: _dioToken(request.cancelToken),
          )
          ..extra[RequestExtras.startedAt] = DateTime.now()
          ..extra[RequestExtras.idempotent] = request.idempotent;
    if (cacheOptions != null && request.cache != null) {
      // Request-level override: the interceptor prefers the CacheOptions
      // stashed under extraKey over its baseline.
      options.extra[extraKey] = cacheOptions!.copyWith(
        policy: request.cache! ? CachePolicy.forceCache : CachePolicy.noCache,
      );
    }
    try {
      return await instance.fetch<T>(options);
    } on dio.DioException catch (error) {
      throw _mapFailure(error);
    }
  }

  dio.Dio _dioFor(LiveRequest request) {
    final route = request.proxyRoute ?? proxyPolicy?.routeFor(request.url, site: request.site) ?? const DirectRoute();
    return _instances.putIfAbsent(route.key, () => _buildDio(route));
  }

  dio.Dio _buildDio(ProxyRoute route) {
    final instance = dio.Dio(
      dio.BaseOptions(
        validateStatus: (status) => true,
        followRedirects: followRedirects,
        maxRedirects: maxRedirects,
        headers: _defaultHeaders,
      ),
    );
    instance.interceptors.addAll([
      if (log != null) NetworkLogInterceptor(log!),
      if (cookieJar != null) CookieManager(cookieJar!),
      if (cacheOptions != null) DioCacheInterceptor(options: cacheOptions!),
      if (maxRetries > 0)
        RetryInterceptor(
          dio: instance,
          retries: maxRetries,
          retryDelays: _retryDelays,
          retryEvaluator: _retryEvaluator,
        ),
    ]);
    instance.httpClientAdapter = _adapterFor(route);
    return instance;
  }

  dio.HttpClientAdapter _adapterFor(ProxyRoute route) {
    final injected = adapterFactory?.call(route);
    if (injected != null) {
      return injected;
    }
    if (route is DirectRoute && useHttp2) {
      try {
        return h2.Http2Adapter(h2.ConnectionManager());
      } on Object {
        // HTTP/2 stack unavailable: fall through.
      }
    }
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (route is HttpProxyRoute) {
          client.findProxy = (uri) => 'PROXY ${route.host}:${route.port}';
        } else if (route is SystemProxyRoute) {
          client.findProxy = HttpClient.findProxyFromEnvironment;
        }
        return client;
      },
    );
  }

  /// Whether a failed attempt may be replayed: cancellations and TLS
  /// rejections never retry, auth failures never retry, and only
  /// idempotent calls do — non-POST verbs count, POST must opt in through
  /// [LiveRequest.idempotent]. The whole call must also stay inside the
  /// retry budget.
  FutureOr<bool> _retryEvaluator(dio.DioException error, int attempt) {
    if (error.type == dio.DioExceptionType.cancel || error.type == dio.DioExceptionType.badCertificate) {
      return false;
    }
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return false;
    }
    final options = error.requestOptions;
    final replayable = options.extra[RequestExtras.idempotent] == true || options.method.toUpperCase() != 'POST';
    if (!replayable) {
      return false;
    }
    final started = options.extra[RequestExtras.startedAt] as DateTime?;
    if (started != null && DateTime.now().difference(started) > _retryBudget) {
      return false;
    }
    return true;
  }

  dio.CancelToken _dioToken(CancelToken token) {
    final bridged = dio.CancelToken();
    if (token.isCancelled) {
      bridged.cancel(token.reason?.toString());
      return bridged;
    }
    unawaited(token.whenCancel.then((_) => bridged.cancel(token.reason?.toString())));
    return bridged;
  }

  static Map<String, String> _headersOf(dio.Headers? headers) {
    if (headers == null) {
      return const {};
    }
    return {for (final entry in headers.map.entries) entry.key.toLowerCase(): entry.value.join(', ')};
  }

  static TransportFailure _mapFailure(dio.DioException error) {
    switch (error.type) {
      case dio.DioExceptionType.connectionTimeout:
      case dio.DioExceptionType.sendTimeout:
      case dio.DioExceptionType.receiveTimeout:
        return TimeoutFailure('request timed out', cause: error.error ?? error);
      case dio.DioExceptionType.cancel:
        return CancelledFailure(cause: error.error);
      case dio.DioExceptionType.badCertificate:
        return TlsFailure('certificate rejected', cause: error.error ?? error);
      case dio.DioExceptionType.connectionError:
        return _mapConnectionError(error.error ?? error);
      case dio.DioExceptionType.transformTimeout:
        return ProtocolFailure('body transformation failed', cause: error.error ?? error);
      case dio.DioExceptionType.badResponse:
      case dio.DioExceptionType.unknown:
        return _mapUnknown(error.error ?? error);
    }
  }

  static TransportFailure _mapConnectionError(Object cause) {
    if (cause is HandshakeException || cause is TlsException) {
      return TlsFailure('tls handshake failed', cause: cause);
    }
    if (cause is SocketException) {
      final detail = cause.osError?.message ?? cause.message;
      return ConnectFailure('connection failed: $detail', cause: cause);
    }
    return ConnectFailure('connection failed', cause: cause);
  }

  static TransportFailure _mapUnknown(Object cause) {
    if (cause is HandshakeException || cause is TlsException) {
      return TlsFailure('tls handshake failed', cause: cause);
    }
    if (cause is SocketException) {
      final detail = cause.osError?.message ?? cause.message;
      return ConnectFailure('connection failed: $detail', cause: cause);
    }
    if (cause is TimeoutException) {
      return TimeoutFailure('request timed out', cause: cause);
    }
    return ProtocolFailure('request failed', cause: cause);
  }
}

/// [LiveStreamedResponse] piping dio's body through a controllable stream
/// so [close] can abort the transfer cleanly even mid-flight.
final class _DioStreamedResponse implements LiveStreamedResponse {
  new({required this.statusCode, required this.headers, required this._upstream}) {
    _controller = StreamController<Uint8List>(onCancel: _discardUpstream);
    _controller.onListen = () {
      _subscription ??= _upstream.listen(
        _controller.add,
        onError: _controller.addError,
        onDone: _controller.close,
        cancelOnError: true,
      );
    };
  }

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  final Stream<Uint8List> _upstream;
  late final StreamController<Uint8List> _controller;
  StreamSubscription<Uint8List>? _subscription;
  bool _closed = false;

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    if (!_controller.hasListener && !_controller.isClosed) {
      // Nobody consumed the body; drop what the server already sent.
      await _discardUpstream();
    }
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<void> _discardUpstream() async {
    try {
      await _upstream.listen((_) {}, onError: (_) {}, cancelOnError: true).cancel();
    } on Object {
      // Best effort: the socket may already be gone.
    }
  }
}
