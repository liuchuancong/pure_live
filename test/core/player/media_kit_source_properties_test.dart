import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/core/playback_source_hints.dart';
import 'package:pure_live/core/player/kernel/media_kit_live_properties.dart';

const _proxy = 'http://127.0.0.1:7897';

Map<String, String> _properties(String url, {String? declared}) =>
    MediaKitLiveProperties.sourceProperties(uri: Uri.parse(url), declaredFormat: declared, proxy: _proxy);

void main() {
  group('按源决定的引擎属性', () {
    test('上游 HLS 指死解复用器，并撤掉点播那套缓存假设', () {
      expect(_properties('https://cdn.example.com/live/index.m3u8'), {
        'http-proxy': _proxy,
        'demuxer-lavf-format': 'hls',
        // 直播清单读到边缘就没有更多数据，cache-pause-wait 要的 4 秒永远凑不齐。
        'force-seekable': 'no',
        'cache-pause': 'no',
      });
    });

    test('渐进式源保留可拖动与自动暂停', () {
      // 数据连续到达，缓存目标凑得齐；B 站轮播房还要靠 seek 落到声明的起播位置。
      expect(_properties('https://cdn.example.com/live/room.flv'), {
        'http-proxy': _proxy,
        'demuxer-lavf-format': '',
        'force-seekable': 'yes',
        'cache-pause': 'yes',
      });
    });

    test('平台声明优先于 URL 形状', () {
      // 声明是 flv，就算地址长得像清单也不能按 HLS 解。
      expect(_properties('https://cdn.example.com/live/index.m3u8', declared: 'flv')['demuxer-lavf-format'], '');
      // 声明是 hls，就算地址没有后缀（Twitch 把签名塞在路径里）也要指死。
      expect(
        _properties('https://apn12.playlist.ttvnw.net/v1/playlist/Co0GAIs', declared: 'hls')['demuxer-lavf-format'],
        'hls',
      );
      // 声明 other（IPTV 的 ts、udpxy）不当清单。
      expect(_properties('https://cdn.example.com/live/index.m3u8', declared: 'other')['demuxer-lavf-format'], '');
    });

    test('非 HLS 上游清空强制值，不漏给下一条源', () {
      // 引擎跨源复用：上一条源强制的 hls 必须被清掉，否则这条 FLV 会被按 HLS 解。
      expect(_properties('https://cdn.example.com/live/room.flv')['demuxer-lavf-format'], '');
      expect(_properties('http://192.168.1.5:1234/udp/239.0.0.1:5140')['demuxer-lavf-format'], '');
    });

    test('本机输入既不送代理也不猜容器', () {
      // 回环中继：代理转发本机端口既多一跳，也会被拒绝本地目标的代理打死；
      // 而 Dart 重写的 HEVC FLV 中继输出的根本不是 HLS，指死解复用器只会打死它。
      expect(_properties('http://127.0.0.1:4321/ingest/index.m3u8'), {
        'http-proxy': '',
        'demuxer-lavf-format': '',
        // 内容仍然是直播清单，缓存策略照样要撤掉点播那套假设。
        'force-seekable': 'no',
        'cache-pause': 'no',
      });
      expect(_properties('http://localhost:4321/live.flv'), {
        'http-proxy': '',
        'demuxer-lavf-format': '',
        'force-seekable': 'yes',
        'cache-pause': 'yes',
      });
      expect(_properties('http://[::1]:4321/index.m3u8')['http-proxy'], '');
      expect(isPrivatePlaybackInput(Uri(scheme: 'owned', path: 'room')), isTrue);
    });

    test('声明随源的 metadata 往返', () {
      final stamped = PlayerSource(
        id: SourceId('live-1'),
        uri: Uri.parse('https://cdn.example.com/index.m3u8'),
        metadata: playbackStreamFormatMetadata('hls'),
      );
      expect(declaredStreamFormatOf(stamped), 'hls');

      final bare = PlayerSource(id: SourceId('live-2'), uri: Uri.parse('https://cdn.example.com/room.flv'));
      expect(playbackStreamFormatMetadata(null), isEmpty);
      expect(declaredStreamFormatOf(bare), isNull);
    });
  });
}
