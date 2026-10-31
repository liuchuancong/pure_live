// The pure rules behind an authenticated proxy route: what a credential is
// allowed to appear in, and what is deliberately kept out of it.
//
// Some calls below repeat a default argument on purpose — the test reads better
// when it says which endpoint shape it is exercising.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:live_device/live_device.dart' show SystemProxyEndpoint;
import 'package:live_net/live_net.dart';

import 'package:pure_live/app/providers/network/network_providers.dart';

ProxySettings _settings({
  ProxyMode mode = ProxyMode.manual,
  String host = '127.0.0.1',
  int port = 7897,
  String username = '',
  String password = '',
}) => (mode: mode, host: host, port: port, username: username, password: password);

SystemProxyEndpoint get _noSystemProxy => SystemProxyEndpoint.notConfigured;

void main() {
  test('a credential never reaches the identity a transport is pooled and logged under', () {
    const route = HttpProxyRoute(host: '127.0.0.1', port: 7897, username: 'user', password: 'sekret');
    expect(route.key, 'http://127.0.0.1:7897');
    expect(route.toString(), route.key);
    // The pooled key and the logged form are the same string, and neither may
    // carry the secret: a route name ends up in transport maps and in logs.
    expect([route.key, route.toString()].any((text) => text.contains('sekret')), isFalse);
    expect(route.proxyAuthorizationHeader, 'Basic dXNlcjpzZWtyZXQ=');
  });

  test('the io route carries the credential without a scheme', () {
    const authenticated = HttpProxyRoute(host: '127.0.0.1', port: 7897, username: 'user', password: 'sekret');
    expect(authenticated.ioRoute, 'PROXY user:sekret@127.0.0.1:7897');
    const open = HttpProxyRoute(host: '127.0.0.1', port: 7897);
    expect(open.ioRoute, open.key);
  });

  test('mpv gets the userinfo URL, FFmpeg gets a bare one', () {
    const route = HttpProxyRoute(host: '127.0.0.1', port: 7897, username: 'us er', password: 'p@ss');
    // mpv parses the userinfo, so it is given a URL with the credential in it…
    expect(route.url(includeCredentials: true), 'http://us%20er:p%40ss@127.0.0.1:7897');
    // …and FFmpeg's `-http_proxy` is handed the bare form, which is the only
    // shape that library reads correctly.
    expect(route.url(), 'http://127.0.0.1:7897');
  });

  test('a half-typed credential is treated as none at all', () {
    const noPassword = HttpProxyRoute(host: 'h', port: 1, username: 'user', password: '');
    const noUser = HttpProxyRoute(host: 'h', port: 1, username: '', password: 'pw');
    expect(noPassword.isAuthenticationRequired, isFalse);
    expect(noUser.isAuthenticationRequired, isFalse);
    expect(noPassword.proxyAuthorizationHeader, isNull);
    expect(noPassword.ioRoute, noPassword.key);
  });

  test('the resolved route carries the credential to its own endpoint only', () {
    final route = appProxyRoute(_settings(username: 'user', password: 'sekret'), _noSystemProxy);
    expect(route, isA<HttpProxyRoute>());
    route as HttpProxyRoute;
    expect(route.username, 'user');
    expect(route.password, 'sekret');
    // The system mode has no credential of its own: the reading is an address.
    expect(appProxyRoute(_settings(mode: ProxyMode.off), _noSystemProxy), isA<DirectRoute>());
  });

  test('copyProxySettings replaces only the named parts', () {
    final next = copyProxySettings(
      _settings(username: 'a', password: 'b'),
      host: 'h2',
      port: 9,
    );
    expect((next.host, next.port, next.username, next.password), ('h2', 9, 'a', 'b'));
    expect(next.mode, ProxyMode.manual);
  });
}
