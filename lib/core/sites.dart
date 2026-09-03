import 'site/yy/yy_site.dart';
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
  static const String allSite = 'all';
  static const String bilibiliSite = 'bilibili';
  static const String douyuSite = 'douyu';
  static const String huyaSite = 'huya';
  static const String douyinSite = 'douyin';
  static const String kuaishouSite = 'kuaishou';
  static const String ccSite = 'cc';
  static const String iptvSite = 'iptv';
  static const String twitchSite = 'twitch';
  static const String soopSite = 'soop';
  static const String yySite = 'yy';

  static const Set<String> supportedSiteIds = {
    bilibiliSite,
    douyuSite,
    huyaSite,
    douyinSite,
    kuaishouSite,
    ccSite,
    twitchSite,
    soopSite,
    yySite,
    iptvSite,
  };

  static bool isSupported(String id) => supportedSiteIds.contains(id.trim().toLowerCase());

  static List<Site> get supportSites => [
    Site(
      id: bilibiliSite,
      name: i18n('site_bilibili'),
      logo: 'assets/images/bilibili_2.png',
      liveSite: BiliBiliSite(),
    ),
    Site(
      id: douyuSite,
      name: i18n('site_douyu'),
      logo: 'assets/images/douyu.png',
      liveSite: DouyuSite(),
    ),
    Site(
      id: huyaSite,
      name: i18n('site_huya'),
      logo: 'assets/images/huya.png',
      liveSite: HuyaSite(),
    ),
    Site(
      id: douyinSite,
      name: i18n('site_douyin'),
      logo: 'assets/images/douyin.png',
      liveSite: DouyinSite(),
    ),
    Site(
      id: kuaishouSite,
      name: i18n('site_kuaishou'),
      logo: 'assets/images/kuaishou.png',
      liveSite: KuaishowSite(),
    ),
    Site(id: ccSite, name: i18n('site_cc'), logo: 'assets/images/cc.png', liveSite: CCSite()),
    Site(
      id: twitchSite,
      name: i18n('site_twitch'),
      logo: 'assets/images/twitch.png',
      liveSite: TwitchSite(),
    ),
    Site(
      id: soopSite,
      name: i18n('site_soop'),
      logo: 'assets/images/soop.png',
      liveSite: SoopSite(),
    ),
    Site(id: yySite, name: i18n('site_yy'), logo: 'assets/images/yy.png', liveSite: YYSite()),
    Site(
      id: iptvSite,
      name: i18n('site_iptv'),
      logo: 'assets/images/logo.png',
      liveSite: IptvSite(),
    ),
  ];

  static Site of(String id) {
    final normalizedId = id.trim().toLowerCase();
    // Do not construct every platform adapter for a single lookup. Favourite
    // verification performs this operation for every saved room; the previous
    // list scan allocated nine adapters per card and also discarded platform
    // session caches immediately afterwards.
    return switch (normalizedId) {
      bilibiliSite => Site(
        id: bilibiliSite,
        name: i18n('site_bilibili'),
        logo: 'assets/images/bilibili_2.png',
        liveSite: BiliBiliSite(),
      ),
      douyuSite => Site(
        id: douyuSite,
        name: i18n('site_douyu'),
        logo: 'assets/images/douyu.png',
        liveSite: DouyuSite(),
      ),
      huyaSite => Site(
        id: huyaSite,
        name: i18n('site_huya'),
        logo: 'assets/images/huya.png',
        liveSite: HuyaSite(),
      ),
      douyinSite => Site(
        id: douyinSite,
        name: i18n('site_douyin'),
        logo: 'assets/images/douyin.png',
        liveSite: DouyinSite(),
      ),
      kuaishouSite => Site(
        id: kuaishouSite,
        name: i18n('site_kuaishou'),
        logo: 'assets/images/kuaishou.png',
        liveSite: KuaishowSite(),
      ),
      ccSite => Site(
        id: ccSite,
        name: i18n('site_cc'),
        logo: 'assets/images/cc.png',
        liveSite: CCSite(),
      ),
      twitchSite => Site(
        id: twitchSite,
        name: i18n('site_twitch'),
        logo: 'assets/images/twitch.png',
        liveSite: TwitchSite(),
      ),
      soopSite => Site(
        id: soopSite,
        name: i18n('site_soop'),
        logo: 'assets/images/soop.png',
        liveSite: SoopSite(),
      ),
      yySite => Site(
        id: yySite,
        name: i18n('site_yy'),
        logo: 'assets/images/yy.png',
        liveSite: YYSite(),
      ),
      iptvSite => Site(
        id: iptvSite,
        name: i18n('site_iptv'),
        logo: 'assets/images/logo.png',
        liveSite: IptvSite(),
      ),
      _ => throw StateError('Unsupported live site: $normalizedId'),
    };
  }

  static LinearGradient gradientOf(String id) {
    return switch (id.trim().toLowerCase()) {
      // 哔哩哔哩
      Sites.bilibiliSite => const LinearGradient(colors: [Color(0xFFFF8FB1), Color(0xFFFB7299)]),

      // 斗鱼
      Sites.douyuSite => const LinearGradient(colors: [Color(0xFFFF9A3D), Color(0xFFFF7700)]),

      // 虎牙
      Sites.huyaSite => const LinearGradient(colors: [Color(0xFFFFD05A), Color(0xFFFFB000)]),

      // 抖音
      Sites.douyinSite => const LinearGradient(colors: [Color(0xFF333333), Color(0xFF000000)]),

      // 快手
      Sites.kuaishouSite => const LinearGradient(colors: [Color(0xFFFF7540), Color(0xFFFF4906)]),

      // CC
      Sites.ccSite => const LinearGradient(colors: [Color(0xFF42B5FF), Color(0xFF0D91E9)]),

      // IPTV
      Sites.iptvSite => const LinearGradient(colors: [Color(0xFFE96A2C), Color(0xFFCC4709)]),

      // Twitch
      Sites.twitchSite => const LinearGradient(colors: [Color(0xFFB47AFF), Color(0xFF9146FF)]),

      // SOOP
      Sites.soopSite => const LinearGradient(colors: [Color(0xFF00C8FF), Color(0xFF008AFF)]),

      // YY
      Sites.yySite => const LinearGradient(colors: [Color(0xFFFFF06A), Color(0xFFFFE600)]),

      _ => const LinearGradient(colors: [Color(0xFF35EF9B), Color(0xFF0BDF75)]),
    };
  }

  static String? logoOf(String id) {
    return switch (id.trim().toLowerCase()) {
      bilibiliSite => 'assets/images/bilibili_2.png',
      douyuSite => 'assets/images/douyu.png',
      huyaSite => 'assets/images/huya.png',
      douyinSite => 'assets/images/douyin.png',
      kuaishouSite => 'assets/images/kuaishou.png',
      ccSite => 'assets/images/cc.png',
      iptvSite => 'assets/images/logo.png',
      twitchSite => 'assets/images/twitch.png',
      soopSite => 'assets/images/soop.png',
      yySite => 'assets/images/yy.png',
      _ => null,
    };
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
      result.insert(
        0,
        Site(
          id: allSite,
          name: i18n('site_all'),
          logo: 'assets/images/all.png',
          liveSite: LiveSite(),
        ),
      );
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
