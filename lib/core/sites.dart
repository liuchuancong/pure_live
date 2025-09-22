import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/cc/cc_site.dart';
import 'package:pure_live/core/site/iptv/iptv_site.dart';
import 'package:pure_live/core/site/juhe/juhe_site.dart';
import 'package:pure_live/core/site/kuaishou/kuaishou_site.dart';
import 'package:pure_live/core/site/soop/soop_site.dart';
import 'package:pure_live/core/site/yy/yy_site.dart';

import '../generated/iconfont.dart';
import 'interface/live_site.dart';
import 'site/douyin/douyin_site.dart';
import 'site/douyu/douyu_site.dart';
import 'site/huya/huya_site.dart';

class Sites {
  static const String allSite = "all";
  static const String bilibiliSite = "bilibili";
  static const String douyuSite = "douyu";
  static const String huyaSite = "huya";
  static const String douyinSite = "douyin";
  static const String kuaishouSite = "kuaishou";
  static const String ccSite = "cc";
  static const String iptvSite = "iptv";
  static const String soopSite = "soop";
  static const String yySite = "yy";
  static const String juheSite = "juhe";
  static List<Site> supportSites = [
    Site(
      id: bilibiliSite,
      name: "哔哩",
      logo: "assets/images/bilibili_2.png",
      liveSite: BiliBiliSite(),
      iconData: IconFont.bilibili,
      iconDataColor: Color(0xffd4237a),
      getSiteName: () => S.current.bilibili,
      // iconDataColor: Colors.blue,
    ),
    Site(
      id: douyuSite,
      name: "斗鱼",
      logo: "assets/images/douyu.png",
      liveSite: DouyuSite(),
      iconData: IconFont.douyu,
      iconDataColor: Color(0xffFE7800),
      getSiteName: () => S.current.douyu,
    ),
    Site(
      id: huyaSite,
      name: "虎牙",
      logo: "assets/images/huya.png",
      liveSite: HuyaSite(),
      iconData: IconFont.huyaxianxing,
      iconDataColor: Color(0xffF49F17),
      getSiteName: () => S.current.huya,
    ),
    Site(id: "huya", name: "虎牙", logo: "assets/images/huya.png", liveSite: HuyaSite()),
    Site(
      id: douyinSite,
      name: "抖音",
      logo: "assets/images/douyin.png",
      liveSite: DouyinSite(),
      iconData: IconFont.douyin3Copy,
      iconDataColor: Color(0xff2c2c2c),
      getSiteName: () => S.current.douyin,
    ),
    Site(
      id: kuaishouSite,
      name: "快手",
      logo: "assets/images/kuaishou.png",
      liveSite: KuaishowSite(),
      iconData: IconFont.kuaishou,
      iconDataColor: Color(0xffFF4A06),
      getSiteName: () => S.current.kuaishou,
    ),
    Site(
      id: ccSite,
      name: "网易CC",
      logo: "assets/images/cc.png",
      liveSite: CCSite(),
      iconData: IconFont.creativeCommons,
      iconDataColor: Color(0xff1980FF),
      getSiteName: () => S.current.cc,
    ),
    Site(
      id: yySite,
      name: "YY",
      logo: "assets/images/yy.png",
      liveSite: YYSite(),
      iconData: IconFont.yyLogoCopy,
      iconDataColor: Color(0xffF49F17),
      getSiteName: () => S.current.yy,
      // cacheCategory: false,
    ),
    Site(
      id: soopSite,
      name: "SOOP",
      logo: "assets/images/soop.png",
      liveSite: SoopSite(),
      iconData: IconFont.soopLogoCopy,
      iconDataColor: Color(0xffD1FF00),
      getSiteName: () => S.current.soop,
    ),
    Site(
      id: juheSite,
      name: "聚合",
      logo: "assets/images/iptv.png",
      liveSite: JuheSite(),
      iconData: IconFont.dianshi,
      iconDataColor: Color(0xffc87d1a),
      getSiteName: () => S.current.juhe,
      // cacheCategory: false,
    ),
    Site(
      id: iptvSite,
      name: "网络",
      logo: "assets/images/iptv.png",
      liveSite: IptvSite(),
      iconData: IconFont.dianshi,
      iconDataColor: Color(0xffFF5540),
      getSiteName: () => S.current.iptv,
      cacheCategory: false,
    ),
    Site(id: "kuaishou", name: "快手", logo: "assets/images/kuaishou.png", liveSite: KuaishowSite()),
    Site(id: "cc", name: "网易CC", logo: "assets/images/cc.png", liveSite: CCSite()),
    Site(id: "iptv", name: "网络", logo: "assets/images/logo.png", liveSite: IptvSite()),
  ];

  static Site of(String id) {
    // return supportSites.firstWhere((e) => id == e.id) ?? supportSites[supportSites.length - 1];
    // return supportSites.firstWhereOrNull((e) => id == e.id) ?? supportSites[supportSites.length - 1];
    return siteMap[id] ?? supportSites[supportSites.length - 1];
  }

  static Map<String, Site>? _map;

  static Map<String, Site> get siteMap {
    if (_map == null) {
      var list = Sites.supportSites.map((e) => MapEntry(e.id, e)).toList();
      var map = Map.fromEntries(list);
      map[Sites.allLiveSite.id] = Sites.allLiveSite;
      _map = map;
    }
    return _map!;
  }

  static Site allLiveSite = Site(
    id: allSite,
    name: "全部",
    logo: "assets/images/all.png",
    liveSite: LiveSite(),
    getSiteName: () => S.current.all,
  );

  static String getSiteName(String siteId) {
    var site = of(siteId);
    return site.getSiteName();
  }

  List<Site> availableSites({bool containsAll = false}) {
    final SettingsService settingsService = Get.find<SettingsService>();
    if (containsAll) {
      var result = supportSites.where((element) => settingsService.hotAreasList.value.contains(element.id)).toList();
      result.insert(0, allLiveSite);
      return result;
    }
    return supportSites.where((element) => settingsService.hotAreasList.value.contains(element.id)).toList();
  }
}

typedef StringCallback = String Function();

class Site {
  final String id;
  final String name;
  final String logo;
  final LiveSite liveSite;
  IconData? iconData;
  Color? iconDataColor;

  /// 是否缓存分类
  bool cacheCategory;
  StringCallback getSiteName;

  Site({
    required this.id,
    required this.liveSite,
    required this.logo,
    required this.name,
    this.iconData,
    this.iconDataColor,
    this.cacheCategory = true,
    required this.getSiteName,
  });
}
