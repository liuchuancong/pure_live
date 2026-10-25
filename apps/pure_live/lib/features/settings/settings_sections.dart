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
enum SettingsSection {
  general(DsIcons.settings),
  appearance(DsIcons.palette),
  background(DsIcons.wallpaper),
  nav(DsIcons.panelLeft),
  refresh(DsIcons.refreshCw),
  network(DsIcons.globe),
  video(DsIcons.video),
  danmaku(DsIcons.captions),
  miniDanmaku(DsIcons.pictureInPicture),
  kernel(DsIcons.cpu),
  recording(DsIcons.disc),
  sites(DsIcons.antenna),
  iptv(DsIcons.antenna),
  vod(DsIcons.film),
  data(DsIcons.database),
  backup(DsIcons.databaseBackup),
  cache(DsIcons.archive),
  about(DsIcons.info);

  SettingsSection(this.icon);

  /// The entry's icon.
  final DsIconData icon;

  /// The entry's name.
  String label(Translations t) => switch (this) {
    SettingsSection.general => t.settings.navGeneral,
    SettingsSection.appearance => t.settings.navAppearance,
    SettingsSection.background => t.settings.navBackground,
    SettingsSection.nav => t.settings.navNavigation,
    SettingsSection.refresh => t.settings.navRefresh,
    SettingsSection.video => t.settings.navVideo,
    SettingsSection.danmaku => t.settings.navDanmaku,
    SettingsSection.miniDanmaku => t.settings.navMiniDanmaku,
    SettingsSection.kernel => t.settings.navKernel,
    SettingsSection.recording => t.settings.navRecording,
    SettingsSection.network => t.settings.navProxy,
    SettingsSection.sites => t.settings.navPlatforms,
    SettingsSection.iptv => t.settings.navIptv,
    SettingsSection.vod => t.settings.navVod,
    SettingsSection.data => t.settings.navData,
    SettingsSection.backup => t.settings.navBackup,
    SettingsSection.cache => t.settings.navCache,
    SettingsSection.about => t.settings.navAbout,
  };

  /// One line on what the section manages.
  String description(Translations t) => switch (this) {
    SettingsSection.general => t.settings.generalDescription,
    SettingsSection.appearance => t.settings.appearanceDescription,
    SettingsSection.background => t.settings.backgroundDescription,
    SettingsSection.nav => t.settings.navigationDescription,
    SettingsSection.refresh => t.settings.refreshDescription,
    SettingsSection.video => t.settings.videoDescription,
    SettingsSection.danmaku => t.settings.danmakuDescription,
    SettingsSection.miniDanmaku => t.settings.miniDanmakuDescription,
    SettingsSection.kernel => t.settings.kernelDescription,
    SettingsSection.recording => t.settings.recordingDescription,
    SettingsSection.network => t.settings.proxyDescription,
    SettingsSection.sites => t.settings.platformsDescription,
    SettingsSection.iptv => t.settings.iptvDescription,
    SettingsSection.vod => t.settings.vodDescription,
    SettingsSection.data => t.settings.dataDescription,
    SettingsSection.backup => t.settings.backupDescription,
    SettingsSection.cache => t.settings.cacheDescription,
    SettingsSection.about => t.settings.aboutDescription,
  };

  /// Parses the route's segment; null when it names nothing.
  static SettingsSection? of(String name) {
    for (final section in SettingsSection.values) {
      if (section.name == name) return section;
    }
    return null;
  }
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
  'groupInterface' => t.settings.groupInterface,
  'groupSources' => t.settings.groupSources,
  'groupPlayback' => t.settings.groupPlayback,
  'groupGeneral' => t.settings.groupGeneral,
  'groupBasics' => t.settings.groupBasics,
  'groupContent' => t.settings.groupContent,
  'groupIptv' => t.settings.groupIptv,
  'groupVod' => t.settings.groupVod,
  'groupData' => t.settings.groupData,
  'groupAbout' => t.settings.groupAbout,
  _ => key,
};
