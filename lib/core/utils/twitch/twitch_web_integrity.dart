import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/core/utils/webview_proxy_scope.dart';

class TwitchWebIntegrityToken {
  const TwitchWebIntegrityToken({required this.token, required this.expiration});

  final String token;
  final int expiration;
}

/// Acquires Twitch's browser-attested integrity token when a plain HTTP
/// request is classified as an automated client.
///
/// Twitch's own web flow loads the KPSDK bootstrap script in a browser origin,
/// then uses its patched `fetch` implementation for `/integrity`. A headless
/// WebView reproduces that narrow flow without loading or rendering Twitch's
/// full directory page.
class TwitchWebIntegrityProvider {
  static const String scriptUrl =
      'https://k.twitchcdn.net/149e9513-01fa-4fb0-aad4-566afd725d1b/2d206a39-8ed7-437e-a3be-862e0f06eea3/p.js';

  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static final Map<String, Future<TwitchWebIntegrityToken?>> _inFlight = <String, Future<TwitchWebIntegrityToken?>>{};
  static Future<void> _evaluationTail = Future<void>.value();

  static Future<TwitchWebIntegrityToken?> acquire({
    required String clientId,
    required String deviceId,
    required String userAgent,
    String channel = 'twitch',
    String? proxyHost,
    int? proxyPort,
  }) async {
    if (!isSupported) return null;

    // ProxyController is process-global on Android. Reuse the active browser
    // acquisition instead of racing multiple headless WebViews that could
    // overwrite and clear each other's proxy configuration.
    final key = '$clientId\u0000$deviceId\u0000${proxyHost ?? ''}\u0000${proxyPort ?? 0}';
    final active = _inFlight[key];
    if (active != null) return active;
    final request = _acquire(
      clientId: clientId,
      deviceId: deviceId,
      userAgent: userAgent,
      channel: channel,
      proxyHost: proxyHost,
      proxyPort: proxyPort,
    );
    _inFlight[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  static Future<TwitchWebIntegrityToken?> _acquire({
    required String clientId,
    required String deviceId,
    required String userAgent,
    required String channel,
    String? proxyHost,
    int? proxyPort,
  }) async {
    final value = await _evaluate(
      functionBody: buildBootstrapScript(clientId: clientId, deviceId: deviceId),
      userAgent: userAgent,
      channel: channel,
      proxyHost: proxyHost,
      proxyPort: proxyPort,
    );
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! Map) {
      throw StateError('Twitch browser integrity script returned an invalid result');
    }
    final token = decoded['token']?.toString().trim() ?? '';
    final expirationValue = decoded['expiration'];
    final expiration = expirationValue is num
        ? expirationValue.toInt()
        : int.tryParse(expirationValue?.toString() ?? '');
    if (token.isEmpty || expiration == null) {
      throw StateError('Twitch browser integrity script returned an incomplete token');
    }
    return TwitchWebIntegrityToken(token: token, expiration: expiration);
  }

  /// Executes the public GraphQL request in Chromium when Twitch rejects the
  /// Dart socket/TLS fingerprint. This is intentionally a last-resort path and
  /// keeps account cookies out of the headless browser session.
  static Future<dynamic> postGraphQl({
    required String body,
    required String clientId,
    required String deviceId,
    required String userAgent,
    String? integrityToken,
    void Function(TwitchWebIntegrityToken token)? onIntegrityToken,
    String channel = 'twitch',
    String? proxyHost,
    int? proxyPort,
  }) async {
    if (!isSupported) return null;
    final value = await _evaluate(
      functionBody: buildGraphQlScript(
        body: body,
        clientId: clientId,
        deviceId: deviceId,
        integrityToken: integrityToken,
      ),
      userAgent: userAgent,
      channel: channel,
      proxyHost: proxyHost,
      proxyPort: proxyPort,
    );
    if (value is! String || value.trim().isEmpty) {
      throw StateError('Twitch browser GraphQL returned an empty response');
    }
    final envelope = jsonDecode(value);
    if (envelope is! Map) {
      throw StateError('Twitch browser GraphQL returned an invalid envelope');
    }
    final responseBody = envelope['responseBody']?.toString() ?? '';
    if (responseBody.isEmpty) {
      throw StateError('Twitch browser GraphQL returned an empty response body');
    }
    final integrity = envelope['integrity'];
    if (integrity is Map) {
      final token = integrity['token']?.toString().trim() ?? '';
      final expirationValue = integrity['expiration'];
      final expiration = expirationValue is num
          ? expirationValue.toInt()
          : int.tryParse(expirationValue?.toString() ?? '');
      if (token.isNotEmpty && expiration != null) {
        onIntegrityToken?.call(TwitchWebIntegrityToken(token: token, expiration: expiration));
      }
    }
    return jsonDecode(responseBody);
  }

  static Future<dynamic> _evaluate({
    required String functionBody,
    required String userAgent,
    required String channel,
    String? proxyHost,
    int? proxyPort,
  }) async {
    // Android WebView's ProxyController is process-global. Serialize every
    // integrity/GraphQL browser operation, not only identical token requests,
    // so one request never clears another request's proxy override.
    final predecessor = _evaluationTail;
    final release = Completer<void>();
    _evaluationTail = release.future;
    try {
      await predecessor;
      // The proxy override is process-global; share its queue with every
      // other headless WebView resolver.
      return await WebViewProxyScope.run(
        () => _evaluateExclusive(functionBody: functionBody, userAgent: userAgent, channel: channel),
        proxyHost: proxyHost ?? '',
        proxyPort: proxyPort ?? 0,
      );
    } finally {
      release.complete();
    }
  }

  static Future<dynamic> _evaluateExclusive({
    required String functionBody,
    required String userAgent,
    required String channel,
  }) async {
    final controllerCompleter = Completer<InAppWebViewController>();
    final pageCompleter = Completer<void>();
    HeadlessInAppWebView? webView;

    try {
      final origin = WebUri('https://www.twitch.tv/$channel');
      final initialData = InAppWebViewInitialData(
        data: '<!doctype html><html><head></head><body></body></html>',
        baseUrl: origin,
        historyUrl: origin,
      );
      webView = HeadlessInAppWebView(
        // Android's loadDataWithBaseURL keeps a synthetic document origin on
        // some WebView builds. Kasada then never emits kpsdk-ready. Navigate
        // to Twitch's real origin and fulfil only the main document with a
        // blank page, matching Streamlink's proven Chromium/CDP flow.
        initialData: Platform.isAndroid ? null : initialData,
        initialUrlRequest: Platform.isAndroid ? URLRequest(url: origin) : null,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          cacheEnabled: true,
          // Let Android WebView expose its internally consistent Chromium UA
          // and client hints. A Windows UA paired with an Android Chromium TLS
          // fingerprint is precisely the mismatch Twitch classifies as an
          // automated client.
          userAgent: Platform.isAndroid ? null : userAgent,
          transparentBackground: true,
        ),
        shouldInterceptRequest: Platform.isAndroid
            ? (controller, request) async {
                if (request.isForMainFrame == true && request.url.host == 'www.twitch.tv') {
                  return WebResourceResponse(
                    contentType: 'text/html',
                    contentEncoding: 'utf-8',
                    data: Uint8List.fromList(utf8.encode('<!doctype html>')),
                    headers: const <String, String>{'Access-Control-Allow-Origin': '*', 'Cache-Control': 'no-store'},
                    statusCode: 200,
                    reasonPhrase: 'OK',
                  );
                }
                return null;
              }
            : null,
        onWebViewCreated: (controller) {
          if (!controllerCompleter.isCompleted) controllerCompleter.complete(controller);
        },
        onLoadStop: (controller, url) {
          if (!pageCompleter.isCompleted) pageCompleter.complete();
        },
      );

      await webView.run();
      final controller = await controllerCompleter.future.timeout(const Duration(seconds: 10));
      await pageCompleter.future.timeout(const Duration(seconds: 10));
      final result = await controller
          .callAsyncJavaScript(functionBody: functionBody)
          .timeout(const Duration(seconds: 30));
      if (result == null || result.error != null) {
        throw StateError('Twitch browser request failed: ${result?.error ?? 'no result'}');
      }
      return result.value;
    } finally {
      if (webView?.isRunning() == true) {
        await webView!.dispose();
      }
    }
  }

