import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/proxy_routing.dart';

void main() {
  test('LAN proxy hosts need Android 17 local-network access', () {
    for (final host in [
      '192.168.1.238',
      '10.0.0.2',
      '172.16.0.1',
      '172.31.255.254',
      '169.254.10.1',
      'router.lan',
      'nas.local',
      'box.home.arpa',
      '[fd00::1]',
      'fe80::1',
      '192。168。1。2', // Chinese IME dots are normalized first.
    ]) {
      expect(isLocalNetworkProxyHost(host), isTrue, reason: host);
    }
  });

  test('loopback, public and malformed hosts do not', () {
    for (final host in [
      '',
      '127.0.0.1',
      'localhost',
      '::1',
      '172.32.0.1',
      '172.15.0.1',
      '8.8.8.8',
      'proxy.example.com',
      '192.168.1',
      '999.168.1.1',
    ]) {
      expect(isLocalNetworkProxyHost(host), isFalse, reason: host);
    }
  });
}
