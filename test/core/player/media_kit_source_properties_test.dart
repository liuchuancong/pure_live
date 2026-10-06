import 'package:flutter_test/flutter_test.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/core/playback_source_hints.dart';
import 'package:pure_live/core/player/kernel/media_kit_live_properties.dart';

const _proxy = 'http://127.0.0.1:7897';

Map<String, String> _properties(String url, {String? declared, bool live = true, bool seekStart = false}) =>
    MediaKitLiveProperties.sourceProperties(
      uri: Uri.parse(url),
      declaredFormat: declared,
      proxy: _proxy,
      live: live,
      seekStart: seekStart,
    );

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

    test('普通直播 FLV 关掉强制可 seek', () {
      // 换绑视频输出时 mpv 会按当前(直播流巨大的)时间戳发起保位置 seek, 线性流
      // seek 不了又失败, 清掉 demuxer 缓冲引发一次重缓冲, 看起来就是播放-卡顿-又播放。
      // 普通直播没有合法 seek 目标, 关掉即可。cache-pause 仍保留: 断流时按目标回灌。
      expect(_properties('https://cdn.example.com/live/room.flv'), {
        'http-proxy': _proxy,
        'demuxer-lavf-format': '',
        'force-seekable': 'no',
        'cache-pause': 'yes',
      });
    });

    test('轮播房带声明起播点时保持可 seek', () {
      // B 站轮播/回放房靠一次 seek 落到平台声明的 video.start, 这条必须仍可 seek。
      expect(_properties('https://cdn.example.com/live/room.flv', seekStart: true), {
        'http-proxy': _proxy,
        'demuxer-lavf-format': '',
        'force-seekable': 'yes',
        'cache-pause': 'yes',
      });
    });

    test('本地文件不是直播, 保持可拖动', () {
      // 本地录播播放页走 SourceType.file, live=false, 进度条要能任意拖动。
      expect(_properties('/storage/emulated/0/Download/PureLiveRecords/a.mp4', live: false)['force-seekable'], 'yes');
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
        // 回环 FLV 中继仍是线性直播流, 同样没有合法 seek 目标。
        'force-seekable': 'no',
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

    test('声明起播点随源的 metadata 往返, 零值不写键', () {
      expect(playbackSeekStartMetadata(const Duration(seconds: 30)), isNotEmpty);
      expect(playbackSeekStartMetadata(Duration.zero), isEmpty);

      final rotation = PlayerSource(
        id: SourceId('live-3'),
        uri: Uri.parse('https://cdn.example.com/live/room.flv'),
        metadata: playbackSeekStartMetadata(const Duration(minutes: 2)),
      );
      expect(hasDeclaredSeekStart(rotation), isTrue);

      final plain = PlayerSource(id: SourceId('live-4'), uri: Uri.parse('https://cdn.example.com/room.flv'));
      expect(hasDeclaredSeekStart(plain), isFalse);
    });
  });
}
