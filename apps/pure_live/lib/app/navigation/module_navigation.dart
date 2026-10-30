import 'package:flutter/widgets.dart' show Widget;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/modules/hongguo/hongguo.dart';
import 'package:pure_live/modules/iptv/iptv.dart';
import 'package:pure_live/modules/live/areas/areas.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/multiview/multiview.dart';
import 'package:pure_live/modules/live/popular/popular.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/search/search.dart';
import 'package:pure_live/modules/live/toolbox/toolbox.dart';
import 'package:pure_live/modules/music/music.dart';
import 'package:pure_live/modules/vod/vod.dart';
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

/// The live module's tools in their default order: multi-view, the toolbox,
/// the search and the watch history. The settings tool-order editor
/// persists this order; the recording centre is a home-menu destination,
/// not a tool, so it is not listed here. The other modules keep their own
/// menus.
const List<NavigationItem> kToolItems = [
  NavigationItem.multiview,
  NavigationItem.toolbox,
  NavigationItem.logs,
  NavigationItem.search,
  NavigationItem.history,
];

/// The settings every module shares, grouped into first-level categories.
/// Each module registers its own category first (its business pages), then
/// the app-wide ones; live inserts its business category between
/// Personalization and Playback. A category is a page listing its sections,
/// and every section listed is a pane that carries settings rows.
const SettingsGroup _personalizationGroup = (
  labelKey: 'groupPersonalization',
  sections: [SettingsSection.theme, SettingsSection.background, SettingsSection.nav, SettingsSection.browsing],
);

const SettingsGroup _liveGroup = (
  labelKey: 'groupLive',
  sections: [SettingsSection.sites, SettingsSection.refresh, SettingsSection.danmaku, SettingsSection.recording],
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
    SettingsSection.logs,
    SettingsSection.backup,
  ],
);

const SettingsGroup _aboutGroup = (labelKey: 'groupAbout', sections: [SettingsSection.about]);

/// What a non-live module shares: the appearance, the player's engine, the
/// system pages and About — never the live page's own rows (the navigation
/// menu, the card layout, the picture options). Live's own catalogue is
/// left exactly as it was.
const SettingsGroup _sharedAppearanceGroup = (
  labelKey: 'groupPersonalization',
  sections: [SettingsSection.theme, SettingsSection.background],
);

const SettingsGroup _sharedPlaybackGroup = (labelKey: 'groupPlayback', sections: [SettingsSection.kernel]);

const List<SettingsGroup> _sharedGroups = [_sharedAppearanceGroup, _sharedPlaybackGroup, _systemGroup, _aboutGroup];

/// The module registry: one row per content type.
const Map<AppModule, ModuleNavigation> kModuleNavigation = {
  // The live home's rail: the four home destinations as one block — the
  // navigation setting orders and hides these, its default being favorites,
  // hot feed, areas and the recording centre — then the tools block the
  // tool-order setting sorts: multi-view, the link parser, the log console,
  // search and history.
  AppModule.live: ModuleNavigation(
    menu: [
      [NavigationItem.favorites, NavigationItem.hot, NavigationItem.zones, NavigationItem.record],
      [
        NavigationItem.multiview,
        NavigationItem.toolbox,
        NavigationItem.logs,
        NavigationItem.search,
        NavigationItem.history,
      ],
    ],
    landing: NavigationItem.hot,
    settingsGroups: [_personalizationGroup, _liveGroup, _playbackGroup, _systemGroup, _aboutGroup],
  ),
  AppModule.iptv: ModuleNavigation(
    // The reference's home order: 直播 first, then the collected channels and
    // the recent ones; the module's own sources sit under them.
    menu: [
      [NavigationItem.channels, NavigationItem.iptvFavorites, NavigationItem.iptvRecent],
      [NavigationItem.iptvGuide, NavigationItem.iptvSources],
    ],
    landing: NavigationItem.channels,
    // IPTV's own surface is guide updates and source syncing; the app-wide
    // groups follow unchanged. Nothing from the live room (danmaku,
    // recording, platforms) or the Bilibili station belongs here.
    settingsGroups: [
      (labelKey: 'groupIptv', sections: [SettingsSection.iptv]),
      ..._sharedGroups,
    ],
  ),
  AppModule.vod: ModuleNavigation(
    // The station's rail in the house measure — content first, tools under:
    // 主页 / 分区 / 影视 / 直播, then 搜索 / 个人. (The reference lists
    // 搜索 first; every module here puts its surfaces ahead of its tools.)
    menu: [
      [NavigationItem.vod, NavigationItem.vodRegions, NavigationItem.vodPgc, NavigationItem.vodLive],
      [NavigationItem.vodSearch, NavigationItem.vodPersonal],
    ],
    landing: NavigationItem.vod,
    // The video station's own page: its Bilibili account, the quality a
    // video opens with and its playback behaviour. Live's sources and
    // danmaku stay out of it.
    settingsGroups: [
      (labelKey: 'groupVod', sections: [SettingsSection.vod]),
      ..._sharedGroups,
    ],
  ),
  AppModule.music: ModuleNavigation(
    // The reference's rail, entry for entry: 搜索 / 歌单 / 排行榜 / 我的列表
    // are its four main entries; the viewer's own surfaces — 本地音乐 /
    // 下载管理 — sit under them as the module's tools.
    menu: [
      [NavigationItem.music, NavigationItem.musicSonglist, NavigationItem.musicToplist, NavigationItem.musicLibrary],
      [NavigationItem.musicLocal, NavigationItem.musicDownloads, NavigationItem.musicEffects],
    ],
    landing: NavigationItem.music,
    // The music module's settings rail, entry for entry the way lx-music
    // lays its own out — playback, lyrics, desktop lyrics, download,
    // sources, hotkeys, sync and the EQ — with the shared pages after.
    settingsGroups: [
      (
        labelKey: 'groupMusic',
        sections: [
          SettingsSection.music,
          SettingsSection.musicLyric,
          SettingsSection.musicDesktopLyric,
          SettingsSection.musicDownload,
          SettingsSection.musicSources,
          SettingsSection.musicHotkeys,
          SettingsSection.musicSync,
          SettingsSection.musicEq,
        ],
      ),
      ..._sharedGroups,
    ],
  ),
  AppModule.hongguo: ModuleNavigation(
    // The reference's top row, entry for entry: the home feed, find-drama
    // and the boards; then the viewer's shelves — favorites, history and
    // the account reservations; then the account itself and the search.
    menu: [
      [NavigationItem.hongguoHome, NavigationItem.hongguoFind, NavigationItem.hongguoRank],
      [NavigationItem.hongguoFavorites, NavigationItem.hongguoHistory, NavigationItem.hongguoReservations],
      [NavigationItem.hongguoAccount, NavigationItem.hongguoSearch],
    ],
    landing: NavigationItem.hongguoHome,
    // The station's own page: the companion service it asks and the
    // rendition an episode opens with. Nothing from the live room or the
    // Bilibili station belongs here.
    settingsGroups: [
      (labelKey: 'groupHongguo', sections: [SettingsSection.hongguo]),
      ..._sharedGroups,
    ],
  ),
};

