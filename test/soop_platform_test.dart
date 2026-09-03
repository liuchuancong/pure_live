import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/soop/soop_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  group('SOOP platform integration', () {
    test('uses PC plus mobile viewers instead of the PC-only count', () {
      expect(
        SoopSite.parseOnlineViewers({
          'current_view_cnt': '6372',
          'm_current_view_cnt': '7834',
          'total_view_cnt': '14206',
        }),
        '14206',
      );
      expect(SoopSite.parseOnlineViewers({'pc_view_cnt': 12, 'mobile_view_cnt': 8}), '20');
      expect(SoopSite.parseOnlineViewers({'view_cnt': 321}), '321');
      expect(SoopSite.parseOnlineViewers({'RESULT': 1}), isEmpty);
      expect(SoopSite.parseOnlineViewers({'total_view_cnt': 0}), '0');
    });

    test('parses play and main-site channel links', () async {
      expect(await LiveUrlTool.parseLiveUrl('https://play.sooplive.co.kr/example_channel'), [
        'example_channel',
        Sites.soopSite,
      ]);
      expect(
        await LiveUrlTool.parseLiveUrl('https://www.sooplive.co.kr/example_channel?from=share'),
        ['example_channel', Sites.soopSite],
      );
    });

    test('parses the global sooplive.com channel link', () async {
      expect(
        await LiveUrlTool.parseLiveUrl('https://www.sooplive.com/example_channel?from=share'),
        ['example_channel', Sites.soopSite],
      );
    });

    test('uses preset names as stable quality request ids', () async {
      final qualities = await SoopSite().getPlayQualites(
        detail: LiveRoom(
          data: {
            'viewpreset': [
              {'name': 'auto', 'bps': 0},
              {'name': 'AUTO', 'bps': 0},
              {'name': 'original', 'bps': '0'},
              {'name': 'hd', 'bps': 2000000},
              {'name': 'HD', 'bps': 1000000},
            ],
          },
        ),
      );

      expect(qualities.map((quality) => quality.selectionId), ['original', 'hd']);
      expect(qualities.map((quality) => quality.quality), ['原画', '高清']);
      expect(qualities.first.sort, greaterThan(qualities.last.sort));
    });
  });
}
