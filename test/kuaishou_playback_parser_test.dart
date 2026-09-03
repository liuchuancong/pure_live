import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';

Map<String, dynamic> descriptor(String prefix) => {
  'adaptationSet': {
    'representation': [
      {
        'name': '高清',
        'shortName': '高清',
        'level': 30,
        'bitrate': 1000,
        'url': 'https://$prefix/hd.flv',
      },
      {
        'name': '蓝光 4M',
        'shortName': '4M',
        'level': 70,
        'bitrate': 4000,
        'url': 'https://$prefix/4m.flv',
      },
    ],
  },
};

void main() {
  group('KuaishowSite.parsePlayQualities', () {
    test('parses current room-page h264 shape in descending quality order', () {
      final qualities = KuaishowSite.parsePlayQualities({
        'h264': descriptor('line-a'),
        'hevc': <String, dynamic>{},
      });

      expect(qualities.map((item) => item.quality), ['蓝光 4M', '高清']);
      expect(qualities.first.sort, 70);
      expect(qualities.first.data, ['https://line-a/4m.flv']);
    });

    test('parses recommendation/replay descriptor list and merges CDN lines', () {
      final qualities = KuaishowSite.parsePlayQualities([
        descriptor('line-a'),
        descriptor('line-b'),
      ]);

      expect(qualities, hasLength(2));
      expect(qualities.first.data, ['https://line-a/4m.flv', 'https://line-b/4m.flv']);
      expect(qualities.last.data, ['https://line-a/hd.flv', 'https://line-b/hd.flv']);
    });

    test('falls back to HEVC when AVC representations are absent', () {
      final qualities = KuaishowSite.parsePlayQualities({
        'h264': <String, dynamic>{},
        'hevc': descriptor('hevc-line'),
      });

      expect(qualities, hasLength(2));
      expect(qualities.first.data, ['https://hevc-line/4m.flv']);
    });

    test('ignores malformed and non-http playback entries', () {
      final qualities = KuaishowSite.parsePlayQualities([
        {
          'adaptationSet': {
            'representation': [
              {'name': 'bad', 'level': 1, 'url': 'javascript:alert(1)'},
              {'name': 'missing', 'level': 2},
            ],
          },
        },
        null,
      ]);

      expect(qualities, isEmpty);
    });
  });
}
