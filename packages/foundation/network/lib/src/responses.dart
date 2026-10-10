// Module: lib/src/responses.dart
// Purpose: The response shapes this client hands back, each keeping the identity of the url that actually
// answered next to the body.
// Author: liuchuancong
// Created: 2026-10-11
//
// The requested url is the one the caller already knew; the answering url is the one that matters for a
// permission decision, and a redirect chain is only observable from the response. Every shape here therefore
// carries both, plus the elapsed time, because a caller that wants to log "slow" cannot recover it later.

import 'dart:convert';

import 'classification.dart';
import 'failure.dart';
import 'headers.dart';
import 'url_reference.dart';

/// Reports bytes received so far and the expected total, when the server declared one.
typedef ProgressReporter = void Function(int received, int? total);

/// Shared shape for everything the client returns.
abstract class HttpResponse {
  const HttpResponse();

  int get statusCode;

  /// The url that answered, after redirects.
  Uri get uri;

  /// The url that was asked for. Differs from [uri] whenever a redirect moved the request.
  Uri get requestedUri;

  HttpHeaderBag get bag;

  Duration get elapsed;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Where the request left the origin it was granted. A plugin config that redirects to another host is the
  /// case this exists for.
  bool get leftOrigin => !sameOrigin(requestedUri, uri);

  String? get contentType => bag.first('content-type');

  /// The declared body size, or null when the server used a chunked encoding.
  int? get contentLength => int.tryParse(bag.first('content-length') ?? '');

  /// Headers safe to write to a log or an error report.
  Map<String, String> get redactedHeaders => bag.redacted();
}

/// A response kept as bytes, with the identity of the url that answered.
final class RawResponse extends HttpResponse {
  RawResponse({
    required this.statusCode,
    required this.uri,
    required this.requestedUri,
    required this.headers,
    required this.bytes,
    this.elapsed = Duration.zero,
  });

  @override
  final int statusCode;
  @override
  final Uri uri;
  @override
  final Uri requestedUri;

  /// Repeated headers are joined with `, `, which is how HTTP spells them on the wire.
  final Map<String, String> headers;
  final List<int> bytes;
  @override
  final Duration elapsed;

  @override
  late final HttpHeaderBag bag = HttpHeaderBag(headers);

  int get size => bytes.length;

  /// The body as a Dart string. A body that is not UTF-8 replaces, it does not throw: a spider that mislabels
  /// an encoding should still be parsable for the ASCII parts.
  String get text => utf8.decode(bytes, allowMalformed: true);

  @override
  String toString() => 'RawResponse($statusCode ${uri.host}, $size bytes)';
}

/// A text body plus what the transport said about it.
final class TextResponse extends HttpResponse {
  const TextResponse({
    required this.statusCode,
    required this.uri,
    required this.requestedUri,
    required this.body,
    required this.bag,
    this.elapsed = Duration.zero,
  });

  @override
  final int statusCode;
  @override
  final Uri uri;
  @override
  final Uri requestedUri;
  final String body;
  @override
  final HttpHeaderBag bag;
  @override
  final Duration elapsed;

  int get size => body.length;

  Map<String, String> get headers => bag.flattened();

  /// The body decoded as a JSON object, with the failing url reported.
  Map<String, Object?> json() => decodeJsonObject(body, url: uri.toString());

  /// The body decoded as a JSON array.
  List<Object?> jsonArray() => decodeJsonList(body, url: uri.toString());

  @override
  String toString() => 'TextResponse($statusCode ${uri.host}, ${size} chars)';
}

/// What a HEAD answered: headers and a length, no body.
final class HeadResponse extends HttpResponse {
  const HeadResponse({
    required this.statusCode,
    required this.uri,
    required this.requestedUri,
    required this.bag,
    this.elapsed = Duration.zero,
  });

  @override
  final int statusCode;
  @override
  final Uri uri;
  @override
  final Uri requestedUri;
  @override
  final HttpHeaderBag bag;
  @override
  final Duration elapsed;

  @override
  String toString() => 'HeadResponse($statusCode ${uri.host}, ${contentLength ?? 'unknown'} bytes)';
}

/// A body read to the end under a byte ceiling.
final class DownloadResult extends HttpResponse {
  const DownloadResult({
    required this.statusCode,
    required this.uri,
    required this.requestedUri,
    required this.bytes,
    required this.bag,
    required this.expectedTotal,
    this.elapsed = Duration.zero,
  });

  @override
  final int statusCode;
  @override
  final Uri uri;
  @override
  final Uri requestedUri;
  final List<int> bytes;
  @override
  final HttpHeaderBag bag;

  /// What the server said it would send, when it said. A ranged response counts from the range, not the file.
  final int? expectedTotal;
  @override
  final Duration elapsed;

  int get size => bytes.length;

  /// True when the transport was told to serve a byte range, i.e. the body is a piece of the file.
  bool get isPartial => statusCode == 206;

  /// True when every declared byte arrived. A truncated download is a retryable condition, and a caller that
  /// treats a partial file as complete corrupts its cache permanently.
  bool get isComplete => expectedTotal == null || expectedTotal == size || isPartial;

  @override
  String toString() =>
      'DownloadResult($statusCode ${uri.host}, $size${expectedTotal == null ? '' : '/$expectedTotal'} bytes)';
}

/// Decodes a JSON object body, reporting the url that failed rather than throwing a bare FormatException.
Map<String, Object?> decodeJsonObject(String body, {required String url}) {
  if (body.trim().isEmpty) {
    throw NetworkFailure(kind: NetworkFailureKind.parse, method: 'GET', url: url, cause: 'empty body');
  }
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw NetworkFailure(
      kind: NetworkFailureKind.parse,
      method: 'GET',
      url: url,
      cause: 'expected a JSON object, got ${decoded.runtimeType}',
    );
  }
  return Map<String, Object?>.from(decoded);
}

/// Decodes a JSON array body. The list-shaped endpoints (playlists, search results) are the common case in a
/// spider, and a `{}` wrapper around them is a shape error worth naming.
List<Object?> decodeJsonList(String body, {required String url}) {
  if (body.trim().isEmpty) {
    throw NetworkFailure(kind: NetworkFailureKind.parse, method: 'GET', url: url, cause: 'empty body');
  }
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw NetworkFailure(
      kind: NetworkFailureKind.parse,
      method: 'GET',
      url: url,
      cause: 'expected a JSON array, got ${decoded.runtimeType}',
    );
  }
  return List<Object?>.unmodifiable(decoded);
}

/// The status-to-kind table, re-exported for callers that classify a response they built themselves.
NetworkFailureKind failureKindFor(int status) => kindForStatus(status);
