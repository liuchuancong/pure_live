import 'site/soop/soop_site.dart';
import 'site/huya/huya_site.dart';
import 'interface/live_site.dart';
import 'site/douyu/douyu_site.dart';
import 'site/douyin/douyin_site.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/cc/cc_site.dart';
import 'package:pure_live/core/site/iptv/iptv_site.dart';
import 'package:pure_live/core/site/twitch/twitch_site.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';

class Sites {
  static const String allSite = "all";
  static const String bilibiliSite = "bilibili";
  static const String douyuSite = "douyu";
  static const String huyaSite = "huya";
  static const String douyinSite = "douyin";
  static const String kuaishouSite = "kuaishou";
  static const String ccSite = "cc";
  static const String iptvSite = "iptv";
  static const String twitchSite = "twitch";
  static const String soopSite = 'soop';
  static const Set<String> supportedSiteIds = {
    bilibiliSite,
    douyuSite,
    huyaSite,
    douyinSite,
    kuaishouSite,
    ccSite,
    twitchSite,
    soopSite,
    iptvSite,
  };

  static bool isSupported(String id) => supportedSiteIds.contains(id.trim().toLowerCase());

  static List<Site> get supportSites => [
    Site(id: bilibiliSite, name: i18n("site_bilibili"), logo: "assets/images/bilibili_2.png", liveSite: BiliBiliSite()),
    Site(id: douyuSite, name: i18n("site_douyu"), logo: "assets/images/douyu.png", liveSite: DouyuSite()),
    Site(id: huyaSite, name: i18n("site_huya"), logo: "assets/images/huya.png", liveSite: HuyaSite()),
    Site(id: douyinSite, name: i18n("site_douyin"), logo: "assets/images/douyin.png", liveSite: DouyinSite()),
    Site(id: kuaishouSite, name: i18n("site_kuaishou"), logo: "assets/images/kuaishou.png", liveSite: KuaishowSite()),
    Site(id: ccSite, name: i18n("site_cc"), logo: "assets/images/cc.png", liveSite: CCSite()),
    Site(id: twitchSite, name: i18n("site_twitch"), logo: "assets/images/twitch.png", liveSite: TwitchSite()),
    Site(id: soopSite, name: i18n("site_soop"), logo: "assets/images/soop.png", liveSite: SoopSite()),
    Site(id: iptvSite, name: i18n("site_iptv"), logo: "assets/images/logo.png", liveSite: IptvSite()),
  ];

  static Site of(String id) {
    final normalizedId = id.trim().toLowerCase();
    return supportSites.firstWhere((e) => normalizedId == e.id);
  }

  List<Site> availableSites({bool containsAll = false}) {
    final List<String> savedIds = SettingsService.to.fav.hotAreasList.v;
    final supportedById = {for (final site in supportSites) site.id: site};
    final List<Site> result = [];
    final seen = <String>{};
    for (String rawId in savedIds) {
      final id = rawId.trim().toLowerCase();
      if (!seen.add(id)) continue;
      final match = supportedById[id];
      if (match != null) {
        result.add(match);
      }
    }
    if (containsAll) {
      result.insert(0, Site(id: allSite, name: i18n("site_all"), logo: "assets/images/all.png", liveSite: LiveSite()));
    }
    return result;
  }
}

class Site {
  final String id;
  final String name;
  final String logo;
  final LiveSite liveSite;
  Site({required this.id, required this.liveSite, required this.logo, required this.name});
}
