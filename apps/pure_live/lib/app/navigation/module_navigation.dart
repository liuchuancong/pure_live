import 'package:flutter/widgets.dart' show Widget;

import 'package:pure_live/features/areas/areas.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/history/history.dart';
import 'package:pure_live/features/iptv/iptv.dart';
import 'package:pure_live/features/multiview/multiview.dart';
import 'package:pure_live/features/music/music.dart';
import 'package:pure_live/features/popular/popular.dart';
import 'package:pure_live/features/recorder/recorder.dart';
import 'package:pure_live/features/search/search.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/toolbox/toolbox.dart';
import 'package:pure_live/features/vod/vod.dart';
import 'package:pure_live/shared/shared.dart';

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

  /// The module's settings pages, flat and in menu order: the sidebar's
  /// rows plus the subpages they carry, so a selection landing on a
  /// subpage survives a module switch when the module offers its parent.
  List<SettingsSection> get settingsSections => [
    for (final group in settingsGroups)
      for (final section in group.sections) ...[section, ...settingsDescendantsOf(section)],
  ];
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

/// The settings every module shares, grouped the way the new settings
/// center reads: a non-clickable group heading over clickable page rows.
/// Each module registers its own group first (its business pages), then the
/// app-wide ones; live inserts its business group between Personalization
/// and Playback. Nothing here is an index page — every section listed is a
/// pane that carries settings rows.
const SettingsGroup _personalizationGroup = (
  labelKey: 'groupPersonalization',
  sections: [
    SettingsSection.theme,
    SettingsSection.typography,
    SettingsSection.background,
    SettingsSection.nav,
    SettingsSection.browsing,
  ],
);

const SettingsGroup _liveGroup = (
  labelKey: 'groupLive',
  sections: [SettingsSection.sites, SettingsSection.refresh, SettingsSection.danmaku, SettingsSection.localInteraction, SettingsSection.recording],
);

const SettingsGroup _playbackGroup = (
  labelKey: 'groupPlayback',
  sections: [SettingsSection.quality, SettingsSection.picture, SettingsSection.kernel],
);

const SettingsGroup _systemGroup = (
  labelKey: 'groupSystem',
  sections: [
    SettingsSection.startup,
    SettingsSection.window,
    SettingsSection.network,
    SettingsSection.dataCache,
    SettingsSection.backup,
    SettingsSection.logs,
  ],
);

const SettingsGroup _aboutGroup = (labelKey: 'groupAbout', sections: [SettingsSection.about]);

/// The app-wide groups in reading order; live's own group is spliced in
/// after Personalization.
const List<SettingsGroup> _appGroups = [_personalizationGroup, _playbackGroup, _systemGroup, _aboutGroup];

/// The module registry: one row per content type.
const Map<AppModule, ModuleNavigation> kModuleNavigation = {
  // The reference's menu: the ways to find a room, the tools, then the four
  // home destinations as one block — the navigation setting's saved order
  // (favorites, hot, zones, recording centre) has to read across all four.
  AppModule.live: ModuleNavigation(
    menu: [
      [NavigationItem.search, NavigationItem.history],
      [NavigationItem.toolbox, NavigationItem.multiview],
      [NavigationItem.favorites, NavigationItem.hot, NavigationItem.zones, NavigationItem.record],
    ],
    landing: NavigationItem.hot,
    settingsGroups: [_personalizationGroup, _liveGroup, _playbackGroup, _systemGroup, _aboutGroup],
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
      ..._appGroups,
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
      ..._appGroups,
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
    settingsGroups: _appGroups,
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
