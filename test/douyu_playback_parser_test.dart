import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyu/douyu_site.dart';

void main() {
  group('Douyu H5 playback response', () {
    test('accepts numeric/string success and preserves playback data', () {
      final data = DouyuSite.parsePlayResponse(<String, dynamic>{
        'error': '0',
        'data': <String, dynamic>{'rtmp_url': 'https://example.test/live'},
      });

      expect(data['rtmp_url'], 'https://example.test/live');
    });

    test('reports API errors and incomplete payloads', () {
      expect(
        () => DouyuSite.parsePlayResponse(<String, dynamic>{'error': 102, 'msg': 'expired'}),
        throwsA(isA<DouyuPlayApiException>()),
      );
      expect(() => DouyuSite.parsePlayResponse(<String, dynamic>{'error': 0}), throwsA(isA<DouyuPlayApiException>()));
    });

    test('deduplicates CDN codes and always provides a fallback line', () {
      expect(
        DouyuSite.parseCdnCodes(<String, dynamic>{
          'rtmp_cdn': 'ws-h5',
          'cdnsWithName': <Map<String, String>>[
            {'cdn': 'ws-h5'},
            {'cdn': 'tct-h5'},
            {'cdn': 'tct-h5'},
          ],
        }),
        <String>['ws-h5', 'tct-h5'],
      );
      expect(DouyuSite.parseCdnCodes(<String, dynamic>{}), <String>['']);
    });

    test('builds and unescapes the actual FLV URL', () {
      final url = DouyuSite.parsePlayUrl(<String, dynamic>{
        'rtmp_url': 'https://cdn.example.test/live/',
        'rtmp_live': '/stream.flv?wsAuth=a&amp;token=b',
      });

      expect(url, 'https://cdn.example.test/live/stream.flv?wsAuth=a&token=b');
      expect(
        () => DouyuSite.parsePlayUrl(<String, dynamic>{'rtmp_live': 'relative.flv'}),
        throwsA(isA<DouyuPlayApiException>()),
      );
    });

    test('keeps API quality order because rate is an opaque request code', () {
      final qualities = DouyuSite.parsePlayQualities(
        <String, dynamic>{
          'multirates': <Map<String, dynamic>>[
            {'name': '蓝光8M', 'rate': 0},
            {'name': '蓝光4M', 'rate': 1},
            {'name': '流畅', 'rate': 3},
            {'name': '重复流畅', 'rate': 3},
          ],
        },
        const <String>['main', 'backup'],
      );

      expect(qualities.map((quality) => quality.quality), ['蓝光8M', '蓝光4M', '流畅']);
      expect(qualities.map((quality) => quality.selectionId), [0, 1, 3]);
      expect((qualities.first.data as DouyuPlayData).cdns, ['main', 'backup']);
    });
  });
}
