import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformKind;
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/app/bootstrap/pure_live_app.dart' show AppLocaleScope;
import 'package:pure_live/app/navigation/module_navigation.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/download_directory_provider.dart' show downloadDirectoryProvider;
import 'package:pure_live/app/providers/dynamic_color_provider.dart'
    show dynamicColorProvider, dynamicColorSeedProvider;
import 'package:pure_live/app/providers/environment_providers.dart'
    show DeviceProfile, deviceProfileProvider, platformRuntimeProvider;
import 'package:pure_live/app/providers/font_library_provider.dart' show fontLibraryProvider;
import 'package:pure_live/app/providers/font_size_provider.dart' show appFontSizesProvider;
import 'package:pure_live/app/providers/keep_screen_on_provider.dart' show keepScreenOnProvider;
import 'package:pure_live/app/providers/liquid_glass_provider.dart' show liquidGlassProvider;
import 'package:pure_live/app/providers/loading_style_provider.dart' show loadingStyleProvider;
import 'package:pure_live/app/providers/module_providers.dart' show selectedModuleProvider;
import 'package:pure_live/app/providers/nav_visibility_providers.dart'
    show kHomeMenuItems, navMenuProvider, showMultiviewProvider;
import 'package:pure_live/app/providers/network_providers.dart' show proxySettingsProvider;
import 'package:pure_live/app/providers/network_type_provider.dart' show networkTypeProvider;
import 'package:pure_live/app/providers/page_size_options_provider.dart';
import 'package:pure_live/app/providers/pip_geometry.dart' show clearPipSavedBounds;
import 'package:pure_live/app/providers/presentation_providers.dart'
    show pipDriverProvider, windowsPipConfigFor, windowsPipWindowProvider;
import 'package:pure_live/app/providers/pure_black_theme_provider.dart' show pureBlackThemeProvider;
import 'package:pure_live/app/providers/refresh_settings_providers.dart';
import 'package:pure_live/app/providers/settings_section_provider.dart' show settingsSectionProvider;
import 'package:pure_live/app/providers/shell_settings_provider.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider, sitesProvider;
import 'package:pure_live/app/providers/splash_settings_provider.dart' show splashSettingsProvider;
import 'package:pure_live/app/providers/startup_provider.dart' show startupProvider;
import 'package:pure_live/app/providers/text_scale_provider.dart'
    show kMaxTextScaleFactor, kMinTextScaleFactor, textScaleFactorProvider;
import 'package:pure_live/app/providers/thumbnail_refresh_provider.dart'
    show kThumbnailRefreshIntervalChoices, thumbnailRefreshProvider;
import 'package:pure_live/app/providers/update_settings_provider.dart' show updateSettingsProvider;
import 'package:pure_live/app/providers/user_notification_providers.dart' show requestUserNotificationPermission;
import 'package:pure_live/app/providers/window_providers.dart' show isPrimaryWindowProvider;
import 'package:pure_live/app/routing/app_router.dart' show SettingsSectionRoute;
import 'package:pure_live/app/theme/font_defaults.dart' show platformFontFamilyLabel;
import 'package:pure_live/app/theme/font_sizes.dart';
import 'package:pure_live/app/theme/theme_mode_dialog.dart' show themeModeLabel;
import 'package:pure_live/app/theme/theme_persistence.dart';
import 'package:pure_live/app/theme/theme_settings.dart';
import 'package:pure_live/app/window_chrome.dart' show WindowChrome, WindowChromeState;
import 'package:pure_live/features/account/account_pane.dart' show AccountPane;
import 'package:pure_live/features/backup/backup_pane.dart' show BackupPane;
import 'package:pure_live/features/backup/webdav_pane.dart' show WebDavSyncPane;
import 'package:pure_live/features/favorites/follow_repository.dart' show followRepositoryProvider, followsProvider;
import 'package:pure_live/features/favorites/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/features/favorites/follow_tags_pane.dart' show FollowTagsPane;
import 'package:pure_live/features/history/history_repository.dart' show historyProvider;
import 'package:pure_live/features/iptv/iptv_settings_pane.dart' show IptvSettingsPane;
import 'package:pure_live/features/recorder/recorder_page.dart' show RecordingSettingsPane;
import 'package:pure_live/features/settings/asmr_sleep_dialog.dart' show showAsmrSleepMinutesDialog;
import 'package:pure_live/features/settings/audience_metric_provider.dart' show audienceMetricProvider;
import 'package:pure_live/features/settings/audience_settings_pane.dart' show AudienceSettingsPane, audienceModeLabel;
import 'package:pure_live/features/settings/auto_shutdown_section.dart' show AutoShutdownSection;
import 'package:pure_live/features/settings/background_panes.dart'
    show
        BackgroundColorsPane,
        BackgroundDevicePane,
        BackgroundLibraryPane,
        BackgroundOverviewPane,
        BackgroundRandomPane;
import 'package:pure_live/features/settings/chat_display_settings.dart'
    show
        chatGiftValueInYuanProvider,
        chatGiftsAboveTierProvider,
        chatListFontSizeProvider,
        chatListLineSpacingProvider,
        chatListStyleProvider,
        chatNamesProvider,
        chatShowGiftsProvider;
import 'package:pure_live/features/settings/clipboard_rooms.dart' show detectClipboardRoomsProvider;
import 'package:pure_live/features/settings/config_preview_dialog.dart' show showConfigPreview;
import 'package:pure_live/features/settings/danmaku_hold_provider.dart' show danmakuHoldProvider;
import 'package:pure_live/features/settings/danmaku_presets.dart' show DanmakuPreset;
import 'package:pure_live/features/settings/danmaku_show_gifts_provider.dart' show danmakuShowGiftsProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart';
import 'package:pure_live/features/settings/danmaku_templates.dart';
import 'package:pure_live/features/settings/floating_window_settings.dart' show floatingWindowSettingsProvider;
import 'package:pure_live/features/settings/font_manager_dialog.dart' show fontFamilyLabel, showFontManagerDialog;
import 'package:pure_live/features/settings/live_alert_settings.dart' show liveAlertSettingsProvider;
import 'package:pure_live/features/settings/live_alert_tags_dialog.dart' show showLiveAlertTagsDialog;
import 'package:pure_live/features/settings/loading_style_dialog.dart' show loadingStyleLabel, showLoadingStyleDialog;
import 'package:pure_live/features/settings/local_interaction_pane.dart' show LocalInteractionPane;
import 'package:pure_live/features/settings/page_size_options_dialog.dart' show showPageSizeOptionsDialog;
import 'package:pure_live/features/settings/pip_danmaku_scale_provider.dart'
    show kPipDanmakuScaleMax, kPipDanmakuScaleMin, pipDanmakuScaleProvider;
import 'package:pure_live/features/settings/platform_preferences_provider.dart'
    show douyuForceRenewProvider, preferH264Provider, youtubeAllChatProvider;
import 'package:pure_live/features/settings/playback_settings_providers.dart';
import 'package:pure_live/features/settings/player_kernel_pane.dart' show PlayerKernelAdvancedPane, PlayerKernelPane;
import 'package:pure_live/features/settings/portrait_fullscreen_settings.dart';
import 'package:pure_live/features/settings/portrait_settings_providers.dart'
    show
        PortraitFullscreenPolicy,
        PortraitLayoutMode,
        PortraitSettings,
        PortraitSettingsController,
        portraitSettingsProvider;
import 'package:pure_live/features/settings/prefer_platform_dialog.dart' show showPreferPlatformDialog;
import 'package:pure_live/features/settings/refresh_rate_section.dart' show RefreshRateSection;
import 'package:pure_live/features/settings/room_card_pane.dart' show RoomCardPane;
import 'package:pure_live/features/settings/room_switcher_settings.dart' show portraitSwipeSwitchProvider;
import 'package:pure_live/features/settings/settings_search.dart' show SettingsSearchHit, settingsSearchHits;
import 'package:pure_live/features/settings/settings_sections.dart';
import 'package:pure_live/features/settings/settings_widgets.dart' show SettingsChoiceRow, SettingsConfigRow;
import 'package:pure_live/features/settings/sites_display_provider.dart';
import 'package:pure_live/features/settings/super_chat_settings.dart' show superChatIncludesMembershipProvider;
import 'package:pure_live/features/settings/theme_color_dialog.dart' show showThemeColorDialog, themeSeedToneLabel;
import 'package:pure_live/features/settings/tv_preferences.dart' show tvFocusZoomProvider, tvMenuExpandedProvider;
import 'package:pure_live/features/settings/twitch_languages_dialog.dart'
    show showTwitchLanguagesDialog, twitchLanguagesSummary;
