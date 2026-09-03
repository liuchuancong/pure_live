import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/proxy_routing.dart';

void main() {
  group('proxy routing', () {
    test('normalizes punctuation emitted by Chinese input methods', () {
      expect(normalizeProxyHost(' 127。0．0。1 '), '127.0.0.1');
      expect(normalizeProxyHost('［::1］'), '[::1]');
    });

    test('builds direct and proxy directives without invalid half-edited values', () {
      expect(buildProxyDirective(enabled: false, host: '127.0.0.1', port: 7897), 'DIRECT');
      expect(buildProxyDirective(enabled: true, host: '', port: 7897), 'DIRECT');
      expect(buildProxyDirective(enabled: true, host: 'localhost', port: 0), 'DIRECT');
      expect(
        buildProxyDirective(enabled: true, host: 'localhost', port: 7897),
        'PROXY localhost:7897',
      );
      expect(
        buildProxyDirective(enabled: true, host: '127。0。0。1', port: 7897),
        'PROXY 127.0.0.1:7897',
      );
      expect(buildProxyDirective(enabled: true, host: '::1', port: 7897), 'PROXY [::1]:7897');
    });

    test('rejects proxy-directive injection', () {
      expect(buildProxyDirective(enabled: true, host: 'localhost; DIRECT', port: 7897), 'DIRECT');
      expect(buildProxyDirective(enabled: true, host: 'localhost\nDIRECT', port: 7897), 'DIRECT');
    });
  });
}
