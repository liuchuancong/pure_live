import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small Android-system HTTP transport for endpoints that terminate a
/// `dart:io` TLS connection after an HTTP CONNECT proxy tunnel is established.
///
/// The native side deliberately accepts only Twitch's HTTPS GraphQL host. It
/// uses Android's platform TLS stack and otherwise keeps the request identity,
/// proxy and response parsing identical to the Dart transport.
class AndroidNativeHttp {
  AndroidNativeHttp._();

  static const MethodChannel _channel = MethodChannel('pure_live/native_http');

  static bool get isSupported => Platform.isAndroid;

  static Future<dynamic> postTwitchJson({
    required String url,
    required Map<String, String> headers,
    required String body,
    String? proxyHost,
    int? proxyPort,
  }) async {
    if (!isSupported) return null;
    final response = await _channel.invokeMapMethod<String, dynamic>('postTwitchJson', <String, dynamic>{
      'url': url,
      'headers': headers,
      'body': body,
      'proxyHost': proxyHost,
      'proxyPort': proxyPort,
      'timeoutMillis': 20000,
    });
    if (response == null) {
      throw StateError('Android native HTTP returned no response');
    }
    return decodeResponse(response);
  }

  @visibleForTesting
  static dynamic decodeResponse(Map<dynamic, dynamic> response) {
    final statusCode = switch (response['statusCode']) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(response['statusCode']?.toString() ?? ''),
    };
    final responseBody = response['body']?.toString() ?? '';
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      final summary = responseBody.replaceAll(RegExp(r'\s+'), ' ').trim();
      throw StateError(
        'Android native Twitch HTTP status ${statusCode ?? 'unknown'}: '
        '${summary.substring(0, summary.length.clamp(0, 240))}',
      );
    }
    if (responseBody.isEmpty) {
      throw StateError('Android native Twitch HTTP returned an empty body');
    }
    return jsonDecode(responseBody);
  }
}
