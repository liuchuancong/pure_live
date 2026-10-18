import 'package:flutter/material.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/settings/appearance/appearance_page.dart';
import 'package:pure_live/features/settings/danmaku/danmaku_settings_page.dart';
import 'package:pure_live/features/settings/data/cache_data_page.dart';
import 'package:pure_live/features/settings/general/general_settings_page.dart';
import 'package:pure_live/features/settings/local_config/local_config_preview_page.dart';
import 'package:pure_live/features/settings/local_interaction/local_interaction_settings_page.dart';
import 'package:pure_live/features/settings/logs/logs_settings_page.dart';
import 'package:pure_live/features/settings/navigation/navigation_settings_page.dart';
import 'package:pure_live/features/settings/network/network_proxy_settings_page.dart';
import 'package:pure_live/features/settings/platforms/platforms_settings_page.dart';
import 'package:pure_live/features/settings/player/mpv_settings_page.dart';
import 'package:pure_live/features/settings/recording/record_settings_page.dart';
import 'package:pure_live/features/settings/refresh/refresh_settings_page.dart';
import 'package:pure_live/features/settings/video/video_settings_page.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The five groups of the settings overview (the reference's `SettingsArea`;
/// the old index's eleven sections collapse into these).
enum SettingsArea {
  /// Appearance and navigation.
  ui,

  /// Platforms, refresh, IPTV.
  sources,

  /// Video, danmaku, player, recording.
  playback,

  /// General, network, local interaction.
  general,

  /// Cache, backup, configuration preview, logs.
  data;

  /// The group title.
  String titleOf(Translations t) => switch (this) {
    SettingsArea.ui => t.settings.areaInterface,
    SettingsArea.sources => t.settings.areaSources,
    SettingsArea.playback => t.settings.areaPlayback,
    SettingsArea.general => t.settings.areaGeneral,
    SettingsArea.data => t.settings.areaData,
  };
}

/// The settings pages: the overview's rows, in its order. A page is either
/// built inline (`page`) or is another route of the app (`route`), which is
/// pushed above the shell in both layouts — the reference's split.
enum SettingsSection {
  /// Theme, colours, loading animation, cards, spacing, language, fonts.
  appearance(SettingsArea.ui, Icons.palette_outlined, page: _appearance),

  /// The navigation bar and the launch page.
  navigation(SettingsArea.ui, Icons.navigation_outlined, page: _navigation),

  /// Platforms, their visibility and order, accounts and tags.
  platforms(SettingsArea.sources, Icons.category_outlined, page: _platforms),

  /// Follow and cover refresh, history.
  refresh(SettingsArea.sources, Icons.refresh_outlined, page: _refresh),

  /// IPTV sources (its own management page).
  iptv(SettingsArea.sources, Icons.dns_outlined, route: RoutePath.iptv),

  /// Video playback.
  video(SettingsArea.playback, Icons.play_circle_outline, page: _video),

  /// Danmaku display and blocking.
  danmaku(SettingsArea.playback, Icons.subtitles_outlined, page: _danmaku),

  /// The mpv player and decoding.
  player(SettingsArea.playback, Icons.memory_outlined, page: _player),

  /// Recording settings (directory, segments).
  recording(SettingsArea.playback, Icons.fiber_manual_record, page: _recording),

  /// Updates, start-up, window, exit timer.
  general(SettingsArea.general, Icons.tune_outlined, page: _general),

  /// Proxies.
  network(SettingsArea.general, Icons.lan_outlined, page: _network),

  /// Local interaction.
  localInteraction(SettingsArea.general, Icons.face_outlined, page: _localInteraction),

  /// Cache and data.
  cache(SettingsArea.data, Icons.storage_outlined, page: _cache),

  /// Backup and restore (its own page).
  backup(SettingsArea.data, Icons.cloud_outlined, route: RoutePath.settingsBackup),

  /// The local configuration, read only.
  configPreview(SettingsArea.data, Icons.description_outlined, page: _configPreview),

  /// The log.
  log(SettingsArea.data, Icons.receipt_long_outlined, page: _logs);

  new(this.area, this.icon, {this.page, this.route});

  /// The overview group this page is in.
  final SettingsArea area;

  /// The overview row's icon.
  final IconData icon;

  /// The inline page builder; null for a [route] section.
  final Widget Function()? page;

  /// Another route of the app that is this page, pushed above the shell in
  /// both layouts — the reference's split.
  final String? route;

  /// Builds the inline page; null for a [route] section.
  Widget? buildPage() => page?.call();

  /// The section named [name] (route arguments), or null.
  static SettingsSection? maybeFromId(String? name) => name == null ? null : values.asNameMap()[name];
}

