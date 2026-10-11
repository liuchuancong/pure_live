// Module: test/support/canned_http.dart
// Purpose: A dio adapter that replays a route table, so the source is tested without the network.
// Author: liuchuancong
// Created: 2026-10-10
//
// The seam is the adapter rather than a fake client because NetworkClient is a concrete class the source
// owns: replacing the transport is the one way to exercise the real decoding path, retries and all.
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// An adapter answering from [routes]: a request is matched by the prefix of its full url, longest key first
/// so `/allpage/6/1` cannot steal a request meant for `/allpage/6/12`.
final class CannedHttp implements HttpClientAdapter {
  CannedHttp(Map<String, String> routes, {Map<String, int> status = const <String, int>{}})
    : _routes = <String, String>{...routes},
      _status = <String, int>{...status};

  final Map<String, String> _routes;
  final Map<String, int> _status;

  /// Every request the source made, in order, so a test can count calls as well as read answers.
  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<String> get urls => requests.map((request) => request.uri.toString());

  int callsMatching(String prefix) => urls.where((url) => url.startsWith(prefix)).length;

  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    lastBody = options.data is String ? options.data as String : null;
    final url = options.uri.toString();
    final keys = _routes.keys.toList()..sort((left, right) => right.length.compareTo(left.length));
    for (final key in keys) {
      if (!url.startsWith(key)) {
        continue;
      }
      // No content-length header: NetworkClient refuses a body over its cap by reading that header, and a
      // canned string has no length the adapter should claim.
      return ResponseBody.fromString(_routes[key]!, _status[key] ?? 200);
    }
    throw StateError('canned http has no route for $url (known: ${_routes.keys.toList()})');
  }

  @override
  void close({bool force = false}) {}
}
