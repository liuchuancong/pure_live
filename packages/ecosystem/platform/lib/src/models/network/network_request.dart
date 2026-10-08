// Module: lib/src/models/network/network_request.dart
// Purpose: The request and response shapes an extension is allowed to send through the platform network exit.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 12 and docs/contracts/platform-contracts.md section 15.
// These are the only network types an extension may touch: the platform enforces host, timeout, response
// size, concurrency and diagnostics around them, and a plugin never holds an HTTP client of its own.
// Timeout default follows platform-contracts.md section 18 (Network 15s); a protocol runtime may override
// it, which is why the field is per request rather than global.

import '../../support/json.dart';

/// Header names whose values must never reach a log or a persisted record
/// (docs/contracts/platform-models.md section 16).
const Set<String> kSensitiveHeaderNames = <String>{
  'authorization',
  'cookie',
  'set-cookie',
  'proxy-authorization',
  'x-api-key',
  'x-auth-token',
};

/// Replaces a sensitive header value with a length-only marker.
///
/// The length survives because it is what makes "the token was sent but empty" debuggable without making
/// the record a credential store.
String? redactHeaderValue(String name, String? value) {
  if (value == null) {
    return null;
  }
  if (!kSensitiveHeaderNames.contains(name.toLowerCase())) {
    return value;
  }
  return value.isEmpty ? '<empty>' : '<${value.length} chars>';
}

/// A request an extension asks the platform to make.
final class NetworkRequest {
  const NetworkRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
    this.body,
    this.timeout,
    this.followRedirects = true,
  });

  factory NetworkRequest.fromJson(Map<String, Object?> json) {
    final raw = json['uri'];
    return NetworkRequest(
      method: requireString(json, 'method', 'network_request'),
      uri: raw is Uri ? raw : Uri.parse(requireString(json, 'uri', 'network_request')),
      headers: _headers(json['headers']),
      timeout: parseDurationMs(json['timeoutMs']),
      followRedirects: json['followRedirects'] as bool? ?? true,
    );
  }

  static const Duration defaultTimeout = Duration(seconds: 15);

  final String method;

  /// Internal code always handles a Uri; a bare string appears only at an import or config boundary
  /// (docs/contracts/platform-models.md section 16).
  final Uri uri;
  final Map<String, String> headers;

  /// Not serialised: a body is bytes or a stream owned by the caller, not a storable value.
  final Object? body;

  /// Null means the platform default applies.
  final Duration? timeout;
  final bool followRedirects;

  Duration get effectiveTimeout => timeout ?? defaultTimeout;

  bool get isReadOnly => method == 'GET' || method == 'HEAD';

  Map<String, String> redactedHeaders() =>
      headers.map((name, value) => MapEntry<String, String>(name, redactHeaderValue(name, value) ?? ''));

  Map<String, Object?> toJson() => <String, Object?>{
    'method': method,
    'uri': uri.toString(),
    'headers': redactedHeaders(),
    'timeoutMs': durationMs(effectiveTimeout),
    if (!followRedirects) 'followRedirects': false,
  };

  @override
  String toString() => 'NetworkRequest($method $uri)';
}

/// The response the platform hands back after enforcing its limits.
final class NetworkResponse {
  const NetworkResponse({
    required this.statusCode,
    required this.finalUri,
    this.headers = const <String, String>{},
    this.body = const <int>[],
  });

  final int statusCode;

  /// Where the request actually landed. A redirect to a host the grant did not name is only visible here,
  /// so the type carries it even when the caller never asks.
  final Uri finalUri;
  final Map<String, String> headers;
  final List<int> body;

  int get bodySize => body.length;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  Map<String, String> redactedHeaders() =>
      headers.map((name, value) => MapEntry<String, String>(name, redactHeaderValue(name, value) ?? ''));

  Map<String, Object?> toJson() => <String, Object?>{
    'statusCode': statusCode,
    'finalUri': finalUri.toString(),
    'headers': redactedHeaders(),
    'bodySize': bodySize,
  };

  @override
  String toString() => 'NetworkResponse($statusCode ${finalUri.host}, $bodySize bytes)';
}

Map<String, String> _headers(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return Map<String, String>.fromEntries(
    value.entries.map((entry) => MapEntry<String, String>('${entry.key}', '${entry.value}')),
  );
}
