import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/core/site/soop/soop_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  group('SOOP platform integration', () {
    test('parses play and main-site channel links', () async {
      expect(await LiveUrlTool.parseLiveUrl('https://play.sooplive.co.kr/example_channel'), [
        'example_channel',
        Sites.soopSite,
      ]);
      expect(await LiveUrlTool.parseLiveUrl('https://www.sooplive.co.kr/example_channel?from=share'), [
        'example_channel',
        Sites.soopSite,
      ]);
    });

    test('parses the global sooplive.com channel link', () async {
      expect(await LiveUrlTool.parseLiveUrl('https://www.sooplive.com/example_channel?from=share'), [
        'example_channel',
        Sites.soopSite,
      ]);
    });

    test('uses preset names as stable quality request ids', () async {
      final qualities = await SoopSite().getPlayQualites(
        detail: LiveRoom(
          data: {
            'viewpreset': [
              {'name': 'auto', 'bps': 0},
              {'name': 'original', 'bps': '8000000'},
              {'name': 'hd', 'bps': 2000000},
              {'name': 'hd', 'bps': 1000000},
            ],
          },
        ),
      );

      expect(qualities.map((quality) => quality.selectionId), ['original', 'hd']);
      expect(qualities.map((quality) => quality.sort), [8000000, 2000000]);
    });
  });
}
