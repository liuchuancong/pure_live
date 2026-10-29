import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart' show SystemProxyEndpoint, SystemProxyStatus;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind;
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart';
import 'package:pure_live/features/backup/backup.dart';
import 'package:pure_live/features/settings/browse/audience_metric_provider.dart' show audienceMetricProvider;
import 'package:pure_live/features/settings/browse/live_alert_settings.dart' show liveAlertSettingsProvider;
import 'package:pure_live/features/settings/browse/platform_preferences_provider.dart'
    show douyuForceRenewProvider, preferH264Provider, youtubeAllChatProvider;
import 'package:pure_live/features/settings/browse/sites_display_provider.dart';
import 'package:pure_live/features/settings/browse/twitch_languages_provider.dart' show twitchLanguagesProvider;
import 'package:pure_live/features/settings/dialogs/asmr_sleep_dialog.dart' show showAsmrSleepMinutesDialog;
import 'package:pure_live/features/settings/dialogs/config_preview_dialog.dart' show showConfigPreview;
import 'package:pure_live/features/settings/dialogs/live_alert_tags_dialog.dart' show showLiveAlertTagsDialog;
import 'package:pure_live/features/settings/dialogs/prefer_platform_dialog.dart' show showPreferPlatformDialog;
import 'package:pure_live/features/settings/dialogs/theme_color_dialog.dart'
    show showThemeColorDialog, themeSeedToneLabel;
import 'package:pure_live/features/settings/dialogs/twitch_languages_dialog.dart'
    show showTwitchLanguagesDialog, twitchLanguagesSummary;
import 'package:pure_live/features/settings/general/auto_shutdown_section.dart' show AutoShutdownSection;
import 'package:pure_live/features/settings/general/refresh_rate_section.dart' show RefreshRateSection;
import 'package:pure_live/features/settings/general/settings_order_list.dart' show SettingsOrderList;
import 'package:pure_live/features/settings/general/tv_preferences.dart'
    show tvFocusZoomProvider, tvMenuExpandedProvider;
import 'package:pure_live/features/settings/general/window_size_row.dart' show WindowSizeRow;
import 'package:pure_live/features/settings/pages/font_manager_page.dart'
    show FontManagerPage, fontFamilyLabel, showFontManagerPage;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show WallpaperDownloadsPane;
import 'package:pure_live/features/settings/panes/audience_settings_pane.dart'
    show AudienceSettingsPane, audienceModeLabel;
import 'package:pure_live/features/settings/panes/background_panes.dart'
    show
        BackgroundColorsPane,
        BackgroundDevicePane,
        BackgroundLibraryPane,
        BackgroundOverviewPane,
        BackgroundRandomPane;
import 'package:pure_live/features/settings/panes/danmaku_panes.dart' show DanmakuDisplayPane, DanmakuPane;
import 'package:pure_live/features/settings/panes/github_mirror_pane.dart' show GithubMirrorSection;
import 'package:pure_live/features/settings/panes/player_kernel_pane.dart'
    show PlayerKernelAdvancedPane, PlayerKernelPane;
import 'package:pure_live/features/settings/panes/room_card_pane.dart' show showRoomCardPreview;
import 'package:pure_live/features/settings/playback/floating_window_settings.dart' show floatingWindowSettingsProvider;
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart';
import 'package:pure_live/features/settings/playback/portrait_fullscreen_settings.dart';
import 'package:pure_live/features/settings/playback/portrait_settings_providers.dart'
    show
        PortraitFullscreenPolicy,
        PortraitLayoutMode,
        PortraitSettings,
        PortraitSettingsController,
        portraitSettingsProvider;
import 'package:pure_live/features/settings/room/room_card_settings.dart' show RoomCardCoverAspect;
import 'package:pure_live/features/settings/room/room_switcher_settings.dart' show portraitSwipeSwitchProvider;
import 'package:pure_live/features/settings/surface/settings_navigation.dart'
    show openSettingsCategory, openSettingsChild, openSettingsSection, settingsStacksRoutes;
import 'package:pure_live/features/settings/surface/settings_search.dart' show SettingsSearchHit, settingsSearchHits;
import 'package:pure_live/features/settings/surface/settings_sections.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart'
    show SettingsChoiceRow, SettingsConfigRow, SettingsHint, SettingsSegmentedRow;
import 'package:pure_live/features/version/version.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/layouts.dart';
import 'package:pure_live/modules/hongguo/hongguo.dart';
import 'package:pure_live/modules/iptv/iptv.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/page/room_orientation.dart' show roomOrientationChoicesProvider;
import 'package:pure_live/modules/live/shield/shield.dart';
import 'package:pure_live/modules/live/toolbox/toolbox.dart';
import 'package:pure_live/modules/music/music.dart';
import 'package:pure_live/modules/vod/vod.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The widest a settings column grows on a wide window: rows keep a readable
/// measure instead of stretching edge to edge.
const double kSettingsContentMaxWidth = 960;

/// The settings surface. One category at a time, then the sections that
/// category carries: the category page is a list of pages (icon, name, one
/// line, chevron), never every setting in one column.
///
/// A desktop window puts the categories in the shell's own sidebar and this
/// page in the centre. A shell without that sidebar — a phone, or a desktop
/// window shrunk under the bottom bar — shows the categories here and pushes
/// each one's page as its own route, then the section's page above that.
final class SettingsPage extends ConsumerWidget {
  /// The settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(platformRuntimeProvider).environment.runtime;
    final stacked = settingsStacksRoutes(
      context,
      formFactor: runtime.formFactor,
      desktopProfile: ref.watch(deviceProfileProvider).isDesktop,
    );
    if (stacked) return const _SettingsMenuList();
    final section = ref.watch(settingsSectionProvider);
    final open = ref.watch(settingsSectionOpenProvider);
    return _SettingsBodyWithSearch(
      body: open ? SettingsSectionPane(key: ValueKey(section), section: section) : const _CategoryPage(),
    );
  }
}

/// The centre page's category selection: the module's groups by key.
final class _CategoryPage extends ConsumerWidget {
  const _CategoryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = navigationOf(ref.watch(selectedModuleProvider)).settingsGroups;
    final key = ref.watch(settingsCategoryProvider);
    final group = groups.where((group) => group.labelKey == key).firstOrNull ?? groups.first;
    return SettingsCategoryPane(
      key: ValueKey(group.labelKey),
      group: group,
      onOpen: (section) => openSettingsSection(ref, section),
    );
  }
}

/// The desktop pane with the search field over it: the sidebar itself is
/// the shell's, so the search that filters the sections lives at the top of
/// the pane — a query lists the matching sections, and picking one opens
/// its page below its category.
final class _SettingsBodyWithSearch extends ConsumerStatefulWidget {
  const _SettingsBodyWithSearch({required this.body});

  /// The surface under the search field: the category page or a section's.
  final Widget body;

  @override
  ConsumerState<_SettingsBodyWithSearch> createState() => _SettingsBodyWithSearchState();
}

final class _SettingsBodyWithSearchState extends ConsumerState<_SettingsBodyWithSearch> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // A remote's arrows belong to the focus, not a caret: the settings
    // search would trap them, and the menu is the TV's way around.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    // The font manager carries the catalogue's own search; a second field
    // above it would search settings rows while the viewer reads fonts.
    final section = ref.watch(settingsSectionProvider);
    final paneOwnsSearch =
        ref.watch(settingsSectionOpenProvider) &&
        (section == SettingsSection.fontApp || section == SettingsSection.fontDanmaku);
    final query = _query.text.trim().toLowerCase();
    // The module's own sections, in the shared areas' order — the search
    // never offers a page this module does not carry.
    final groups = navigationOf(ref.watch(selectedModuleProvider)).settingsGroups;
    final results = query.isEmpty ? const <SettingsSection>[] : _matchingSections(t, query, groups);
    final hits = query.isEmpty
        ? const <SettingsSearchHit>[]
        : settingsSearchHits(t, query, settingsSearchSections(groups));
    final inset = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsSpace.s16 : DsSpace.s24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!tv && !paneOwnsSearch)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, inset, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: DsSearchField(
                  controller: _query,
                  placeholder: t.settings.searchSettings,
                  semanticLabel: t.settings.searchSettings,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
        Expanded(
          child: query.isEmpty
              ? widget.body
              : _SectionSearchResults(
                  sections: results,
                  hits: hits,
                  onOpen: (section) {
                    _query.clear();
                    openSettingsSection(ref, section);
                    setState(() {});
                  },
                ),
        ),
      ],
    );
  }
}

/// A settings column centred at [kSettingsContentMaxWidth]: a wide window
/// gets margins, not rows that run the whole screen.
final class _SettingsColumn extends StatelessWidget {
  /// The column's [children], top to bottom.
  const _SettingsColumn({required this.children, this.spacing = 0});

  /// The rows and sections the page carries.
  final List<Widget> children;

  /// Space between [children].
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kSettingsContentMaxWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing, children: children),
      ),
    );
  }
}

/// One category's page: the sections it carries, each row naming the page
/// and what it manages, with the chevron into that page.
final class SettingsCategoryPane extends StatelessWidget {
  /// The page for [group].
  const SettingsCategoryPane({required this.group, required this.onOpen, super.key});

  /// The group whose sections are listed here.
  final SettingsGroup group;