  @visibleForTesting
  static String buildGraphQlScript({
    required String body,
    required String clientId,
    required String deviceId,
    String? integrityToken,
  }) {
    final encodedBody = jsonEncode(body);
    final encodedHeaders = jsonEncode(<String, String>{
      'Accept': 'application/json',
      'Content-Type': 'text/plain;charset=UTF-8',
      'Client-ID': clientId,
      'Device-Id': deviceId,
    });
    final encodedIntegrityHeaders = jsonEncode(<String, String>{'Client-ID': clientId, 'X-Device-Id': deviceId});
    final encodedInitialToken = jsonEncode(integrityToken?.trim() ?? '');
    final source = jsonEncode(scriptUrl);
    return '''
const gqlHeaders = $encodedHeaders;
const requestBody = $encodedBody;
const initialToken = $encodedInitialToken;
const requestGraphQl = async token => {
  const headers = Object.assign({}, gqlHeaders);
  if (token) headers['Client-Integrity'] = token;
  const response = await window.fetch('https://gql.twitch.tv/gql', {
    headers,
    body: requestBody,
    method: 'POST',
    mode: 'cors',
    credentials: 'omit'
  });
  return {status: response.status, body: await response.text()};
};
const failedIntegrity = body => {
  let decoded;
  try {
    decoded = JSON.parse(body);
  } catch (_) {
    return false;
  }
  const envelopes = Array.isArray(decoded) ? decoded : [decoded];
  return envelopes.some(envelope => {
    if (!envelope || !Array.isArray(envelope.errors)) return false;
    return envelope.errors.some(error => {
      const message = String(error && error.message || '').toLowerCase();
      return message.includes('failed integrity check') || message.includes('integrity token');
    });
  });
};
const validateGraphQl = result => {
  if (result.status < 200 || result.status >= 300) {
    throw new Error('Unexpected Twitch GraphQL status ' + result.status + ': ' + result.body.slice(0, 240));
  }
  return result;
};
let result = await requestGraphQl(initialToken);
let integrity = null;
if (failedIntegrity(result.body)) {
  integrity = await new Promise((resolve, reject) => {
    let settled = false;
    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      reject('Twitch KPSDK readiness timed out');
    }, 20000);
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      callback(value);
    };
    const configure = () => {
      window.KPSDK.configure([{
        protocol: 'https:',
        method: 'POST',
        domain: 'gql.twitch.tv',
        path: '/integrity'
      }]);
    };
    const fetchIntegrity = async () => {
      const response = await window.fetch('https://gql.twitch.tv/integrity', {
        headers: $encodedIntegrityHeaders,
        body: null,
        method: 'POST',
        mode: 'cors',
        credentials: 'omit'
      });
      const responseBody = await response.text();
      if (response.status !== 200) {
        throw new Error('Unexpected Twitch integrity status ' + response.status + ': ' + responseBody.slice(0, 240));
      }
      return JSON.parse(responseBody);
    };
    document.addEventListener('kpsdk-load', configure, {once: true});
    document.addEventListener('kpsdk-ready', () => {
      fetchIntegrity().then(
        value => finish(resolve, value),
        error => finish(reject, String(error))
      );
    }, {once: true});
    const script = document.createElement('script');
    script.addEventListener('error', () => finish(reject, 'Twitch KPSDK script failed to load'));
    script.src = $source;
    document.body.appendChild(script);
  });
  const token = integrity && typeof integrity.token === 'string' ? integrity.token : '';
  if (!token) throw new Error('Twitch integrity endpoint returned an incomplete token');
  result = await requestGraphQl(token);
  if (failedIntegrity(result.body)) {
    throw new Error('Twitch Chromium GraphQL response still failed integrity validation');
  }
}
validateGraphQl(result);
return JSON.stringify({responseBody: result.body, integrity});
''';
  }

