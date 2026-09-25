import 'dart:async';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/services/settings_service.dart';

/// Runs headless-WebView work behind the user's application proxy.
///
/// Android's WebView [ProxyController] is process-global, so every resolver
/// that loads a site page must share one queue: otherwise one resolver's
/// cleanup clears the override while another page is still loading. Windows
/// WebView2 follows the system proxy and is left unchanged.
class WebViewProxyScope {
  const WebViewProxyScope._();

  static Future<void> _tail = Future<void>.value();

  /// Applies [proxyHost]:[proxyPort], or the enabled application proxy from
  /// settings when neither is given, for the duration of [body].
  static Future<T> run<T>(Future<T> Function() body, {String? proxyHost, int? proxyPort}) async {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = release.future;
    try {
      await predecessor;
      final rule = proxyHost == null && proxyPort == null
          ? _settingsRule()
          : proxyRule(host: proxyHost, port: proxyPort);
      return await _withOverride(rule, body);
    } finally {
      release.complete();
    }
  }

  /// `host:port` for a usable proxy, otherwise null.
  static String? proxyRule({required String? host, required int? port}) {
    final value = host?.trim() ?? '';
    if (value.isEmpty || port == null || port <= 0 || port > 65535) return null;
    return '$value:$port';
  }

  static String? _settingsRule() {
    try {
      final proxy = SettingsService.to.proxy;
      if (!proxy.enableAppProxy.value) return null;
      return proxyRule(host: proxy.appProxyHost.value, port: proxy.appProxyPort.value);
    } catch (_) {
      return null;
    }
  }

  static Future<T> _withOverride<T>(String? rule, Future<T> Function() body) async {
    if (rule == null || !Platform.isAndroid) return body();
    final controller = ProxyController.instance();
    var overridden = false;
    try {
      if (await WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
        await controller.setProxyOverride(
          settings: ProxySettings(proxyRules: [ProxyRule(url: rule)]),
        );
        overridden = true;
      }
      return await body();
    } finally {
      if (overridden) {
        try {
          await controller.clearProxyOverride();
        } catch (_) {
          /* The next override replaces it anyway. */
        }
      }
    }
  }
}