  /// Opens one of the group's sections.
  final ValueChanged<SettingsSection> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsSpace.s16 : DsSpace.s24;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s20, inset, DsSpace.s24),
      child: _SettingsColumn(
        children: [
          DsListSection(
            children: [
              for (final section in group.sections)
                DsListRow(
                  leading: DsIcon(section.icon),
                  title: Text(section.label(t)),
                  description: Text(section.description(t)),
                  showChevron: true,
                  onPressed: () => onOpen(section),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The sections whose label or line matches [query] (lower case, trimmed),
/// in the module's menu order.
List<SettingsSection> _matchingSections(Translations t, String query, List<SettingsGroup> groups) {
  // Several words narrow a search (the reference's AND): each one must
  // appear somewhere in the group, the page's name or its line.
  final words = query.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  bool hasAll(String text) {
    final lower = text.toLowerCase();
    return words.every(lower.contains);
  }

  final found = <SettingsSection>[];
  for (final group in groups) {
    // The group's own name is a way in too: "通用" should find the browsing
    // and network pages it heads, not only a page that repeats the word.
    final byGroup = hasAll(settingsGroupLabel(t, group.labelKey));
    for (final section in group.sections) {
      if (byGroup || hasAll(section.label(t)) || hasAll(section.description(t))) {
        found.add(section);
      }
    }
  }
  // The pages nested under a category are not menu rows, but the search
  // still finds them by their own words.
  for (final section in settingsSearchSections(groups)) {
    if (!section.isNested) continue;
    if ((hasAll(section.label(t)) || hasAll(section.description(t))) && !found.contains(section)) {
      found.add(section);
    }
  }
  return found;
}

/// The search's answer on a desktop pane: matching sections first, then the
/// rows those sections carry whose own words (or keywords) match. Either row
/// takes the viewer to its section.
final class _SectionSearchResults extends StatelessWidget {
  const _SectionSearchResults({required this.sections, required this.hits, required this.onOpen});

  final List<SettingsSection> sections;
  final List<SettingsSearchHit> hits;
  final ValueChanged<SettingsSection> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (sections.isEmpty && hits.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.settings.searchNoResults)),
      );
    }
    final inset = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsSpace.s16 : DsSpace.s24;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, inset, DsSpace.s24),
      child: _SettingsColumn(
        spacing: DsSpace.s16,
        children: [
          if (sections.isNotEmpty)
            DsListSection(
              header: Text(t.settings.searchSections),
              children: [
                for (final section in sections)
                  DsListRow(
                    leading: DsIcon(section.icon),
                    title: Text(section.label(t)),
                    description: Text(section.description(t)),
                    showChevron: true,
                    onPressed: () => onOpen(section),
                  ),
              ],
            ),
          if (hits.isNotEmpty)
            DsListSection(
              header: Text(t.settings.searchRows),
              children: [
                for (final hit in hits)
                  DsListRow(
                    leading: DsIcon(hit.section.icon),
                    title: Text(hit.title),
                    description: Text(hit.section.label(t)),
                    showChevron: true,
                    onPressed: () => onOpen(hit.section),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The phone's settings page: the first-level categories as one list, each
/// pushing its own page — the desktop sidebar's categories, reshaped for a
/// thumb. A search skips the category step and opens the matching section
/// directly, which is what a typed query is after.
final class _SettingsMenuList extends ConsumerStatefulWidget {
  const _SettingsMenuList();

  @override
  ConsumerState<_SettingsMenuList> createState() => _SettingsMenuListState();
}

final class _SettingsMenuListState extends ConsumerState<_SettingsMenuList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The areas are the shared grouping; the module's registry decides
    // which of their sections this module carries.
    final groups = navigationOf(ref.watch(selectedModuleProvider)).settingsGroups;
    final query = _query.trim().toLowerCase();
    bool matches(SettingsSection section) =>
        section.label(t).toLowerCase().contains(query) || section.description(t).toLowerCase().contains(query);
    final hits = query.isEmpty
        ? const <SettingsSearchHit>[]
        : settingsSearchHits(t, query, settingsSearchSections(groups));
    final blocks = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: DsSpace.s12),
        child: DsSearchField(
          placeholder: t.settings.searchSettings,
          semanticLabel: t.settings.searchSettings,
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
    ];
    var shown = 0;
    if (query.isEmpty) {
      shown = groups.length;
      blocks.add(
        DsListSection(
          children: [
            for (final group in groups)
              DsListRow(
                leading: DsIcon(settingsGroupIcon(group.labelKey)),
                title: Text(settingsGroupLabel(t, group.labelKey)),
                description: Text(settingsGroupDescription(t, group.labelKey)),
                showChevron: true,
                onPressed: () {
                  openSettingsCategory(ref, group.labelKey);
                  unawaited(context.push(RouteNames.settingsCategoryFor(group.labelKey)));
                },
              ),
          ],
        ),
      );
    } else {
      for (final group in groups) {
        final byGroup = settingsGroupLabel(t, group.labelKey).toLowerCase().contains(query);
        List<String> rowMatches(SettingsSection section) => [
          for (final hit in hits)
            if (hit.section == section) hit.title,
        ];
        // A search reaches the pages nested under each category too; the
        // plain menu keeps them out of the row list.
        final sections = [...group.sections, for (final category in group.sections) ...settingsDescendantsOf(category)];
        final kept = [
          for (final section in sections)
            if (byGroup || matches(section) || rowMatches(section).isNotEmpty) section,
        ];
        if (kept.isEmpty) continue;
        shown += kept.length;
        blocks.add(
          DsListSection(
            header: Text(settingsGroupLabel(t, group.labelKey)),
            children: [
              for (final section in kept)
                DsListRow(
                  leading: DsIcon(section.icon),
                  title: Text(section.label(t)),
                  description: Text(
                    !byGroup && !matches(section) && rowMatches(section).isNotEmpty
                        ? t.settings.searchRowMatches(items: rowMatches(section).join(' · '))
                        : section.description(t),
                  ),
                  showChevron: true,
                  onPressed: () {
                    // The route pushes the page the provider names; keeping
                    // it in step also carries the visit over to a desktop
                    // window the app may be resized into.
                    openSettingsSection(ref, section);
                    unawaited(context.push(SettingsSectionRoute(section: section.name).location));
                  },
                ),
            ],
          ),
        );
      }
    }
    if (shown == 0) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
          child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.settings.searchNoResults)),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s24),
      child: _SettingsColumn(spacing: DsSpace.s16, children: blocks),
    );
  }
}

/// One section's content pane: the section's own controls. Desktop shows it
/// as the page below its category; the mobile route shows it alone under the
/// section's name.
final class SettingsSectionPane extends StatelessWidget {
  /// The pane for [section].
  const SettingsSectionPane({required this.section, super.key});

  /// The section rendered here.
  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final body = switch (section) {
      SettingsSection.theme || SettingsSection.personalization || SettingsSection.appearance => const _ThemePane(),
      SettingsSection.typography => const _ThemePane(),
      SettingsSection.fontApp => const FontManagerPage(),
      SettingsSection.background => const BackgroundOverviewPane(),
      SettingsSection.backgroundImages => const BackgroundLibraryPane(video: false),
      SettingsSection.backgroundRandom => const BackgroundRandomPane(),
      SettingsSection.backgroundVideos => const BackgroundLibraryPane(video: true),
      SettingsSection.backgroundColors => const BackgroundColorsPane(),
      SettingsSection.backgroundDevice => const BackgroundDevicePane(),
      SettingsSection.backgroundDownloads => const WallpaperDownloadsPane(),
      SettingsSection.nav => const _NavPane(),
      SettingsSection.navHomeMenu => const _NavHomeMenuPane(),
      SettingsSection.navToolOrder => const _NavToolOrderPane(),
      SettingsSection.browsing || SettingsSection.general => const _BrowsingPane(),
      // The card's page is the sample itself: the browsing entry opens it.
      SettingsSection.roomCard => const _BrowsingPane(),
      SettingsSection.sites || SettingsSection.live || SettingsSection.sources => const _SitesPane(),
      SettingsSection.sitesDisplay => const _SitesDisplayPane(),
      SettingsSection.accounts => const AccountPane(),
      SettingsSection.refresh => const _RefreshPane(),
      SettingsSection.followTags => const FollowTagsPane(),
      SettingsSection.danmaku || SettingsSection.miniDanmaku => const DanmakuPane(),
      SettingsSection.fontDanmaku => const FontManagerPage(danmaku: true),
      SettingsSection.danmakuDisplay => const DanmakuDisplayPane(),
      SettingsSection.shield => const ShieldPane(),
      SettingsSection.recording => const _RecordingPane(),
      SettingsSection.quality ||
      SettingsSection.playback ||
      SettingsSection.video ||
      SettingsSection.audio => const _QualityAudioPane(),
      SettingsSection.picture => const _PicturePane(),
      SettingsSection.floatingWindow => const _FloatingWindowPane(),
      SettingsSection.portrait => const _PortraitPane(),
      SettingsSection.audience => const AudienceSettingsPane(),
      SettingsSection.kernel => const PlayerKernelPane(),
      SettingsSection.kernelAdvanced => const PlayerKernelAdvancedPane(),
      SettingsSection.startup || SettingsSection.system => const _StartupPane(),
      SettingsSection.window => const _WindowPane(),
      SettingsSection.network => const _NetworkPane(),
      SettingsSection.nodes => const PlatformNodesPane(),
      SettingsSection.dataCache || SettingsSection.data || SettingsSection.cache => const _DataCachePane(),
      SettingsSection.backup => const BackupPane(),
      SettingsSection.webdavSync => const WebDavSyncPane(),
      SettingsSection.logs => const LogsPane(),
      SettingsSection.about => const _AboutPane(),
      SettingsSection.iptv => const IptvSettingsPane(),
      SettingsSection.iptvBrowse => const IptvBrowsePane(),
      SettingsSection.iptvGroups => const IptvGroupsPane(),
      SettingsSection.vod => const VodSettingsPane(),
      SettingsSection.vodPlayback => const VodPlaybackPane(),
      SettingsSection.vodInterface => const VodInterfacePane(),
      SettingsSection.music => const MusicSettingsPane(),
      SettingsSection.hongguo => const HongguoSettingsPane(),
      SettingsSection.musicList => const MusicListPane(),
      SettingsSection.musicSources => const MusicSourcesPane(),
      SettingsSection.musicDownload => const MusicDownloadPane(),
      SettingsSection.musicLyric => const MusicLyricPane(),
      SettingsSection.musicDesktopLyric => const MusicDesktopLyricPane(),
      SettingsSection.musicHotkeys => const MusicHotkeysPane(),
      SettingsSection.musicSync => const MusicSyncPane(),
      SettingsSection.musicEq => const MusicEqPane(),
    };
    final inset = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsSpace.s16 : DsSpace.s24;
    final padding = EdgeInsets.fromLTRB(inset, DsSpace.s20, inset, DsSpace.s24);
    // Some pages own their height instead of scrolling the whole pane with
    // it: the log console expands into what the settings above leave, a
    // wallpaper page fills the window with as many whole rows as fit, and the
    // font manager pins its filters over a table that scrolls by itself.
    if (section == SettingsSection.logs ||
        section == SettingsSection.backgroundImages ||
        section == SettingsSection.backgroundVideos ||
        section == SettingsSection.backgroundDownloads ||
        section == SettingsSection.fontApp ||
        section == SettingsSection.fontDanmaku) {
      return Padding(padding: padding, child: body);
    }
    return SingleChildScrollView(
      padding: padding,
      child: _SettingsColumn(children: [body]),
    );
  }
}

/// The entry row a parent pane offers for its subpage: the subpage's own
/// name and description, opening in place on desktop and as its own route
/// on a touch shell — the way the background page already lists its five
/// sources.
final class SettingsChildEntry extends ConsumerWidget {
  /// The entry to [child].
  const SettingsChildEntry({required this.child, this.detail, super.key});

  /// The subpage this row opens.
  final SettingsSection child;

  /// The subpage's current value, shown on the row.
  final Widget? detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsListRow(
      leading: DsIcon(child.icon),
      title: Text(child.label(t)),
      description: Text(child.description(t)),
      detail: detail,
      showChevron: true,
      onPressed: () => openSettingsChild(context, ref, child),
    );
  }
}

/// The theme picker at the top of the theme page: the three theme modes as
/// previews. Picking a preview applies it at once, as Windows' theme
/// thumbnails do.
final class _ThemePreviewSection extends StatelessWidget {
  const _ThemePreviewSection({required this.settings, required this.onChanged, this.dynamicSeed});

  final AppThemeSettings settings;

  /// The palette seed in force while dynamic colour is on; the previews show
  /// the colours the app actually uses.
  final Color? dynamicSeed;

  final ValueChanged<DsThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    DsThemeData preview(DsThemeMode mode) {
      final brightness = switch (mode) {
        DsThemeMode.light => Brightness.light,
        DsThemeMode.dark => Brightness.dark,
        DsThemeMode.system => platformDark ? Brightness.dark : Brightness.light,
      };
      return DsThemeData(
        brightness: brightness,
        seed: dynamicSeed == null ? settings.seed ?? DsSeed.blue : DsSeed.color(dynamicSeed!),
        contrast: settings.contrast,
        cornerStyle: settings.cornerStyle,
        selectionStyle: settings.selectionStyle,
        autoClashRule: settings.autoClashRule,
        density: settings.density,
        platform: settings.platform,
        adjustColors: settings.adjustColors,
      );
    }