  @visibleForTesting
  static String buildBootstrapScript({required String clientId, required String deviceId}) {
    final headers = jsonEncode(<String, String>{'Client-ID': clientId, 'X-Device-Id': deviceId});
    final source = jsonEncode(scriptUrl);
    return '''
return await new Promise((resolve, reject) => {
  let settled = false;
  const timeout = setTimeout(() => {
    if (settled) return;
    settled = true;
    reject('Twitch KPSDK readiness timed out: ' + JSON.stringify({
      href: location.href,
      origin: location.origin,
      readyState: document.readyState,
      kpsdk: typeof window.KPSDK,
      userAgent: navigator.userAgent
    }));
  }, 20000);
  const finish = (callback, value) => {
    if (settled) return;
    settled = true;
    clearTimeout(timeout);
    callback(value);
  };
  const configure = () => {
    window.KPSDK.configure([{
      protocol: 'https:',
      method: 'POST',
      domain: 'gql.twitch.tv',
      path: '/integrity'
    }]);
  };
  const fetchIntegrity = async () => {
    const response = await window.fetch('https://gql.twitch.tv/integrity', {
      headers: $headers,
      body: null,
      method: 'POST',
      mode: 'cors',
      credentials: 'omit'
    });
    if (response.status !== 200) {
      throw new Error('Unexpected Twitch integrity status ' + response.status);
    }
    return JSON.stringify(await response.json());
  };
  document.addEventListener('kpsdk-load', configure, {once: true});
  document.addEventListener('kpsdk-ready', () => {
    fetchIntegrity().then(
      value => finish(resolve, value),
      error => finish(reject, String(error))
    );
  }, {once: true});
  const script = document.createElement('script');
  script.addEventListener('error', () => finish(reject, 'Twitch KPSDK script failed to load'));
  script.src = $source;
  document.body.appendChild(script);
});
''';
  }
}
