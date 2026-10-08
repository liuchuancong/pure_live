import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/models/live_category.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

/// Per-site display configuration for the areas directory.
///
/// `LiveSite.getCategores` always answers with a two-level structure: top-level
/// categories that each carry their children. The areas page draws a second tab
/// bar for those top-level categories, which is right for a platform with a
/// couple of entries each - the extra tab layer fragments a list that could be
/// read in one screen.
///
/// Sites in [flatAreaSites] render flat; unlisted sites keep the two-level tabs.
const Set<String> flatAreaSites = <String>{
  Sites.douyinSite,
  Sites.yySite,
  Sites.acfunSite,
  Sites.kilakilaSite,
  Sites.weiboSite,
  Sites.jdLiveSite,
  Sites.soopSite,
  Sites.picartoSite,
  Sites.twitcastingSite,
  Sites.inkeSite,
  Sites.chzzkSite,
  Sites.bigoSite,
  Sites.pandaLiveSite,
  Sites.fc2LiveSite,
  Sites.steamBroadcastSite,
  Sites.kugouLiveSite,
  Sites.baiduLiveSite,
  Sites.sixRoomSite,
  Sites.lookLiveSite,
};

/// Whether [siteId] opted into the flat directory rendering.
bool isFlatAreaSite(String siteId) => flatAreaSites.contains(siteId.trim().toLowerCase());

/// Whether the areas directory of one site should render flat.
///
/// Two cases:
/// * the site answered with at most one top-level category - flattening just
///   spreads its children, and a single-tab layer carries no information, so
///   this applies automatically;
/// * the site is listed in [flatAreaSites] - several groups but few entries
///   overall, where showing everything at once beats switching tabs.
bool shouldFlattenCategories(String siteId, List<LiveCategory> categories) =>
    categories.length <= 1 || isFlatAreaSite(siteId);

/// Flattens the two-level category directory into one list.
///
/// Every entry keeps the name of its top-level group ([LiveArea.typeName] is
/// filled by the site layer); flattening only expands, it never reorders.
List<LiveArea> flattenCategories(List<LiveCategory> categories) {
  return <LiveArea>[for (final category in categories) ...category.children];
}
