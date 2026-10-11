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
}