Widget _appearance() => const AppearancePage();
Widget _navigation() => const NavigationSettingsPage();
Widget _platforms() => const PlatformsSettingsPage();
Widget _refresh() => const RefreshSettingsPage();
Widget _video() => const VideoSettingsPage();
Widget _danmaku() => const DanmakuSettingsPage();
Widget _player() => const MpvSettingsPage();
Widget _recording() => const RecordSettingsPage();
Widget _general() => const GeneralSettingsPage();
Widget _network() => const NetworkProxySettingsPage();
Widget _localInteraction() => const LocalInteractionSettingsPage();
Widget _cache() => const CacheDataPage();
Widget _configPreview() => const LocalConfigPreviewPage();
Widget _logs() => const LogsSettingsPage();

/// The section's title.
String settingsSectionTitle(Translations t, SettingsSection section) => switch (section) {
  SettingsSection.appearance => t.settings.appearance,
  SettingsSection.navigation => t.settings.navigationSettings,
  SettingsSection.platforms => t.settings.platformsTitle,
  SettingsSection.refresh => t.settings.refreshSettings,
  SettingsSection.iptv => t.iptv.title,
  SettingsSection.video => t.settings.video,
  SettingsSection.danmaku => t.settings.danmakuTitle,
  SettingsSection.player => t.settings.playerTitle,
  SettingsSection.recording => t.settings.recordingTitle,
  SettingsSection.general => t.settings.general,
  SettingsSection.network => t.settings.proxySettings,
  SettingsSection.localInteraction => t.settings.localInteraction,
  SettingsSection.cache => t.settings.cacheAndData,
  SettingsSection.backup => t.backup.title,
  SettingsSection.configPreview => t.settings.localConfig,
  SettingsSection.log => t.logs.title,
};

/// The section's explanation, shown under the title in the overview.
String settingsSectionDescription(Translations t, SettingsSection section) => switch (section) {
  SettingsSection.appearance => t.settings.appearanceSubtitle,
  SettingsSection.navigation => t.settings.navigationDesc,
  SettingsSection.platforms => t.settings.platformsDesc,
  SettingsSection.refresh => t.settings.refreshDesc,
  SettingsSection.iptv => t.settings.iptvDesc,
  SettingsSection.video => t.settings.videoDesc,
  SettingsSection.danmaku => t.settings.danmakuDesc,
  SettingsSection.player => t.settings.playerDesc,
  SettingsSection.recording => t.settings.recordingDesc,
  SettingsSection.general => t.settings.generalDesc,
  SettingsSection.network => t.settings.proxyDesc,
  SettingsSection.localInteraction => t.settings.localInteractionDesc,
  SettingsSection.cache => t.settings.cacheDesc,
  SettingsSection.backup => t.settings.backupDesc,
  SettingsSection.configPreview => t.settings.configPreviewDesc,
  SettingsSection.log => t.settings.logDesc,
};

/// One row of the settings catalogue: where it lives and how search finds
/// it. The pages draw their own rows; the catalogue is the search index and
/// the reveal target — tapping a result opens its page (the reference's
/// `opens` entries), which is where the row lives.
@immutable
final class SettingsEntry {
  /// Creates an entry.
  const new({
    required this.id,
    required this.section,
    required this.group,
    required this.title,
    this.description,
    this.keywords = const [],
  });

  /// Unique id.
  final String id;

  /// The page it is on.
  final SettingsSection section;

  /// The group title on that page.
  final String Function(Translations t) group;

  /// The row title.
  final String Function(Translations t) title;

  /// The row explanation, when it has one.
  final String Function(Translations t)? description;

  /// More words that find it (both languages, as written).
  final List<String> keywords;

  /// The translated title.
  String titleText(Translations t) => title(t);

  /// The translated explanation, or null.
  String? descriptionText(Translations t) => description == null ? null : description!(t);

  /// "页面 › 分组" of a search result.
  String crumb(Translations t) => '${settingsSectionTitle(t, section)} › ${group(t)}';

  /// Whether [query] (one lower-case word) finds this entry.
  bool matches(Translations t, String query) {
    final words = [titleText(t), ?descriptionText(t), group(t), settingsSectionTitle(t, section), ...keywords];
    return words.any((word) => word.toLowerCase().contains(query));
  }
}

/// The lower-case words of [query].
List<String> searchWords(String query) =>
    query.toLowerCase().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

/// The entries found by [query] in [entries], in catalogue order; every word
/// of the query must match (so "弹幕 字号" finds the danmaku size row).
List<SettingsEntry> searchSettings(Translations t, Iterable<SettingsEntry> entries, String query) {
  final words = searchWords(query);
  if (words.isEmpty) return const [];
  return [
    for (final entry in entries)
      if (words.every((word) => entry.matches(t, word))) entry,
  ];
}
