import 'dart:convert';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/huya/huya_manifest.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's transport: a [LiveHttp] wrapper that hands parsers
/// `(text, status)` pairs and maps transport breakdowns onto
/// [HuyaFailureKind.network].
final class HuyaHttp {
  /// Wraps [http] as the huya transport.
  const HuyaHttp(this.http);

  /// The wrapped transport.
  final LiveHttp http;

  /// GETs [url] with [headers]; bad statuses are ordinary answers — the
  /// parsers decide what 403/422/429/5xx mean for their endpoint.
  Future<({String text, int status})> get(Uri url, {Map<String, String> headers = const {}}) async {
    try {
      final response = await http.send(LiveRequest.custom(method: 'GET', site: huyaSiteId, url: url, headers: headers));
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw HuyaFailure(HuyaFailureKind.network, 'GET $url: $failure', cause: failure);
    }
  }

  /// POSTs [json] as a JSON body (the anonymous viewer login).
  Future<({String text, int status})> postJson(
    Uri url, {
    required Object? json,
    Map<String, String> headers = const {},
  }) async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: huyaSiteId,
          url: url,
          body: jsonEncode(json),
          contentType: 'application/json',
          headers: headers,
        ),
      );
      return (text: response.text, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw HuyaFailure(HuyaFailureKind.network, 'POST $url: $failure', cause: failure);
    }
  }

  /// POSTs [body] as raw bytes (a WUP RPC packet, whose body the caller already
  /// encoded); bad statuses are ordinary answers.
  Future<({Uint8List bytes, int status})> postBytes(
    Uri url, {
    required List<int> body,
    Map<String, String> headers = const {},
    Duration? timeout,
  }) async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: 'POST',
          site: huyaSiteId,
          url: url,
          bodyBytes: Uint8List.fromList(body),
          headers: headers,
          timeout: timeout,
        ),
      );
      return (bytes: response.bodyBytes, status: response.statusCode);
    } on TransportFailure catch (failure) {
      if (failure is CancelledFailure) rethrow;
      throw HuyaFailure(HuyaFailureKind.network, 'POST $url: $failure', cause: failure);
    }
  }

  /// Releases the wrapped transport.
  void close() => http.close();
}
