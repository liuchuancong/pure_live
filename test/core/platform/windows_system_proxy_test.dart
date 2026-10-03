import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/platform/windows_system_proxy.dart';

void main() {
  group('Windows 系统代理解析', () {
    test('单端点写法两个协议共用', () {
      expect(parseWindowsProxyServer('127.0.0.1:7897'), ('127.0.0.1', 7897));
      expect(parseWindowsProxyServer('  127.0.0.1:7897  '), ('127.0.0.1', 7897));
    });

    test('分协议写法优先 https，缺一边就借另一边', () {
      expect(parseWindowsProxyServer('http=127.0.0.1:7890;https=127.0.0.1:7897'), ('127.0.0.1', 7897));
      expect(parseWindowsProxyServer('http=127.0.0.1:7890'), ('127.0.0.1', 7890));
      expect(parseWindowsProxyServer('https=127.0.0.1:7897'), ('127.0.0.1', 7897));
    });

    test('容错用户从系统设置里抄来的写法', () {
      expect(parseWindowsProxyServer('http://127.0.0.1:7897'), ('127.0.0.1', 7897));
      expect(parseWindowsProxyServer('127.0.0.1:7897/'), ('127.0.0.1', 7897));
      expect(parseWindowsProxyServer('[::1]:7897'), ('::1', 7897));
      expect(parseWindowsProxyServer('proxy.lan:8080'), ('proxy.lan', 8080));
    });

    test('用不上的和残缺的一律不认', () {
      expect(parseWindowsProxyServer(''), isNull);
      expect(parseWindowsProxyServer('127.0.0.1'), isNull);
      expect(parseWindowsProxyServer('127.0.0.1:'), isNull);
      expect(parseWindowsProxyServer('127.0.0.1:70000'), isNull);
      expect(parseWindowsProxyServer('127.0.0.1:port'), isNull);
      // socks/ftp 播放器和 dio 都不认，认下来只会让所有请求失败。
      expect(parseWindowsProxyServer('socks=127.0.0.1:1080'), isNull);
      expect(parseWindowsProxyServer('ftp=127.0.0.1:21'), isNull);
    });
  });
}
