import 'package:desen_ui/desen_ui.dart';

import 'package:pure_live/l10n/translations.dart' show Translations;
import 'package:pure_live/shared/enums/app_module.dart' show AppModule;

/// The shell's navigation destinations. The v4 navigation design keeps
/// three blocks apart: each content type's business menu (no section
/// headings — live's is exactly 关注 / 热门 / 分区), the shared tools under
/// a divider, and settings pinned to the sidebar's foot.
enum NavigationItem {
  /// The live branch.
  live(DsIcons.tv),

  /// The channels branch.
  channels(DsIcons.layoutGrid),

  /// The discover branch.
  discover(DsIcons.compass),

  /// The history branch.
  history(DsIcons.history),

  /// The multi-view branch.
  multiview(DsIcons.columns2),

  /// The favorites branch.
  favorites(DsIcons.heart),

  /// The hot branch.
  hot(DsIcons.flame),

  /// The zones branch.
  zones(DsIcons.squareStack),

  /// The search branch.
  search(DsIcons.search),

  /// The toolbox branch.
  toolbox(DsIcons.wrench),

  /// The recording branch.
  record(DsIcons.disc3),

  /// The settings branch.
  settings(DsIcons.settings),

  /// The appearance branch.
  appearance(DsIcons.palette),

  /// The network proxy branch.
  proxy(DsIcons.globe),

  /// The user branch.
  user(DsIcons.circleUser);

  NavigationItem(this.icon);

  /// The destination's icon.
  final DsIconData icon;

  /// The localized label.
  String label(Translations t) => switch (this) {
    NavigationItem.live => t.navigation.live,
    NavigationItem.channels => t.navigation.channels,
    NavigationItem.discover => t.navigation.discover,
    NavigationItem.history => t.navigation.history,
    NavigationItem.multiview => t.navigation.multiview,
    NavigationItem.favorites => t.navigation.favorites,
    NavigationItem.hot => t.navigation.hot,
    NavigationItem.zones => t.navigation.zones,
    NavigationItem.search => t.navigation.search,
    NavigationItem.toolbox => t.navigation.toolbox,
    NavigationItem.record => t.navigation.record,
    NavigationItem.settings => t.navigation.settings,
    NavigationItem.appearance => t.navigation.appearance,
    NavigationItem.proxy => t.navigation.proxy,
    NavigationItem.user => t.navigation.user,
  };
}

/// Each module's business menu, the sidebar's top block — flat, without
/// section headings. Switching the app switcher's content type swaps this
/// block (and the content area) in place.
const Map<AppModule, List<NavigationItem>> kModuleBusinessItems = {
  AppModule.live: [NavigationItem.favorites, NavigationItem.hot, NavigationItem.zones],
  AppModule.iptv: [NavigationItem.channels, NavigationItem.favorites, NavigationItem.history],
  AppModule.vod: [NavigationItem.zones, NavigationItem.favorites, NavigationItem.history],
  AppModule.music: [NavigationItem.favorites, NavigationItem.history],
};

/// The shared tools under the divider below the business menu: they serve
/// every content type, so they never repeat inside a business menu.
const List<NavigationItem> kToolItems = [
  NavigationItem.multiview,
  NavigationItem.search,
  NavigationItem.record,
  NavigationItem.toolbox,
];

/// Where a module lands when it is chosen in the app switcher: live opens
/// on the hot feed, the others on their first page.
NavigationItem defaultNavigationItemFor(AppModule module) =>
    kModuleBusinessItems[module]!.first;