import 'package:pure_live/features/settings/twitch_languages_provider.dart' show twitchLanguagesProvider;
import 'package:pure_live/features/settings/window_size_row.dart' show WindowSizeRow;
import 'package:pure_live/features/shield/shield_pane.dart' show ShieldPane;
import 'package:pure_live/features/toolbox/toolbox_page.dart' show LogsPane, PlatformNodesPane;
import 'package:pure_live/features/version/version_controller.dart' show versionCheckProvider;
import 'package:pure_live/features/version/version_page.dart' show showReleaseHistory, showUpdatePanel;
import 'package:pure_live/features/vod/vod_settings_pane.dart' show VodSettingsPane;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart' show AppMark;
import 'package:pure_live/shared/enums/app_module.dart' show AppModule;
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;
import 'package:pure_live/shared/enums/tool_order.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteIcon, localizedSiteName;
import 'package:pure_live/shared/rooms/room_visibility.dart' show showUnplayableProvider;
import 'package:pure_live/shared/widgets/app_loading_indicator.dart' show AppLoadingIndicator;
import 'package:restart_app/restart_app.dart' show Restart, RestartMode;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The width below which the settings surface takes the pushed-menu layout.
const double kSettingsCompactWidth = 768;

/// Opens [section] from a category overview: desktop switches the pane in
/// place and keeps the sidebar; a touch shell pushes the page as its own
/// route, the same way the settings menu does.
void openSettingsChild(BuildContext context, WidgetRef ref, SettingsSection section) {
  ref.read(settingsSectionProvider.notifier).section = section;
  // Only the touch menu pushes a page. A desktop window keeps the sidebar
  // and switches its pane, however narrow the window is.
  final compact =
      !ref.read(deviceProfileProvider).isDesktop && MediaQuery.sizeOf(context).width < kSettingsCompactWidth;
  if (compact) {
    unawaited(context.push(SettingsSectionRoute(section: section.name).location));
  }
}

/// The settings surface. On a desktop window the shell's own sidebar lists
/// the categories — the same menu the module destinations live in, so
/// entering settings swaps the menu's entries rather than stacking a second
/// menu beside it — and this page is the selected category or its child
/// page. On a phone, where there is no sidebar, the page is the grouped
/// list whose entries push their category as its own route
/// ([SettingsSectionRoute]); the category's rows push its children.
///
/// Both read and write [settingsSectionProvider]: the sidebar and the list
/// agree on which page is on screen, and the pane is always that one.
final class SettingsPage extends ConsumerWidget {
  /// The settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < kSettingsCompactWidth;
    final desktop = ref.watch(deviceProfileProvider).isDesktop;
    if (compact && !desktop) return const _SettingsMenuList();
    final section = ref.watch(settingsSectionProvider);
    return _SettingsPaneWithSearch(section: section);
  }
}

/// The desktop pane with the search field over it: the sidebar itself is
/// the shell's, so the search that filters the sections lives at the top of
/// the pane — a query lists the matching sections, and picking one moves
/// the selection the sidebar and the pane share.
final class _SettingsPaneWithSearch extends ConsumerStatefulWidget {
  const _SettingsPaneWithSearch({required this.section});

  /// The section the sidebar selected.
  final SettingsSection section;

  @override
  ConsumerState<_SettingsPaneWithSearch> createState() => _SettingsPaneWithSearchState();
}

final class _SettingsPaneWithSearchState extends ConsumerState<_SettingsPaneWithSearch> {
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
    // search would trap them, and the section menu is the TV's way around.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    final query = _query.text.trim().toLowerCase();
    // The module's own sections, in the shared areas' order — the search
    // never offers a page this module does not carry.
    final groups = navigationOf(ref.watch(selectedModuleProvider)).settingsGroups;
    final results = query.isEmpty ? const <SettingsSection>[] : _matchingSections(t, query, groups);
    final hits = query.isEmpty
        ? const <SettingsSearchHit>[]
        : settingsSearchHits(t, query, settingsSearchSections(groups));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!tv)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s16, DsSpace.s24, 0),
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
              ? SettingsSectionPane(key: ValueKey(widget.section), section: widget.section)
              : _SectionSearchResults(
                  sections: results,
                  hits: hits,
                  onOpen: (section) {
                    _query.clear();
                    ref.read(settingsSectionProvider.notifier).section = section;
                    setState(() {});
                  },
                ),
        ),
      ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s16, DsSpace.s24, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    onPressed: () => onOpen(section),
                    trailing: const DsIcon(DsIcons.chevronRight),
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
                    onPressed: () => onOpen(hit.section),
                    trailing: const DsIcon(DsIcons.chevronRight),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The mobile menu: the same areas as full-width rows, each pushing its
/// section as a route — the phone's way into a submenu. The search field
/// filters the rows by their words.
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
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    // The areas are the shared grouping; the module's registry decides
    // which of their sections this module carries.
    final groups = navigationOf(ref.watch(selectedModuleProvider)).settingsGroups;
    final query = _query.trim().toLowerCase();
    bool matches(SettingsSection section) =>
        query.isEmpty ||
        section.label(t).toLowerCase().contains(query) ||
        section.description(t).toLowerCase().contains(query);
    final hits = query.isEmpty
        ? const <SettingsSearchHit>[]
        : settingsSearchHits(t, query, settingsSearchSections(groups));
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, 0),
        child: DsSearchField(
          placeholder: t.settings.searchSettings,
          semanticLabel: t.settings.searchSettings,
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
    ];
    var shown = 0;
    for (final group in groups) {
      final byGroup = settingsGroupLabel(t, group.labelKey).toLowerCase().contains(query);
      List<String> rowMatches(SettingsSection section) => [
        for (final hit in hits)
          if (hit.section == section) hit.title,
      ];
      // A search reaches the pages nested under each category too; the
      // plain menu keeps them out of the row list.
      final sections = [
        ...group.sections,
        if (query.isNotEmpty)
          for (final category in group.sections) ...settingsDescendantsOf(category),
      ];
      final kept = [
        for (final section in sections)
          if (byGroup || matches(section) || rowMatches(section).isNotEmpty) section,
      ];
      if (kept.isEmpty) continue;
      shown += kept.length;
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s16, DsSpace.s20, DsSpace.s4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              settingsGroupLabel(t, group.labelKey),
              style: theme.typography.overline.copyWith(color: colors.textSubtle),
            ),
          ),
        ),
      );
      for (final section in kept) {
        rows.add(
          DsListRow(
            leading: DsIcon(section.icon),
            title: Text(section.label(t)),
            description: Text(
              !byGroup && !matches(section) && rowMatches(section).isNotEmpty
                  ? t.settings.searchRowMatches(items: rowMatches(section).join(' · '))
                  : section.description(t),
            ),
            onPressed: () {
              // The pane the route pushes is the provider's section; keeping
              // it in step also carries the last visit over to a desktop
              // window the app may be resized into.
              ref.read(settingsSectionProvider.notifier).section = section;
              unawaited(context.push(SettingsSectionRoute(section: section.name).location));
            },
            trailing: const DsIcon(DsIcons.chevronRight),
          ),
        );
      }
    }
    if (shown == 0) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
          child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.settings.searchNoResults)),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: DsSpace.s24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

/// One section's content pane: the section's name as the pane's headline,
/// its description, then the section's own controls. Desktop shows it
/// beside the menu; the mobile route shows it alone.
final class SettingsSectionPane extends ConsumerWidget {
  /// The pane for [section].
  const SettingsSectionPane({required this.section, super.key});

  /// The section rendered here.
  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    // The group the current module puts this section in; a shared surface
    // can sit in different groups from one module to the next, and a
    // section the module does not carry has no overline.
    final groups = navigationOf(ref.watch(selectedModuleProvider)).settingsGroups;
    final groupKey = settingsGroupKeyOf(groups, section) ?? settingsGroupKeyOf(groups, section.menuSection);
    final groupLabel = groupKey == null ? null : settingsGroupLabel(t, groupKey);
    final body = switch (section) {
      SettingsSection.theme || SettingsSection.personalization || SettingsSection.appearance => const _ThemePane(),
      SettingsSection.typography => const _TypographyPane(),
      SettingsSection.background => const BackgroundOverviewPane(),
      SettingsSection.backgroundImages => const BackgroundLibraryPane(video: false),
      SettingsSection.backgroundRandom => const BackgroundRandomPane(),
      SettingsSection.backgroundVideos => const BackgroundLibraryPane(video: true),
      SettingsSection.backgroundColors => const BackgroundColorsPane(),
      SettingsSection.backgroundDevice => const BackgroundDevicePane(),
      SettingsSection.nav => const _NavPane(),
      SettingsSection.browsing || SettingsSection.general => const _BrowsingPane(),
      SettingsSection.roomCard => const RoomCardPane(),
      SettingsSection.sites || SettingsSection.live || SettingsSection.sources => const _SitesPane(),
      SettingsSection.accounts => const AccountPane(),
      SettingsSection.refresh => const _RefreshPane(),
      SettingsSection.followTags => const FollowTagsPane(),
      SettingsSection.danmaku || SettingsSection.danmakuStyle || SettingsSection.miniDanmaku => const _DanmakuPane(),
      SettingsSection.shield => const ShieldPane(),
      SettingsSection.localInteraction => const LocalInteractionPane(),
      SettingsSection.recording => const _RecordingPane(),
      SettingsSection.quality ||
      SettingsSection.playback ||
      SettingsSection.video ||
      SettingsSection.audio => const _QualityAudioPane(),
      SettingsSection.picture => const _PicturePane(),
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
      SettingsSection.vod => const VodSettingsPane(),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s20, DsSpace.s24, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          // The reference's area, above the page's own name. A category
          // whose group carries the same name (Live, IPTV) does not repeat
          // it as an overline. The parent category is carried by the
          // shell's location breadcrumb above the pane, not repeated here.
          if (groupLabel != null && groupLabel.isNotEmpty && groupLabel != section.label(t))
            Text(groupLabel, style: theme.typography.overline.copyWith(color: colors.textSubtle)),
          Text(section.label(t), style: theme.typography.display.copyWith(color: colors.text)),
          Text(section.description(t), style: theme.typography.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: DsSpace.s12),
          body,
        ],
      ),
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

