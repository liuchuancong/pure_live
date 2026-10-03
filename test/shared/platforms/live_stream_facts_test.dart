import 'package:flutter_test/flutter_test.dart';
import 'package:media_core_ingest/media_core_ingest.dart';
import 'package:pure_live/domains/live/data/stream/live_stream_ingest.dart';
import 'package:pure_live/shared/platforms/baidulive/baidu_live_api.dart';
import 'package:pure_live/domains/iptv/data/platforms/iptv_site.dart';
import 'package:pure_live/shared/platforms/bilibili/bilibili_site.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/shared/platforms/twitcasting/twitcasting_site.dart';

void main() {
  group('线路事实决定转流方式', () {
    test('FLV 里的 HEVC 交给本机 FFmpeg 转封装', () {
      const facts = (format: LiveStreamFormat.flv, codec: 'hevc', unresolvedChildren: false);

      expect(ingestNeedsFor(facts), contains(IngestNeed.legacyContainer));
      expect(requiresFfmpegRemux(facts), isTrue);
      expect(requiresManifestRelay(facts), isFalse);
    });

    test('裸名子清单走回环改写，不动 FFmpeg', () {
      const facts = (format: LiveStreamFormat.hls, codec: null, unresolvedChildren: true);

      expect(ingestNeedsFor(facts), contains(IngestNeed.relativeChildren));
      expect(requiresManifestRelay(facts), isTrue);
      expect(requiresFfmpegRemux(facts), isFalse);
    });

    test('普通 AVC 线路保持直连', () {
      for (final facts in [
        (format: LiveStreamFormat.hls, codec: 'avc', unresolvedChildren: false),
        (format: LiveStreamFormat.flv, codec: 'avc', unresolvedChildren: false),
      ]) {
        expect(ingestNeedsFor(facts), isEmpty);
        expect(requiresFfmpegRemux(facts), isFalse);
        expect(requiresManifestRelay(facts), isFalse);
      }
    });

    test('声明为 other 的单条 HTTP 流不当清单探测', () {
      const facts = (format: LiveStreamFormat.other, codec: null, unresolvedChildren: false);
      final uri = Uri.parse('http://192.168.1.1:4022/udp/239.0.0.1:5000');

      expect(isDeclaredManifest(facts, uri), isFalse);
      expect(requiresManifestRelay(facts), isFalse);
    });

    test('没有声明时回退到 URL 形状', () {
      final manifest = Uri.parse('https://cdn.example.com/live/room/playlist.m3u8');
      final plain = Uri.parse('https://cdn.example.com/live/room.flv');

      expect(isDeclaredManifest(null, manifest), isTrue);
      expect(isDeclaredManifest(null, plain), isFalse);
      expect(ingestNeedsFor(null), isEmpty);
    });
  });

  group('解析结果携带线路事实', () {
    test('只保留本次解析里真实存在的线路', () {
      const kept = 'https://cdn.example.com/live/room.flv';
      final resolution = LivePlayUrlResolution.withSourcePolicies(
        urls: [kept],
        sourceQueryPolicies: const {},
        streamFacts: const {
          kept: (format: LiveStreamFormat.flv, codec: 'hevc', unresolvedChildren: false),
          'https://cdn.example.com/live/other.flv': (
            format: LiveStreamFormat.flv,
            codec: 'hevc',
            unresolvedChildren: false,
          ),
        },
      );

      expect(resolution.streamFacts.keys, [kept]);
      expect(resolution.factsFor(kept)?.codec, 'hevc');
      expect(resolution.factsFor('https://cdn.example.com/live/other.flv'), isNull);
      // normalized() 复制时不能把事实丢掉
      expect(resolution.normalized().factsFor(kept)?.codec, 'hevc');
    });

    test('默认构造与 owned 输入不带事实', () {
      expect(const LivePlayUrlResolution(urls: ['https://cdn.example.com/a.flv']).streamFacts, isEmpty);
    });
  });

  group('站点声明', () {
    test('百度把 HEVC 档位解析成独立的 hevc 线路', () {
      final room = BaiduLiveApi.parseRoomJson({
        'errno': 0,
        'data': {
          '371': {
            'error_code': 0,
            'status': 0,
            'host': {'nick_name': '主播', 'name': 'room'},
            'video': {
              'url_clarity_list': [
                {
                  'resolution': 1080,
                  'urls': {
                    'avc_flv': 'https://flv-live.bdstatic.com/live/avc_123456.flv',
                    'hevc_flv': 'https://flv-live.bdstatic.com/live/hevc_123456.flv',
                    'hls': 'https://hls-live.bdstatic.com/live/hls_123456.m3u8',
                  },
                },
              ],
              'hevc_url': 'https://flv-live.bdstatic.com/live/origin_123456.flv',
            },
          },
        },
      }, expectedRoomId: '123456');

      final hevc = room.variants.where((variant) => variant.codec == 'hevc').toList();
      expect(hevc, hasLength(2), reason: '档位里的 hevc_flv 与源站 hevc_url 都要出现');
      expect(hevc.every((variant) => variant.protocol == 'flv'), isTrue);
      expect(hevc.map((variant) => variant.id), containsAll(<String>['flv:1080:hevc', 'flv:0:hevc']));

      // 站点声明的事实因此把这条线路判给 FFmpeg
      final facts = (format: LiveStreamFormat.flv, codec: hevc.first.codec, unresolvedChildren: false);
      expect(requiresFfmpegRemux(facts), isTrue);

      final avc = room.variants.where((variant) => variant.codec == 'avc').toList();
      expect(avc, isNotEmpty);
      expect(
        requiresFfmpegRemux((format: LiveStreamFormat.flv, codec: avc.first.codec, unresolvedChildren: false)),
        isFalse,
      );
    });

    test('TwitCasting 声明 tc-hls 的裸名子清单', () {
      final facts = TwitcastingSite().declareStreamFacts([
        'https://tc-hls.twitcasting.tv/tc.livehls/v1/streams/1/movie/1.1/media.m3u8',
        'https://twitcasting.tv/other.flv',
      ]);

      expect(facts.keys, hasLength(2));
      expect(facts.values.every((value) => value.unresolvedChildren), isTrue);
      expect(facts.values.every((value) => value.format == LiveStreamFormat.hls), isTrue);
      expect(facts.entries.every((entry) => requiresManifestRelay(entry.value)), isTrue);
    });

    test('TwitCasting 不给站外主机声明事实', () {
      final facts = TwitcastingSite().declareStreamFacts(['https://cdn.example.com/room.m3u8']);

      expect(facts, isEmpty);
    });
  });
  group('B 站与 IPTV 的线路声明', () {
    test('B 站直播线路带上容器与编码，flv 之外的单条响应算 other', () {
      Map<String, Object?> codec(String name, String format, String base, String host) => <String, Object?>{
        'codec_name': name,
        'current_qn': 10000,
        'base_url': base,
        'url_info': [
          {'host': host, 'extra': '?expires=1'},
        ],
      };

      final resolution = BiliBiliSite.parsePlayUrlResolution({
        'code': 0,
        'data': {
          'playurl_info': {
            'playurl': {
              'stream': [
                {
                  'protocol_name': 'http_stream',
                  'format': [
                    {
                      'format_name': 'flv',
                      'codec': [codec('avc', 'flv', '/live-bvc/avc.flv', 'https://cn-gotcha01.bilivideo.com')],
                    },
                    {
                      'format_name': 'ts',
                      'codec': [codec('hevc', 'ts', '/live-bvc/hevc.ts', 'https://cn-gotcha01.bilivideo.com')],
                    },
                  ],
                },
              ],
            },
          },
        },
      }, requestedQualityData: '10000');

      expect(resolution.urls, hasLength(2));
      expect(resolution.streamFacts.keys.toSet(), resolution.urls.toSet());

      final flv = resolution.streamFacts.entries.firstWhere((entry) => entry.key.endsWith('avc.flv?expires=1'));
      expect(flv.value.format, LiveStreamFormat.flv);
      expect(flv.value.codec, 'avc');
      expect(requiresFfmpegRemux(flv.value), isFalse);

      final ts = resolution.streamFacts.entries.firstWhere((entry) => entry.key.endsWith('hevc.ts?expires=1'));
      expect(ts.value.format, LiveStreamFormat.other);
      expect(ts.value.codec, 'hevc');
      // MPEG-TS 里的 HEVC 是标准组合，播放器自己就能解，不该白付一次转封装。
      expect(requiresFfmpegRemux(ts.value), isFalse);
      expect(isDeclaredManifest(ts.value, Uri.parse(ts.key)), isFalse);
    });

    test('IPTV 把 ts 与 udpxy 归为 other，m3u8 归为清单，认不出的不声明', () {
      expect(iptvStreamFormat('http://192.168.1.10:4022/udp/239.0.0.1:5000'), LiveStreamFormat.other);
      expect(iptvStreamFormat('http://cdn.example.com/live/channel.ts'), LiveStreamFormat.other);
      expect(iptvStreamFormat('rtp://239.0.0.1:5000'), LiveStreamFormat.other);
      expect(iptvStreamFormat('http://cdn.example.com/live/index.m3u8'), LiveStreamFormat.hls);
      expect(iptvStreamFormat('http://cdn.example.com/live/stream'), isNull);

      final facts = IptvSite().declareStreamFacts([
        'http://192.168.1.10:4022/udp/239.0.0.1:5000',
        'http://cdn.example.com/live/index.m3u8',
        'http://cdn.example.com/live/stream',
      ]);
      expect(facts.keys, hasLength(2), reason: '认不出容器的那条不声明，交给探测');
      expect(facts['http://192.168.1.10:4022/udp/239.0.0.1:5000']?.format, LiveStreamFormat.other);
      expect(
        isDeclaredManifest(
          facts['http://cdn.example.com/live/index.m3u8'],
          Uri.parse('http://cdn.example.com/live/index.m3u8'),
        ),
        isTrue,
      );
    });
  });
}