    final ui = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.settings.personalizationChooseTheme, style: ui.typography.heading.copyWith(color: colors.text)),
        DsListSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(DsSpace.s16),
              child: Wrap(
                spacing: DsSpace.s12,
                runSpacing: DsSpace.s12,
                children: [
                  for (final mode in DsThemeMode.values)
                    SizedBox(
                      width: 150,
                      child: _ThemeModeTile(
                        theme: preview(mode),
                        selected: settings.mode == mode,
                        label: themeModeLabel(t, mode),
                        onPressed: () => onChanged(mode),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One theme mode as a thumbnail: a window in that theme, the mode's name
/// under it, and the accent edge plus a check while it is the theme in force.
final class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.theme, required this.selected, required this.label, required this.onPressed});

  final DsThemeData theme;
  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      onPressed: onPressed,
      selected: selected,
      semanticLabel: label,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        final focused = states.contains(WidgetState.focused);
        final edge = selected
            ? colors.accent
            : focused
            ? colors.focus
            : hovered
            ? colors.textSubtle
            : colors.border;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            AnimatedContainer(
              duration: ui.motion.toneDuration,
              curve: ui.motion.toneCurve,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ui.radii.card),
                border: Border.all(color: edge, width: selected || focused ? 2 : 1),
              ),
              child: Stack(
                children: [
                  _ThemeWindow(theme: theme),
                  if (selected)
                    PositionedDirectional(
                      top: 7,
                      end: 7,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
                        child: DsIcon(DsIcons.check, size: 12, color: colors.onAccent),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: ui.typography.caption.copyWith(color: selected ? colors.text : colors.textMuted),
            ),
          ],
        );
      },
    );
  }
}

/// A small app window drawn from one theme's own tokens: chrome, a rail,
/// text bars and an accent action. It is the theme preview, not a picture.
final class _ThemeWindow extends StatelessWidget {
  const _ThemeWindow({required this.theme});

  final DsThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colors;
    Widget dot() => Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSubtle.withValues(alpha: 0.55)),
    );
    Widget bar(double width, {double height = 5, Color? color}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color ?? colors.border, borderRadius: BorderRadius.circular(3)),
    );
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: colors.field,
              child: Row(spacing: 4, children: [dot(), dot(), dot()]),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    color: colors.field.withValues(alpha: 0.55),
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [bar(22, height: 4), bar(16, height: 4), bar(20, height: 4), bar(14, height: 4)],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          bar(58, height: 6, color: colors.textMuted.withValues(alpha: 0.6)),
                          bar(96, height: 4),
                          bar(72, height: 4),
                          const Spacer(),
                          Container(
                            width: 44,
                            height: 9,
                            decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The browsing page: what the feed grids decide for themselves — the gaps
/// between cards and the density of the follow page — plus the row that
/// opens the room-card preview, where the card itself is tuned. Card width
/// and page size are not here: both follow the window and the site's own
/// feed window now.
final class _BrowsingPane extends ConsumerWidget {
  const _BrowsingPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.groupCards),
          children: [
            // The gaps are desen_ui's spacing tokens, chosen from the same
            // dropdown the rest of the settings surface uses — not a free
            // pixel range the grids then have to guess at.
            SettingsChoiceRow<double>(
              leading: const DsIcon(DsIcons.columns2),
              title: t.settings.crossSpacing,
              description: t.settings.crossSpacingDescription,
              value: settings.crossSpacing,
              options: [
                for (final spacing in kBrowseSpacingChoices)
                  DsSelectOption(value: spacing, label: '${spacing.round()} px'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).crossSpacing = value,
            ),
            SettingsChoiceRow<double>(
              leading: const DsIcon(DsIcons.rows3),
              title: t.settings.mainSpacing,
              description: t.settings.mainSpacingDescription,
              value: settings.mainSpacing,
              options: [
                for (final spacing in kBrowseSpacingChoices)
                  DsSelectOption(value: spacing, label: '${spacing.round()} px'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).mainSpacing = value,
            ),
          ],
        ),
        // How many cards a screen holds: the columns are a choice now, not
        // only a consequence of the window's width; the cover's shape and
        // the title's lines decide how tall a card stands.
        DsListSection(
          header: Text(t.settings.browseLayoutGroup),
          children: [
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.columns3),
              title: t.settings.browseColumns,
              value: settings.gridColumns,
              options: [
                DsSelectOption(value: 0, label: t.settings.browseAuto),
                for (final columns in kBrowseGridColumnChoices) DsSelectOption(value: columns, label: '$columns'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).gridColumns = value,
            ),
            SettingsSegmentedRow<RoomCardCoverAspect>(
              leading: const DsIcon(DsIcons.rectangleHorizontal),
              title: t.settings.browseCoverAspect,
              value: settings.coverAspect,
              options: const [
                (value: RoomCardCoverAspect.wide, label: '16:9'),
                (value: RoomCardCoverAspect.boxed, label: '4:3'),
              ],
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).coverAspect = value,
            ),
          ],
        ),
        DsListSection(
          children: [
            // The row opens the card's own page — the sample at a feed's
            // size — rather than a settings list beside it.
            DsListRow(
              leading: const DsIcon(DsIcons.idCard),
              title: Text(t.settings.roomCardSettingsTitle),
              description: Text(t.settings.roomCardPreviewHint),
              showChevron: true,
              onPressed: () => unawaited(showRoomCardPreview(context)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The window page: the window's own shape — title bar, room windows, size
/// and refresh rate. Closing and exit behaviour is the startup page's task.
final class _WindowPane extends ConsumerWidget {
  const _WindowPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final primary = ref.watch(isPrimaryWindowProvider);
    final desktop = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.windowGroup),
          children: [
            if (desktop)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.appWindow),
                title: t.settings.roomWindow,
                description: t.settings.roomWindowDesc,
                control: DsSwitch(
                  value: ref.watch(roomWindowsProvider),
                  onChanged: (value) => unawaited(ref.read(roomWindowsProvider.notifier).setEnabled(value: value)),
                ),
              ),
            if (primary && desktop) const WindowSizeRow(),
          ],
        ),
        const RefreshRateSection(),
      ],
    );
  }
}

/// The startup page (启动与退出): both ends of the process's life — launch
/// at login and the startup mark, the window's close behaviour, and
/// scheduled shutdown.
final class _StartupPane extends ConsumerWidget {
  const _StartupPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final startup = ref.watch(startupProvider);
    final window = ref.watch(shellWindowSettingsProvider);
    final primary = ref.watch(isPrimaryWindowProvider);
    final desktop = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
    final kind = ref.watch(platformRuntimeProvider).environment.runtime.kind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navStartup),
          children: [
            if (primary && startup.supported)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.rocket),
                title: t.settings.startup,
                description: startup.error.isEmpty
                    ? t.settings.startupDesc
                    : '${t.settings.startupFailed}: ${startup.error}',
                control: startup.loading
                    ? const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: SizedBox.square(dimension: 18, child: DsSpinner()),
                      )
                    : DsSwitch(
                        value: startup.enabled,
                        onChanged: (value) => unawaited(ref.read(startupProvider.notifier).setEnabled(value: value)),
                      ),
              ),
            if (primary)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.playCircle),
                title: t.settings.splashAnimation,
                description: t.settings.splashAnimationDesc,
                control: DsSwitch(
                  value: ref.watch(splashSettingsProvider),
                  onChanged: (value) => ref.read(splashSettingsProvider.notifier).enabled = value,
                ),
              ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.closeExitGroup),
          children: [
            if (primary)
              SettingsChoiceRow<CloseAction>(
                leading: const DsIcon(DsIcons.x),
                title: t.settings.closeAction,
                description: t.settings.closeActionDesc,
                value: window.closeAction,
                options: [
                  DsSelectOption(value: CloseAction.quit, label: t.settings.closeQuit),
                  DsSelectOption(value: CloseAction.minimise, label: t.settings.closeMinimise),
                  DsSelectOption(value: CloseAction.hideToTray, label: t.settings.closeHideToTray),
                ],
                onChanged: (value) => unawaited(ref.read(shellWindowSettingsProvider.notifier).setCloseAction(value)),
              ),
            if (primary && desktop && kind != PlatformKind.macos)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.messageCircleWarning),
                title: t.settings.noExitConfirm,
                description: t.settings.noExitConfirmDescription,
                control: DsSwitch(
                  value: window.dontAskExit,
                  onChanged: (value) =>
                      unawaited(ref.read(shellWindowSettingsProvider.notifier).setDontAskExit(value: value)),
                ),
              ),
          ],
        ),
        if (primary) const AutoShutdownSection(),
      ],
    );
  }
}

/// The refresh pane (the reference's Refresh): the follows page's periodic
/// and one-shot foreground refresh, its interval and queue bound, plus the
/// periodic cover cache refresh. The follows page owns its timers; the cover
/// timer is process-wide and re-arms from the app root.
final class _RefreshPane extends ConsumerWidget {
  const _RefreshPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final autoRefresh = ref.watch(followsAutoRefreshProvider);
    final maxConcurrent = ref.watch(maxConcurrentRefreshProvider);
    final thumbnails = ref.watch(thumbnailRefreshProvider);
    final liveAlerts = ref.watch(liveAlertSettingsProvider);
    final tags = ref.watch(followTagsProvider);
    // A stored interval the choices do not list still shows as chosen.
    final intervals = {...kRefreshIntervalChoices, autoRefresh.minutes}.toList()..sort();
    final thumbnailIntervals = {...kThumbnailRefreshIntervalChoices, thumbnails.minutes}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.refreshGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.heart),
              title: t.settings.followsAutoRefresh,
              description: t.settings.followsAutoRefreshDesc,
              control: DsSwitch(
                value: autoRefresh.enabled,
                onChanged: (value) => unawaited(ref.read(followsAutoRefreshProvider.notifier).setEnabled(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: t.settings.refreshOnResume,
              description: t.settings.refreshOnResumeDesc,
              control: DsSwitch(
                value: autoRefresh.onResume,
                onChanged: (value) =>
                    unawaited(ref.read(followsAutoRefreshProvider.notifier).setOnResume(value: value)),
              ),
            ),
            if (autoRefresh.enabled) ...[
              SettingsChoiceRow<int>(
                leading: const DsIcon(DsIcons.timer),
                title: t.settings.refreshInterval,
                value: autoRefresh.minutes,
                options: [
                  for (final minutes in intervals) DsSelectOption(value: minutes, label: _intervalLabel(minutes)),
                ],
                onChanged: (value) => unawaited(ref.read(followsAutoRefreshProvider.notifier).setMinutes(value)),
              ),
            ],
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.bell),
              title: t.settings.liveAlert,
              description: t.settings.liveAlertDesc,
              control: DsSwitch(
                value: liveAlerts.enabled,
                onChanged: (value) {
                  if (value) unawaited(requestUserNotificationPermission());
                  unawaited(ref.read(liveAlertSettingsProvider.notifier).setEnabled(value: value));
                },
              ),
            ),
            if (liveAlerts.enabled)
              DsListRow(
                leading: const DsIcon(DsIcons.tag),
                title: Text(t.settings.liveAlertTags),
                description: Text(tags.isEmpty ? t.settings.liveAlertTagsNone : t.settings.liveAlertTagsDesc),
                detail: Text(
                  liveAlerts.tagIds.isEmpty
                      ? t.settings.liveAlertTagsAll
                      : t.settings.liveAlertTagCount(selected: liveAlerts.tagIds.length),
                ),
                showChevron: tags.isNotEmpty,
                onPressed: tags.isEmpty ? null : () => unawaited(showLiveAlertTagsDialog(context)),
              ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.waypoints),
              title: t.settings.maxConcurrentRefresh,
              description: t.settings.maxConcurrentRefreshDesc,
              value: maxConcurrent,
              options: [
                for (var value = kMaxConcurrentRefreshMin; value <= kMaxConcurrentRefreshMax; value++)
                  DsSelectOption(
                    value: value,
                    label: value == kMaxConcurrentRefreshDefault ? '$value · ${t.settings.recommended}' : '$value',
                  ),
              ],
              onChanged: (value) => unawaited(ref.read(maxConcurrentRefreshProvider.notifier).set(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.image),
              title: t.settings.refreshThumbnails,
              description: t.settings.refreshThumbnailsDesc,
              control: DsSwitch(
                value: thumbnails.enabled,
                onChanged: (value) => unawaited(ref.read(thumbnailRefreshProvider.notifier).setEnabled(value: value)),
              ),
            ),
            if (thumbnails.enabled)
              SettingsChoiceRow<int>(
                leading: const DsIcon(DsIcons.timer),
                title: t.settings.thumbnailRefreshInterval,
                value: thumbnails.minutes,
                options: [
                  for (final minutes in thumbnailIntervals)
                    DsSelectOption(value: minutes, label: _intervalLabel(minutes)),
                ],
                onChanged: (value) => unawaited(ref.read(thumbnailRefreshProvider.notifier).setMinutes(value)),
              ),
          ],
        ),
        const DsListSection(children: [SettingsChildEntry(child: SettingsSection.followTags)]),
      ],
    );
  }
}