/// The navigation of [module].
ModuleNavigation navigationOf(AppModule module) => kModuleNavigation[module]!;

/// Where a module lands when chosen in the app switcher.
NavigationItem defaultNavigationItemFor(AppModule module) => navigationOf(module).landing;

/// The page a menu entry shows outside the live module. Live's entries are
/// router branches; the other modules render these pages in place, so every
/// item their menus list is a page that actually opens. Entries that share a
/// page differ only in where that page opens — the station's own tabs, the
/// IPTV module's surfaces, the music module's lists.
final Map<NavigationItem, Widget Function()> kModulePages = {
  NavigationItem.channels: IptvPage.new,
  NavigationItem.iptvGuide: IptvGuidePage.new,
  NavigationItem.iptvSources: () => const IptvPage(initialView: IptvView.sources),
  NavigationItem.iptvFavorites: () => const IptvPage(initialScope: IptvChannelScope.favourites),
  NavigationItem.iptvRecent: IptvRecentPage.new,
  NavigationItem.vod: VodPage.new,
  NavigationItem.vodLive: VodLivePage.new,
  NavigationItem.vodPgc: VodPgcPage.new,
  NavigationItem.vodRegions: VodRegionsPage.new,
  NavigationItem.vodSearch: VodSearchPage.new,
  NavigationItem.vodPersonal: VodPersonalPage.new,
  NavigationItem.music: MusicPage.new,
  NavigationItem.musicSonglist: () => const MusicPage(view: MusicView.songlists),
  NavigationItem.musicToplist: () => const MusicPage(view: MusicView.toplists),
  NavigationItem.musicLibrary: () => const MusicPage(view: MusicView.mine),
  NavigationItem.musicLocal: () => const MusicPage(view: MusicView.local),
  NavigationItem.musicDownloads: () => const MusicPage(view: MusicView.downloads),
  NavigationItem.musicEffects: MusicEqCenterPage.new,
  NavigationItem.hongguoHome: HongguoPage.new,
  NavigationItem.hongguoFind: () => const HongguoPage(view: HongguoView.find),
  NavigationItem.hongguoRank: () => const HongguoPage(view: HongguoView.rank),
  NavigationItem.hongguoFavorites: () => const HongguoPage(view: HongguoView.favorites),
  NavigationItem.hongguoHistory: () => const HongguoPage(view: HongguoView.history),
  NavigationItem.hongguoReservations: () => const HongguoPage(view: HongguoView.reservations),
  NavigationItem.hongguoAccount: () => const HongguoPage(view: HongguoView.account),
  NavigationItem.hongguoSearch: () => const HongguoPage(view: HongguoView.search),
  NavigationItem.favorites: FavoritesPage.new,
  NavigationItem.history: HistoryPage.new,
  NavigationItem.zones: AreasPage.new,
  NavigationItem.hot: PopularPage.new,
  NavigationItem.search: SearchPage.new,
  NavigationItem.multiview: MultiviewPage.new,
  NavigationItem.record: RecorderPage.new,
  NavigationItem.toolbox: ToolboxPage.new,
};
