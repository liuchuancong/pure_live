import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test('every built-in platform declares a recording detail resolver', () {
    expect(
      Sites.supportedSiteIds,
      unorderedEquals(const [
        Sites.weiboSite,
        Sites.bilibiliSite,
        Sites.douyuSite,
        Sites.huyaSite,
        Sites.douyinSite,
        Sites.kuaishouSite,
        Sites.ccSite,
        Sites.twitchSite,
        Sites.soopSite,
        Sites.yySite,
        Sites.acfunSite,
        Sites.picartoSite,
        Sites.twitcastingSite,
        Sites.missevanSite,
        Sites.inkeSite,
        Sites.kilakilaSite,
        Sites.huajiaoSite,
        Sites.openrecSite,
        Sites.ttingSite,
        Sites.xiaohongshuSite,
        Sites.niconicoSite,
        Sites.showroomSite,
        Sites.chzzkSite,
        Sites.kickSite,
        Sites.seventeenLiveSite,
        Sites.liveMeSite,
        Sites.iptvSite,
      ]),
    );
    for (final siteId in Sites.supportedSiteIds) {
      expect(Sites.of(siteId).liveSite, isA<LiveSiteRecordRoomResolver>(), reason: siteId);
    }
  });

  test('per-CDN signing platforms expose the lazy recording line cursor', () {
    for (final siteId in const <String>[Sites.douyuSite, Sites.huyaSite]) {
      expect(Sites.of(siteId).liveSite, isA<LivePlayUrlCursorResolver>(), reason: siteId);
    }
  });
}