/// The navigation page: the two orders the shell reads — which home entries
/// the sidebar, drawer and bottom bar show, in what order, and the same for
/// the tools block under the sidebar's divider.
///
/// Each is its own route: the lists are long enough, and the ordering edit
/// is a mode of its own, so neither belongs flattened onto one page.
final class _NavPane extends StatelessWidget {
  const _NavPane();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          children: [
            SettingsChildEntry(child: SettingsSection.navHomeMenu),
            SettingsChildEntry(child: SettingsSection.navToolOrder),
          ],
        ),
      ],
    );
  }
}

/// The home menu page: the four live destinations in their saved order,
/// each row carrying its own show/hide switch.
///
/// No row ever moves for a switch — all four stay listed in place, on or
/// off, and the switch writes only the hidden set. The order key is
/// written only by the draft's save, so until the viewer reorders the menu
/// the rows keep the default order; at least one entry stays shown.
final class _NavHomeMenuPane extends ConsumerWidget {
  const _NavHomeMenuPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final homeOrder = ref.watch(navMenuOrderProvider);
    final visible = ref.watch(navMenuProvider).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        SettingsOrderList<NavigationItem>(
          header: t.settings.navHomeMenuTitle,
          items: homeOrder,
          identityOf: (item) => item.name,
          labelOf: (item) => item.label(t),
          leadingOf: (item) => DsIcon(item.icon),
          trailingOf: (item) => DsSwitch(
            value: visible.contains(item),
            onChanged: (value) async {
              final changed = await ref.read(navMenuProvider.notifier).setVisible(item, value: value);
              if (!changed && context.mounted) {
                showDsToast(context: context, title: t.settings.navMenuKeepOne);
              }
            },
          ),
          onSave: (draft) => unawaited(ref.read(navMenuProvider.notifier).setOrder(draft)),
        ),
      ],
    );
  }
}

/// The tools page: the sidebar's block under its divider, in the viewer's
/// order. Every tool stays shown — the order is the only choice here.
final class _NavToolOrderPane extends ConsumerWidget {
  const _NavToolOrderPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return SettingsOrderList<NavigationItem>(
      header: t.settings.toolsOrder,
      items: ref.watch(toolOrderProvider),
      identityOf: (item) => item.name,
      labelOf: (item) => item.label(t),
      leadingOf: (item) => DsIcon(item.icon),
      onSave: (draft) => unawaited(ref.read(toolOrderProvider.notifier).setOrder(draft)),
    );
  }
}

/// Applies the z-order choice to a compact Windows window when one is up,
/// then stores it for the next entry.
Future<void> _setWindowsPipAlwaysOnTop(WidgetRef ref, bool value) async {
  final window = ref.read(windowsPipWindowProvider);
  if (window != null) {
    try {
      await window.setAlwaysOnTop(value: value);
    } on Object {
      // The next PiP entry reads the stored choice again.
    }
  }
  await ref.read(playbackSettingsProvider.notifier).setWindowsPipAlwaysOnTop(value: value);
}

/// Pushes the current PiP size policy into the driver; the next compact
/// window uses it without a restart.
void _syncWindowsPipConfig(WidgetRef ref) {
  ref.read(pipDriverProvider).config = windowsPipConfigFor(ref.read(playbackSettingsProvider));
}

/// Clears both remembered compact-window placements after a confirmation;
/// the next PiP entry opens at the app window's own corner again.
Future<void> _resetWindowsPipGeometry(BuildContext context) async {
  final t = context.t;
  final confirmed = await showDsConfirm(
    context: context,
    title: t.settings.windowsPipResetPosition,
    description: t.settings.windowsPipResetPositionConfirm,
    confirmLabel: t.settings.windowsPipResetAction,
    cancelLabel: t.common.cancel,
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await clearPipSavedBounds();
  if (!context.mounted) {
    return;
  }
  showDsToast(context: context, title: t.settings.windowsPipResetPositionSuccess);
}

/// A resolution tier's localized name; an unknown tier shows as stored.
String preferredQualityLabel(Translations t, String quality) => switch (quality) {
  '原画' => t.settings.qualityOriginal,
  '蓝光8M' => t.settings.qualityBluRay8M,
  '蓝光4M' => t.settings.qualityBluRay4M,
  '蓝光' => t.settings.qualityBluRay,
  '超清' => t.settings.qualityUltra,
  '高清' => t.settings.qualityHigh,
  '标清' => t.settings.qualityStandard,
  '流畅' => t.settings.qualitySmooth,
  _ => quality,
};

/// A refresh interval's label: minutes under an hour, whole hours above,
/// half hours as the decimal the reference shows ("1.5 h").
String _intervalLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes % 60 == 0) return '${minutes ~/ 60} h';
  if (minutes % 30 == 0) return '${minutes / 60} h';
  return '$minutes min';
}

/// The theme page: the three theme modes as previews at the top, then the
/// palette and the design system's own choices — contrast, selection style
/// and the clash rule are as much a setting as light/dark — plus the type
/// that carries them and the app language. One labelled row per choice, the
/// control inline on a wide pane and under the label on a narrow one.
final class _ThemePane extends ConsumerWidget {
  const _ThemePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final scope = AppThemeScope.of(context);
    final localeScope = AppLocaleScope.of(context);
    final settings = scope.settings;
    String? seedName;
    for (final (name, seed) in kNamedSeeds) {
      if (seed == settings.seed) seedName = name;
    }
    final customSeed = scope.seedColor;
    final dynamicSeed = scope.dynamicSeedColor;
    final textScale = ref.watch(textScaleFactorProvider);
    final dynamicSupported = ref.watch(dynamicColorSeedProvider).value != null;
    final dynamicEnabled = ref.watch(dynamicColorProvider);
    final seedDetail = seedName != null
        ? themeSeedToneLabel(t, seedName)
        : customSeed != null
        ? ThemePersistence.encodeSeedColor(customSeed)
        : t.settings.themeSeedSystem;
    void update(AppThemeSettings next) => scope.onChanged(next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        _ThemePreviewSection(
          settings: settings,
          dynamicSeed: dynamicSeed,
          onChanged: (mode) {
            if (mode != settings.mode) update(settings.rebuild((b) => b..mode = mode));
          },
        ),
        DsListSection(
          header: Text(t.settings.groupTheme),
          children: [
            DsListRow(
              leading: dynamicSeed != null
                  ? _SeedSwatch.color(dynamicSeed)
                  : seedName != null
                  ? _SeedSwatch(seed: settings.seed)
                  : customSeed != null
                  ? _SeedSwatch.color(customSeed)
                  : const DsIcon(DsIcons.palette),
              title: Text(t.settings.themeSeed),
              // While dynamic colour is on the wallpaper decides; the picker
              // would write a seed the theme never uses.
              description: Text(
                dynamicSeed != null ? t.settings.themeSeedDynamicDescription : t.settings.themeSeedDescription,
              ),
              detail: Text(dynamicSeed != null ? t.settings.themeSeedDynamic : seedDetail),
              showChevron: dynamicSeed == null,
              onPressed: dynamicSeed == null
                  ? () => unawaited(
                      showThemeColorDialog(
                        context,
                        settings: settings,
                        seedColor: customSeed,
                        onChanged: scope.onChanged,
                      ),
                    )
                  : null,
            ),
            if (dynamicSupported)
              DsListRow(
                leading: const DsIcon(DsIcons.wandSparkles),
                title: Text(t.settings.dynamicColor),
                description: Text(t.settings.dynamicColorDescription),
                trailing: DsSwitch(
                  value: dynamicEnabled,
                  onChanged: (value) => ref.read(dynamicColorProvider.notifier).enabled = value,
                ),
              ),
            // A01.5: the phone shell's bottom bar is the only place this
            // paints, so the desktop profile hides the switch outright
            // rather than offer a choice that changes nothing there.
            if (ref.watch(deviceProfileProvider) == DeviceProfile.mobile)
              DsListRow(
                leading: const DsIcon(DsIcons.layers),
                title: Text(t.settings.liquidGlass),
                description: Text(t.settings.liquidGlassDescription),
                trailing: DsSwitch(
                  value: ref.watch(liquidGlassProvider),
                  onChanged: (value) => unawaited(ref.read(liquidGlassProvider.notifier).set(value: value)),
                ),
              ),
            SettingsChoiceRow<DsContrast>(
              leading: const DsIcon(DsIcons.contrast),
              title: t.settings.contrast,
              description: t.settings.contrastDescription,
              value: settings.contrast,
              options: [
                DsSelectOption(value: DsContrast.soft, label: t.settings.contrastSoft),
                DsSelectOption(value: DsContrast.standard, label: t.settings.contrastStandard),
              ],
              onChanged: (value) => update(settings.rebuild((b) => b..contrast = value)),
            ),
            SettingsChoiceRow<DsSelectionStyle>(
              leading: const DsIcon(DsIcons.ellipseSelection),
              title: t.settings.selectionStyle,
              description: t.settings.selectionDescription,
              value: settings.selectionStyle,
              options: [
                DsSelectOption(value: DsSelectionStyle.soft, label: t.settings.selectionSoft),
                DsSelectOption(value: DsSelectionStyle.strong, label: t.settings.selectionStrong),
              ],
              onChanged: (value) => update(settings.rebuild((b) => b..selectionStyle = value)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.wandSparkles),
              title: Text(t.settings.autoClash),
              description: Text(t.settings.autoClashDesc),
              trailing: DsSwitch(
                value: settings.autoClashRule,
                onChanged: (value) => update(settings.rebuild((b) => b..autoClashRule = value)),
              ),
            ),
            SettingsChoiceRow<DsCornerStyle>(
              leading: const DsIcon(DsIcons.cornerDownRight),
              title: t.settings.corners,
              value: settings.cornerStyle,
              options: [
                DsSelectOption(value: DsCornerStyle.sharp, label: t.settings.cornersSharp),
                DsSelectOption(value: DsCornerStyle.standard, label: t.settings.cornersStandard),
                DsSelectOption(value: DsCornerStyle.soft, label: t.settings.cornersSoft),
                DsSelectOption(value: DsCornerStyle.pill, label: t.settings.cornersPill),
              ],
              onChanged: (value) => update(settings.rebuild((b) => b..cornerStyle = value)),
            ),
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.rows3),
              title: t.settings.density,
              value: settings.density?.name ?? '',
              options: [
                DsSelectOption(value: '', label: t.settings.densitySystem),
                DsSelectOption(value: 'compact', label: t.settings.densityCompact),
                DsSelectOption(value: 'touch', label: t.settings.densityTouch),
              ],
              onChanged: (value) {
                final density = switch (value) {
                  'compact' => DsDensity.compact,
                  'touch' => DsDensity.touch,
                  _ => null,
                };
                update(settings.rebuild((b) => b..density = density));
              },
            ),
          ],
        ),
        // The language is the other thing this page decides for the whole
        // app, so it gets its own card ahead of the type that carries it.
        DsListSection(
          header: Text(t.settings.groupLanguage),
          children: [
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.languages),
              title: t.settings.language,
              value: localeScope.localeCode ?? '',
              options: [
                DsSelectOption(value: '', label: t.settings.languageSystem),
                DsSelectOption(
                  value: ThemePersistence.localeSimplifiedChinese,
                  label: t.settings.languageSimplifiedChinese,
                ),
                DsSelectOption(value: ThemePersistence.localeEnglish, label: t.settings.languageEnglish),
              ],
              onChanged: (value) => localeScope.onChanged(value.isEmpty ? null : value),
            ),
          ],
        ),
        // The typeface and the overall text scale belong to the theme: they
        // change what every page is drawn with, which is what this page is
        // for. They keep their own card so the colour rows stay one group.
        // The card gaps are not here — they configure the feed grids, so they
        // live on the browsing page with the rest of the cards.
        DsListSection(
          header: Text(t.settings.navTypography),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.type),
              title: Text(t.settings.font),
              description: Text(t.settings.fontDescription),
              detail: Text(
                fontFamilyLabel(
                  t,
                  settings.fontFamily,
                  name: ref.watch(freeFontStoreProvider).nameOf(settings.fontFamily),
                ),
              ),
              showChevron: true,
              onPressed: () => showFontManagerPage(context, ref),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fontSize),
              title: t.settings.textScale,
              description: t.settings.textScaleDescription,
              detail: Text('${(textScale * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: textScale,
                min: kMinTextScaleFactor,
                max: kMaxTextScaleFactor,
                divisions: ((kMaxTextScaleFactor - kMinTextScaleFactor) / kTextScaleStep).round(),
                onChanged: (value) => ref.read(textScaleFactorProvider.notifier).factor = value,
                semanticLabel: t.settings.textScale,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A seed as a small color dot, so the palette choice reads as a color
/// rather than a word.
final class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({required this.seed}) : color = null;

  const _SeedSwatch.color(this.color) : seed = null;

  final DsSeed? seed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dot = color ?? (_seedAccents[seed!] ??= DsThemeData(seed: seed!).colors.accent);
    return Container(
      width: 14,
      height: 14,
      decoration: DsBoxDecoration(color: dot, borderRadius: BorderRadius.circular(7)),
    );
  }
}

