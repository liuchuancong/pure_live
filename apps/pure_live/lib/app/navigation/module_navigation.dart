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
import 'package:pure_live/features/settings/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/toolbox/toolbox_page.dart' show ToolboxPage;
import 'package:pure_live/features/vod/vod_page.dart' show VodPage;
import 'package:pure_live/shared/enums/app_module.dart' show AppModule;
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// One group of a module's settings menu: a label key (resolved through the
/// settings namespace) and its sections.
typedef SettingsGroup = ({String labelKey, List<SettingsSection> sections});

/// One module's whole navigation surface, in one place.
///
/// A module is one content type (live, IPTV, VOD, music) and everything the
/// shell shows while it is selected: its business menu ([business]), the
/// shared tools it offers ([tools]), and the settings sections its settings
/// surface carries ([settingsGroups]). Adding a module or reshaping one is
/// one table edit here — the desktop sidebar, the phone drawer and the
/// settings page all read this registry, so they cannot drift apart.
///
/// The live module is the one whose pages are router branches (they keep
/// their state and own deep links); every other module's pages are looked up
/// per menu entry in [kModulePages] and rendered in place.
final class ModuleNavigation {
  /// A module's navigation definition.
  const ModuleNavigation({required this.business, required this.tools, required this.settingsGroups});

  /// The module's business menu, flat and in order (the sidebar's top
  /// block, no headings). Its first entry is the module's landing page.
  final List<NavigationItem> business;

  /// The shared tools under the divider; [kToolItems] in the viewer's own
  /// order unless the module offers a different set.
  final List<NavigationItem> tools;

  /// The settings menu's groups, top to bottom.
  final List<SettingsGroup> settingsGroups;

  /// The module's settings sections, flat and in menu order.
  List<SettingsSection> get settingsSections => [
    for (final group in settingsGroups) ...group.sections,
  ];

  /// Where the module lands when chosen in the app switcher.
  NavigationItem get landing => business.first;
}

/// The shared tools under the divider below a business menu.
const List<NavigationItem> kToolItems = [
  NavigationItem.multiview,
  NavigationItem.search,
  NavigationItem.record,
  NavigationItem.toolbox,
];

/// The settings every module shares: the app-wide surface. A module adds
/// its own group on top of these (live adds 站点; a future downloader would
/// add its downloads group), never edits another module's.
const List<SettingsGroup> _mediaSettings = [
  (
    labelKey: 'groupBasics',
    sections: [
      SettingsSection.general,
      SettingsSection.appearance,
      SettingsSection.network,
      SettingsSection.playback,
    ],
  ),
  (labelKey: 'groupData', sections: [SettingsSection.data, SettingsSection.cache]),
  (labelKey: 'groupAbout', sections: [SettingsSection.about]),
];

/// The module registry: one row per content type.
const Map<AppModule, ModuleNavigation> kModuleNavigation = {
  AppModule.live: ModuleNavigation(
    business: [NavigationItem.favorites, NavigationItem.hot, NavigationItem.zones],
    tools: kToolItems,
    settingsGroups: [
      (
        labelKey: 'groupBasics',
        sections: [
          SettingsSection.general,
          SettingsSection.appearance,
          SettingsSection.network,
          SettingsSection.playback,
          SettingsSection.shield,
        ],
      ),
      (labelKey: 'groupContent', sections: [SettingsSection.sites]),
      (labelKey: 'groupData', sections: [SettingsSection.data, SettingsSection.cache]),
      (labelKey: 'groupAbout', sections: [SettingsSection.about]),
    ],
  ),
  AppModule.iptv: ModuleNavigation(
    business: [NavigationItem.channels, NavigationItem.favorites, NavigationItem.history],
    tools: kToolItems,
    settingsGroups: _mediaSettings,
  ),
  AppModule.vod: ModuleNavigation(
    business: [NavigationItem.vod, NavigationItem.favorites, NavigationItem.history],
    tools: kToolItems,
    settingsGroups: _mediaSettings,
  ),
  AppModule.music: ModuleNavigation(
    business: [NavigationItem.music, NavigationItem.favorites, NavigationItem.history],
    tools: kToolItems,
    settingsGroups: _mediaSettings,
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
