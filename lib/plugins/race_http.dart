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
    if (urls.isEmpty) return null;

    final completer = Completer<String?>();
    var remaining = urls.length;
    final clients = <http.Client>[];
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    for (final url in urls) {
      final client = http.Client();
      clients.add(client);
      unawaited(
        Future(() async {
          try {
            final request = http.Request('GET', Uri.parse(url));
            if (headers != null) request.headers.addAll(headers);
            // Several GitHub proxies reject HEAD. A one-byte GET exercises the
            // same route without downloading the asset used by the caller.
            request.headers.putIfAbsent('Range', () => 'bytes=0-0');
            final res = await client.send(request).timeout(timeout);
            if ((res.statusCode == 200 || res.statusCode == 206) && !completer.isCompleted) {
              completer.complete(url);
            }
          } catch (_) {
            // Another mirror may still win the race.
          } finally {
            client.close();
            remaining--;
            if (remaining == 0 && !completer.isCompleted) completer.complete(null);
          }
        }),
      );
    }

    final result = await completer.future;
    timer.cancel();
    for (final client in clients) {
      client.close();
    }
    return result;
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
    for (final url in urls) {
      unawaited(
        Future(() async {
          try {
            final result = await task(url);
            if (result == null) return;

            if (!completer.isCompleted) {
              completer.complete(result);
              debugPrint("🏁 Race winner: $url");
            }
          } catch (_) {}
        }),
      );
    }

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }
}
