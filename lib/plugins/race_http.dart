import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class RaceHttp {
  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>?> fetchJson(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 5),
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

        return res.body;
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
