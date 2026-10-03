import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/core/playback_proxy_policy.dart';
import 'package:pure_live/core/player/kernel/media_kit_live_properties.dart';

void main() {
  group('播放器代理', () {
    test('远端输入拿到 http:// 形式的代理，私有输入和应用直连都不给', () {
      expect(PlaybackProxyPolicy.nativeUrl('PROXY 127.0.0.1:7897', privateInput: false), 'http://127.0.0.1:7897');
      // 回环中继与自有输入必须绕过代理：本机端口经代理转发既多一跳，也会被
      // 拒绝本地目标的代理直接打死。
      expect(PlaybackProxyPolicy.nativeUrl('PROXY 127.0.0.1:7897', privateInput: true), '');
      expect(PlaybackProxyPolicy.nativeUrl('DIRECT', privateInput: false), '');
    });

    test('引擎属性里始终带 http-proxy，值要么是空串要么是 mpv 认的 http 端点', () {
      // 空串而不是缺键：mpv 把空串读作"不用代理"，这样关掉开关能清掉上一次的值。
      // 具体值不钉死——它来自本机设置，没配播放器代理时还会跟随 Windows 系统代理。
      final properties = MediaKitLiveProperties.build();
      expect(properties.containsKey('http-proxy'), isTrue);
      final value = properties['http-proxy']!;
      expect(value.isEmpty || value.startsWith('http://'), isTrue, reason: 'mpv 只认 http:// 形式的代理端点');
    });
  });
}
