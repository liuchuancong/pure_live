import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/yy/yy_site.dart';

void main() {
  group('YY category metadata', () {
    test('parses the embedded JavaScript literal without a JS runtime', () {
      const html = '''
        <script>
          var pageInfo = {
            pageBar: {totalPages: 8, moduleId: 308, biz: 'sing', subBiz: "idx"},
            position: 'secondary'
          };
        </script>
      ''';

      expect(YYSite.parseCategoryPageInfo(html), <String, dynamic>{
        'moduleId': 308,
        'biz': 'sing',
        'subBiz': 'idx',
      });
    });

    test('rejects incomplete metadata and upgrades public URLs to HTTPS', () {
      expect(YYSite.parseCategoryPageInfo('var pageInfo = {biz: "sing"};'), isNull);
      expect(YYSite.normalizeWebUrl('http://www.yy.com/music/'), 'https://www.yy.com/music/');
      expect(YYSite.normalizeWebUrl('//image.yy.com/a.jpg'), 'https://image.yy.com/a.jpg');
    });

    test('normalizes string and boolean live-state fields', () {
      expect(YYSite.isLiveValue('1'), isTrue);
      expect(YYSite.isLiveValue(true), isTrue);
      expect(YYSite.isLiveValue('0'), isFalse);
      expect(YYSite.isLiveValue(null), isFalse);
    });

    test('keeps YY gears distinct and validates returned CDN URLs', () {
      final qualities = YYSite.parsePlayQualities({
        'channel_stream_info': {
          'streams': [
            {'stream_key': 'a', 'json': '{"gear_info":{"name":"高清","gear":"4"},"rate":"4000"}'},
            {'stream_key': 'b', 'json': '{"gear_info":{"name":"高清","gear":"2"},"rate":2000}'},
            {
              'stream_key': 'duplicate',
              'json': '{"gear_info":{"name":"重复","gear":"2"},"rate":1000}',
            },
          ],
        },
      });

      expect(qualities.map((quality) => quality.selectionId), ['4', '2']);
      expect(qualities.map((quality) => quality.quality), ['高清 · 4', '高清 · 2']);
      expect(
        YYSite.parsePlayUrls({
          'avp_info_res': {
            'stream_line_addr': {
              'a': {
                'cdn_info': {'url': '//cdn.test/live.flv'},
              },
              'duplicate': {
                'cdn_info': {'url': 'https://cdn.test/live.flv'},
              },
              'bad': {
                'cdn_info': {'url': 'javascript:alert(1)'},
              },
            },
          },
        }),
        ['https://cdn.test/live.flv'],
      );
    });

    test('parses YY anonymous mobile HLS fallback and rejects unsafe URLs', () {
      expect(
        YYSite.parseMobileHlsPayload(
          '({"code":0,"width":1280,"height":720,'
          '"video":"xv_room_0_0_0","hls":"https://sslproxy.yy.com/live.m3u8?tk=token"})',
        ),
        containsPair('video', 'xv_room_0_0_0'),
      );
      expect(YYSite.parseMobileHlsPayload('{"code":1,"hls":"https://cdn.test/live.m3u8"}'), isNull);
      expect(YYSite.parseMobileHlsPayload('{"code":0,"hls":"javascript:alert(1)"}'), isNull);
      expect(YYSite.parseMobileHlsPayload('not-json'), isNull);
    });
  });
}
