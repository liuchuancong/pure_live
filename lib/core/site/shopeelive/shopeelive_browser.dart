import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/core/utils/webview_proxy_scope.dart';

abstract interface class ShopeeLiveSessionResolver {
  Future<Map<String, dynamic>> resolve(String sessionId);
}

/// Resolves a Shopee Live session inside the official public web application.
///
/// The session endpoint is protected by Shopee's browser fingerprint and SAP
/// request middleware. Reusing the site's own loaded API module keeps those
/// dynamic headers tied to the same browser context instead of persisting a
/// short-lived token in application storage.
class ShopeeLiveBrowserSessionResolver implements ShopeeLiveSessionResolver {
  static const String pageUrl = 'https://live.shopee.co.id/guide-download';

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  static final Map<String, Future<Map<String, dynamic>>> _inFlight = <String, Future<Map<String, dynamic>>>{};
  static Future<void> _evaluationTail = Future<void>.value();

  @override
  Future<Map<String, dynamic>> resolve(String sessionId) {
    if (!isSupported) throw UnsupportedError('Shopee Live browser session resolver is not supported');
    final active = _inFlight[sessionId];
    if (active != null) return active;
    final request = _serializedResolve(sessionId);
    _inFlight[sessionId] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[sessionId], request)) _inFlight.remove(sessionId);
    });
  }

  static Future<Map<String, dynamic>> _serializedResolve(String sessionId) async {
    final predecessor = _evaluationTail;
    final release = Completer<void>();
    _evaluationTail = release.future;
    try {
      await predecessor;
      return await WebViewProxyScope.run(() => _resolveExclusive(sessionId));
    } finally {
      release.complete();
    }
  }

  static Future<Map<String, dynamic>> _resolveExclusive(String sessionId) async {
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageCompleter = Completer<void>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(pageUrl)),
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, cacheEnabled: true, transparentBackground: true),
        onWebViewCreated: (controller) {
          if (!controllerCompleter.isCompleted) controllerCompleter.complete(controller);
        },
        onLoadStop: (controller, url) {
          if (!pageCompleter.isCompleted) pageCompleter.complete();
        },
      );
      await webView.run();
      final controller = await controllerCompleter.future.timeout(const Duration(seconds: 12));
      await pageCompleter.future.timeout(const Duration(seconds: 20));
      final result = await controller
          .callAsyncJavaScript(functionBody: buildSessionScript(sessionId))
          .timeout(const Duration(seconds: 35));
      if (result == null || result.error != null || result.value is! String) {
        throw StateError('Shopee Live browser resolver returned an invalid result');
      }
      final decoded = jsonDecode(result.value! as String);
      if (decoded is! Map) throw StateError('Shopee Live browser resolver returned an invalid envelope');
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } finally {
      if (webView?.isRunning() == true) await webView!.dispose();
    }
  }

  @visibleForTesting
  static String buildSessionScript(String sessionId) {
    final encodedSessionId = jsonEncode(sessionId);
    return '''
const sessionId = $encodedSessionId;
const deadline = Date.now() + 15000;
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
while (typeof window.webpackJsonp !== 'function' && Date.now() < deadline) {
  await sleep(50);
}
if (typeof window.webpackJsonp !== 'function') {
  throw new Error('Shopee Live webpack runtime did not load');
}
if (typeof window.__pureLiveShopeeRequire !== 'function') {
  const moduleId = 990001;
  window.webpackJsonp([990001], {
    [moduleId]: function(module, exports, require) {
      window.__pureLiveShopeeRequire = require;
    }
  }, [moduleId]);
}
const require = window.__pureLiveShopeeRequire;
const findApi = () => {
  for (const module of Object.values(require.c || {})) {
    const exported = module && module.exports;
    for (const candidate of [exported, exported && exported.default, exported && exported.a]) {
      if (candidate && typeof candidate.getSessionInfoWithId === 'function') return candidate;
    }
  }
  return null;
};
let api = findApi();
if (!api) {
  for (const [id, factory] of Object.entries(require.m || {})) {
    if (!String(factory).includes('getSessionInfoWithId')) continue;
    try { require(id); } catch (_) {}
    api = findApi();
    if (api) break;
  }
}
if (!api) throw new Error('Shopee Live session module was not found');
const tuple = await api.getSessionInfoWithId(sessionId);
const data = Array.isArray(tuple) ? tuple[0] : tuple;
const error = Array.isArray(tuple) ? tuple[1] : null;
if (error || !data || typeof data !== 'object') {
  throw new Error('Shopee Live session request failed');
}
return JSON.stringify(data);
''';
  }
}
