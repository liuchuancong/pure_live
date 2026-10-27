import 'package:desen_ui/desen_ui.dart';

import 'package:pure_live/l10n/translations.dart';

/// One first-level settings category: a label key (resolved through the
/// settings namespace) and the section pages it carries. The module registry
/// owns the groups; this shared type lets the settings surface and the
/// session helpers read them without importing a widget.
typedef SettingsGroup = ({String labelKey, List<SettingsSection> sections});

/// The settings surface's pages.
///
/// The surface is two levels: the menus list first-level categories
/// ([SettingsGroup]s), and a category's page lists the section pages it
/// carries — no value here is a pure index. A subpage (an entry in
/// [settingsChildrenOf]) is reached from its parent section's pane and
/// keeps the parent's category lit.
///
/// Fourteen values are deep-link aliases only: the old category and
/// overview pages they name no longer exist, [of] resolves them to the
/// page that now carries the content, and no sidebar row or search hit
/// offers them.
enum SettingsSection {
  // 个性化 group.
  theme(DsIcons.palette),
  fontApp(DsIcons.type),
  background(DsIcons.wallpaper),
  backgroundImages(DsIcons.image),
  backgroundRandom(DsIcons.shuffle),
  backgroundVideos(DsIcons.film),
  backgroundColors(DsIcons.palette),
  backgroundDevice(DsIcons.upload),
  nav(DsIcons.panelLeft),
  navHomeMenu(DsIcons.listTodo),
  navToolOrder(DsIcons.listOrdered),
  browsing(DsIcons.layoutGrid),
  roomCard(DsIcons.idCard),
  // 直播 group.
  sites(DsIcons.antenna),
  sitesDisplay(DsIcons.listOrdered),
  accounts(DsIcons.userRound),
  refresh(DsIcons.refreshCw),
  followTags(DsIcons.tag),
  danmaku(DsIcons.captions),
  danmakuStyle(DsIcons.type),
  fontDanmaku(DsIcons.type),
  danmakuDisplay(DsIcons.list),
  shield(DsIcons.shield),
  recording(DsIcons.disc),
  // 播放 group.
  quality(DsIcons.gauge),
  picture(DsIcons.rectangleHorizontal),
  floatingWindow(DsIcons.pictureInPicture2),
  portrait(DsIcons.rectangleVertical),
  audience(DsIcons.eye),
  kernel(DsIcons.cpu),
  kernelAdvanced(DsIcons.slidersHorizontal),
  // 系统 group.
  startup(DsIcons.rocket),
  window(DsIcons.appWindow),
  network(DsIcons.globe),
  nodes(DsIcons.activity),
  dataCache(DsIcons.database),
  backup(DsIcons.databaseBackup),
  webdavSync(DsIcons.cloudUpload),
  logs(DsIcons.terminal),
  // 关于 / module groups.
  about(DsIcons.info),
  iptv(DsIcons.antenna),
  vod(DsIcons.film),
  // Deep-link aliases: their content lives on another page now (see
  // [aliasTarget]); kept readable so stored links never 404.
  personalization(DsIcons.brushFlat),
  live(DsIcons.live),
  playback(DsIcons.play),
  system(DsIcons.settings),
  appearance(DsIcons.palette),
  general(DsIcons.appWindow),
  sources(DsIcons.antenna),
  typography(DsIcons.type),
  miniDanmaku(DsIcons.pictureInPicture),
  video(DsIcons.video),
  audio(DsIcons.volume),
  data(DsIcons.database),
  cache(DsIcons.archive);

  SettingsSection(this.icon);

  /// The entry's icon.
  final DsIconData icon;