/// The theme picker at the top of the theme page: a window drawn in the
/// current theme on the start side, the three theme modes as previews on
/// the end side. Picking a preview applies it at once, as Windows' theme
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

    final current = preview(settings.mode);
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 680;
                  final choices = Wrap(
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
                  );
                  final previewCard = _ThemeWindow(theme: current);
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DsSpace.s16,
                      children: [previewCard, choices],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s24,
                    children: [
                      Expanded(flex: 4, child: previewCard),
                      Expanded(flex: 5, child: choices),
                    ],
                  );
                },
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

/// The general pane: the browsing preferences that work end to end — how
/// wide a feed card gets where the module browses cards, how many rows a
/// page reveals, and the window's own title bar and close action. The
/// default site belongs to the live module and lives in its Sites pane.
/// The browsing page: feed cards, pagination and the audience metric.
final class _BrowsingPane extends ConsumerWidget {
  const _BrowsingPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final module = ref.watch(selectedModuleProvider);
    final showsCardExtent = module == AppModule.live || module == AppModule.vod;

    return DsListSection(
      header: Text(t.settings.browsingTitle),
      children: [
        if (showsCardExtent)
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.columns2),
            title: t.settings.cardExtent,
            description: t.settings.cardExtentDescription,
            detail: Text('${settings.homeCardExtent.round()} px'),
            controlWidth: 220,
            control: DsSlider(
              value: settings.homeCardExtent,
              min: 160,
              max: 420,
              divisions: 26,
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).homeCardExtent = value,
              semanticLabel: t.settings.cardExtent,
            ),
          ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.list),
          title: t.settings.pageSize,
          description: t.settings.pageSizeDescription,
          detail: Text('${settings.homePageSize}'),
          controlWidth: 220,
          control: DsSlider(
            value: settings.homePageSize.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (value) => ref.read(browseSettingsProvider.notifier).homePageSize = value.round(),
            semanticLabel: t.settings.pageSize,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.listRestart),
          title: Text(t.settings.pageSizeOptions),
          description: Text(t.settings.pageSizeOptionsDescription),
          detail: Text(ref.watch(pageSizeOptionsProvider).join(', ')),
          showChevron: true,
          onPressed: () => unawaited(showPageSizeOptionsDialog(context)),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.listOrdered),
          title: t.settings.pageSizeSelector,
          description: t.settings.pageSizeSelectorDescription,
          control: DsSwitch(
            value: ref.watch(showPageSizeSelectorProvider),
            onChanged: (value) => unawaited(ref.read(showPageSizeSelectorProvider.notifier).set(show: value)),
          ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.hash),
          title: t.settings.showGotoButton,
          description: t.settings.showGotoButtonDescription,
          control: DsSwitch(
            value: ref.watch(showGotoButtonProvider),
            onChanged: (value) => unawaited(ref.read(showGotoButtonProvider.notifier).set(show: value)),
          ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.aArrowUp),
          title: t.settings.showScrollToTop,
          description: t.settings.showScrollToTopDescription,
          control: DsSwitch(
            value: ref.watch(showScrollToTopProvider),
            onChanged: (value) => unawaited(ref.read(showScrollToTopProvider.notifier).set(show: value)),
          ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.clipboard),
          title: t.settings.clipboardRooms,
          description: t.settings.clipboardRoomsDesc,
          control: DsSwitch(
            value: ref.watch(detectClipboardRoomsProvider),
            onChanged: (value) => unawaited(ref.read(detectClipboardRoomsProvider.notifier).set(value: value)),
          ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.layoutGrid),
          title: t.settings.favoritesDense,
          description: t.settings.favoritesDenseDescription,
          control: DsSwitch(
            value: ref.watch(favoritesDensityProvider),
            onChanged: (value) => unawaited(ref.read(favoritesDensityProvider.notifier).set(dense: value)),
          ),
        ),
        const DsListSection(children: [SettingsChildEntry(child: SettingsSection.roomCard)]),
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
            if (WindowChromeState.configurable)
              SettingsChoiceRow<WindowChrome>(
                leading: const DsIcon(DsIcons.appWindow),
                title: t.settings.windowChrome,
                description: t.settings.windowChromeDesc,
                value: WindowChromeState.chrome,
                options: [
                  DsSelectOption(value: WindowChrome.system, label: t.settings.windowChromeSystem),
                  DsSelectOption(value: WindowChrome.custom, label: t.settings.windowChromeCustom),
                ],
                onChanged: (value) => unawaited(_setWindowChrome(context, value)),
              ),
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
              DsListRow(
                leading: const DsIcon(DsIcons.rocket),
                title: Text(t.settings.startup),
                description: Text(
                  startup.error.isEmpty ? t.settings.startupDesc : '${t.settings.startupFailed}: ${startup.error}',
                ),
                trailing: startup.loading
                    ? const SizedBox.square(dimension: 18, child: DsSpinner())
                    : DsSwitch(
                        value: startup.enabled,
                        onChanged: (value) => unawaited(ref.read(startupProvider.notifier).setEnabled(value: value)),
                      ),
              ),
            if (primary)
              DsListRow(
                leading: const DsIcon(DsIcons.playCircle),
                title: Text(t.settings.splashAnimation),
                description: Text(t.settings.splashAnimationDesc),
                trailing: DsSwitch(
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
                leading: const DsIcon(DsIcons.panelLeftClose),
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
                leading: const DsIcon(DsIcons.panelLeftClose),
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
            DsListRow(
              leading: const DsIcon(DsIcons.heart),
              title: Text(t.settings.followsAutoRefresh),
              description: Text(t.settings.followsAutoRefreshDesc),
              trailing: DsSwitch(
                value: autoRefresh.enabled,
                onChanged: (value) => unawaited(ref.read(followsAutoRefreshProvider.notifier).setEnabled(value: value)),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.settings.refreshOnResume),
              description: Text(t.settings.refreshOnResumeDesc),
              trailing: DsSwitch(
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
            DsListRow(
              leading: const DsIcon(DsIcons.bell),
              title: Text(t.settings.liveAlert),
              description: Text(t.settings.liveAlertDesc),
              trailing: DsSwitch(
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
              leading: const DsIcon(DsIcons.layers),
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
            DsListRow(
              leading: const DsIcon(DsIcons.image),
              title: Text(t.settings.refreshThumbnails),
              description: Text(t.settings.refreshThumbnailsDesc),
              trailing: DsSwitch(
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

/// The navigation pane (the reference's navigation-bar controls): the live
/// home menu's entries, their order and the multi-view entry, which the
/// desktop sidebar and the phone drawer and bottom bar all read; then the
/// shared tools block's order.
///
/// The four home entries persist as one visible order (`nav.menuIds`); the
/// reference's `savedMenuIds` works the same way. At least one stays shown.
final class _NavPane extends ConsumerWidget {
  const _NavPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final toolOrder = ref.watch(toolOrderProvider);
    final showMultiview = ref.watch(showMultiviewProvider);
    final homeMenus = ref.watch(navMenuProvider);
    final hiddenMenus = [
      for (final item in kHomeMenuItems)
        if (!homeMenus.contains(item)) item,
    ];
    final canReorder = homeMenus.length > 1;

    Widget menuSwitch(NavigationItem item, {required bool shown, bool draggable = false}) {
      return Row(
        key: ValueKey(item.name),
        children: [
          Expanded(
            child: DsSwitch(
              value: shown,
              onChanged: (value) async {
                final changed = await ref.read(navMenuProvider.notifier).setVisible(item, value: value);
                if (!changed && context.mounted) {
                  showDsToast(context: context, title: t.settings.navMenuKeepOne);
                }
              },
              label: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s6,
                children: [DsIcon(item.icon, size: 18), Text(item.label(t))],
              ),
              description: shown ? null : Text(t.settings.navMenuHidden),
            ),
          ),
          if (draggable) ...[const SizedBox(width: DsSpace.s8), const DsReorderableHandle()],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.navHomeMenuGroup),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.grid2x2),
              title: Text(t.settings.multiviewVisible),
              description: Text(t.settings.multiviewVisibleDesc),
              trailing: DsSwitch(
                value: showMultiview,
                onChanged: (value) => unawaited(ref.read(showMultiviewProvider.notifier).set(value: value)),
              ),
            ),
            // The visible entries in their saved order; the hidden ones
            // follow with no handle, as in the reference's page.
            DsReorderableList(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              defaultHandles: false,
              padding: EdgeInsets.zero,
              itemCount: homeMenus.length,
              onReorder: canReorder
                  ? (from, to) {
                      if (from < 0 || from >= homeMenus.length) return;
                      final target = to.clamp(0, homeMenus.length - 1);
                      if (from != target) unawaited(ref.read(navMenuProvider.notifier).move(from, target));
                    }
                  : null,
              itemBuilder: (context, index) => menuSwitch(homeMenus[index], shown: true, draggable: canReorder),
            ),
            for (final item in hiddenMenus) menuSwitch(item, shown: false),
          ],
        ),
        DsListSection(
          header: Text(t.settings.toolsOrder),
          children: [
            for (final (index, item) in toolOrder.indexed)
              DsListRow(
                leading: DsIcon(item.icon),
                title: Text(item.label(t)),
                trailing: Row(
                  spacing: DsSpace.s4,
                  children: [
                    _OrderButton(
                      icon: DsIcons.chevronUp,
                      label: t.settings.moveUp,
                      enabled: index > 0,
                      onPressed: () => unawaited(ref.read(toolOrderProvider.notifier).move(index, index - 1)),
                    ),
                    _OrderButton(
                      icon: DsIcons.chevronDown,
                      label: t.settings.moveDown,
                      enabled: index < toolOrder.length - 1,
                      onPressed: () => unawaited(ref.read(toolOrderProvider.notifier).move(index, index + 1)),
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

/// The title bar's owner is a creation-time choice: store it, ask about a
/// restart, and put the old value back when the viewer would rather not
/// restart now (so the row never shows a choice the window does not have).
Future<void> _setWindowChrome(BuildContext context, WindowChrome? value) async {
  if (value == null || value == WindowChromeState.chrome) {
    return;
  }
  await WindowChromeState.store(value);
  if (!context.mounted) {
    return;
  }
  final t = context.t;
  final restart = await showDsConfirm(
    context: context,
    title: t.settings.windowChromeRestartTitle,
    description: t.settings.windowChromeRestartDesc,
    confirmLabel: t.settings.windowChromeRestartNow,
    cancelLabel: t.common.cancel,
  );
  if (restart) {
    // The caption lives on the native window, so an engine-only restart keeps
    // the old frame and would draw the app strip under it. Replace the process.
    unawaited(Restart.restartApp(mode: RestartMode.process));
  } else {
    await WindowChromeState.store(WindowChromeState.chrome);
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

/// The theme page: the live theme preview at the top, then the palette and
/// the design system's own choices — contrast, selection style and the
/// clash rule are as much a setting as light/dark — plus the card spacing
/// and the app language. One labelled row per choice, the control inline
/// on a wide pane and under the label on a narrow one.
final class _ThemePane extends ConsumerWidget {
  const _ThemePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final scope = AppThemeScope.of(context);
    final localeScope = AppLocaleScope.of(context);
    final settings = scope.settings;
    final browse = ref.watch(browseSettingsProvider);
    String? seedName;
    for (final (name, seed) in kNamedSeeds) {
      if (seed == settings.seed) seedName = name;
    }
    final customSeed = scope.seedColor;
    final dynamicSeed = scope.dynamicSeedColor;
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
            SettingsChoiceRow<DsThemeMode>(
              leading: const DsIcon(DsIcons.sun),
              title: t.settings.themeMode,
              description: t.settings.appearanceDescription,
              value: settings.mode,
              options: [
                for (final mode in DsThemeMode.values) DsSelectOption(value: mode, label: themeModeLabel(t, mode)),
              ],
              onChanged: (mode) => update(settings.rebuild((b) => b..mode = mode)),
            ),
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
            DsListRow(
              leading: const DsIcon(DsIcons.moon),
              title: Text(t.settings.pureBlack),
              // The reference greys the switch in light mode and says why in
              // the description instead of hiding a choice that cannot apply.
              description: Text(
                settings.mode == DsThemeMode.light ? t.settings.pureBlackLightReason : t.settings.pureBlackDescription,
              ),
              trailing: DsSwitch(
                value: ref.watch(pureBlackThemeProvider),
                onChanged: settings.mode == DsThemeMode.light
                    ? null
                    : (value) => unawaited(ref.read(pureBlackThemeProvider.notifier).set(value: value)),
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
            DsListRow(
              // A still frame: the gallery plays the styles; a settings visit
              // should not keep an animation running.
              leading: const TickerMode(
                enabled: false,
                child: SizedBox.square(dimension: 22, child: AppLoadingIndicator(size: 22)),
              ),
              title: Text(t.settings.loadingStyle),
              description: Text(t.settings.loadingStyleDescription),
              detail: Text(loadingStyleLabel(t, ref.watch(loadingStyleProvider))),
              showChevron: true,
              onPressed: () => unawaited(showLoadingStyleDialog(context)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.contrast),
              title: t.settings.contrast,
              description: t.settings.contrastDescription,
              control: DsSegmentedControl<DsContrast>(
                value: settings.contrast,
                onChanged: (value) => update(settings.rebuild((b) => b..contrast = value)),
                segments: [
                  DsSegment(value: DsContrast.soft, label: Text(t.settings.contrastSoft)),
                  DsSegment(value: DsContrast.standard, label: Text(t.settings.contrastStandard)),
                ],
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.ellipseSelection),
              title: t.settings.selectionStyle,
              description: t.settings.selectionDescription,
              control: DsSegmentedControl<DsSelectionStyle>(
                value: settings.selectionStyle,
                onChanged: (value) => update(settings.rebuild((b) => b..selectionStyle = value)),
                segments: [
                  DsSegment(value: DsSelectionStyle.soft, label: Text(t.settings.selectionSoft)),
                  DsSegment(value: DsSelectionStyle.strong, label: Text(t.settings.selectionStrong)),
                ],
              ),
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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.cornerDownRight),
              title: t.settings.corners,
              controlWidth: 320,
              control: DsSegmentedControl<DsCornerStyle>(
                value: settings.cornerStyle,
                onChanged: (value) => update(settings.rebuild((b) => b..cornerStyle = value)),
                segments: [
                  DsSegment(value: DsCornerStyle.sharp, label: Text(t.settings.cornersSharp)),
                  DsSegment(value: DsCornerStyle.standard, label: Text(t.settings.cornersStandard)),
                  DsSegment(value: DsCornerStyle.soft, label: Text(t.settings.cornersSoft)),
                  DsSegment(value: DsCornerStyle.pill, label: Text(t.settings.cornersPill)),
                ],
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.rows3),
              title: t.settings.density,
              controlWidth: 260,
              control: DsSegmentedControl<String>(
                value: settings.density?.name ?? '',
                onChanged: (value) {
                  final density = switch (value) {
                    'compact' => DsDensity.compact,
                    'touch' => DsDensity.touch,
                    _ => null,
                  };
                  update(settings.rebuild((b) => b..density = density));
                },
                segments: [
                  DsSegment(value: '', label: Text(t.settings.densitySystem)),
                  DsSegment(value: 'compact', label: Text(t.settings.densityCompact)),
                  DsSegment(value: 'touch', label: Text(t.settings.densityTouch)),
                ],
              ),
            ),
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
        DsListSection(
          header: Text(t.settings.groupCards),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.columns2),
              title: t.settings.crossSpacing,
              description: t.settings.crossSpacingDescription,
              detail: Text('${browse.crossSpacing.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: browse.crossSpacing,
                max: kBrowseSpacingMax,
                divisions: kBrowseSpacingMax.round(),
                onChanged: (value) => ref.read(browseSettingsProvider.notifier).crossSpacing = value,
                semanticLabel: t.settings.crossSpacing,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.rows3),
              title: t.settings.mainSpacing,
              description: t.settings.mainSpacingDescription,
              detail: Text('${browse.mainSpacing.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: browse.mainSpacing,
                max: kBrowseSpacingMax,
                divisions: kBrowseSpacingMax.round(),
                onChanged: (value) => ref.read(browseSettingsProvider.notifier).mainSpacing = value,
                semanticLabel: t.settings.mainSpacing,
              ),
            ),
          ],
        ),
        DsListSection(
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.layoutGrid),
              title: Text(t.settings.pageSettingsEntry),
              description: Text(t.settings.browsingPageDescription),
              showChevron: true,
              onPressed: () => openSettingsChild(context, ref, SettingsSection.browsing),
            ),
          ],
        ),
      ],
    );
  }
}

/// The typography page: the typeface manager, the text scale and the five
/// named type sizes.
final class _TypographyPane extends ConsumerWidget {
  const _TypographyPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = AppThemeScope.of(context).settings;
    final textScale = ref.watch(textScaleFactorProvider);
    final fontSizes = ref.watch(appFontSizesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.groupType),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.type),
              title: Text(t.settings.font),
              description: Text(t.settings.fontDescription),
              detail: Text(
                settings.fontFamily == null
                    ? platformFontFamilyLabel()
                    : fontFamilyLabel(
                        t,
                        settings.fontFamily,
                        cloudName: ref.read(fontLibraryProvider).nameOf(settings.fontFamily!),
                      ),
              ),
              showChevron: true,
              onPressed: () => unawaited(showFontManagerDialog(context)),
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
                divisions: 30,
                onChanged: (value) => ref.read(textScaleFactorProvider.notifier).factor = value,
                semanticLabel: t.settings.textScale,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                child: Text(
                  t.settings.textScalePreview,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DsTheme.colorsOf(context).textMuted),
                ),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.fontBodyGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.fontSize),
              title: t.settings.fontBodySmall,
              description: t.settings.fontBodySmallDescription,
              detail: Text('${fontSizes.bodySmall.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: fontSizes.bodySmall,
                min: kMinFontSizeBodySmall,
                max: kMaxFontSizeBodySmall,
                divisions: (kMaxFontSizeBodySmall - kMinFontSizeBodySmall).round(),
                onChanged: (value) => ref.read(appFontSizesProvider.notifier).bodySmall = value,
                semanticLabel: t.settings.fontBodySmall,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.type),
              title: t.settings.fontBodyMedium,
              description: t.settings.fontBodyMediumDescription,
              detail: Text('${fontSizes.bodyMedium.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: fontSizes.bodyMedium,
                min: kMinFontSizeBodyMedium,
                max: kMaxFontSizeBodyMedium,
                divisions: (kMaxFontSizeBodyMedium - kMinFontSizeBodyMedium).round(),
                onChanged: (value) => ref.read(appFontSizesProvider.notifier).bodyMedium = value,
                semanticLabel: t.settings.fontBodyMedium,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.aArrowUp),
              title: t.settings.fontBodyLarge,
              description: t.settings.fontBodyLargeDescription,
              detail: Text('${fontSizes.bodyLarge.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: fontSizes.bodyLarge,
                min: kMinFontSizeBodyLarge,
                max: kMaxFontSizeBodyLarge,
                divisions: (kMaxFontSizeBodyLarge - kMinFontSizeBodyLarge).round(),
                onChanged: (value) => ref.read(appFontSizesProvider.notifier).bodyLarge = value,
                semanticLabel: t.settings.fontBodyLarge,
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.fontTitleGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.heading),
              title: t.settings.fontTitleMedium,
              description: t.settings.fontTitleMediumDescription,
              detail: Text('${fontSizes.titleMedium.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: fontSizes.titleMedium,
                min: kMinFontSizeTitleMedium,
                max: kMaxFontSizeTitleMedium,
                divisions: (kMaxFontSizeTitleMedium - kMinFontSizeTitleMedium).round(),
                onChanged: (value) => ref.read(appFontSizesProvider.notifier).titleMedium = value,
                semanticLabel: t.settings.fontTitleMedium,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.heading1),
              title: t.settings.fontTitleLarge,
              description: t.settings.fontTitleLargeDescription,
              detail: Text('${fontSizes.titleLarge.round()} px'),
              controlWidth: 220,
              control: DsSlider(
                value: fontSizes.titleLarge,
                min: kMinFontSizeTitleLarge,
                max: kMaxFontSizeTitleLarge,
                divisions: (kMaxFontSizeTitleLarge - kMinFontSizeTitleLarge).round(),
                onChanged: (value) => ref.read(appFontSizesProvider.notifier).titleLarge = value,
                semanticLabel: t.settings.fontTitleLarge,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.proxy),
          children: [
            DsSwitch(
              value: proxy.enabled,
              onChanged: (value) => unawaited(controller.setEnabled(value: value)),
              label: Text(t.settings.proxy),
              description: Text(t.settings.proxyDesc),
            ),
            if (proxy.enabled) ...[
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.server),
                title: t.settings.proxyHost,
                controlWidth: 260,
                control: DsTextField(
                  initialValue: proxy.host,
                  clearable: true,
                  placeholder: t.settings.proxyHost,
                  onChanged: (value) => unawaited(controller.setHost(value)),
                  semanticLabel: t.settings.proxyHost,
                ),
              ),
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.hash),
                title: t.settings.proxyPort,
                controlWidth: 160,
                control: DsTextField(
                  initialValue: '${proxy.port}',
                  placeholder: t.settings.proxyPort,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final port = int.tryParse(value.trim());
                    if (port != null) unawaited(controller.setPort(port));
                  },
                  semanticLabel: t.settings.proxyPort,
                ),
              ),
            ],
          ],
        ),
        const DsListSection(children: [SettingsChildEntry(child: SettingsSection.nodes)]),
      ],
    );
  }
}

