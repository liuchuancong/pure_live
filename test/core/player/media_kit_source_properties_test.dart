import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/core/playback_source_hints.dart';
import 'package:pure_live/core/player/kernel/media_kit_live_properties.dart';

const _proxy = 'http://127.0.0.1:7897';

Map<String, String> _properties(String url, {String? declared}) =>
    MediaKitLiveProperties.sourceProperties(uri: Uri.parse(url), declaredFormat: declared, proxy: _proxy);

void main() {
  group('按源决定的引擎属性', () {
    test('上游 HLS 指死解复用器，跳过格式探测', () {
      expect(_properties('https://cdn.example.com/live/index.m3u8'), {
        'http-proxy': _proxy,
        'demuxer-lavf-format': 'hls',
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
      for (final url in [
        'http://127.0.0.1:4321/ingest/index.m3u8',
        'http://localhost:4321/live.flv',
        'http://[::1]:4321/index.m3u8',
      ]) {
        expect(_properties(url), {'http-proxy': '', 'demuxer-lavf-format': ''}, reason: url);
      }
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