  /// The entry's name.
  String label(Translations t) => switch (this) {
    SettingsSection.theme => t.settings.navTheme,
    SettingsSection.fontApp => t.settings.fontManagerTitle,
    SettingsSection.background => t.settings.navBackground,
    SettingsSection.backgroundImages => t.settings.backgroundImagesTitle,
    SettingsSection.backgroundRandom => t.settings.navRandomWallpaper,
    SettingsSection.backgroundVideos => t.settings.backgroundVideosTitle,
    SettingsSection.backgroundColors => t.settings.backgroundColorsTitle,
    SettingsSection.backgroundDevice => t.settings.backgroundDeviceTitle,
    SettingsSection.nav => t.settings.navNavigation,
    SettingsSection.navHomeMenu => t.settings.navHomeMenuTitle,
    SettingsSection.navToolOrder => t.settings.toolsOrder,
    SettingsSection.browsing => t.settings.navBrowsing,
    SettingsSection.roomCard => t.settings.roomCardSettingsTitle,
    SettingsSection.sites => t.settings.navSites,
    SettingsSection.sitesDisplay => t.settings.sitesDisplay,
    SettingsSection.accounts => t.settings.navAccounts,
    SettingsSection.refresh => t.settings.navRefresh,
    SettingsSection.followTags => t.settings.tagManagement,
    SettingsSection.danmaku => t.settings.navDanmaku,
    SettingsSection.danmakuStyle => t.settings.danmakuStyleGroup,
    SettingsSection.fontDanmaku => t.settings.danmakuFont,
    SettingsSection.danmakuDisplay => t.settings.danmakuDisplayGroup,
    SettingsSection.shield => t.settings.navShield,
    SettingsSection.recording => t.settings.navRecording,
    SettingsSection.quality => t.settings.qualityAudioTitle,
    SettingsSection.picture => t.settings.navPicture,
    SettingsSection.floatingWindow => t.settings.navFloatingWindow,
    SettingsSection.portrait => t.settings.navPortrait,
    SettingsSection.audience => t.settings.navAudience,
    SettingsSection.kernel => t.settings.navKernel,
    SettingsSection.kernelAdvanced => t.settings.kernelAdvancedTitle,
    SettingsSection.startup => t.settings.navStartup,
    SettingsSection.window => t.settings.navWindow,
    SettingsSection.network => t.settings.navProxy,
    SettingsSection.nodes => t.toolbox.toolNetworkTitle,
    SettingsSection.dataCache => t.settings.navDataCache,
    SettingsSection.backup => t.settings.navBackup,
    SettingsSection.webdavSync => t.settings.webdavSyncTitle,
    SettingsSection.logs => t.toolbox.toolLogsTitle,
    SettingsSection.about => t.settings.navAbout,
    SettingsSection.iptv => t.settings.navIptv,
    SettingsSection.vod => t.settings.navVod,
    // Aliases: their pre-merge words, kept for anything still naming them.
    SettingsSection.personalization => t.settings.navPersonalization,
    SettingsSection.live => t.settings.navLive,
    SettingsSection.playback => t.settings.navPlayback,
    SettingsSection.system => t.settings.navSystem,
    SettingsSection.appearance => t.settings.navAppearance,
    SettingsSection.typography => t.settings.navTypography,
    SettingsSection.general => t.settings.navGeneral,
    SettingsSection.sources => t.settings.navLiveSources,
    SettingsSection.miniDanmaku => t.settings.navMiniDanmaku,
    SettingsSection.video => t.settings.navPlaybackPreferences,
    SettingsSection.audio => t.settings.navAudio,
    SettingsSection.data => t.settings.navData,
    SettingsSection.cache => t.settings.navCache,
  };

  /// One line on what the section manages.
  String description(Translations t) => switch (this) {
    SettingsSection.theme => t.settings.themePageDescription,
    SettingsSection.fontApp => t.settings.fontManagerDescription,
    SettingsSection.background => t.settings.backgroundDescription,
    SettingsSection.backgroundImages => t.settings.backgroundImagesDescription,
    SettingsSection.backgroundRandom => t.settings.randomWallpaperDescription,
    SettingsSection.backgroundVideos => t.settings.backgroundVideosDescription,
    SettingsSection.backgroundColors => t.settings.backgroundColorsDescription,
    SettingsSection.backgroundDevice => t.settings.backgroundDeviceDescription,
    SettingsSection.nav => t.settings.navigationDescription,
    SettingsSection.navHomeMenu => t.settings.navHomeMenuDescription,
    SettingsSection.navToolOrder => t.settings.toolsOrderDesc,
    SettingsSection.browsing => t.settings.browsingPageDescription,
    SettingsSection.roomCard => t.settings.roomCardSettingsDescription,
    SettingsSection.sites => t.settings.sitesDescription,
    SettingsSection.sitesDisplay => t.settings.sitesDisplayDesc,
    SettingsSection.accounts => t.settings.accountsPageDescription,
    SettingsSection.refresh => t.settings.refreshDescription,
    SettingsSection.followTags => t.settings.tagManagementDesc,
    SettingsSection.danmaku => t.settings.danmakuDescription,
    SettingsSection.fontDanmaku => t.settings.danmakuFontManagerDescription,
    SettingsSection.shield => t.settings.shieldDescription,
    SettingsSection.recording => t.settings.recordingDescription,
    SettingsSection.quality => t.settings.qualityAudioDescription,
    SettingsSection.picture => t.settings.picturePageDescription,
    SettingsSection.floatingWindow => t.settings.floatingWindowPageDescription,
    SettingsSection.portrait => t.settings.portraitPageDescription,
    SettingsSection.audience => t.settings.audiencePageDescription,
    SettingsSection.kernel => t.settings.kernelDescription,
    SettingsSection.kernelAdvanced => t.settings.kernelAdvancedDescription,
    SettingsSection.startup => t.settings.startupPageDescription,
    SettingsSection.window => t.settings.windowPageDescription,
    SettingsSection.network => t.settings.proxyDescription,
    SettingsSection.nodes => t.toolbox.toolNetworkDescription,
    SettingsSection.dataCache => t.settings.dataCacheDescription,
    SettingsSection.backup => t.settings.backupDescription,
    SettingsSection.webdavSync => t.settings.webdavSyncDescription,
    SettingsSection.logs => t.toolbox.toolLogsDescription,
    SettingsSection.about => t.settings.aboutDescription,
    SettingsSection.iptv => t.settings.iptvDescription,
    SettingsSection.vod => t.settings.vodDescription,
    SettingsSection.personalization => t.settings.personalizationDescription,
    SettingsSection.live => t.settings.liveSettingsDescription,
    SettingsSection.playback => t.settings.playbackSettingsDescription,
    SettingsSection.system => t.settings.systemDescription,
    SettingsSection.appearance => t.settings.appearanceDescription,
    SettingsSection.typography => t.settings.typographyPageDescription,
    SettingsSection.general => t.settings.generalDescription,
    SettingsSection.sources => t.settings.liveSourcesDescription,
    SettingsSection.danmakuStyle => t.settings.danmakuStyleDescription,
    SettingsSection.danmakuDisplay => t.settings.danmakuDisplayDescription,
    SettingsSection.miniDanmaku => t.settings.miniDanmakuDescription,
    SettingsSection.video => t.settings.videoDescription,
    SettingsSection.audio => t.settings.audioPageDescription,
    SettingsSection.data => t.settings.dataDescription,
    SettingsSection.cache => t.settings.cacheDescription,
  };