/// One of the reorder buttons at a row's end: dimmed at its boundary.
final class _OrderButton extends StatelessWidget {
  const _OrderButton({required this.icon, required this.label, required this.enabled, required this.onPressed});

  final DsIconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: enabled ? onPressed : null,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 26,
          height: 26,
          decoration: DsBoxDecoration(
            color: hovered && enabled ? colors.hover : colors.control,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: DsIcon(icon, size: 14, color: enabled ? colors.textMuted : colors.textSubtle)),
        );
      },
    );
  }
}

/// The danmaku page: the flying layer's display switch, its look and
/// motion, the compact window's own danmaku switch (the look is shared, so
/// the two can never drift) and the entry to the shield's lists.
final class _DanmakuPane extends ConsumerWidget {
  const _DanmakuPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    final frameRate = ref.watch(danmakuFrameRateProvider);
    final frameRateController = ref.read(danmakuFrameRateProvider.notifier);
    final effectiveFps = ref.watch(danmakuEffectiveFpsProvider);
    final activePreset = DanmakuPreset.matching(style, frameRate);
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final playback = ref.watch(playbackSettingsProvider);
    final tapInteraction = ref.watch(danmakuTapInteractionProvider);
    final longPressInteraction = ref.watch(danmakuLongPressInteractionProvider);
    final pipScale = ref.watch(pipDanmakuScaleProvider);
    final pipScaleController = ref.read(pipDanmakuScaleProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.danmakuTemplatesGroup),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s8,
                children: [
                  DsChoiceChips<DanmakuPreset?>(
                    value: activePreset,
                    semanticLabel: t.settings.danmakuTemplatesGroup,
                    onChanged: (preset) {
                      if (preset != null) unawaited(_applyPreset(context, ref, preset));
                    },
                    options: [
                      for (final preset in DanmakuPreset.values)
                        DsChipOption(value: preset, label: Text(_presetLabel(t, preset))),
                    ],
                  ),
                  Text(t.settings.danmakuPresetHint, style: theme.typography.small.copyWith(color: colors.textSubtle)),
                ],
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.bookmarkPlus),
              title: Text(t.settings.danmakuTemplateSaveMine),
              onPressed: () => unawaited(_saveTemplate(context, ref)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCcw),
              title: Text(t.settings.danmakuTemplateUseMine),
              onPressed: () => unawaited(_restoreTemplate(context, ref)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.danmakuDisplayGroup),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.captions),
              title: Text(t.settings.showFlyingDanmaku),
              description: Text(t.settings.showFlyingDanmakuDesc),
              trailing: DsSwitch(
                value: playback.danmakuVisible,
                onChanged: (value) =>
                    unawaited(ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: value)),
              ),
            ),
            SettingsChoiceRow<DanmakuPausedBehavior>(
              leading: const DsIcon(DsIcons.pause),
              title: t.settings.danmakuPausedBehavior,
              description: t.settings.danmakuPausedBehaviorDesc,
              value: ref.watch(danmakuPausedBehaviorProvider),
              options: [
                DsSelectOption(value: DanmakuPausedBehavior.pause, label: t.settings.danmakuPausedPause),
                DsSelectOption(value: DanmakuPausedBehavior.fly, label: t.settings.danmakuPausedFly),
              ],
              onChanged: (value) => unawaited(ref.read(danmakuPausedBehaviorProvider.notifier).set(value)),
            ),
            DsSwitch(
              value: ref.watch(danmakuShowGiftsProvider),
              onChanged: (value) => unawaited(ref.read(danmakuShowGiftsProvider.notifier).set(value: value)),
              label: Text(t.settings.danmakuShowGifts),
              description: Text(t.settings.danmakuShowGiftsDesc),
            ),
            DsSwitch(
              value: ref.watch(chatNamesProvider),
              onChanged: (value) => unawaited(ref.read(chatNamesProvider.notifier).set(value: value)),
              label: Text(t.settings.chatShowNames),
              description: Text(t.settings.chatShowNamesDesc),
            ),
            DsSwitch(
              value: ref.watch(chatShowGiftsProvider),
              onChanged: (value) => unawaited(ref.read(chatShowGiftsProvider.notifier).set(value: value)),
              label: Text(t.settings.chatShowGifts),
              description: Text(t.settings.chatShowGiftsDesc),
            ),
            DsSwitch(
              value: ref.watch(chatGiftsAboveTierProvider),
              onChanged: ref.watch(chatShowGiftsProvider)
                  ? (value) => unawaited(ref.read(chatGiftsAboveTierProvider.notifier).set(value: value))
                  : null,
              label: Text(t.settings.chatGiftsAboveTier),
              description: Text(t.settings.chatGiftsAboveTierDesc),
            ),
            DsSwitch(
              value: ref.watch(chatGiftValueInYuanProvider),
              onChanged: ref.watch(chatShowGiftsProvider)
                  ? (value) => unawaited(ref.read(chatGiftValueInYuanProvider.notifier).set(value: value))
                  : null,
              label: Text(t.settings.chatGiftValueInYuan),
              description: Text(t.settings.chatGiftValueInYuanDesc),
            ),
            DsSwitch(
              value: ref.watch(superChatIncludesMembershipProvider),
              onChanged: (value) => unawaited(ref.read(superChatIncludesMembershipProvider.notifier).set(value: value)),
              label: Text(t.settings.superChatIncludesMembership),
              description: Text(t.settings.superChatIncludesMembershipDesc),
            ),
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.list),
              title: t.settings.chatListStyle,
              value: ref.watch(chatListStyleProvider),
              options: [
                DsSelectOption(value: 'compact', label: t.settings.chatListStyleCompact),
                DsSelectOption(value: 'card', label: t.settings.chatListStyleCard),
              ],
              onChanged: (value) => unawaited(ref.read(chatListStyleProvider.notifier).set(value)),
            ),
            SettingsChoiceRow<int>(
              leading: const DsIcon(DsIcons.type),
              title: t.settings.chatListFontSize,
              value: ref.watch(chatListFontSizeProvider),
              options: [
                DsSelectOption(value: 0, label: t.settings.chatListFollowTheme),
                for (final size in const [12, 14, 16, 18, 20, 22])
                  DsSelectOption(
                    value: size,
                    label: t.settings.chatListFontSizeValue(size: size),
                  ),
              ],
              onChanged: (value) => unawaited(ref.read(chatListFontSizeProvider.notifier).set(value)),
            ),
            SettingsChoiceRow<String>(
              leading: const DsIcon(DsIcons.moveVertical),
              title: t.settings.chatListLineSpacing,
              value: ref.watch(chatListLineSpacingProvider),
              options: [
                DsSelectOption(value: 'compact', label: t.settings.chatListSpacingCompact),
                DsSelectOption(value: 'standard', label: t.settings.chatListSpacingStandard),
                DsSelectOption(value: 'loose', label: t.settings.chatListSpacingLoose),
              ],
              onChanged: (value) => unawaited(ref.read(chatListLineSpacingProvider.notifier).set(value)),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.danmakuInteractionGroup),
          children: [
            DsSwitch(
              value: tapInteraction,
              onChanged: (value) => unawaited(ref.read(danmakuTapInteractionProvider.notifier).set(value: value)),
              label: Text(t.settings.styleTapInteraction),
              description: Text(t.settings.styleTapInteractionDesc),
            ),
            DsSwitch(
              value: longPressInteraction,
              onChanged: (value) => unawaited(ref.read(danmakuLongPressInteractionProvider.notifier).set(value: value)),
              label: Text(t.settings.styleLongPressInteraction),
              description: Text(t.settings.styleLongPressInteractionDesc),
            ),
            DsSwitch(
              value: ref.watch(danmakuHoldProvider),
              onChanged: (value) => unawaited(ref.read(danmakuHoldProvider.notifier).set(value: value)),
              label: Text(t.settings.holdDanmakuOnPress),
              description: Text(t.settings.holdDanmakuOnPressDesc),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.settings.danmakuStyleGroup),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.type),
              title: Text(t.settings.danmakuFont),
              description: Text(t.settings.danmakuFontDescription),
              detail: Text(
                style.fontFamily == null
                    ? platformFontFamilyLabel()
                    : fontFamilyLabel(
                        t,
                        style.fontFamily,
                        cloudName: ref.read(fontLibraryProvider).nameOf(style.fontFamily!),
                      ),
              ),
              showChevron: true,
              onPressed: () => unawaited(showFontManagerDialog(context, danmaku: true)),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.type),
              title: t.settings.styleFontSize,
              detail: Text('${style.fontSize.toStringAsFixed(1)} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.fontSize,
                min: DanmakuStyleRange.fontSizeMin,
                max: DanmakuStyleRange.fontSizeMax,
                onChanged: (value) => unawaited(controller.setFontSize(value)),
                semanticLabel: t.settings.styleFontSize,
                semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.bold),
              title: t.settings.styleFontWeight,
              detail: Text(danmakuFontWeightLabel(t, style.fontWeight)),
              controlWidth: 220,
              control: DsSlider(
                value: style.fontWeight.toDouble(),
                min: DanmakuStyleRange.fontWeightMin.toDouble(),
                max: DanmakuStyleRange.fontWeightMax.toDouble(),
                divisions: DanmakuStyleRange.fontWeightDivisions,
                onChanged: (value) => unawaited(controller.setFontWeight(value.round())),
                semanticLabel: t.settings.styleFontWeight,
                semanticFormatter: (value) => danmakuFontWeightLabel(t, value.round()),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.letterSpacing),
              title: t.settings.styleLetterSpacing,
              detail: Text('${style.letterSpacing.toStringAsFixed(1)} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.letterSpacing,
                min: DanmakuStyleRange.letterSpacingMin,
                max: DanmakuStyleRange.letterSpacingMax,
                onChanged: (value) => unawaited(controller.setLetterSpacing(value)),
                semanticLabel: t.settings.styleLetterSpacing,
                semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.wind),
              title: t.settings.styleSpeed,
              detail: Text('${style.baseSpeed.round()} px/s'),
              controlWidth: 220,
              control: DsSlider(
                value: style.baseSpeed,
                min: DanmakuStyleRange.speedMin,
                max: DanmakuStyleRange.speedMax,
                onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
                semanticLabel: t.settings.styleSpeed,
                semanticFormatter: (value) => '${value.round()} px/s',
              ),
            ),
            DsSwitch(
              value: style.noEmoji,
              onChanged: (value) => unawaited(controller.setNoEmoji(value: value)),
              label: Text(t.settings.styleNoEmoji),
              description: Text(t.settings.styleNoEmojiDesc),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.moveVertical),
              title: t.settings.styleArea,
              description: t.settings.styleAreaDesc,
              detail: Text('${(style.area * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: style.area,
                divisions: DanmakuStyleRange.areaDivisions,
                onChanged: (value) => unawaited(controller.setArea(value)),
                semanticLabel: t.settings.styleArea,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowUpToLine),
              title: t.settings.styleTopMargin,
              description: t.settings.styleTopMarginDesc,
              detail: Text('${style.topMargin.round()}'),
              control: DsNumberField(
                value: style.topMargin.round(),
                min: DanmakuStyleRange.topMarginMin,
                max: DanmakuStyleRange.topMarginMax,
                semanticLabel: t.settings.styleTopMargin,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setTopMargin(value));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.arrowDownToLine),
              title: t.settings.styleBottomMargin,
              description: t.settings.styleBottomMarginDesc,
              detail: Text('${style.bottomMargin.round()}'),
              control: DsNumberField(
                value: style.bottomMargin.round(),
                min: DanmakuStyleRange.bottomMarginMin,
                max: DanmakuStyleRange.bottomMarginMax,
                semanticLabel: t.settings.styleBottomMargin,
                onChanged: (value) {
                  if (value != null) unawaited(controller.setBottomMargin(value));
                },
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.circle),
              title: t.settings.styleOpacity,
              detail: Text('${(style.opacity * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: style.opacity,
                // The reference's 0–1 range is the slider's own default:
                // transparent through fully opaque.
                onChanged: (value) => unawaited(controller.setOpacity(value)),
                semanticLabel: t.settings.styleOpacity,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.baseline),
              title: t.settings.styleStroke,
              description: t.settings.styleStrokeDesc,
              control: DsSwitch(
                value: style.showStroke,
                onChanged: (value) => unawaited(controller.setShowStroke(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.square),
              title: t.settings.styleStrokeWidth,
              description: t.settings.styleStrokeWidthDesc,
              detail: Text('${style.strokeWidth.toStringAsFixed(1)} px'),
              controlWidth: 220,
              control: DsSlider(
                value: style.strokeWidth,
                max: DanmakuStyleRange.strokeWidthMax,
                // Greyed out while the outline is off, as in the reference;
                // the stored width survives for when it is switched back on.
                onChanged: style.showStroke ? (value) => unawaited(controller.setStrokeWidth(value)) : null,
                semanticLabel: t.settings.styleStrokeWidth,
                semanticFormatter: (value) => '${value.toStringAsFixed(1)} px',
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.layers),
              title: t.settings.styleFpsFollow,
              description: t.settings.styleFpsFollowDesc,
              control: DsSwitch(
                value: frameRate.autoFps,
                onChanged: (value) => unawaited(frameRateController.setAutoFps(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.gauge),
              title: t.settings.styleFps,
              detail: Text(t.settings.styleFpsValue(count: '${frameRate.autoFps ? effectiveFps : frameRate.fps}')),
              controlWidth: 220,
              control: DsSlider(
                value: (frameRate.autoFps ? effectiveFps : frameRate.fps).toDouble(),
                min: DanmakuStyleRange.fpsMin.toDouble(),
                max: DanmakuStyleRange.fpsMax.toDouble(),
                divisions: DanmakuStyleRange.fpsDivisions,
                onChanged: frameRate.autoFps ? null : (value) => unawaited(frameRateController.setFps(value.round())),
                semanticLabel: t.settings.styleFps,
                semanticFormatter: (value) => t.settings.styleFpsValue(count: '${value.round()}'),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.layers),
              title: t.settings.styleMaxVisible,
              description: t.settings.styleMaxVisibleDesc,
              detail: Text(t.settings.styleMaxVisibleValue(count: '${style.maxVisibleCount}')),
              controlWidth: 220,
              control: DsSlider(
                value: style.maxVisibleCount.toDouble(),
                min: DanmakuStyleRange.maxVisibleMin.toDouble(),
                max: DanmakuStyleRange.maxVisibleMax.toDouble(),
                divisions: DanmakuStyleRange.maxVisibleDivisions,
                onChanged: style.massMode ? null : (value) => unawaited(controller.setMaxVisibleCount(value.round())),
                semanticLabel: t.settings.styleMaxVisible,
                semanticFormatter: (value) => t.settings.styleMaxVisibleValue(count: '${value.round()}'),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.flame),
              title: t.settings.styleMassMode,
              description: t.settings.styleMassModeDesc,
              control: DsSwitch(
                value: style.massMode,
                onChanged: (value) => unawaited(controller.setMassMode(value: value)),
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.appWindow),
              title: t.settings.pipDanmakuScaleAuto,
              description: t.settings.pipDanmakuScaleAutoDesc,
              control: DsSwitch(
                value: pipScale.auto,
                onChanged: (value) => unawaited(pipScaleController.setAuto(value: value)),
              ),
            ),
            if (!pipScale.auto)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.scale),
                title: t.settings.pipDanmakuScale,
                detail: Text('x${pipScale.scale.toStringAsFixed(2)}'),
                controlWidth: 220,
                control: DsSlider(
                  value: pipScale.scale,
                  min: kPipDanmakuScaleMin,
                  divisions: ((kPipDanmakuScaleMax - kPipDanmakuScaleMin) / 0.01).round(),
                  onChanged: (value) => unawaited(pipScaleController.setScale(value)),
                  semanticLabel: t.settings.pipDanmakuScale,
                  semanticFormatter: (value) => 'x${value.toStringAsFixed(2)}',
                ),
              ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCw),
              title: Text(t.settings.styleReset),
              onPressed: () {
                unawaited(controller.reset());
                unawaited(frameRateController.reset());
                unawaited(ref.read(danmakuTapInteractionProvider.notifier).reset());
                unawaited(ref.read(danmakuLongPressInteractionProvider.notifier).reset());
                unawaited(pipScaleController.reset());
              },
            ),
          ],
        ),
        const _MiniDanmakuPane(),
        const DsListSection(children: [SettingsChildEntry(child: SettingsSection.shield)]),
      ],
    );
  }

  String _presetLabel(Translations t, DanmakuPreset preset) => switch (preset) {
    DanmakuPreset.best => t.settings.danmakuPresetBest,
    DanmakuPreset.comfort => t.settings.danmakuPresetComfort,
    DanmakuPreset.dense => t.settings.danmakuPresetDense,
    DanmakuPreset.full => t.settings.danmakuPresetFull,
  };

  Future<void> _applyPreset(BuildContext context, WidgetRef ref, DanmakuPreset preset) async {
    await preset.apply(
      style: ref.read(danmakuStyleProvider.notifier),
      frameRate: ref.read(danmakuFrameRateProvider.notifier),
      noEmoji: ref.read(danmakuStyleProvider).noEmoji,
      fps: ref.read(danmakuFrameRateProvider).fps,
    );
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.settings.danmakuTemplateApplied);
  }

  Future<void> _saveTemplate(BuildContext context, WidgetRef ref) async {
    final template = DanmakuTemplate.of(ref.read(danmakuStyleProvider), ref.read(danmakuFrameRateProvider));
    await writeSavedDanmakuTemplate(template.encode());
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.settings.danmakuTemplateSaved);
  }

  Future<void> _restoreTemplate(BuildContext context, WidgetRef ref) async {
    final raw = readSavedDanmakuTemplate();
    if (raw == null) {
      showDsToast(context: context, title: context.t.settings.danmakuTemplateEmpty);
      return;
    }
    final fallback = DanmakuTemplate.of(ref.read(danmakuStyleProvider), ref.read(danmakuFrameRateProvider));
    final template = DanmakuTemplate.tryDecode(raw, fallback);
    if (template == null) {
      showDsToast(context: context, title: context.t.settings.danmakuTemplateInvalid);
      return;
    }
    await applyDanmakuTemplate(
      template,
      style: ref.read(danmakuStyleProvider.notifier),
      frameRate: ref.read(danmakuFrameRateProvider.notifier),
    );
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.settings.danmakuTemplateApplied);
  }
}

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
    final selectedId = ref.watch(selectedSiteIdProvider);
    final selectedSite = sites.where((site) => site.manifest.id == selectedId).firstOrNull;
    final hidden = ref.watch(sitesDisplayProvider);
    final display = ref.read(sitesDisplayProvider.notifier);
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
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        if (ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv) ...[
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
        DsListSection(
          header: Text(t.settings.sitesDisplay),
          children: [
            SettingsChoiceRow<String>(
              leading: localizedSiteIcon(selectedSite, size: 20) ?? const DsIcon(DsIcons.tv),
              title: t.settings.site,
              value: selectedId,
              options: [
                for (final site in sites)
                  DsSelectOption(
                    value: site.manifest.id,
                    label: localizedSiteName(site),
                    leading: localizedSiteIcon(site, size: 20),
                  ),
              ],
              placeholder: t.settings.site,
              onChanged: (id) => ref.read(selectedSiteIdProvider.notifier).selected = id,
            ),
            if (hidden.isEmpty)
              DsListRow(leading: const DsIcon(DsIcons.antenna), title: Text(t.settings.sitesAllShown)),
            // The rows are the display order itself: a drag (or Alt+arrow
            // on a focused row) moves a platform, and the provider keeps
            // the new order for the browsing pages.
            DsReorderableList(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.order.length,
              itemBuilder: (context, index) {
                final id = order.order[index];
                return DsSwitch(
                  key: ValueKey(id),
                  value: shown(id),
                  onChanged: (value) async {
                    final changed = await display.toggle(id);
                    if (!changed && context.mounted) {
                      showDsToast(context: context, title: t.settings.sitesKeepOne);
                    }
                  },
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [?localizedSiteIcon(sitesById[id], size: 18), Text(name(id))],
                  ),
                  description: Text(id),
                );
              },
              onReorder: (from, to) => unawaited(orderController.move(from, to)),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.pin),
              title: Text(t.settings.preferPlatform),
              description: Text(t.settings.preferPlatformDesc),
              detail: Text(order.preferred.isEmpty ? t.settings.preferPlatform : name(order.preferred)),
              showChevron: true,
              onPressed: () => unawaited(pickPreferred()),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.listRestart),
              title: Text(t.settings.sitesOrderReset),
              description: Text(t.settings.sitesOrderResetDesc),
              onPressed: () => unawaited(orderController.resetOrder()),
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
        const DsListSection(children: [SettingsChildEntry(child: SettingsSection.accounts)]),
      ],
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
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
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
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: _busy ? null : () => unawaited(_clear()),
            child: Text(t.settings.cacheClear),
          ),
        ),
        SettingsChoiceRow<int>(
          leading: const DsIcon(DsIcons.settings),
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
          description: Text(t.settings.downloadDirectoryDesc),
          detail: Text(download.custom.isEmpty ? t.settings.downloadDirectoryDefaultLabel : download.custom),
          onPressed: _busy ? null : () => unawaited(_pickDownloadDirectory()),
        ),
        if (download.custom.isNotEmpty)
          DsListRow(
            leading: const DsIcon(DsIcons.rotateCcw),
            title: Text(t.settings.downloadDirectoryReset),
            onPressed: _busy ? null : () => unawaited(_resetDownloadDirectory()),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s16),
          child: Text(t.settings.cacheHint, style: theme.typography.caption.copyWith(color: colors.textMuted)),
        ),
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
          leading: const DsIcon(DsIcons.refreshCw),
          title: Text(t.settings.checkUpdate),
          description: Text(status),
          trailing: latest != null
              ? DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(showUpdatePanel(context, latest)),
                  child: Text(t.settings.viewUpdate),
                )
              : DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: check.checking ? null : () => unawaited(ref.read(versionCheckProvider.notifier).check()),
                  child: Text(t.settings.checkUpdate),
                ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.refreshCw),
          title: Text(t.settings.autoCheckUpdate),
          description: Text(t.settings.autoCheckUpdateDesc),
          trailing: DsSwitch(
            value: ref.watch(updateSettingsProvider),
            onChanged: (value) => ref.read(updateSettingsProvider.notifier).enabled = value,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.list),
          title: Text(t.settings.releaseHistory),
          description: Text(t.settings.releaseHistoryDesc),
          onPressed: () => unawaited(showReleaseHistory(context)),
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
          leading: const DsIcon(DsIcons.scale),
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
            DsListRow(
              leading: const DsIcon(DsIcons.volumeOff),
              title: Text(t.settings.defaultMuted),
              description: Text(t.settings.defaultMutedDesc),
              trailing: DsSwitch(
                value: settings.muted,
                onChanged: (value) => unawaited(controller.setMuted(value: value)),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.volumeX),
              title: Text(t.settings.globalMute),
              description: Text(t.settings.globalMuteDesc),
              trailing: DsSwitch(
                value: settings.globalMute,
                onChanged: (value) => unawaited(controller.setGlobalMute(value: value)),
              ),
            ),
            if (ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.android) ...[
              DsListRow(
                leading: const DsIcon(DsIcons.music),
                title: Text(t.settings.backgroundPlay),
                description: Text(t.settings.backgroundPlayDesc),
                trailing: DsSwitch(
                  value: settings.backgroundPlay,
                  onChanged: (value) => unawaited(controller.setBackgroundPlay(value: value)),
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.captions),
                title: Text(t.settings.backgroundPauseDanmaku),
                description: Text(t.settings.backgroundPauseDanmakuDesc),
                trailing: DsSwitch(
                  value: settings.backgroundPauseDanmaku,
                  onChanged: (value) => unawaited(controller.setBackgroundPauseDanmaku(value: value)),
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.headphones),
                title: Text(t.settings.backgroundAudioOnly),
                description: Text(t.settings.backgroundAudioOnlyDesc),
                trailing: DsSwitch(
                  value: settings.backgroundAudioOnly,
                  onChanged: (value) => unawaited(controller.setBackgroundAudioOnly(value: value)),
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.pictureInPicture),
                title: Text(t.settings.pauseOnPipClose),
                description: Text(t.settings.pauseOnPipCloseDesc),
                trailing: DsSwitch(
                  value: settings.pauseOnPipClose,
                  onChanged: (value) => unawaited(controller.setPauseOnPipClose(value: value)),
                ),
              ),
              DsListRow(
                leading: const DsIcon(DsIcons.moon),
                title: Text(t.settings.asmrSleepMode),
                description: Text(t.settings.asmrSleepModeDesc),
                trailing: DsSwitch(
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
          ],
        ),
      ],
    );
  }
}

