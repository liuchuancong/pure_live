// Module: lib/src/failure.dart
// Purpose: A transport-level failure classification so callers branch on cause instead of on Dio internals.
// Author: liuchuancong
// Created: 2026-10-08
//
// The codes are the network namespace of docs/contracts/platform-models.md section 14, so a failure can be
// reported through PlatformErrorInfo without inventing a second vocabulary.

/// Why a request did not produce a usable response.
enum NetworkFailureKind {
  /// The request or receive window elapsed.
  timeout,

  /// DNS, connection refused, TLS or an unreachable host.
  unreachable,

  /// The server answered 401 or 403.
  forbidden,

  /// The server answered 429.
  rateLimited,

  /// A response body exceeded the configured ceiling.
  responseTooLarge,

  /// A request body was refused before it left the device.
  requestTooLarge,

  /// The server answered 404.
  notFound,

  /// The server answered a 5xx class error.
  server,

  /// A response body could not be decoded into the expected shape.
  parse,

  /// Any other HTTP status the caller treats as an error.
  httpStatus,

  /// The caller cancelled; never retried (platform-models section 20 invariant 9).
  cancelled,

  /// A redirect was refused by policy.
  redirectRefused,

  /// Something we did not predict.
  unknown,
}

/// A failed request, carrying enough context to log and to decide about a retry.
final class NetworkFailure implements Exception {
  const NetworkFailure({
    required this.kind,
    required this.method,
    required this.url,
    this.statusCode,
    this.cause,
    this.retryable = false,
    this.retryAfter,
    this.actualUri,
  });

  /// The standard code for this kind, ready to put into PlatformErrorInfo.code.
  String get code {
    return switch (kind) {
      NetworkFailureKind.timeout => 'network.timeout',
      NetworkFailureKind.unreachable => 'network.unreachable',
      NetworkFailureKind.forbidden => 'network.forbidden',
      NetworkFailureKind.rateLimited => 'network.rate_limited',
      NetworkFailureKind.responseTooLarge => 'network.response_too_large',
      NetworkFailureKind.requestTooLarge => 'network.request_too_large',
      NetworkFailureKind.cancelled => 'task.cancelled',
      NetworkFailureKind.notFound => 'network.not_found',
      NetworkFailureKind.server => 'network.server',
      NetworkFailureKind.parse => 'network.parse',
      // These extend the section 14 list rather than reusing an unrelated code: a 5xx is not
      // "unreachable", and mislabelling it would make the retry dashboard lie about the cause.
      NetworkFailureKind.httpStatus => 'network.http_status',
      NetworkFailureKind.redirectRefused => 'network.redirect_refused',
      NetworkFailureKind.unknown => 'network.unknown',
    };
  }

  final NetworkFailureKind kind;
  final String method;

  /// The request URL. Never contains a credential: the client logs a redacted form.
  final String url;
  final int? statusCode;
  final Object? cause;

  /// Whether retrying the same request is reasonable.
  final bool retryable;

  /// How long the server asked for before the next attempt (`Retry-After` on a 429 or 503), when it said.
  /// Null means no instruction, not "no wait".
  final Duration? retryAfter;

  /// Where the response actually came from, when it differs from [url]: a redirect that left the granted
  /// origin is only visible from here, and a refused one must name the host it tried to reach.
  final Uri? actualUri;

  /// The same failure with [retryAfter] and [actualUri] filled in from a response.
  NetworkFailure withResponse({Duration? retryAfter, Uri? actualUri}) => NetworkFailure(
    kind: kind,
    method: method,
    url: url,
    statusCode: statusCode,
    cause: cause,
    retryable: retryable,
    retryAfter: retryAfter ?? this.retryAfter,
    actualUri: actualUri ?? this.actualUri,
  );

  @override
  String toString() {
    final status = statusCode == null ? '' : ' status=$statusCode';
    final wait = retryAfter == null ? '' : ' retryAfter=${retryAfter!.inMilliseconds}ms';
    return 'NetworkFailure($kind $method $url$status$wait retryable=$retryable)';
  }
}