  /// The subpage's parent row, or null for a row the sidebar lists
  /// directly (every alias answers null; it resolves through [aliasTarget]
  /// before the tree is consulted).
  SettingsSection? get parentSection => switch (this) {
    SettingsSection.fontApp => SettingsSection.theme,
    SettingsSection.fontDanmaku => SettingsSection.danmakuStyle,
    SettingsSection.backgroundImages ||
    SettingsSection.backgroundRandom ||
    SettingsSection.backgroundVideos ||
    SettingsSection.backgroundColors ||
    SettingsSection.backgroundDevice => SettingsSection.background,
    SettingsSection.accounts => SettingsSection.sites,
    SettingsSection.sitesDisplay => SettingsSection.sites,
    SettingsSection.navHomeMenu || SettingsSection.navToolOrder => SettingsSection.nav,
    SettingsSection.roomCard => SettingsSection.browsing,
    SettingsSection.followTags => SettingsSection.refresh,
    SettingsSection.shield || SettingsSection.danmakuStyle || SettingsSection.danmakuDisplay => SettingsSection.danmaku,
    SettingsSection.portrait || SettingsSection.floatingWindow => SettingsSection.picture,
    SettingsSection.audience => SettingsSection.sites,
    SettingsSection.kernelAdvanced => SettingsSection.kernel,
    SettingsSection.nodes => SettingsSection.network,
    SettingsSection.webdavSync => SettingsSection.backup,
    _ => null,
  };

  /// The page a deep-link alias now lives on; null for a real page. The
  /// alias never renders its own pane — [of] resolves it before anything
  /// else reads it, and the settings dispatch maps it defensively too.
  SettingsSection? get aliasTarget => switch (this) {
    SettingsSection.personalization || SettingsSection.appearance => SettingsSection.theme,
    SettingsSection.typography => SettingsSection.theme,
    SettingsSection.live || SettingsSection.sources => SettingsSection.sites,
    SettingsSection.playback || SettingsSection.video || SettingsSection.audio => SettingsSection.quality,
    SettingsSection.system => SettingsSection.startup,
    SettingsSection.general => SettingsSection.browsing,
    SettingsSection.miniDanmaku => SettingsSection.danmakuStyle,
    SettingsSection.data || SettingsSection.cache => SettingsSection.dataCache,
    _ => null,
  };

  /// The page itself, or the page an alias names: everything downstream
  /// (dispatch, highlight, search) works on canonical pages only.
  SettingsSection get canonical => aliasTarget ?? this;

  /// The sidebar row this page highlights: its parent row when it is a
  /// subpage, else itself.
  SettingsSection get menuSection {
    var current = canonical;
    for (var parent = current.parentSection; parent != null; parent = parent.parentSection) {
      current = parent;
    }
    return current;
  }

  /// Whether this page is reached through its parent row rather than the
  /// sidebar.
  bool get isNested => parentSection != null;