/// Generated seed accents, one per named tone (the theme engine's output is
/// stable for one seed).
final Map<DsSeed, Color> _seedAccents = {};

/// The network pane (the reference's custom network proxy): the app proxy the
/// shared transport factory applies to every module's requests — vod, the
/// IPTV guide, backups. The tools order moved to the navigation pane.
final class _NetworkPane extends ConsumerWidget {
  const _NetworkPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final proxy = ref.watch(proxySettingsProvider);
    final controller = ref.read(proxySettingsProvider.notifier);
    final system = ref.watch(systemProxyProvider);
    // Only the manual mode types an endpoint; the other two answer from the
    // platform or from nothing at all.
    final manual = proxy.mode == ProxyMode.manual;
    final muted = DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navNetwork),
          children: [
            SettingsChoiceRow<ProxyMode>(
              leading: const DsIcon(DsIcons.globe),
              title: t.settings.proxy,
              description: switch (proxy.mode) {
                ProxyMode.off => t.settings.proxyModeOffDesc,
                ProxyMode.system => t.settings.proxyModeSystemDesc,
                ProxyMode.manual => t.settings.proxyModeManualDesc,
              },
              value: proxy.mode,
              options: [
                DsSelectOption(value: ProxyMode.off, label: t.settings.proxyModeOff),
                DsSelectOption(value: ProxyMode.system, label: t.settings.proxyModeSystem),
                DsSelectOption(value: ProxyMode.manual, label: t.settings.proxyModeManual),
              ],
              onChanged: (mode) => unawaited(controller.setMode(mode)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.server),
              title: t.settings.proxyHost,
              description: t.settings.proxyHostDesc,
              controlWidth: 220,
              // The endpoint stays on screen with the proxy off, greyed out:
              // a row that vanishes reads as a setting that went missing.
              control: DsTextField(
                initialValue: proxy.host,
                clearable: true,
                enabled: manual,
                placeholder: t.settings.proxyHost,
                onChanged: (value) => unawaited(controller.setHost(value)),
                semanticLabel: t.settings.proxyHost,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.hash),
              title: t.settings.proxyPort,
              description: t.settings.proxyPortDesc,
              controlWidth: 220,
              control: DsTextField(
                initialValue: '${proxy.port}',
                enabled: manual,
                placeholder: t.settings.proxyPort,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final port = int.tryParse(value.trim());
                  if (port != null) unawaited(controller.setPort(port));
                },
                semanticLabel: t.settings.proxyPort,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
              child: Text(_systemProxyStatusText(t, system), style: muted),
            ),
          ],
        ),
        const GithubMirrorSection(),
        DsListSection(
          children: [
            const SettingsChildEntry(child: SettingsSection.nodes),
            DsListRow(
              leading: const DsIcon(DsIcons.refresh),
              title: Text(t.settings.proxySystemRecheck),
              description: Text(t.settings.proxySystemRecheckDesc),
              onPressed: () => unawaited(ref.read(systemProxyProvider.notifier).refresh()),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the system-proxy reading amounts to, in the words the network page
/// prints under the mode row.
///
/// A PAC script or a SOCKS-only setting says so rather than reporting "none":
/// the difference is what tells a viewer to type the endpoint instead.
String _systemProxyStatusText(Translations t, SystemProxyEndpoint endpoint) => switch (endpoint.status) {
  SystemProxyStatus.probing => t.settings.proxySystemProbing,
  SystemProxyStatus.resolved => t.settings.proxySystemResolved(host: endpoint.authority),
  SystemProxyStatus.notConfigured => t.settings.proxySystemNone,
  SystemProxyStatus.notExpressible => t.settings.proxySystemNotExpressible,
  SystemProxyStatus.unsupported => t.settings.proxySystemUnsupported,
  SystemProxyStatus.failed => t.settings.proxySystemFailed,
};

/// The sites pane: the platform display (the reference's hot-areas
/// setting) — one switch per site, in the viewer's own order (drag a
/// handle, or Alt+Up/Down, to move one; "restore default" puts the
/// registry's back) and the preferred platform; a switched-off platform
/// leaves the popular and areas tab lists until it is switched back on.
/// Accounts and follow tags are their own pages beside it.
final class _SitesPane extends ConsumerWidget {
  const _SitesPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final sites = ref.watch(sitesProvider).all;
    final hidden = ref.watch(sitesDisplayProvider);
    final order = ref.watch(sitesOrderProvider);
    final orderController = ref.read(sitesOrderProvider.notifier);
    final names = {for (final site in sites) site.manifest.id: localizedSiteName(site)};
    final sitesById = {for (final site in sites) site.manifest.id: site};
    String name(String id) => names[id] ?? id;
    // The hidden set stores the platforms switched off; an empty set shows
    // everything.
    bool shown(String id) => hidden.isEmpty || !hidden.contains(id);
    // The preferred platform is chosen among the ones browsing shows: a
    // hidden platform is not a destination for the browse surfaces.
    final visibleOrder = [
      for (final id in order.order)
        if (shown(id)) id,
    ];
    // The reference opens a filterable picker rather than a plain list: the
    // platform catalogue is long enough that finding one by name or id is
    // the point, and an empty result says so instead of showing nothing.
    Future<void> pickPreferred() async {
      final picked = await showPreferPlatformDialog(
        context: context,
        options: [
          for (final id in visibleOrder)
            DsSelectOption(value: id, label: name(id), leading: localizedSiteIcon(sitesById[id], size: 20)),
        ],
        value: visibleOrder.contains(order.preferred) ? order.preferred : null,
      );
      if (picked != null) await orderController.setPreferred(picked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv)
          DsListSection(
            children: [
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.focus),
                title: t.settings.tvFocusZoom,
                description: t.settings.tvFocusZoomDesc,
                control: DsSwitch(
                  value: ref.watch(tvFocusZoomProvider),
                  onChanged: (value) => unawaited(ref.read(tvFocusZoomProvider.notifier).set(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.panelLeft),
                title: t.settings.tvMenuExpanded,
                description: t.settings.tvMenuExpandedDesc,
                control: DsSwitch(
                  value: ref.watch(tvMenuExpandedProvider),
                  onChanged: (value) => unawaited(ref.read(tvMenuExpandedProvider.notifier).set(value: value)),
                ),
              ),
            ],
          ),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.pin),
              title: Text(t.settings.preferPlatform),
              description: Text(t.settings.preferPlatformDesc),
              detail: Text(order.preferred.isEmpty ? t.settings.preferPlatform : name(order.preferred)),
              showChevron: true,
              onPressed: () => unawaited(pickPreferred()),
            ),
            // The reference's discover filter, kept with the platforms it
            // applies to: the popular page counts what it hides and can be
            // turned over from there too.
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.circleAlert),
              title: t.settings.showUnplayableTitle,
              description: t.settings.showUnplayableDesc,
              control: DsSwitch(
                value: ref.watch(showUnplayableProvider),
                onChanged: (value) => ref.read(showUnplayableProvider.notifier).setShow(value: value),
              ),
            ),
          ],
        ),
        // The pages that carry their own controls, in one block: a settings
        // page reads as a list of destinations, not three one-row cards.
        DsListSection(
          children: [
            const SettingsChildEntry(child: SettingsSection.sitesDisplay),
            SettingsChildEntry(
              child: SettingsSection.audience,
              detail: Text(audienceModeLabel(t, ref.watch(audienceMetricProvider))),
            ),
            const SettingsChildEntry(child: SettingsSection.accounts),
          ],
        ),
        DsListSection(
          header: Text(t.settings.twitchLanguages),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.messageCircle),
              title: t.settings.youtubeAllChat,
              description: t.settings.youtubeAllChatDesc,
              control: DsSwitch(
                value: ref.watch(youtubeAllChatProvider),
                onChanged: (value) => unawaited(ref.read(youtubeAllChatProvider.notifier).set(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.video),
              title: t.settings.preferH264,
              description: t.settings.preferH264Desc,
              control: DsSwitch(
                value: ref.watch(preferH264Provider),
                onChanged: (value) => unawaited(ref.read(preferH264Provider.notifier).set(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.refreshCw),
              title: t.settings.douyuForceRenew,
              description: t.settings.douyuForceRenewDesc,
              control: DsSwitch(
                value: ref.watch(douyuForceRenewProvider),
                onChanged: (value) => unawaited(ref.read(douyuForceRenewProvider.notifier).set(value: value)),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.languages),
              title: Text(t.settings.twitchLanguages),
              description: Text(t.settings.twitchLanguagesDesc),
              detail: Text(twitchLanguagesSummary(t, ref.watch(twitchLanguagesProvider))),
              showChevron: true,
              onPressed: () async {
                final result = await showTwitchLanguagesDialog(context, initial: ref.read(twitchLanguagesProvider));
                if (result != null) await ref.read(twitchLanguagesProvider.notifier).set(result);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// The platform display page: every platform the build carries, in the
/// viewer's order, each with its own show/hide switch — the order the browse
/// surfaces read, the visibility they filter by.
///
/// The rows are the display order itself, but only a draft edits it:
/// 「编辑顺序」 opens one and the order reaches storage on 保存顺序, the same
/// two states the navigation pages use. Showing or hiding a platform stays
/// immediate — it is a different choice from where a platform sits.
final class _SitesDisplayPane extends ConsumerWidget {
  const _SitesDisplayPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final sites = ref.watch(sitesProvider).all;
    final hidden = ref.watch(sitesDisplayProvider);
    final display = ref.read(sitesDisplayProvider.notifier);
    final order = ref.watch(sitesOrderProvider);
    final orderController = ref.read(sitesOrderProvider.notifier);
    final names = {for (final site in sites) site.manifest.id: localizedSiteName(site)};
    final sitesById = {for (final site in sites) site.manifest.id: site};
    // The hidden set stores the platforms switched off; an empty set shows
    // everything.
    bool shown(String id) => hidden.isEmpty || !hidden.contains(id);

    return SettingsOrderList<String>(
      header: t.settings.sitesDisplay,
      items: order.order,
      identityOf: (id) => id,
      labelOf: (id) => names[id] ?? id,
      leadingOf: (id) => localizedSiteIcon(sitesById[id], size: 20) ?? const DsIcon(DsIcons.antenna),
      descriptionOf: (id) => id,
      trailingOf: (id) => DsSwitch(
        value: shown(id),
        onChanged: (value) async {
          final changed = await display.toggle(id);
          if (!changed && context.mounted) {
            showDsToast(context: context, title: t.settings.sitesKeepOne);
          }
        },
      ),
      extraRows: [
        // With nothing hidden the line is a status; with anything hidden it
        // is the one-step way back to every platform.
        if (hidden.isEmpty)
          DsListRow(leading: const DsIcon(DsIcons.antenna), title: Text(t.settings.sitesAllShown))
        else
          DsListRow(
            leading: const DsIcon(DsIcons.antenna),
            title: Text(t.settings.sitesShowAll),
            description: Text(t.settings.sitesShowAllDesc),
            onPressed: () => unawaited(display.showAll()),
          ),
        DsListRow(
          leading: const DsIcon(DsIcons.listRestart),
          title: Text(t.settings.sitesOrderReset),
          description: Text(t.settings.sitesOrderResetDesc),
          onPressed: () => unawaited(orderController.resetOrder()),
        ),
      ],
      onSave: (draft) => unawaited(orderController.setOrder(draft)),
    );
  }
}

/// The data-and-cache page: what the app keeps on this machine — the watch
/// history and the follow list's clipboard round trip — and the cover
/// image cache's size, clearing and cap. One page because clearing either
/// is the same task of freeing or moving local data.
final class _DataCachePane extends StatelessWidget {
  const _DataCachePane();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [_DataPane(), _CachePane()],
    );
  }
}

/// The live data pane: the watch history's cap, clearing the watch history
/// behind a confirm, and the follow list as a JSON round trip through the
/// clipboard. Backups, restores and WebDAV sync are their own app-wide
/// section, so the video and IPTV modules can reach them without carrying
/// the live history.
final class _DataPane extends ConsumerWidget {
  const _DataPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final historyLimit = ref.watch(historyLimitProvider);
    // A cap imported from outside the choices still shows as chosen.
    final limits = {...HistoryLimitController.choices, historyLimit}.toList()..sort();
    void toast(String message) {
      showDsToast(context: context, title: message);
    }

    return DsListSection(
      header: Text(t.settings.navData),
      children: [
        SettingsChoiceRow<int>(
          leading: const DsIcon(DsIcons.clock),
          title: t.settings.historyLimit,
          description: t.settings.historyLimitDesc,
          value: historyLimit,
          options: [for (final limit in limits) DsSelectOption(value: limit, label: '$limit')],
          onChanged: (value) => unawaited(ref.read(historyLimitProvider.notifier).setLimit(value)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.history),
          title: Text(t.settings.dataClearHistory),
          description: Text(t.settings.dataClearHistoryDesc),
          destructive: true,
          onPressed: () async {
            final confirmed = await showDsConfirm(
              context: context,
              title: t.settings.confirmClearTitle,
              description: t.settings.confirmClearDesc,
              confirmLabel: t.settings.confirm,
              destructive: true,
            );
            if (!confirmed) return;
            await ref.read(historyProvider.notifier).clear();
            toast(t.settings.dataDone);
          },
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.upload),
          title: Text(t.settings.dataExportFollows),
          description: Text(t.settings.dataExportFollowsDesc),
          onPressed: () async {
            final rooms = ref.read(followsProvider).rooms;
            if (rooms.isEmpty) {
              toast(t.settings.dataEmpty);
              return;
            }
            await Clipboard.setData(ClipboardData(text: encodeFollows(rooms)));
            toast(t.settings.dataDone);
          },
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.download),
          title: Text(t.settings.dataImportFollows),
          description: Text(t.settings.dataImportFollowsDesc),
          onPressed: () async {
            final raw = await Clipboard.getData(Clipboard.kTextPlain).then((data) => data?.text);
            final rooms = raw == null ? null : decodeFollows(raw);
            if (rooms == null) {
              toast(t.settings.dataBadData);
              return;
            }
            final repository = ref.read(followRepositoryProvider).value;
            if (repository != null) {
              for (final room in rooms) {
                await repository.add(room);
              }
            }
            toast(t.settings.dataDone);
          },
        ),
      ],
    );
  }
}