/// The picture-and-small-window page: video fit, the floating and automatic
/// compact windows with their Windows geometry, fullscreen and keep-awake.
final class _PicturePane extends ConsumerWidget {
  const _PicturePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final portrait = ref.watch(portraitSettingsProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    return DsListSection(
      header: Text(t.settings.navPicture),
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
        DsListRow(
          leading: const DsIcon(DsIcons.pictureInPicture2),
          title: Text(t.settings.floatPlay),
          description: Text(t.settings.floatPlayDesc),
          trailing: DsSwitch(
            value: settings.floatPlay,
            onChanged: (value) => unawaited(controller.setFloatPlay(value: value)),
          ),
        ),
        SettingsChoiceRow<String>(
          leading: const DsIcon(DsIcons.maximize),
          title: t.settings.floatWindowSize,
          description: t.settings.floatWindowSizeDesc,
          value: ref.watch(floatingWindowSettingsProvider).size,
          options: [
            DsSelectOption(value: 'small', label: t.settings.floatWindowSmall),
            DsSelectOption(value: 'medium', label: t.settings.floatWindowMedium),
            DsSelectOption(value: 'large', label: t.settings.floatWindowLarge),
          ],
          onChanged: (value) => unawaited(ref.read(floatingWindowSettingsProvider.notifier).setSize(value)),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.pictureInPicture),
          title: Text(t.settings.autoPip),
          description: Text(t.settings.autoPipDesc),
          trailing: DsSwitch(
            value: settings.autoPipOnLeave,
            onChanged: (value) => unawaited(controller.setAutoPipOnLeave(value: value)),
          ),
        ),
        if (ref.watch(platformRuntimeProvider).environment.runtime.kind == PlatformKind.windows) ...[
          DsListRow(
            leading: const DsIcon(DsIcons.pin),
            title: Text(t.settings.windowsPipAlwaysOnTop),
            description: Text(t.settings.windowsPipAlwaysOnTopDesc),
            trailing: DsSwitch(
              value: settings.windowsPipAlwaysOnTop,
              onChanged: (value) => unawaited(_setWindowsPipAlwaysOnTop(ref, value)),
            ),
          ),
          DsListRow(
            leading: const DsIcon(DsIcons.appWindow),
            title: Text(t.settings.rememberPipPosition),
            description: Text(t.settings.rememberPipPositionDesc),
            trailing: DsSwitch(
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
          DsListRow(
            leading: const DsIcon(DsIcons.aspectRatio),
            title: Text(t.settings.windowsPipFreeAspect),
            description: Text(t.settings.windowsPipFreeAspectDesc),
            trailing: DsSwitch(
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
        DsListRow(
          leading: const DsIcon(DsIcons.fullscreen),
          title: Text(t.settings.fullscreenDefault),
          description: Text(t.settings.fullscreenDefaultDesc),
          trailing: DsSwitch(
            value: settings.fullscreenDefault,
            onChanged: (value) => unawaited(controller.setFullscreenDefault(value: value)),
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.sun),
          title: Text(t.settings.keepScreenOn),
          description: Text(t.settings.keepScreenOnDesc),
          trailing: DsSwitch(
            value: ref.watch(keepScreenOnProvider),
            onChanged: (value) => ref.read(keepScreenOnProvider.notifier).enabled = value,
          ),
        ),
        SettingsChildEntry(
          child: SettingsSection.portrait,
          detail: Text(
            portrait.adaptation && portrait.adaptiveHeight
                ? _portraitLayoutLabel(t, portrait.layoutMode)
                : t.settings.portraitEntryOff,
          ),
        ),
        if (ref.watch(selectedModuleProvider) == AppModule.live)
          SettingsChildEntry(
            child: SettingsSection.audience,
            detail: Text(audienceModeLabel(t, ref.watch(audienceMetricProvider))),
          ),
        DsListRow(
          leading: const DsIcon(DsIcons.filter),
          title: Text(t.settings.danmakuFilter),
          description: Text(t.settings.danmakuFilterDesc),
          showChevron: true,
          onPressed: () => openSettingsChild(context, ref, SettingsSection.shield),
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
            SettingsChoiceRow<PortraitFullscreenPolicy>(
              leading: const DsIcon(DsIcons.fullscreen),
              title: t.settings.portraitFullscreenPolicy,
              description: t.settings.portraitFullscreenPolicyDesc,
              value: settings.fullscreenPolicy,
              options: [
                DsSelectOption(
                  value: PortraitFullscreenPolicy.followSource,
                  label: t.settings.portraitFullscreenFollowSource,
                ),
                DsSelectOption(
                  value: PortraitFullscreenPolicy.followSystem,
                  label: t.settings.portraitFullscreenFollowSystem,
                ),
                DsSelectOption(
                  value: PortraitFullscreenPolicy.landscape,
                  label: t.settings.portraitFullscreenLandscape,
                ),
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
    DsListRow(
      leading: const DsIcon(DsIcons.rectangleVertical),
      title: Text(t.settings.portraitSmartDetection),
      description: Text(t.settings.portraitSmartDetectionDesc),
      trailing: DsSwitch(
        value: settings.adaptation,
        onChanged: (value) => unawaited(controller.setAdaptation(value: value)),
      ),
    ),
    if (settings.adaptation) ...[
      DsListRow(
        leading: const DsIcon(DsIcons.moveVertical),
        title: Text(t.settings.portraitAdaptiveHeight),
        description: Text(t.settings.portraitAdaptiveHeightDesc),
        trailing: DsSwitch(
          value: settings.adaptiveHeight,
          onChanged: (value) => unawaited(controller.setAdaptiveHeight(value: value)),
        ),
      ),
      if (settings.adaptiveHeight)
        SettingsChoiceRow<PortraitLayoutMode>(
          leading: const DsIcon(DsIcons.layoutGrid),
          title: t.settings.portraitLayoutMode,
          description: t.settings.portraitLayoutModeDesc,
          value: settings.layoutMode,
          options: [
            DsSelectOption(value: PortraitLayoutMode.balanced, label: t.settings.portraitLayoutBalanced),
            DsSelectOption(value: PortraitLayoutMode.immersive, label: t.settings.portraitLayoutImmersive),
            DsSelectOption(value: PortraitLayoutMode.compatibility, label: t.settings.portraitLayoutCompatibility),
          ],
          onChanged: (mode) => unawaited(controller.setLayoutMode(mode)),
        ),
    ] else
      Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
        child: Text(
          t.settings.portraitDetectionOff,
          style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
        ),
      ),
  ],
);

/// One of the portrait layout modes as the settings row and the entry show
/// it.
String _portraitLayoutLabel(Translations t, PortraitLayoutMode mode) => switch (mode) {
  PortraitLayoutMode.balanced => t.settings.portraitLayoutBalanced,
  PortraitLayoutMode.immersive => t.settings.portraitLayoutImmersive,
  PortraitLayoutMode.compatibility => t.settings.portraitLayoutCompatibility,
};

/// The small-window danmaku pane (the reference's mini-window danmaku): whether the
/// flying layer also draws while the window is the compact one. The look
/// itself is shared with the danmaku pane, so the two can never drift.
final class _MiniDanmakuPane extends ConsumerWidget {
  const _MiniDanmakuPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    return DsListSection(
      header: Text(t.settings.navMiniDanmaku),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.pictureInPicture),
          title: Text(t.settings.miniDanmakuVisible),
          description: Text(t.settings.miniDanmakuVisibleDesc),
          trailing: DsSwitch(
            value: settings.miniDanmakuVisible,
            onChanged: (value) =>
                unawaited(ref.read(playbackSettingsProvider.notifier).setMiniDanmakuVisible(value: value)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
          child: Text(
            t.settings.miniDanmakuHint,
            style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
          ),
        ),
      ],
    );
  }
}

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
