import 'package:desen_ui/desen_ui.dart';

import 'package:pure_live/l10n/translations.dart';

/// One group of a module's settings menu: a label key (resolved through the
/// settings namespace) and its sections. The module registry owns the
/// groups; this shared type lets the session helpers read them without the
/// registry importing a settings widget.
typedef SettingsGroup = ({String labelKey, List<SettingsSection> sections});

/// The settings surface's pages, in the reference's order: a grouped list
/// on the left (desktop) or a pushed submenu (mobile), one pane of content
/// per entry on the right.
///
/// The first values are the categories the sidebar shows — Personalization,
/// Live, Playback, System, About — and the pages nested under them follow.
/// A category's overview lists its children; the child remains a route (and
/// a deep link) even though the sidebar reaches it through the category.
enum SettingsSection {
  personalization(DsIcons.brushFlat),
  live(DsIcons.live),
  playback(DsIcons.play),
  system(DsIcons.settings),
  appearance(DsIcons.palette),
  background(DsIcons.wallpaper),
  backgroundImages(DsIcons.image),
  backgroundRandom(DsIcons.shuffle),
  backgroundVideos(DsIcons.film),
  backgroundColors(DsIcons.palette),
  backgroundDevice(DsIcons.upload),
  nav(DsIcons.panelLeft),
  general(DsIcons.appWindow),
  sources(DsIcons.antenna),
  danmaku(DsIcons.captions),
  recording(DsIcons.disc),
  video(DsIcons.video),
  kernel(DsIcons.cpu),
  network(DsIcons.globe),
  nodes(DsIcons.activity),
  logs(DsIcons.terminal),
  dataCache(DsIcons.database),
  backup(DsIcons.databaseBackup),
  about(DsIcons.info),
  iptv(DsIcons.antenna),
  vod(DsIcons.film),
  // Legacy routes kept readable: their panes live inside the merged pages
  // now, but a stored deep link still resolves to the relevant content.
  refresh(DsIcons.refreshCw),
  miniDanmaku(DsIcons.pictureInPicture),
  data(DsIcons.database),
  cache(DsIcons.archive);

  SettingsSection(this.icon);

  /// The entry's icon.
  final DsIconData icon;

  /// The entry's name.
  String label(Translations t) => switch (this) {
    SettingsSection.personalization => t.settings.navPersonalization,
    SettingsSection.live => t.settings.navLive,
    SettingsSection.playback => t.settings.navPlayback,
    SettingsSection.system => t.settings.navSystem,
    SettingsSection.appearance => t.settings.navAppearance,
    SettingsSection.background => t.settings.navBackground,
    SettingsSection.backgroundImages => t.settings.backgroundImagesTitle,
    SettingsSection.backgroundRandom => t.settings.navRandomWallpaper,
    SettingsSection.backgroundVideos => t.settings.backgroundVideosTitle,
    SettingsSection.backgroundColors => t.settings.backgroundColorsTitle,
    SettingsSection.backgroundDevice => t.settings.backgroundDeviceTitle,
    SettingsSection.nav => t.settings.navNavigation,
    SettingsSection.general => t.settings.navGeneral,
    SettingsSection.sources => t.settings.navLiveSources,
    SettingsSection.danmaku => t.settings.navDanmaku,
    SettingsSection.recording => t.settings.navRecording,
    SettingsSection.video => t.settings.navPlaybackPreferences,
    SettingsSection.kernel => t.settings.navKernel,
    SettingsSection.network => t.settings.navProxy,
    SettingsSection.nodes => t.toolbox.toolNetworkTitle,
    SettingsSection.logs => t.toolbox.toolLogsTitle,
    SettingsSection.dataCache => t.settings.navDataCache,
    SettingsSection.backup => t.settings.navBackup,
    SettingsSection.about => t.settings.navAbout,
    SettingsSection.iptv => t.settings.navIptv,
    SettingsSection.vod => t.settings.navVod,
    SettingsSection.refresh => t.settings.navRefresh,
    SettingsSection.miniDanmaku => t.settings.navMiniDanmaku,
    SettingsSection.data => t.settings.navData,
    SettingsSection.cache => t.settings.navCache,
  };

  /// One line on what the section manages.
  String description(Translations t) => switch (this) {
    SettingsSection.personalization => t.settings.personalizationDescription,
    SettingsSection.live => t.settings.liveSettingsDescription,
    SettingsSection.playback => t.settings.playbackSettingsDescription,
    SettingsSection.system => t.settings.systemDescription,
    SettingsSection.appearance => t.settings.appearanceDescription,
    SettingsSection.background => t.settings.backgroundDescription,
    SettingsSection.backgroundImages => t.settings.backgroundImagesDescription,
    SettingsSection.backgroundRandom => t.settings.randomWallpaperDescription,
    SettingsSection.backgroundVideos => t.settings.backgroundVideosDescription,
    SettingsSection.backgroundColors => t.settings.backgroundColorsDescription,
    SettingsSection.backgroundDevice => t.settings.backgroundDeviceDescription,
    SettingsSection.nav => t.settings.navigationDescription,
    SettingsSection.general => t.settings.generalDescription,
    SettingsSection.sources => t.settings.liveSourcesDescription,
    SettingsSection.danmaku => t.settings.danmakuDescription,
    SettingsSection.recording => t.settings.recordingDescription,
    SettingsSection.video => t.settings.videoDescription,
    SettingsSection.kernel => t.settings.kernelDescription,
    SettingsSection.network => t.settings.proxyDescription,
    SettingsSection.nodes => t.toolbox.toolNetworkDescription,
    SettingsSection.logs => t.toolbox.toolLogsDescription,
    SettingsSection.dataCache => t.settings.dataCacheDescription,
    SettingsSection.backup => t.settings.backupDescription,
    SettingsSection.about => t.settings.aboutDescription,
    SettingsSection.iptv => t.settings.iptvDescription,
    SettingsSection.vod => t.settings.vodDescription,
    SettingsSection.refresh => t.settings.refreshDescription,
    SettingsSection.miniDanmaku => t.settings.miniDanmakuDescription,
    SettingsSection.data => t.settings.dataDescription,
    SettingsSection.cache => t.settings.cacheDescription,
  };