/// The cache pane: the cover/avatar disk cache the network images live in —
/// its size, a manual clear, and the automatic cap the boot prunes to.
final class _CachePane extends ConsumerStatefulWidget {
  const _CachePane();

  @override
  ConsumerState<_CachePane> createState() => _CachePaneState();
}

final class _CachePaneState extends ConsumerState<_CachePane> {
  int? _bytes;
  int _limitMb = imageCacheLimitMb();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_measure());
  }

  Future<void> _measure() async {
    final bytes = await imageCacheBytes();
    if (mounted) {
      setState(() => _bytes = bytes);
    }
  }

  Future<void> _clear() async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.cacheClear,
      description: t.settings.cacheClearDesc,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await clearImageCache();
      await _measure();
      if (mounted) {
        showDsToast(context: context, title: context.t.settings.cacheCleared);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshThumbnails() async {
    setState(() => _busy = true);
    try {
      await ref.read(thumbnailRefreshProvider.notifier).refreshNow();
      await _measure();
      if (mounted) {
        showDsToast(context: context, title: context.t.settings.cacheRefreshThumbnailsDone);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setLimit(int? value) async {
    if (value == null) {
      return;
    }
    setState(() => _limitMb = value);
    await storeImageCacheLimitMb(value);
    // Applying the cap at once makes the setting honest on the spot.
    if (value > 0) {
      await enforceImageCacheLimit(value * 1024 * 1024);
      await _measure();
    }
  }

  Future<void> _pickDownloadDirectory() async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.settings.downloadDirectory);
      if (selected == null || selected.trim().isEmpty) return;
      final saved = await ref.read(downloadDirectoryProvider.notifier).setDirectory(selected);
      if (!mounted) return;
      if (!saved) {
        showDsToast(context: context, title: t.settings.downloadDirectoryPermissionHint, status: DsStatus.danger);
        return;
      }
      showDsToast(context: context, title: t.settings.downloadDirectoryUpdated);
    } on Object {
      if (mounted) {
        showDsToast(context: context, title: t.settings.downloadDirectoryPickFailed, status: DsStatus.danger);
      }
    }
  }

  Future<void> _resetDownloadDirectory() async {
    await ref.read(downloadDirectoryProvider.notifier).reset();
    if (mounted) {
      showDsToast(context: context, title: context.t.settings.downloadDirectoryUpdated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final download = ref.watch(downloadDirectoryProvider);
    return DsListSection(
      header: Text(t.settings.navCache),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.archive),
          title: Text(t.settings.cacheSize),
          detail: Text(_bytes == null ? '…' : formatCacheSize(_bytes!)),
          trailing: DsButton(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.refreshCw, size: 16),
            onPressed: _busy ? null : () => unawaited(_measure()),
            child: Text(t.settings.cacheRefresh),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.image),
          title: Text(t.settings.cacheRefreshThumbnails),
          description: Text(t.settings.cacheRefreshThumbnailsDesc),
          trailing: DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: _busy ? null : () => unawaited(_refreshThumbnails()),
            child: Text(t.settings.cacheRefreshThumbnails),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.trash2),
          title: Text(t.settings.cacheClear),
          description: Text(t.settings.cacheClearDesc),
          trailing: DsButton(
            variant: DsButtonVariant.dangerSoft,
            size: DsSize.sm,
            onPressed: _busy ? null : () => unawaited(_clear()),
            child: Text(t.settings.cacheClear),
          ),
        ),
        SettingsChoiceRow<int>(
          leading: const DsIcon(DsIcons.database),
          title: t.settings.cacheLimit,
          description: t.settings.cacheLimitDesc,
          value: _limitMb,
          options: [
            DsSelectOption(value: 0, label: t.settings.cacheLimitOff),
            for (final mb in const [100, 200, 500, 1024, 2048]) DsSelectOption(value: mb, label: '$mb MB'),
          ],
          onChanged: (value) => unawaited(_setLimit(value)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.folder),
          title: Text(t.settings.downloadDirectory),
          // The folder itself is what this row is for, and a Windows path is
          // long: the description slot has the card's width to show it, and
          // the tooltip carries the whole thing when it still has to shorten.
          description: DsTooltip(
            message: download.effectivePath,
            child: Text(download.effectivePath, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          detail: Text(
            download.custom.isEmpty
                ? t.settings.downloadDirectoryDefaultLabel
                : t.settings.downloadDirectoryCustomLabel,
          ),
          onPressed: _busy ? null : () => unawaited(_pickDownloadDirectory()),
        ),
        // Always on screen: with the default folder in place there is nothing
        // to undo, so the row waits greyed rather than disappearing.
        DsListRow(
          leading: const DsIcon(DsIcons.rotateCcw),
          title: Text(t.settings.downloadDirectoryReset),
          onPressed: download.custom.isEmpty || _busy ? null : () => unawaited(_resetDownloadDirectory()),
        ),
        SettingsHint(t.settings.cacheHint),
      ],
    );
  }
}

/// The about pane: the app's name and version, the update check, the
/// release history, the project home, and the open-source licences (the
/// reference's about view, without an in-app installer: a release opens its
/// own download page).
final class _AboutPane extends ConsumerWidget {
  const _AboutPane();

