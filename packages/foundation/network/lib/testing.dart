// Module: lib/testing.dart
// Purpose: A scripted transport, published so consumers can test their HTTP paths without owning dio.
// Author: liuchuancong
// Created: 2026-10-11
//
// Why this is a second entry point instead of a barrel export: it is only for tests, and it must not appear in
// a production import graph. `ecosystem/capability` already ships `lib/testing.dart` for the same reason.
//
// Before this file existed, every provider that wanted to verify its endpoints had to implement dio's
// HttpClientAdapter itself and declare dio as a dev dependency for one fake - which also means the transport
// rules this package owns (json headers, per-key answer order, cancellation) got re-implemented slightly
// differently in each test directory.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One request the code under test made, in shapes a test can assert on **without naming dio types**.
final class ScriptedRequest {
  const ScriptedRequest._(this.method, this.uri, this.headers, this.bodyText);

  factory ScriptedRequest.from(RequestOptions options, String? bodyText) => ScriptedRequest._(
    options.method.toUpperCase(),
    options.uri,
    Map<String, String>.fromEntries(options.headers.entries.map((entry) => MapEntry('${entry.key}', '${entry.value}'))),
    bodyText,
  );

  final String method;
  final Uri uri;
  final Map<String, String> headers;

  /// The request body as text, when there was one.
  final String? bodyText;

  /// `host + path` - the key a script of responses is usually indexed by when one host serves several
  /// endpoints with the same path (`www.x.com/cache.php` versus `mp.x.com/cache.php`).
  String get hostKey => '${uri.host}${uri.path}';

  /// `path` alone, for a script that does not care which host answered.
  String get pathKey => uri.path;

  Map<String, String> get query => uri.queryParameters;

  /// The header [name] compared case-insensitively, as HTTP header names are.
  String? header(String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  String toString() => 'ScriptedRequest($method ${uri.toString()}${bodyText == null ? '' : ' +body'})';
}

/// A transport that answers from a script instead of a socket.
///
/// Keys are matched against each request in three shapes - the full url, `host+path`, then `path` - so a script
/// can be as specific as the case needs. A key may hold several bodies, answered in call order and repeating the
/// last one, which is how "the second poll answered differently" gets expressed without a queue DSL.
///
/// A body that starts with `!` throws instead of answering: an unreachable endpoint is a normal branch of this
/// code, and it should not need a different fake to produce it. The thrown failure is a connection error, which
/// is **retryable** by [NetworkSettings.retry] - so a test that counts requests has to build its client with
/// `RetryPolicy(attempts: 1)`, or one scripted failure shows up as three.
final class ScriptedTransport implements HttpClientAdapter {
  ScriptedTransport(this.script, {this.defaultStatus = 200, this.contentType = 'application/json; charset=utf-8'});

  /// An empty script refuses every request rather than answering 200 with an empty body: a test that forgot to
  /// script an endpoint the code started calling would otherwise pass quietly.
  final Map<String, List<String>> script;

  final int defaultStatus;
  final String contentType;
  final List<ScriptedRequest> _requests = <ScriptedRequest>[];
  bool _closed = false;

  /// Every request made so far, in order.
  List<ScriptedRequest> get requests => List<ScriptedRequest>.unmodifiable(_requests);

  /// How many requests matched [key] (host+path or path).
  int requestsTo(String key) => _requests.where((request) => request.hostKey == key || request.pathKey == key).length;

  bool get closed => _closed;

  /// The script keys no request matched. Useful for the assertion "nothing was left un-requested", which is how
  /// a stale script notices the code stopped calling an endpoint.
  List<String> get unconsumedKeys {
    final touched = <String>{
      for (final request in _requests) request.hostKey,
      for (final request in _requests) request.pathKey,
      for (final request in _requests) request.uri.toString(),
    };
    return script.keys.where((key) => !touched.contains(key)).toList(growable: false);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyText = requestStream == null ? null : await _drain(requestStream);
    final request = ScriptedRequest.from(options, bodyText);
    _requests.add(request);
    final key = _matchKey(request);
    final bodies = key == null ? null : script[key];
    if (bodies == null || bodies.isEmpty) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: 'ScriptedTransport has nothing scripted for ${request.uri}',
      );
    }
    final seen = _requests.where((entry) => _matchKey(entry) == key).length - 1;
    final body = bodies[seen.clamp(0, bodies.length - 1)];
    if (body.startsWith('!')) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError, error: body.substring(1));
    }
    return ResponseBody.fromString(
      body,
      defaultStatus,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[contentType],
      },
    );
  }

  @override
  void close({bool force = false}) => _closed = true;

  String? _matchKey(ScriptedRequest request) {
    final full = request.uri.toString();
    for (final candidate in <String>[full, request.hostKey, request.pathKey]) {
      if (script.containsKey(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static Future<String> _drain(Stream<Uint8List> stream) async {
    final collected = <int>[];
    await for (final chunk in stream) {
      collected.addAll(chunk);
    }
    return utf8.decode(collected, allowMalformed: true);
  }
}
