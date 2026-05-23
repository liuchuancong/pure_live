import 'site/huya_site.dart';
import 'site/douyu_site.dart';
import 'site/douyin_site.dart';
import 'interface/live_site.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/cc_site.dart';
import 'package:pure_live/core/site/iptv_site.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:pure_live/core/site/kuaishou_site.dart';

class Sites {
  static const String allSite = "all";
  static const String bilibiliSite = "bilibili";
  static const String douyuSite = "douyu";
  static const String huyaSite = "huya";
  static const String douyinSite = "douyin";
  static const String kuaishouSite = "kuaishou";
  static const String ccSite = "cc";
  static const String iptvSite = "iptv";
  static List<Site> get supportSites => [
    Site(id: "bilibili", name: i18n("site_bilibili"), logo: "assets/images/bilibili_2.png", liveSite: BiliBiliSite()),
    Site(id: "douyu", name: i18n("site_douyu"), logo: "assets/images/douyu.png", liveSite: DouyuSite()),
    Site(id: "huya", name: i18n("site_huya"), logo: "assets/images/huya.png", liveSite: HuyaSite()),
    Site(id: "douyin", name: i18n("site_douyin"), logo: "assets/images/douyin.png", liveSite: DouyinSite()),
    Site(id: "kuaishou", name: i18n("site_kuaishou"), logo: "assets/images/kuaishou.png", liveSite: KuaishowSite()),
    Site(id: "cc", name: i18n("site_cc"), logo: "assets/images/cc.png", liveSite: CCSite()),
    Site(id: "iptv", name: i18n("site_iptv"), logo: "assets/images/logo.png", liveSite: IptvSite()),
  ];

  static Site of(String id) {
    return supportSites.firstWhere((e) => id == e.id);
  }

  List<Site> availableSites({bool containsAll = false}) {
    final SettingsService settingsService = Get.find<SettingsService>();
    final List<String> savedIds = settingsService.hotAreasList.value;

    List<Site> result = [];

    for (String id in savedIds) {
      final match = supportSites.firstWhereOrNull((element) => element.id == id);
      if (match != null) {
        result.add(match);
      }
    }

    if (containsAll) {
      result.insert(0, Site(id: "all", name: i18n("site_all"), logo: "assets/images/all.png", liveSite: LiveSite()));
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
