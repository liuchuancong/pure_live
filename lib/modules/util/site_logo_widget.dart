import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/core/sites.dart';

class SiteWidget {
  /// logo 宽度
  static double logoWidth = 25;

  /// 所有站点的 logo
  static Map<String, Widget> get siteLogeImageMap {
    var list = Sites.supportSites.map((e) => MapEntry(e.id, getSiteLogo(e))).toList();
    var map = Map.fromEntries(list);
    map[Sites.allLiveSite.id] = getSiteLogo(Sites.allLiveSite);

    return map;
  }

  /// 获取站点 logo Image
  static Widget getSiteLogo(Site site) {
    var iconData = site.iconData;
    if(iconData != null) {
      return Icon(iconData, color: site.iconDataColor,);
    }
    return ExtendedImage.asset(
      // key: ValueKey(site.id),
      site.logo,
      width: logoWidth,
      // cacheWidth: logoWidth.toInt(),
      cacheRawData: true,
      clearMemoryCacheWhenDispose: false,
    );
  }

  /// 获取站点 logo Image
  static Widget? getSiteLogeImage(String siteId) {
    // return siteLogeImageMap[siteId];
    return getSiteLogo(Sites.of(siteId));
  }

  /// 获取站点 Tab
  static Tab getSiteTab(Site site) {
    return Tab(
      // key: ValueKey(site.id),
      text: Sites.getSiteName(site.id),
      iconMargin: const EdgeInsets.all(0),
      icon: getSiteLogeImage(site.id),
    );
  }

  /// 获取 可用站点的 tab 包含一个所有站点的标志
  static List<Widget> get availableSitesWithAllTabList {
    return Sites().availableSites(containsAll: true).map((site) => getSiteTab(site)).toList();
  }

  /// 获取 可用站点的 tab
  static List<Widget> get availableSitesTabList {
    return Sites().availableSites().map((site) => getSiteTab(site)).toList();
  }

  static List<Widget> getAvailableSites({bool containsAll = false}) {
    if (containsAll) {
      return availableSitesWithAllTabList;
    }
    return availableSitesTabList;
  }
}
