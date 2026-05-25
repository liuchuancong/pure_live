import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:charset_converter/charset_converter.dart';

class RaceHttp {
  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>?> fetchJson(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 30),
    Map<String, String>? headers,
  }) async {
    return _race<Map<String, dynamic>?>(
      urls,
      timeout: timeout,
      task: (url) async {
        final res = await _client.get(Uri.parse(url), headers: headers).timeout(timeout);
        if (res.statusCode != 200) return null;
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
        return null;
      },
    );
  }

  /// Finds the fastest responsive URL from a list of mirrors without modifying RaceHttp.
  static Future<String?> findFastestUrl(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 60),
    Map<String, String>? headers,
  }) async {
    final completer = Completer<String?>();

    for (final url in urls) {
      unawaited(
        Future(() async {
          try {
            final client = http.Client();
            final res = await client.head(Uri.parse(url), headers: headers).timeout(timeout);
            if (res.statusCode == 200 && !completer.isCompleted) {
              completer.complete(url);
            }
          } catch (_) {}
        }),
      );
    }
    return completer.future;
  }

  static Future<String?> fetchText(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 5),
    Map<String, String>? headers,
  }) async {
    return _race<String?>(
      urls,
      timeout: timeout,
      task: (url) async {
        final res = await _client.get(Uri.parse(url), headers: headers).timeout(timeout);
        if (res.statusCode != 200) return null;
        final bytes = res.bodyBytes;

        try {
          return utf8.decode(bytes);
        } catch (_) {
          // 🔥 fallback GBK
          return await CharsetConverter.decode("gbk", bytes);
        }
      },
    );
  }

  static Future<T?> _race<T>(
    List<String> urls, {
    required Future<T?> Function(String url) task,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<T?>();
    final active = <Future>[];

    for (final url in urls) {
      final future = Future(() async {
        try {
          final result = await task(url);
          if (result == null) return;

          if (!completer.isCompleted) {
            completer.complete(result);
            debugPrint("🏁 Race winner: $url");
          }
        } catch (_) {}
      });

      active.add(future);
    }

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }
}
