import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
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
  });
}
