// Module: lib/src/settings.dart
// Purpose: One place that states how a client behaves: timeouts, ceilings, retries, concurrency and redirect
// policy.
// Author: liuchuancong
// Created: 2026-10-11
//
// These values used to be spread over BaseOptions construction and three private fields, so a provider that
// wanted "this site needs 40 seconds, not 15" had to rebuild a Dio. The settings object is the whole contract,
// and every field has a ceiling on purpose: a request with no byte cap is a memory crash waiting for a
// misbehaving CDN.

import 'retry_policy.dart';

/// How a client behaves. Defaults are the values the site adapters agreed on.
final class NetworkSettings {
  const NetworkSettings({
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.sendTimeout = const Duration(seconds: 15),
    this.retry = const RetryPolicy(),
    this.maxResponseBytes = 32 * 1024 * 1024,
    this.maxRequestBytes = 8 * 1024 * 1024,
    this.userAgent,
    this.defaultHeaders = const <String, String>{},
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.refuseOriginChange = false,
    this.maxConcurrent,
    this.hostMinSpacing,
    this.acceptsGzip = true,
  });

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Attempts, backoff and whether to obey `Retry-After`.
  final RetryPolicy retry;

  /// A body larger than this aborts the request instead of exhausting memory.
  final int maxResponseBytes;

  /// A request body larger than this is refused before a byte leaves the device: uploading a 2 GB "config
  /// import" to a plugin endpoint is not a thing the transport should discover late.
  final int maxRequestBytes;
  final String? userAgent;
  final Map<String, String> defaultHeaders;

  /// Whether the transport follows 3xx itself. When false, a 3xx is returned as a response and the caller
  /// decides - which is the only way to show a user "this link leaves the site we were granted".
  final bool followRedirects;
  final int maxRedirects;

  /// Refuse a redirect that lands on a different origin than the url that was asked for. Off by default
  /// because a CDN hop is normal; a plugin or extension fetcher should turn it on.
  final bool refuseOriginChange;

  /// How many requests one client may run at once. Null means unbounded, which a fan-out search should not.
  final int? maxConcurrent;

  /// The smallest gap between two requests to the same host. Null means none.
  final Duration? hostMinSpacing;

  /// Declares gzip support. A site that serves gzipped m3u8 to a client that did not ask for it is rare; a
  /// site that serves it because the header was inherited from a browser UA string is not.
  final bool acceptsGzip;

  /// The headers every request carries, with the per-request ones applied on top.
  Map<String, String> headersFor(Map<String, String>? overrides) {
    return <String, String>{
      if (userAgent != null) 'user-agent': userAgent!,
      if (acceptsGzip) 'accept-encoding': 'gzip, deflate',
      ...defaultHeaders,
      ...?overrides,
    };
  }

  /// A copy with one timeout changed, for a caller that knows a specific endpoint is slow.
  NetworkSettings withReceiveTimeout(Duration value) => NetworkSettings(
    connectTimeout: connectTimeout,
    receiveTimeout: value,
    sendTimeout: sendTimeout,
    retry: retry,
    maxResponseBytes: maxResponseBytes,
    maxRequestBytes: maxRequestBytes,
    userAgent: userAgent,
    defaultHeaders: defaultHeaders,
    followRedirects: followRedirects,
    maxRedirects: maxRedirects,
    refuseOriginChange: refuseOriginChange,
    maxConcurrent: maxConcurrent,
    hostMinSpacing: hostMinSpacing,
    acceptsGzip: acceptsGzip,
  );

  /// A copy with a different retry policy.
  NetworkSettings withRetry(RetryPolicy value) => NetworkSettings(
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    sendTimeout: sendTimeout,
    retry: value,
    maxResponseBytes: maxResponseBytes,
    maxRequestBytes: maxRequestBytes,
    userAgent: userAgent,
    defaultHeaders: defaultHeaders,
    followRedirects: followRedirects,
    maxRedirects: maxRedirects,
    refuseOriginChange: refuseOriginChange,
    maxConcurrent: maxConcurrent,
    hostMinSpacing: hostMinSpacing,
    acceptsGzip: acceptsGzip,
  );
}
