import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/site/cc/cc_site.dart';

void main() {
  group('CC audience fields', () {
    test('separates platform heat from the much smaller concurrent count', () {
      final audience = CCSite.parseRoomAudience({'webcc_visitor': 534739, 'vision_visitor': 850, 'online_num': 843});

      expect(audience.popularity, '534739');
      expect(audience.onlineViewers, '850');
    });

    test('keeps an explicit zero online count', () {
      final audience = CCSite.parseRoomAudience({'webcc_visitor': 65150, 'vision_visitor': 0});

      expect(audience.popularity, '65150');
      expect(audience.onlineViewers, '0');
    });
  });

  test('CC quality keys stay attached to their own ordered CDN lines', () async {
    final qualities = await CCSite().getPlayQualites(
      detail: LiveRoom(
        data: {
          'resolution': {
            'low': {
              'vbr': '500',
              'cdn': {'random': 'https://other.test/low.flv', 'hs': 'https://preferred.test/low.flv'},
            },
            'original': {
              'vbr': 8000,
              'cdn': {'hs': 'https://preferred.test/source.flv'},
            },
          },
        },
      ),
    );

    expect(qualities.map((quality) => quality.selectionId), ['original', 'low']);
    expect(qualities.first.data, ['https://preferred.test/source.flv']);
    expect(qualities.last.data, ['https://preferred.test/low.flv', 'https://other.test/low.flv']);
  });
}
