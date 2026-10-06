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

    test('装配表不得声明按源属性，否则和 beforeOpen 抢同一把钥匙', () {
      // 工厂的 configure 收的是 void 回调，装配表的 Future 没人 await，它的写入
      // 可能落在某条源打开之后。同一个属性有两个所有者，谁最后生效就是随机的——
      // Twitch 那次复现里，按源写的 force-seekable=no 就被这张表的 yes 盖掉了。
      final properties = MediaKitLiveProperties.build();
      for (final key in const ['http-proxy', 'demuxer-lavf-format', 'force-seekable', 'cache-pause']) {
        expect(properties.containsKey(key), isFalse, reason: key);
      }
      // 与 cache-pause 配套的等待时长是全局的，留在表里。
      expect(properties.containsKey('cache-pause-wait'), isTrue);
    });

    test('代理出口被 CDN 拒吐流的主机强制直连', () {
      // Steam 广播按请求 IP 做缓存亲和：代理出口清单 200、分片 410 Gone，直连 200。
      expect(playsDirectBehindProxy(Uri.parse('https://cache3-tyo3.steamcontent.com/broadcast/x/master.m3u8')), isTrue);
      expect(playsDirectBehindProxy(Uri.parse('https://steamcontent.com/x.m3u8')), isTrue);
      // 后缀必须整段匹配，不能让 notsteamcontent.com 误入。
      expect(playsDirectBehindProxy(Uri.parse('https://notsteamcontent.com/x.m3u8')), isFalse);
      expect(playsDirectBehindProxy(Uri.parse('https://apn14.playlist.ttvnw.net/v1/playlist/x.m3u8')), isFalse);
      // 直连覆写要反映到按源属性上：代理开着也发空 http-proxy。
      expect(
        MediaKitLiveProperties.sourceProperties(
          uri: Uri.parse('https://cache3-tyo3.steamcontent.com/broadcast/x/master.m3u8'),
          declaredFormat: 'hls',
          proxy: 'http://127.0.0.1:7897',
        )['http-proxy'],
        '',
      );
    });
  });
}