  static const String _projectUrl = 'https://github.com/liuchuancong/pure_live';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final check = ref.watch(versionCheckProvider);
    final latest = check.latest;
    final status = check.checking
        ? t.settings.checkingUpdate
        : check.error != null
        ? '${t.settings.updateCheckFailed} · ${check.error}'
        : latest != null
        ? t.settings.updateAvailable(version: latest.version)
        : check.checked
        ? t.settings.upToDate
        : t.settings.checkUpdateDesc;
    return DsListSection(
      header: Text(t.settings.navAbout),
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return DsListRow(
              leading: const DsIcon(DsIcons.info),
              title: Text(t.settings.aboutVersion),
              detail: Text(info == null ? '…' : '${info.version}+${info.buildNumber}'),
            );
          },
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudDownload),
          title: Text(t.settings.checkUpdate),
          description: Text(status),
          trailing: latest != null
              ? DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(showUpdateDialog(context, latest)),
                  child: Text(t.settings.viewUpdate),
                )
              : DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: check.checking ? null : () => unawaited(ref.read(versionCheckProvider.notifier).check()),
                  child: Text(t.settings.checkUpdate),
                ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.refreshCw),
          title: t.settings.autoCheckUpdate,
          description: t.settings.autoCheckUpdateDesc,
          control: DsSwitch(
            value: ref.watch(updateSettingsProvider),
            onChanged: (value) => ref.read(updateSettingsProvider.notifier).enabled = value,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.history),
          title: Text(t.settings.releaseHistory),
          description: Text(t.settings.releaseHistoryDesc),
          showChevron: true,
          onPressed: () => unawaited(showReleaseHistory(context)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudDownload),
          // The installers are the release's own files; the page lists
          // every build so a viewer on another architecture can still
          // take the right one.
          title: Text(t.settings.downloadTitle),
          description: Text(t.settings.downloadHint),
          showChevron: true,
          onPressed: () => unawaited(showDownloadPage(context)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.fileText),
          title: Text(t.settings.configPreview),
          description: Text(t.settings.configPreviewDesc),
          onPressed: () => unawaited(showConfigPreview(context)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.link),
          title: Text(t.settings.aboutProject),
          description: const Text(_projectUrl),
          onPressed: () => unawaited(launchUrl(Uri.parse(_projectUrl), mode: LaunchMode.externalApplication)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.scrollText),
          title: Text(t.settings.aboutLicense),
          description: Text(t.settings.aboutLicenseDesc),
          onPressed: () => showLicensePage(
            context: context,
            applicationName: t.common.appTitle,
            applicationIcon: const AppMark(size: 40),
          ),
        ),
      ],
    );
  }
}

