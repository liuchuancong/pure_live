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
  });
}
