import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/src/proxy.dart';

/// Cooperative cancellation handle shared between the caller and the
/// transport.
///
/// The token stays transport-agnostic: the transport bridges it to its own
/// cancellation primitive internally. Cancelling is idempotent; the first
/// [reason] wins.
final class CancelToken {
  final Completer<Object?> _completer = Completer<Object?>();

  Object? _reason;
  bool _isCancelled = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _isCancelled;

  /// The reason passed to the first [cancel] call, if any.
  Object? get reason => _reason;

  /// Completes with the [reason] once the token is cancelled.
  Future<Object?> get whenCancel => _completer.future;

  /// Marks the token cancelled. Later calls are ignored.
  void cancel([Object? reason]) {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _reason = reason;
    _completer.complete(reason);
  }
}

/// A single HTTP request, described without any transport details.
///
/// Bodies are pre-encoded strings ([LiveRequest.form] and [LiveRequest.json]
/// do the encoding) so what goes over the wire is exactly what was built,
/// independent of the transport's own serialization habits.
final class LiveRequest {
  /// A request with an explicit method and pre-encoded body.
  new custom({
    required this.method,
    required this.url,
    this.body,
    this.bodyBytes,
    this.contentType,
    this.headers = const {},
    this.site,
    this.timeout,
    CancelToken? cancelToken,
    this.proxyRoute,
    this.cache,
    this.idempotent = false,
  }) : cancelToken = cancelToken ?? CancelToken();

  /// A GET request.
  new get(
    Uri url, {
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
    ProxyRoute? proxyRoute,
  }) : this.custom(
         method: 'GET',
         url: url,
         headers: headers,
         site: site,
         timeout: timeout,
         cancelToken: cancelToken,
         proxyRoute: proxyRoute,
       );

  /// A HEAD request.
  new head(
    Uri url, {
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
    ProxyRoute? proxyRoute,
  }) : this.custom(
         method: 'HEAD',
         url: url,
         headers: headers,
         site: site,
         timeout: timeout,
         cancelToken: cancelToken,
         proxyRoute: proxyRoute,
       );

  /// A POST whose body is `application/x-www-form-urlencoded`.
  ///
  /// Fields are encoded with [Uri.encodeQueryComponent] so `+` means space,
  /// matching what servers expect for form bodies.
  new form(
    Uri url, {
    required Map<String, String> fields,
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
    ProxyRoute? proxyRoute,
  }) : this.custom(
         method: 'POST',
         url: url,
         body: Uri(queryParameters: fields).query,
         contentType: 'application/x-www-form-urlencoded',
         headers: headers,
         site: site,
         timeout: timeout,
         cancelToken: cancelToken,
         proxyRoute: proxyRoute,
       );

  /// A POST whose body is JSON.
  new json(
    Uri url, {
    required Object? body,
    Map<String, String> headers = const {},
    String? site,
    Duration? timeout,
    CancelToken? cancelToken,
    ProxyRoute? proxyRoute,
  }) : this.custom(
         method: 'POST',
         url: url,
         body: body == null ? null : jsonEncode(body),
         contentType: 'application/json',
         headers: headers,
         site: site,
         timeout: timeout,
         cancelToken: cancelToken,
         proxyRoute: proxyRoute,
       );

  /// Upper-case HTTP method, e.g. `GET`.
  final String method;

  /// Absolute target URL.
  final Uri url;

  /// Pre-encoded request body, or null for bodyless requests.
  final String? body;

  /// A raw byte request body (a binary envelope, e.g. a WUP packet), sent
  /// instead of [body] when set. Null for text or bodyless requests.
  final Uint8List? bodyBytes;

  /// Content type of [body]; the transport picks a default when null.
  final String? contentType;

  /// Extra request headers. Take precedence over transport defaults.
  final Map<String, String> headers;

  /// Owning site id, used by proxy policies and (later) cookie routing.
  final String? site;

  /// Per-phase timeout (connect, send, receive). Null means transport
  /// default.
  final Duration? timeout;

  /// Cancellation handle, always non-null (fresh one when not provided).
  final CancelToken cancelToken;

  /// Overrides the proxy policy's decision for this request when non-null.
  final ProxyRoute? proxyRoute;

  /// Three-state cache override for the dio cache interceptor: `true`
  /// forces the response into the cache, `false` forbids caching this
  /// response outright, `null` follows the client profile's default.
  final bool? cache;

  /// Whether the request can be replayed safely by the retry policy.
  /// Non-POST requests are treated as idempotent regardless; a POST must
  /// opt in explicitly.
  final bool idempotent;

  /// Returns a copy of the request with [query] appended to the URL.
  ///
  /// The already-encoded query string is carried over verbatim — signed or
  /// tokenized queries must not be re-encoded, only appended to.
  LiveRequest withQuery(Map<String, String> query) {
    if (query.isEmpty) {
      return this;
    }
    final existing = url.query;
    final separator = existing.isEmpty ? '?' : '?$existing&';
    final additions = query.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}'
              '=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final buffer = StringBuffer()
      ..write(url.scheme)
      ..write('://')
      ..write(url.authority)
      ..write(url.path)
      ..write(separator)
      ..write(additions);
    if (url.hasFragment) {
      buffer
        ..write('#')
        ..write(url.fragment);
    }
    return LiveRequest.custom(
      method: method,
      url: Uri.parse(buffer.toString()),
      body: body,
      contentType: contentType,
      headers: headers,
      site: site,
      timeout: timeout,
      cancelToken: cancelToken,
      proxyRoute: proxyRoute,
      cache: cache,
      idempotent: idempotent,
    );
  }

  @override
  String toString() => '${method.toUpperCase()} $url';
}
