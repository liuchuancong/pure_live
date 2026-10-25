import 'package:flutter/widgets.dart' show Widget;

import 'package:pure_live/features/areas/areas_page.dart' show AreasPage;
import 'package:pure_live/features/favorites/favorites_page.dart' show FavoritesPage;
import 'package:pure_live/features/history/history_page.dart' show HistoryPage;
import 'package:pure_live/features/iptv/iptv_page.dart' show IptvPage;
import 'package:pure_live/features/multiview/multiview_page.dart' show MultiviewPage;
import 'package:pure_live/features/music/music_page.dart' show MusicPage;
import 'package:pure_live/features/popular/popular_page.dart' show PopularPage;
import 'package:pure_live/features/recorder/recorder_page.dart' show RecorderPage;
import 'package:pure_live/features/search/search_page.dart' show SearchPage;
import 'package:pure_live/features/settings/settings_sections.dart' show SettingsGroup, SettingsSection;
import 'package:pure_live/features/toolbox/toolbox_page.dart' show ToolboxPage;
import 'package:pure_live/features/vod/vod_page.dart' show VodPage;
import 'package:pure_live/shared/enums/app_module.dart' show AppModule;
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// One module's whole navigation surface, in one place.
///
/// A module is one content type (live, IPTV, VOD, music) and everything the
/// shell shows while it is selected: its app menu ([menu] — one list per
/// block, a divider drawn between blocks) and the settings sections its
/// settings surface carries ([settingsGroups]). Adding a module or reshaping
/// one is one table edit here — the desktop sidebar, the phone drawer and the
/// settings page all read this registry, so they cannot drift apart.
///
/// The live module's blocks read the reference's rail block for block:
/// Search Live / Watch history, then Link Parser / Multi-view, then
/// Favorites / Popular / Areas, then Recording centre. Settings is not part of [menu]; the shell pins it to the foot.
///
/// The live module is also the one whose pages are router branches (they keep
/// their state and own deep links); every other module's pages are looked up
/// per menu entry in [kModulePages] and rendered in place.
final class ModuleNavigation {
  /// A module's navigation definition.
  const ModuleNavigation({required this.menu, required this.landing, required this.settingsGroups});

  /// The app menu's blocks, top to bottom; the sidebar draws a divider
  /// between them. Every entry is a page the menu can open.
  final List<List<NavigationItem>> menu;

  /// Where the module lands when chosen in the app switcher: live opens on
  /// its feed (Popular), the other modules on their own entry.
  final NavigationItem landing;

  /// The settings menu's groups, top to bottom.
  final List<SettingsGroup> settingsGroups;

  /// The module's settings sections, flat and in menu order.
  List<SettingsSection> get settingsSections => [for (final group in settingsGroups) ...group.sections];
}

/// The shared tools in their default order: multi-view, search, the recording
/// centre and the link parser. The non-live modules show them as their tools
/// block under their own entries; the settings tool-order editor persists
/// this order.
const List<NavigationItem> kToolItems = [
  NavigationItem.multiview,
  NavigationItem.search,
  NavigationItem.record,
  NavigationItem.toolbox,
];

/// The settings every module shares: the app's own surface. A module adds
/// its own category on top of these (live its sources, danmaku and
/// recording; IPTV its guide updates; video its Bilibili account), never
/// borrows another module's. Categories are the sidebar's entries; the
/// pages inside them are reached from the category's overview.
const List<SettingsGroup> _appCategories = [
  (labelKey: 'groupApp', sections: [SettingsSection.personalization, SettingsSection.playback, SettingsSection.system]),
];

/// Live's categories sit in the app list with the shared ones: a group
/// header repeating the category's own name ("Live / Live") is noise, not
/// structure.
const List<SettingsGroup> _liveAppCategories = [
  (
    labelKey: 'groupApp',
    sections: [SettingsSection.live, SettingsSection.personalization, SettingsSection.playback, SettingsSection.system],
  ),
];

const List<SettingsGroup> _aboutCategories = [
  (labelKey: 'groupAbout', sections: [SettingsSection.about]),
];

/// The module registry: one row per content type.
const Map<AppModule, ModuleNavigation> kModuleNavigation = {
  // The reference's menu, block for block: the ways to find a room, the
  // tools, the three feeds, and the recording centre.
  AppModule.live: ModuleNavigation(
    menu: [
      [NavigationItem.search, NavigationItem.history],
      [NavigationItem.toolbox, NavigationItem.multiview],
      [NavigationItem.favorites, NavigationItem.hot, NavigationItem.zones],
      [NavigationItem.record],
    ],
    landing: NavigationItem.hot,
    settingsGroups: [..._liveAppCategories, ..._aboutCategories],
  ),
  AppModule.iptv: ModuleNavigation(
    menu: [
      [NavigationItem.channels, NavigationItem.favorites, NavigationItem.history],
      kToolItems,
    ],
    landing: NavigationItem.channels,
    // IPTV's own surface is guide updates and source syncing; the app-wide
    // groups follow unchanged. Nothing from the live room (danmaku,
    // recording, platforms) or the Bilibili station belongs here.
    settingsGroups: [
      (labelKey: 'groupIptv', sections: [SettingsSection.iptv]),
      ..._appCategories,
      ..._aboutCategories,
    ],
  ),
  AppModule.vod: ModuleNavigation(
    menu: [
      [NavigationItem.vod, NavigationItem.favorites, NavigationItem.history],
      kToolItems,
    ],
    landing: NavigationItem.vod,
    // The video station's own page: its Bilibili account, the quality a
    // video opens with and its playback behaviour. Live's sources and
    // danmaku stay out of it.
    settingsGroups: [
      (labelKey: 'groupVod', sections: [SettingsSection.vod]),
      ..._appCategories,
      ..._aboutCategories,
    ],
  ),
  AppModule.music: ModuleNavigation(
    menu: [
      [NavigationItem.music, NavigationItem.favorites, NavigationItem.history],
      kToolItems,
    ],
    landing: NavigationItem.music,
    // No music source feeds the module yet; it carries only the app's own
    // settings rather than borrowing another module's playback or sources.
    settingsGroups: [..._appCategories, ..._aboutCategories],
  ),
};

/// The navigation of [module].
ModuleNavigation navigationOf(AppModule module) => kModuleNavigation[module]!;

/// Where a module lands when chosen in the app switcher.
NavigationItem defaultNavigationItemFor(AppModule module) => navigationOf(module).landing;

/// The page a menu entry shows outside the live module. Live's entries are
/// router branches; the other modules render these pages in place, so every
/// item their menus list is a page that actually opens.
const Map<NavigationItem, Widget Function()> kModulePages = {
  NavigationItem.channels: IptvPage.new,
  NavigationItem.vod: VodPage.new,
  NavigationItem.music: MusicPage.new,
  NavigationItem.favorites: FavoritesPage.new,
  NavigationItem.history: HistoryPage.new,
  NavigationItem.zones: AreasPage.new,
  NavigationItem.hot: PopularPage.new,
  NavigationItem.search: SearchPage.new,
  NavigationItem.multiview: MultiviewPage.new,
  NavigationItem.record: RecorderPage.new,
  NavigationItem.toolbox: ToolboxPage.new,
};
