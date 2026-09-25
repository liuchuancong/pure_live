import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/utils/webview_proxy_scope.dart';

void main() {
  test('proxy rule needs a host and a valid port', () {
    expect(WebViewProxyScope.proxyRule(host: ' 127.0.0.1 ', port: 7897), '127.0.0.1:7897');
    expect(WebViewProxyScope.proxyRule(host: '', port: 7897), isNull);
    expect(WebViewProxyScope.proxyRule(host: null, port: 7897), isNull);
    expect(WebViewProxyScope.proxyRule(host: 'proxy', port: 0), isNull);
    expect(WebViewProxyScope.proxyRule(host: 'proxy', port: 70000), isNull);
  });

  test('WebView work from different resolvers never overlaps', () async {
    final events = <String>[];
    final gate = Completer<void>();
    final first = WebViewProxyScope.run(() async {
      events.add('nimo start');
      await gate.future;
      events.add('nimo end');
    });
    final second = WebViewProxyScope.run(() async => events.add('twitch'), proxyHost: '', proxyPort: 0);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events, ['nimo start']);
    gate.complete();
    await Future.wait([first, second]);
    expect(events, ['nimo start', 'nimo end', 'twitch']);
  });

  test('a failing resolver releases the queue', () async {
    await expectLater(WebViewProxyScope.run<void>(() async => throw StateError('page failed')), throwsStateError);
    expect(await WebViewProxyScope.run(() async => 1), 1);
  });
}