/// The quality-and-sound page: the stream quality a room opens with (and
/// its cellular cap) and the audio defaults, in one page because both are
/// the same user task — what playback sounds and looks like by default.
/// Picture geometry is its own page. All applied as the player handle
/// arrives.
final class _QualityAudioPane extends ConsumerWidget {
  const _QualityAudioPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    final network = ref.watch(networkTypeProvider);
    final stored = settings.preferredQuality ?? kPreferredResolutionChoices.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navQuality),
          children: [
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.preferredQuality,
              description: t.settings.preferredQualityDesc,
              value: stored,
              options: [
                for (final quality in kPreferredResolutionChoices)
                  DsSelectOption(value: quality, label: preferredQualityLabel(t, quality)),
              ],
              onChanged: (value) => unawaited(controller.setPreferredQuality(value)),
            ),
            if (network.reportsCellular)
              SettingsChoiceRow<String>(
                leading: const DsIcon(DsIcons.smartphone),
                title: t.settings.preferredQualityCellular,
                description: t.settings.preferredQualityCellularDesc,
                value: settings.preferredQualityCellular ?? kPreferredResolutionChoices.first,
                options: [
                  for (final quality in kPreferredResolutionChoices)
                    DsSelectOption(value: quality, label: preferredQualityLabel(t, quality)),
                ],
                onChanged: (value) => unawaited(controller.setPreferredQualityCellular(value)),
              ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.navAudio),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.volumeOff),
              title: t.settings.defaultMuted,
              description: t.settings.defaultMutedDesc,
              control: DsSwitch(
                value: settings.muted,
                onChanged: (value) => unawaited(controller.setMuted(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.volumeX),
              title: t.settings.globalMute,
              description: t.settings.globalMuteDesc,
              control: DsSwitch(
                value: settings.globalMute,
                onChanged: (value) => unawaited(controller.setGlobalMute(value: value)),
              ),
            ),
            if (ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.android) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.music),
                title: t.settings.backgroundPlay,
                description: t.settings.backgroundPlayDesc,
                control: DsSwitch(
                  value: settings.backgroundPlay,
                  onChanged: (value) => unawaited(controller.setBackgroundPlay(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.captions),
                title: t.settings.backgroundPauseDanmaku,
                description: t.settings.backgroundPauseDanmakuDesc,
                control: DsSwitch(
                  value: settings.backgroundPauseDanmaku,
                  onChanged: (value) => unawaited(controller.setBackgroundPauseDanmaku(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.headphones),
                title: t.settings.backgroundAudioOnly,
                description: t.settings.backgroundAudioOnlyDesc,
                control: DsSwitch(
                  value: settings.backgroundAudioOnly,
                  onChanged: (value) => unawaited(controller.setBackgroundAudioOnly(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.pictureInPicture),
                title: t.settings.pauseOnPipClose,
                description: t.settings.pauseOnPipCloseDesc,
                control: DsSwitch(
                  value: settings.pauseOnPipClose,
                  onChanged: (value) => unawaited(controller.setPauseOnPipClose(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.moon),
                title: t.settings.asmrSleepMode,
                description: t.settings.asmrSleepModeDesc,
                control: DsSwitch(
                  value: settings.asmrSleepMode,
                  onChanged: (value) => unawaited(controller.setAsmrSleepMode(value: value)),
                ),
              ),
              if (settings.asmrSleepMode)
                DsListRow(
                  leading: const DsIcon(DsIcons.timer),
                  title: Text(t.settings.asmrSleepTimer),
                  description: Text(t.settings.asmrSleepTimerDesc),
                  trailing: Text(asmrSleepDurationLabel(settings.asmrSleepMinutes)),
                  onPressed: () => unawaited(showAsmrSleepMinutesDialog(context, ref)),
                ),
            ],
            // The iOS system picture-in-picture window can also be closed by
            // the viewer, so the same choice is offered there; the Android
            // block above keeps the switch next to its background playback
            // row.
            if (ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.ios)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.pictureInPicture),
                title: t.settings.pauseOnPipClose,
                description: t.settings.pauseOnPipCloseDesc,
                control: DsSwitch(
                  value: settings.pauseOnPipClose,
                  onChanged: (value) => unawaited(controller.setPauseOnPipClose(value: value)),
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.volume),
              title: t.settings.defaultVolume,
              description: t.settings.defaultVolumeDesc,
              detail: Text('${(controller.volume * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: controller.volume,
                onChanged: (value) => unawaited(controller.setVolume(value)),
                semanticLabel: t.settings.defaultVolume,
              ),
            ),
            SettingsSegmentedRow<int>(
              leading: const DsIcon(DsIcons.volume2),
              title: t.settings.volumeWheelStep,
              description: t.settings.volumeWheelStepDesc,
              value: settings.volumeWheelStepPercent,
              options: [
                for (final percent in kVolumeWheelStepChoices)
                  (value: percent, label: t.settings.volumeWheelStepValue(percent: percent)),
              ],
              onChanged: (value) => unawaited(controller.setVolumeWheelStepPercent(value)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The picture page: how the video fills its area and what the screen does
/// around it. The floating and compact windows the picture can leave behind
/// are their own page, as is the portrait-stream layout.
final class _PicturePane extends ConsumerWidget {
  const _PicturePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final portrait = ref.watch(portraitSettingsProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.pictureDisplayGroup),
          children: [
            SettingsChoiceRow<PlaybackFit>(
              leading: const DsIcon(DsIcons.rectangleHorizontal),
              title: t.settings.fit,
              description: t.settings.fitDesc,
              value: settings.fit,
              options: [
                for (final (index, option) in PlaybackFit.values.indexed)
                  DsSelectOption(value: option, label: fitLabels(t)[index]),
              ],
              placeholder: t.settings.fit,
              onChanged: (value) => unawaited(controller.setFit(value)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fullscreen),
              title: t.settings.fullscreenDefault,
              description: t.settings.fullscreenDefaultDesc,
              control: DsSwitch(
                value: settings.fullscreenDefault,
                onChanged: (value) => unawaited(controller.setFullscreenDefault(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.eyeOff),
              title: t.settings.controlsAutoHide,
              description: t.settings.controlsAutoHideDesc,
              detail: Text(t.settings.controlsAutoHideValue(count: settings.controlsAutoHideSeconds)),
              controlWidth: 220,
              control: DsSlider(
                value: settings.controlsAutoHideSeconds.toDouble(),
                min: kControlsAutoHideSecondsMin.toDouble(),
                max: kControlsAutoHideSecondsMax.toDouble(),
                divisions: kControlsAutoHideSecondsMax - kControlsAutoHideSecondsMin,
                onChanged: (value) => unawaited(controller.setControlsAutoHideSeconds(value.round())),
                semanticLabel: t.settings.controlsAutoHide,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.sun),
              title: t.settings.keepScreenOn,
              description: t.settings.keepScreenOnDesc,
              control: DsSwitch(
                value: ref.watch(keepScreenOnProvider),
                onChanged: (value) => ref.read(keepScreenOnProvider.notifier).enabled = value,
              ),
            ),
          ],
        ),
        DsListSection(
          children: [
            const SettingsChildEntry(child: SettingsSection.floatingWindow),
            SettingsChildEntry(
              child: SettingsSection.portrait,
              detail: Text(
                portrait.adaptation && portrait.adaptiveHeight
                    ? _portraitLayoutLabel(t, portrait.layoutMode)
                    : t.settings.portraitEntryOff,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The floating-window page: the in-app window the player leaves behind when
/// a room scrolls away, and the system picture-in-picture it hands the
/// picture to — including the geometry only the Windows shell exposes.
final class _FloatingWindowPane extends ConsumerWidget {
  const _FloatingWindowPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    final windows = ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.windows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.floatWindowGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pictureInPicture2),
              title: t.settings.floatPlay,
              description: t.settings.floatPlayDesc,
              control: DsSwitch(
                value: settings.floatPlay,
                onChanged: (value) => unawaited(controller.setFloatPlay(value: value)),
              ),
            ),
            SettingsSegmentedRow<String>(
              leading: const DsIcon(DsIcons.maximize),
              title: t.settings.floatWindowSize,
              description: t.settings.floatWindowSizeDesc,
              value: ref.watch(floatingWindowSettingsProvider).size,
              options: [
                (value: 'small', label: t.settings.floatWindowSmall),
                (value: 'medium', label: t.settings.floatWindowMedium),
                (value: 'large', label: t.settings.floatWindowLarge),
              ],
              onChanged: (value) => unawaited(ref.read(floatingWindowSettingsProvider.notifier).setSize(value)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.pipGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pictureInPicture),
              title: t.settings.autoPip,
              description: t.settings.autoPipDesc,
              control: DsSwitch(
                value: settings.autoPipOnLeave,
                onChanged: (value) => unawaited(controller.setAutoPipOnLeave(value: value)),
              ),
            ),
            // The other platforms give the picture to the operating system's
            // own player, which has none of these knobs.
            if (windows) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.pin),
                title: t.settings.windowsPipAlwaysOnTop,
                description: t.settings.windowsPipAlwaysOnTopDesc,
                control: DsSwitch(
                  value: settings.windowsPipAlwaysOnTop,
                  onChanged: (value) => unawaited(_setWindowsPipAlwaysOnTop(ref, value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.appWindow),
                title: t.settings.rememberPipPosition,
                description: t.settings.rememberPipPositionDesc,
                control: DsSwitch(
                  value: settings.rememberPipPosition,
                  onChanged: (value) => unawaited(controller.setRememberPipPosition(value: value)),
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.aspectRatio),
                title: t.settings.windowsPipBaseSize,
                description: t.settings.windowsPipBaseSizeDesc,
                detail: Text('${settings.windowsPipBaseSize.round()} px'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.windowsPipBaseSize,
                  min: kWindowsPipBaseSizeMin,
                  max: kWindowsPipBaseSizeMax,
                  divisions: ((kWindowsPipBaseSizeMax - kWindowsPipBaseSizeMin) / 10).round(),
                  onChanged: (value) {
                    unawaited(controller.setWindowsPipBaseSize(value));
                    _syncWindowsPipConfig(ref);
                  },
                  semanticLabel: t.settings.windowsPipBaseSize,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.arrowLeftRight),
                title: t.settings.windowsPipMinWidth,
                description: t.settings.windowsPipMinWidthDesc,
                detail: Text('${settings.windowsPipMinWidth.round()} px'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.windowsPipMinWidth,
                  min: kWindowsPipMinWidthMin,
                  max: kWindowsPipMinWidthMax,
                  divisions: ((kWindowsPipMinWidthMax - kWindowsPipMinWidthMin) / 10).round(),
                  onChanged: (value) {
                    unawaited(controller.setWindowsPipMinWidth(value));
                    _syncWindowsPipConfig(ref);
                  },
                  semanticLabel: t.settings.windowsPipMinWidth,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.moveVertical),
                title: t.settings.windowsPipMinHeight,
                description: t.settings.windowsPipMinHeightDesc,
                detail: Text('${settings.windowsPipMinHeight.round()} px'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.windowsPipMinHeight,
                  min: kWindowsPipMinHeightMin,
                  max: kWindowsPipMinHeightMax,
                  divisions: ((kWindowsPipMinHeightMax - kWindowsPipMinHeightMin) / 10).round(),
                  onChanged: (value) {
                    unawaited(controller.setWindowsPipMinHeight(value));
                    _syncWindowsPipConfig(ref);
                  },
                  semanticLabel: t.settings.windowsPipMinHeight,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.aspectRatio),
                title: t.settings.windowsPipFreeAspect,
                description: t.settings.windowsPipFreeAspectDesc,
                control: DsSwitch(
                  value: settings.windowsPipFreeAspect,
                  onChanged: (value) {
                    unawaited(controller.setWindowsPipFreeAspect(value: value));
                    _syncWindowsPipConfig(ref);
                  },
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.locate),
                title: Text(t.settings.windowsPipResetPosition),
                description: Text(t.settings.windowsPipResetPositionDesc),
                showChevron: true,
                onPressed: () => unawaited(_resetWindowsPipGeometry(context)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The portrait-stream page (the reference's portrait live settings): the
/// room page's portrait detection, adaptive height and layout mode. The
/// room page reads the same preferences when it lays a narrow room out, so
/// every change lands on the next build.
final class _PortraitPane extends ConsumerWidget {
  const _PortraitPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(portraitSettingsProvider);
    final controller = ref.read(portraitSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        _portraitDetectionSection(context, t, settings, controller),
        DsListSection(
          header: Text(t.settings.portraitPresentationGroup),
          children: [
            SettingsSegmentedRow<PortraitFullscreenPolicy>(
              leading: const DsIcon(DsIcons.fullscreen),
              title: t.settings.portraitFullscreenPolicy,
              description: t.settings.portraitFullscreenPolicyDesc,
              value: settings.fullscreenPolicy,
              options: [
                (value: PortraitFullscreenPolicy.followSource, label: t.settings.portraitFullscreenFollowSource),
                (value: PortraitFullscreenPolicy.followSystem, label: t.settings.portraitFullscreenFollowSystem),
                (value: PortraitFullscreenPolicy.landscape, label: t.settings.portraitFullscreenLandscape),
              ],
              onChanged: (policy) => unawaited(controller.setFullscreenPolicy(policy)),
            ),
          ],
        ),
        _PortraitFullscreenSection(state: ref.watch(portraitFullscreenProvider)),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.settings.portraitReset),
              description: Text(t.settings.portraitResetDesc),
              destructive: true,
              onPressed: () => unawaited(_resetPortraitSettings(context, ref)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Restores the portrait page (the reference's `portrait_reset_settings`,
/// confirmed first). Only the preferences this build stores are reset; the
/// remembered room orientations the reference also clears do not exist here.
Future<void> _resetPortraitSettings(BuildContext context, WidgetRef ref) async {
  final t = context.t;
  final confirmed = await showDsConfirm(
    context: context,
    title: t.settings.portraitReset,
    description: t.settings.portraitResetConfirm,
    confirmLabel: t.settings.styleReset,
    cancelLabel: t.common.cancel,
    destructive: true,
    icon: const DsIcon(DsIcons.rotateCcw),
  );
  if (!confirmed) return;
  await ref.read(portraitSettingsProvider.notifier).resetToDefaults();
  await ref.read(portraitFullscreenProvider.notifier).resetToDefaults();
  // The rooms' remembered framings belong to the same surface: reset drops
  // their overrides too (the store write reaches the other windows through
  // the refresh list).
  await ref.read(roomOrientationChoicesProvider.notifier).reset();
  if (context.mounted) {
    showDsToast(context: context, title: t.settings.mpvResetDone);
  }
}

/// The portrait full-screen group: picture mode, danmaku area, per-room
/// remembering, diagnostics and the clear action for saved room choices.
final class _PortraitFullscreenSection extends ConsumerWidget {
  const _PortraitFullscreenSection({required this.state});

  final PortraitFullscreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.read(portraitFullscreenProvider.notifier);
    final formFactor = ref.watch(platformRuntimeProvider).environment.runtime.formFactor;
    final mobile = formFactor == FormFactor.phone || formFactor == FormFactor.tablet;
    return DsListSection(
      header: Text(t.settings.portraitFullscreenGroup),
      children: [
        SettingsChoiceRow<PortraitFullscreenMode>(
          leading: const DsIcon(DsIcons.rectangleVertical),
          title: t.settings.portraitDisplayMode,
          description: t.settings.portraitDisplayModeDesc,
          value: state.display,
          options: [
            DsSelectOption(value: PortraitFullscreenMode.complete, label: t.room.portraitDisplayComplete),
            DsSelectOption(value: PortraitFullscreenMode.ambient, label: t.room.portraitDisplayAmbient),
            DsSelectOption(value: PortraitFullscreenMode.balanced, label: t.room.portraitDisplayBalanced),
            DsSelectOption(value: PortraitFullscreenMode.cover, label: t.room.portraitDisplayCover),
          ],
          onChanged: (value) => unawaited(controller.remember('', (display: value, danmaku: state.danmaku))),
        ),
        SettingsChoiceRow<PortraitDanmakuMode>(
          leading: const DsIcon(DsIcons.captions),
          title: t.settings.portraitDanmakuMode,
          description: t.settings.portraitDanmakuModeDesc,
          value: state.danmaku,
          options: [
            DsSelectOption(value: PortraitDanmakuMode.followGlobal, label: t.room.portraitDanmakuFollow),
            DsSelectOption(value: PortraitDanmakuMode.upperQuarter, label: t.room.portraitDanmakuUpper),
            DsSelectOption(value: PortraitDanmakuMode.reduced, label: t.room.portraitDanmakuReduced),
            DsSelectOption(value: PortraitDanmakuMode.hidden, label: t.room.portraitDanmakuHidden),
          ],
          onChanged: (value) => unawaited(controller.remember('', (display: state.display, danmaku: value))),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.bookmarkPlus),
          title: t.settings.portraitRememberRoom,
          description: t.settings.portraitRememberRoomDesc,
          control: DsSwitch(
            value: state.rememberRoom,
            onChanged: (value) => unawaited(controller.setRemember(value: value)),
          ),
        ),
        if (mobile)
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.arrowUpDown),
            title: t.settings.portraitSwipeSwitch,
            description: t.settings.portraitSwipeSwitchDesc,
            control: DsSwitch(
              value: ref.watch(portraitSwipeSwitchProvider),
              onChanged: (value) => unawaited(ref.read(portraitSwipeSwitchProvider.notifier).set(value: value)),
            ),
          ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.activity),
          title: t.settings.portraitDiagnostics,
          description: t.settings.portraitDiagnosticsDesc,
          control: DsSwitch(
            value: state.diagnostics,
            onChanged: (value) => unawaited(controller.setDiagnostics(value: value)),
          ),
        ),
        if (state.overrides.isNotEmpty)
          DsListRow(
            leading: const DsIcon(DsIcons.trash2),
            title: Text(t.settings.portraitClearOverrides),
            description: Text(
              '${t.settings.portraitClearOverridesDesc}\n'
              '${t.settings.portraitOverridesCount(count: state.overrides.length)}',
            ),
            destructive: true,
            onPressed: () async {
              await controller.clearOverrides();
              if (!context.mounted) return;
              showDsToast(context: context, title: t.settings.portraitOverridesCleared);
            },
          ),
      ],
    );
  }
}

/// The detection group: the switch, the adaptive height and the layout mode
/// under it (the reference's `portrait_detection_group`).
Widget _portraitDetectionSection(
  BuildContext context,
  Translations t,
  PortraitSettings settings,
  PortraitSettingsController controller,
) => DsListSection(
  header: Text(t.settings.portraitDetectionGroup),
  children: [
    SettingsConfigRow(
      leading: const DsIcon(DsIcons.rectangleVertical),
      title: t.settings.portraitSmartDetection,
      description: t.settings.portraitSmartDetectionDesc,
      control: DsSwitch(
        value: settings.adaptation,
        onChanged: (value) => unawaited(controller.setAdaptation(value: value)),
      ),
    ),
    if (settings.adaptation) ...[
      SettingsConfigRow(
        leading: const DsIcon(DsIcons.moveVertical),
        title: t.settings.portraitAdaptiveHeight,
        description: t.settings.portraitAdaptiveHeightDesc,
        control: DsSwitch(
          value: settings.adaptiveHeight,
          onChanged: (value) => unawaited(controller.setAdaptiveHeight(value: value)),
        ),
      ),
      if (settings.adaptiveHeight)
        SettingsSegmentedRow<PortraitLayoutMode>(
          leading: const DsIcon(DsIcons.layoutGrid),
          title: t.settings.portraitLayoutMode,
          description: t.settings.portraitLayoutModeDesc,
          value: settings.layoutMode,
          options: [
            (value: PortraitLayoutMode.balanced, label: t.settings.portraitLayoutBalanced),
            (value: PortraitLayoutMode.immersive, label: t.settings.portraitLayoutImmersive),
            (value: PortraitLayoutMode.compatibility, label: t.settings.portraitLayoutCompatibility),
          ],
          onChanged: (mode) => unawaited(controller.setLayoutMode(mode)),
        ),
    ] else
      SettingsHint(t.settings.portraitDetectionOff),
  ],
);

/// One of the portrait layout modes as the settings row and the entry show
/// it.
String _portraitLayoutLabel(Translations t, PortraitLayoutMode mode) => switch (mode) {
  PortraitLayoutMode.balanced => t.settings.portraitLayoutBalanced,
  PortraitLayoutMode.immersive => t.settings.portraitLayoutImmersive,
  PortraitLayoutMode.compatibility => t.settings.portraitLayoutCompatibility,
};

/// The player-kernel pane (the reference's player kernel): the engine in use and
/// its hardware-decoding choice, applied to each attached engine through
/// media_core's engine-option surface.
/// The recording pane (the reference's Recording): the recorder's own settings,
/// shared with the recording centre's header so both surfaces write the
/// same stored truth.
final class _RecordingPane extends StatelessWidget {
  const _RecordingPane();

  @override
  Widget build(BuildContext context) => const RecordingSettingsPane();
}