  /// The category this page belongs to, or null for a top-level category.
  SettingsSection? get parentSection => switch (this) {
    SettingsSection.appearance || SettingsSection.nav => SettingsSection.personalization,
    SettingsSection.background => SettingsSection.personalization,
    SettingsSection.backgroundImages ||
    SettingsSection.backgroundRandom ||
    SettingsSection.backgroundVideos ||
    SettingsSection.backgroundColors ||
    SettingsSection.backgroundDevice => SettingsSection.background,
    SettingsSection.sources || SettingsSection.danmaku || SettingsSection.recording => SettingsSection.live,
    SettingsSection.video || SettingsSection.kernel => SettingsSection.playback,
    SettingsSection.general ||
    SettingsSection.network ||
    SettingsSection.nodes ||
    SettingsSection.logs ||
    SettingsSection.dataCache ||
    SettingsSection.backup => SettingsSection.system,
    // Legacy routes: show the category they now live under.
    SettingsSection.refresh || SettingsSection.miniDanmaku => SettingsSection.live,
    SettingsSection.data || SettingsSection.cache => SettingsSection.system,
    _ => null,
  };

  /// The sidebar row this page highlights: its top-level category when
  /// nested, else itself.
  SettingsSection get menuSection {
    var current = this;
    for (var parent = parentSection; parent != null; parent = parent.parentSection) {
      current = parent;
    }
    return current;
  }

  /// Whether this page is reached through a category rather than the menu.
  bool get isNested => parentSection != null;

  /// Parses the route's segment; null when it names nothing.
  static SettingsSection? of(String name) {
    for (final section in SettingsSection.values) {
      if (section.name == name) return section;
    }
    return null;
  }
}

/// The pages under [category], in reading order. Empty for a page that has
/// no children (a leaf category such as IPTV or About).
List<SettingsSection> settingsChildrenOf(SettingsSection category) => switch (category) {
  SettingsSection.personalization => const [
    SettingsSection.appearance,
    SettingsSection.background,
    SettingsSection.nav,
  ],
  SettingsSection.background => const [
    SettingsSection.backgroundImages,
    SettingsSection.backgroundRandom,
    SettingsSection.backgroundVideos,
    SettingsSection.backgroundColors,
    SettingsSection.backgroundDevice,
  ],
  SettingsSection.live => const [SettingsSection.sources, SettingsSection.danmaku, SettingsSection.recording],
  SettingsSection.playback => const [SettingsSection.video, SettingsSection.kernel],
  SettingsSection.system => const [
    SettingsSection.general,
    SettingsSection.network,
    SettingsSection.nodes,
    SettingsSection.logs,
    SettingsSection.dataCache,
    SettingsSection.backup,
  ],
  _ => const [],
};

/// Every page under [section], at any depth: its own children first, then
/// theirs, in reading order.
List<SettingsSection> settingsDescendantsOf(SettingsSection section) => [
  for (final child in settingsChildrenOf(section)) ...[child, ...settingsDescendantsOf(child)],
];

/// Every page the settings search may open: the menu's categories plus the
/// children behind them, which are not rows of the menu themselves.
List<SettingsSection> settingsSearchSections(Iterable<SettingsGroup> groups) {
  final sections = [for (final group in groups) ...group.sections];
  // Nested pages can themselves be categories (Background lists its four
  // sources), so the walk is a queue rather than one pass over the menu.
  for (var index = 0; index < sections.length; index++) {
    for (final child in settingsChildrenOf(sections[index])) {
      if (!sections.contains(child)) sections.add(child);
    }
  }
  return sections;
}

/// The group a section sits in for a module's own [groups] — the group the
/// settings pane prints above the page's name; null when the module does
/// not carry it.
String? settingsGroupKeyOf(Iterable<SettingsGroup> groups, SettingsSection section) {
  for (final group in groups) {
    if (group.sections.contains(section)) return group.labelKey;
  }
  return null;
}

/// A group label's words.
String settingsGroupLabel(Translations t, String key) => switch (key) {
  'groupApp' => t.settings.groupApp,
  'groupLive' => t.settings.groupLive,
  'groupIptv' => t.settings.groupIptv,
  'groupVod' => t.settings.groupVod,
  'groupData' => t.settings.groupData,
  'groupAbout' => t.settings.groupAbout,
  _ => key,
};
