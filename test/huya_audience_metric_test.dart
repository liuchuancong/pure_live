import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/huya_site.dart';

void main() {
  group('Huya audience metric parsing', () {
    test('does not relabel room detail heat as concurrent viewers', () {
      final metrics = HuyaSite.parseRoomAudience({'userCount': 5636930, 'totalCount': 5636930});

      expect(metrics.popularity, '5636930');
      expect(metrics.onlineViewers, isEmpty);
    });

    test('keeps userCount as a popularity fallback', () {
      final metrics = HuyaSite.parseRoomAudience({'userCount': '4200000', 'totalCount': ''});

      expect(metrics.popularity, '4200000');
      expect(metrics.onlineViewers, isEmpty);
    });
  });
}
