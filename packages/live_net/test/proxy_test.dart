import 'package:live_net/live_net.dart';
import 'package:test/test.dart';

void main() {
  group('FixedProxyPolicy', () {
    test('falls back to the global route when no site override matches', () {
      const global = HttpProxyRoute(host: '127.0.0.1');
      const policy = FixedProxyPolicy(global: global);

      final route = policy.routeFor(Uri.parse('https://api.example.com/x'), site: 'unknown_site');

      expect(route, same(global));
    });

    test('per-site overrides win over the global route', () {
      const global = HttpProxyRoute(host: '127.0.0.1');
      const override = HttpProxyRoute(host: '10.0.0.1', port: 8080);
      const policy = FixedProxyPolicy(global: global, bySite: {'bilibili': override});

      final route = policy.routeFor(Uri.parse('https://api.bilibili.com/x'), site: 'bilibili');

      expect(route, same(override));
    });

    test('a null per-site override forces direct connection', () {
      const global = HttpProxyRoute(host: '127.0.0.1');
      const policy = FixedProxyPolicy(global: global, bySite: {'huya': null});

      final route = policy.routeFor(Uri.parse('https://www.huya.com/x'), site: 'huya');

      expect(route, isNull);
    });

    test('no policy configured means no decision (null)', () {
      const policy = FixedProxyPolicy();

      expect(policy.routeFor(Uri.parse('https://api.example.com/x')), isNull);
    });

    test('routes are pooled by their key', () {
      const route = HttpProxyRoute(host: '127.0.0.1');

      expect(route.key, 'http://127.0.0.1:7897');
      expect(const DirectRoute().key, 'direct');
    });
  });

  group('bypassesProxy', () {
    test('loopback addresses bypass by literal', () {
      expect(bypassesProxy(Uri.parse('http://127.0.0.1:8080/pair')), isTrue);
      expect(bypassesProxy(Uri.parse('http://[::1]:9000/x')), isTrue);
    });

    test('private and link-local ranges bypass', () {
      expect(bypassesProxy(Uri.parse('http://192.168.1.20:8765/status')), isTrue);
      expect(bypassesProxy(Uri.parse('http://10.0.0.5/x')), isTrue);
      expect(bypassesProxy(Uri.parse('http://172.16.9.9/x')), isTrue);
      expect(bypassesProxy(Uri.parse('http://172.32.0.1/x')), isFalse);
      expect(bypassesProxy(Uri.parse('http://169.254.3.4/x')), isTrue);
      expect(bypassesProxy(Uri.parse('http://[fe80::1]/x')), isTrue);
      expect(bypassesProxy(Uri.parse('http://[fd00::a]/x')), isTrue);
    });

    test('localhost and mDNS names bypass', () {
      expect(bypassesProxy(Uri.parse('http://localhost:8080/')), isTrue);
      expect(bypassesProxy(Uri.parse('http://nas.local/x')), isTrue);
      expect(bypassesProxy(Uri.parse('http://box.localhost/x')), isTrue);
    });

    test('public targets stay on the proxy', () {
      expect(bypassesProxy(Uri.parse('https://api.example.com/x')), isFalse);
      expect(bypassesProxy(Uri.parse('http://8.8.8.8/x')), isFalse);
      expect(bypassesProxy(Uri.parse('https://www.huya.com/x')), isFalse);
      expect(bypassesProxy(Uri.parse('http://nas.home.arpa/x')), isFalse);
    });
  });

  group('HttpProxyRoute.ioRouteFor', () {
    test('a LAN target answers DIRECT while the public keeps the proxy', () {
      const route = HttpProxyRoute(host: '127.0.0.1');

      expect(route.ioRouteFor(Uri.parse('http://192.168.1.20:8765/status')), 'DIRECT');
      expect(route.ioRouteFor(Uri.parse('https://api.example.com/x')), 'PROXY 127.0.0.1:7897');
    });

    test('an authenticated LAN target also answers DIRECT', () {
      const route = HttpProxyRoute(host: '127.0.0.1', username: 'u', password: 'p');

      expect(route.ioRouteFor(Uri.parse('http://nas.local/x')), 'DIRECT');
      expect(route.ioRouteFor(Uri.parse('https://api.example.com/x')), 'PROXY u:p@127.0.0.1:7897');
    });
  });
}