  /// Parses the route's segment; an alias resolves to the page that now
  /// carries the content, null when the name is not a section at all.
  static SettingsSection? of(String name) {
    for (final section in SettingsSection.values) {
      if (section.name == name) return section.canonical;
    }
    return null;
  }
}

/// The pages under [category], one level deep. Empty for a leaf.
List<SettingsSection> settingsChildrenOf(SettingsSection category) => switch (category) {
  SettingsSection.background => const [
    // The built-in palette leads: it is the source that needs no network and
    // the one the reference's own background page puts first.
    SettingsSection.backgroundColors,
    SettingsSection.backgroundImages,
    SettingsSection.backgroundRandom,
    SettingsSection.backgroundVideos,
    SettingsSection.backgroundDevice,
  ],
  SettingsSection.sites => const [SettingsSection.sitesDisplay, SettingsSection.audience, SettingsSection.accounts],
  SettingsSection.nav => const [SettingsSection.navHomeMenu, SettingsSection.navToolOrder],
  SettingsSection.browsing => const [SettingsSection.roomCard],
  SettingsSection.refresh => const [SettingsSection.followTags],
  SettingsSection.danmaku => const [SettingsSection.danmakuStyle, SettingsSection.danmakuDisplay, SettingsSection.shield],
  SettingsSection.picture => const [SettingsSection.floatingWindow, SettingsSection.portrait],
  SettingsSection.kernel => const [SettingsSection.kernelAdvanced],
  SettingsSection.network => const [SettingsSection.nodes],
  SettingsSection.backup => const [SettingsSection.webdavSync],
  _ => const [],
};

/// Every page under [section], at any depth: its own children first, then
/// theirs, in reading order.
List<SettingsSection> settingsDescendantsOf(SettingsSection section) => [
  for (final child in settingsChildrenOf(section)) ...[child, ...settingsDescendantsOf(child)],
];

/// Every page the settings search may open: the menu's rows plus the
/// subpages behind them, which are not rows of the menu themselves.
List<SettingsSection> settingsSearchSections(Iterable<SettingsGroup> groups) {
  final sections = [for (final group in groups) ...group.sections];
  for (var index = 0; index < sections.length; index++) {
    for (final child in settingsChildrenOf(sections[index])) {
      if (!sections.contains(child)) sections.add(child);
    }
  }
  return sections;
}

/// A group label's words. The five app-wide groups reuse the category
/// names the old overview pages carried.
String settingsGroupLabel(Translations t, String key) => switch (key) {
  'groupPersonalization' => t.settings.navPersonalization,
  'groupLive' => t.settings.navLive,
  'groupPlayback' => t.settings.navPlayback,
  'groupSystem' => t.settings.navSystem,
  'groupApp' => t.settings.groupApp,
  'groupIptv' => t.settings.navIptv,
  'groupVod' => t.settings.navVod,
  'groupData' => t.settings.groupData,
  'groupAbout' => t.settings.groupAbout,
  _ => key,
};

/// One line on what a group carries: the category rows' description.
String settingsGroupDescription(Translations t, String key) => switch (key) {
  'groupPersonalization' => t.settings.personalizationDescription,
  'groupLive' => t.settings.liveSettingsDescription,
  'groupPlayback' => t.settings.playbackSettingsDescription,
  'groupSystem' => t.settings.systemDescription,
  'groupApp' => t.settings.generalDescription,
  'groupIptv' => t.settings.iptvDescription,
  'groupVod' => t.settings.vodDescription,
  'groupData' => t.settings.dataCacheDescription,
  'groupAbout' => t.settings.aboutDescription,
  _ => '',
};

/// The glyph a group's row carries in the category menus.
DsIconData settingsGroupIcon(String key) => switch (key) {
  'groupPersonalization' => DsIcons.palette,
  'groupLive' => DsIcons.live,
  'groupPlayback' => DsIcons.play,
  'groupSystem' => DsIcons.settings,
  'groupApp' => DsIcons.appWindow,
  'groupIptv' => DsIcons.antenna,
  'groupVod' => DsIcons.film,
  'groupData' => DsIcons.database,
  'groupAbout' => DsIcons.info,
  _ => DsIcons.settings,
};

/// The group [section] belongs to: the group that lists its top-level page.
/// A nested page follows its menu section up to the row the group carries.
SettingsGroup? settingsGroupOf(Iterable<SettingsGroup> groups, SettingsSection section) {
  final menu = section.canonical.menuSection;
  for (final group in groups) {
    if (group.sections.contains(menu)) return group;
  }
  return null;
}

/// The group the settings surface opens on when nothing else is chosen: the
/// app-wide first group every module carries.
const String kSettingsDefaultGroupKey = 'groupPersonalization';
