import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/app/background/background_library.dart' show showBackgroundLibrary;
import 'package:pure_live/app/background/background_presets.dart'
    show kBackgroundGalleryUrls, kBackgroundGradientPresets, kBackgroundSolidPresets;
import 'package:pure_live/app/background/background_settings.dart';
import 'package:pure_live/app/bootstrap/pure_live_app.dart' show AppLocaleScope;
import 'package:pure_live/app/navigation/module_navigation.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/module_providers.dart' show selectedModuleProvider;
import 'package:pure_live/app/providers/nav_visibility_providers.dart' show showMultiviewProvider;
import 'package:pure_live/app/providers/network_providers.dart' show proxySettingsProvider;
import 'package:pure_live/app/providers/refresh_settings_providers.dart';
import 'package:pure_live/app/providers/settings_section_provider.dart' show settingsSectionProvider;
import 'package:pure_live/app/providers/shell_settings_provider.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider, sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show SettingsSectionRoute;
import 'package:pure_live/app/theme/font_defaults.dart';
import 'package:pure_live/app/theme/theme_persistence.dart';
import 'package:pure_live/app/theme/theme_settings.dart';
import 'package:pure_live/app/window_chrome.dart' show WindowChrome, WindowChromeState;
import 'package:pure_live/features/account/account_pane.dart' show AccountPane;
import 'package:pure_live/features/backup/backup_pane.dart' show BackupPane;
import 'package:pure_live/features/favorites/follow_repository.dart' show followRepositoryProvider, followsProvider;
import 'package:pure_live/features/history/history_repository.dart' show historyProvider;
import 'package:pure_live/features/iptv/iptv_settings_pane.dart' show IptvSettingsPane;
import 'package:pure_live/features/recorder/recorder_page.dart' show RecordingSettingsPane;
import 'package:pure_live/features/settings/audience_metric_provider.dart' show AudienceMetricChoice, audienceMetricProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart';
import 'package:pure_live/features/settings/playback_settings_providers.dart';
import 'package:pure_live/features/settings/settings_search.dart' show SettingsSearchHit, settingsSearchHits;
import 'package:pure_live/features/settings/settings_sections.dart';
import 'package:pure_live/features/settings/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/features/settings/sites_display_provider.dart';
import 'package:pure_live/features/shield/shield_pane.dart' show ShieldPane;
import 'package:pure_live/features/version/version_controller.dart' show versionCheckProvider;
import 'package:pure_live/features/version/version_page.dart' show showReleaseHistory, showUpdatePanel;
import 'package:pure_live/features/vod/vod_settings_pane.dart' show VodSettingsPane;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart' show AppMark;
import 'package:pure_live/shared/enums/app_module.dart' show AppModule;
import 'package:pure_live/shared/enums/tool_order.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteIcon, localizedSiteName;
import 'package:restart_app/restart_app.dart' show Restart;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// The settings surface. On a desktop window the shell's own sidebar lists
/// the sections — the same menu the module destinations live in, so
/// entering settings swaps the menu's entries rather than stacking a second
/// menu beside it — and this page is the selected section's pane alone. On
/// a phone, where there is no sidebar, the page is the grouped list whose
/// entries push their section as its own route ([SettingsSectionRoute]).
///
/// Both read and write [settingsSectionProvider]: the sidebar and the list
/// agree on which section is on screen, and the pane is always that one.
final class SettingsPage extends ConsumerWidget {
  /// The settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 768;
    if (compact) return const _SettingsMenuList();
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
        : settingsSearchHits(t, query, groups.expand((group) => group.sections));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!tv)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s16, DsSpace.s24, 0),
            child: DsSearchField(
              controller: _query,
              placeholder: t.settings.searchSettings,
              semanticLabel: t.settings.searchSettings,
              onChanged: (_) => setState(() {}),
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
        : settingsSearchHits(t, query, groups.expand((group) => group.sections));
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
      final kept = [
        for (final section in group.sections)
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
    final groupKey = settingsGroupKeyOf(groups, section);
    final body = switch (section) {
      SettingsSection.general => const _GeneralPane(),
      SettingsSection.appearance => const _AppearancePane(),
      SettingsSection.background => const _BackgroundPane(),
      SettingsSection.nav => const _NavPane(),
      SettingsSection.refresh => const _RefreshPane(),
      SettingsSection.network => const _NetworkPane(),
      SettingsSection.video => const _VideoPane(),
      SettingsSection.danmaku => const _DanmakuPane(),
      SettingsSection.miniDanmaku => const _MiniDanmakuPane(),
      SettingsSection.kernel => const _KernelPane(),
      SettingsSection.recording => const _RecordingPane(),
      SettingsSection.sites => const _SitesPane(),
      SettingsSection.iptv => const IptvSettingsPane(),
      SettingsSection.vod => const VodSettingsPane(),
      SettingsSection.data => const _DataPane(),
      SettingsSection.backup => const BackupPane(),
      SettingsSection.cache => const _CachePane(),
      SettingsSection.about => const _AboutPane(),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s20, DsSpace.s24, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          // The reference's area, above the page's own name: Interface, Live
          // sources, Playback, General & network or Data.
          if (groupKey != null)
            Text(settingsGroupLabel(t, groupKey), style: theme.typography.overline.copyWith(color: colors.textSubtle)),
          Text(section.label(t), style: theme.typography.display.copyWith(color: colors.text)),
          Text(section.description(t), style: theme.typography.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: DsSpace.s12),
          body,
        ],
      ),
    );
  }
}

/// The general pane: the browsing preferences that work end to end — how
/// wide a feed card gets where the module browses cards, how many rows a
/// page reveals, and the window's own title bar and close action. The
/// default site belongs to the live module and lives in its Sites pane.
final class _GeneralPane extends ConsumerWidget {
  const _GeneralPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final module = ref.watch(selectedModuleProvider);
    final showsCardExtent = module == AppModule.live || module == AppModule.vod;
    final window = ref.watch(shellWindowSettingsProvider);

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
            min: 10,
            max: 90,
            divisions: 16,
            onChanged: (value) => ref.read(browseSettingsProvider.notifier).homePageSize = value.round(),
            semanticLabel: t.settings.pageSize,
          ),
        ),
        if (module == AppModule.live)
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.eye),
            title: t.settings.audienceMetric,
            description: t.settings.audienceMetricDesc,
            controlWidth: 220,
            control: DsSelect<AudienceMetricChoice>(
              value: ref.watch(audienceMetricProvider),
              onChanged: (value) {
                if (value != null) unawaited(ref.read(audienceMetricProvider.notifier).select(value));
              },
              options: [
                DsSelectOption(value: AudienceMetricChoice.automatic, label: t.settings.audienceAutomatic),
                DsSelectOption(value: AudienceMetricChoice.onlineViewers, label: t.settings.audienceOnline),
                DsSelectOption(value: AudienceMetricChoice.popularity, label: t.settings.audiencePopularity),
                DsSelectOption(value: AudienceMetricChoice.totalViewers, label: t.settings.audienceTotal),
              ],
              semanticLabel: t.settings.audienceMetric,
            ),
          ),
        // The window's own choices belong to every viewer: the title bar
        // and the close button are always offered (the reference keeps them
        // in the general page).
        if (WindowChromeState.configurable) ...[
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.appWindow),
            title: t.settings.windowChrome,
            description: t.settings.windowChromeDesc,
            controlWidth: 220,
            control: DsSelect<WindowChrome>(
              value: WindowChromeState.chrome,
              onChanged: (value) => unawaited(_setWindowChrome(context, value)),
              options: [
                DsSelectOption(value: WindowChrome.system, label: t.settings.windowChromeSystem),
                DsSelectOption(value: WindowChrome.custom, label: t.settings.windowChromeCustom),
              ],
              semanticLabel: t.settings.windowChrome,
            ),
          ),
        ],
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.panelLeftClose),
          title: t.settings.closeAction,
          // The tray is not wired yet, so its choice is named but dimmed
          // rather than offered: an honest row over a lying one.
          description: t.settings.closeTrayUnavailable,
          control: DsSelect<CloseAction>(
            value: window.closeAction == CloseAction.hideToTray ? CloseAction.quit : window.closeAction,
            onChanged: (value) {
              if (value != null) unawaited(ref.read(shellWindowSettingsProvider.notifier).setCloseAction(value));
            },
            options: [
              DsSelectOption(value: CloseAction.quit, label: t.settings.closeQuit),
              DsSelectOption(value: CloseAction.minimise, label: t.settings.closeMinimise),
            ],
            semanticLabel: t.settings.closeAction,
          ),
        ),
      ],
    );
  }
}

/// The refresh pane (the reference's Refresh): the follows page's auto
/// refresh and its interval — the timer the follows page itself runs, so
/// every change applies on the next arm. The cover refresh needs a
/// thumbnail pref this app does not keep yet, so it is not offered.
final class _RefreshPane extends ConsumerWidget {
  const _RefreshPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final autoRefresh = ref.watch(followsAutoRefreshProvider);
    // A stored interval the choices do not list still shows as chosen.
    final intervals = {...kRefreshIntervalChoices, autoRefresh.minutes}.toList()..sort();

    return DsListSection(
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
        if (autoRefresh.enabled) ...[
          SettingsConfigRow(
            leading: const DsIcon(DsIcons.timer),
            title: t.settings.refreshInterval,
            controlWidth: 180,
            control: DsSelect<int>(
              value: autoRefresh.minutes,
              onChanged: (value) {
                if (value != null) unawaited(ref.read(followsAutoRefreshProvider.notifier).setMinutes(value));
              },
              options: [
                for (final minutes in intervals) DsSelectOption(value: minutes, label: _intervalLabel(minutes)),
              ],
              semanticLabel: t.settings.refreshInterval,
            ),
          ),
        ],
      ],
    );
  }
}

/// The navigation pane (the reference's navigation-bar controls): the shared tools
/// block's order, moved here from the network pane. A tool's on/off switch
/// and the multi-view entry's need a visibility pref the sidebar reads,
/// which does not exist yet — the order alone is what is honest today.
final class _NavPane extends ConsumerWidget {
  const _NavPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final toolOrder = ref.watch(toolOrderProvider);
    final showMultiview = ref.watch(showMultiviewProvider);

    return DsListSection(
      header: Text(t.settings.toolsOrder),
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
    unawaited(Restart.restartApp());
  } else {
    await WindowChromeState.store(WindowChromeState.chrome);
  }
}

/// A refresh interval's label: minutes under an hour, whole hours above,
/// half hours as the decimal the reference shows ("1.5 h").
String _intervalLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes % 60 == 0) return '${minutes ~/ 60} h';
  if (minutes % 30 == 0) return '${minutes / 60} h';
  return '$minutes min';
}

/// The appearance pane, laid out as desen_ui's own settings surface: one
/// labelled row per choice, the control inline on a wide pane and under
/// the label on a narrow one. The options themselves are the design
/// system's: contrast, selection style and the clash rule are as much a
/// setting as light/dark.
final class _AppearancePane extends ConsumerWidget {
  const _AppearancePane();

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
    void update(AppThemeSettings next) => scope.onChanged(next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.groupTheme),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.sun),
              title: t.settings.themeMode,
              description: t.settings.appearanceDescription,
              controlWidth: 280,
              control: DsSegmentedControl<DsThemeMode>(
                value: settings.mode,
                onChanged: (value) => update(settings.rebuild((b) => b..mode = value)),
                segments: [
                  DsSegment(value: DsThemeMode.system, label: Text(t.settings.themeModeSystem)),
                  DsSegment(value: DsThemeMode.light, label: Text(t.settings.themeModeLight)),
                  DsSegment(value: DsThemeMode.dark, label: Text(t.settings.themeModeDark)),
                ],
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.palette),
              title: t.settings.themeSeed,
              description: t.settings.themeSeedSystem,
              controlWidth: 220,
              control: DsSelect<String>(
                value: seedName ?? '',
                onChanged: (value) {
                  if (value == null) return;
                  DsSeed? seed;
                  for (final (name, candidate) in kNamedSeeds) {
                    if (name == value) seed = candidate;
                  }
                  update(withSeed(settings, seed));
                },
                options: [
                  DsSelectOption(value: '', label: t.settings.themeSeedSystem, leading: const DsIcon(DsIcons.monitor)),
                  for (final (name, seed) in kNamedSeeds)
                    DsSelectOption(
                      value: name,
                      label: _seedLabel(t, name),
                      leading: _SeedSwatch(seed: seed),
                    ),
                ],
                semanticLabel: t.settings.themeSeed,
              ),
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
              leading: const DsIcon(DsIcons.circle),
              title: Text(t.settings.pureBlack),
              description: Text(t.settings.pureBlackDesc),
              trailing: DsSwitch(
                value: settings.pureBlack,
                onChanged: (value) => update(settings.rebuild((b) => b..pureBlack = value)),
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
          header: Text(t.settings.groupType),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.type),
              title: t.settings.font,
              description: t.settings.fontDescription,
              controlWidth: 220,
              control: DsSelect<String>(
                value: settings.fontFamily ?? '',
                onChanged: (value) {
                  if (value == null) return;
                  update(
                    settings.rebuild((b) {
                      // Empty is the platform's own face; a preset id is this
                      // app's bundled family, never a package one.
                      b
                        ..fontFamily = value.isEmpty ? null : value
                        ..fontPackage = null;
                    }),
                  );
                },
                options: [
                  DsSelectOption(value: '', label: t.settings.fontPlatform),
                  for (final (id, label) in kBundledFontPresets) DsSelectOption(value: id, label: label),
                ],
                semanticLabel: t.settings.font,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.languages),
              title: t.settings.language,
              control: DsSelect<String>(
                value: localeScope.localeCode ?? '',
                onChanged: (value) => localeScope.onChanged(value == null || value.isEmpty ? null : value),
                options: [
                  DsSelectOption(value: '', label: t.settings.languageSystem),
                  const DsSelectOption(value: 'zh-CN', label: '简体中文'),
                  const DsSelectOption(value: 'en', label: 'English'),
                ],
                semanticLabel: t.settings.language,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _seedLabel(Translations t, String name) => switch (name) {
    'seedBlue' => t.settings.seedBlue,
    'seedNavy' => t.settings.seedNavy,
    'seedIndigo' => t.settings.seedIndigo,
    'seedGraphite' => t.settings.seedGraphite,
    'seedOxblood' => t.settings.seedOxblood,
    'seedForest' => t.settings.seedForest,
    _ => name,
  };
}

/// A named seed as a small color dot, so the palette choice reads as a
/// color rather than a word.
final class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({required this.seed});

  final DsSeed seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: DsBoxDecoration(
        color: _seedAccents[seed] ??= DsThemeData(seed: seed).colors.accent,
        borderRadius: BorderRadius.circular(7),
      ),
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

    return DsListSection(
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

/// The danmaku pane: the shield's lists, then the flying layer's own look
/// and motion — every slider applies on the very next message.
final class _DanmakuPane extends ConsumerWidget {
  const _DanmakuPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final style = ref.watch(danmakuStyleProvider);
    final controller = ref.read(danmakuStyleProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        const ShieldPane(),
        DsListSection(
          header: Text(t.settings.danmakuStyleGroup),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.type),
              title: t.settings.styleFontSize,
              detail: Text('${style.fontSize.round()}'),
              controlWidth: 220,
              control: DsSlider(
                value: style.fontSize,
                min: DanmakuStyleRange.fontSizeMin,
                max: DanmakuStyleRange.fontSizeMax,
                onChanged: (value) => unawaited(controller.setFontSize(value)),
                semanticLabel: t.settings.styleFontSize,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.wind),
              title: t.settings.styleSpeed,
              detail: Text('${style.baseSpeed.round()}'),
              controlWidth: 220,
              control: DsSlider(
                value: style.baseSpeed,
                min: DanmakuStyleRange.speedMin,
                max: DanmakuStyleRange.speedMax,
                onChanged: (value) => unawaited(controller.setBaseSpeed(value)),
                semanticLabel: t.settings.styleSpeed,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.moveVertical),
              title: t.settings.styleArea,
              detail: Text('${(style.area * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: style.area,
                min: DanmakuStyleRange.areaMin,
                // The ceiling is the slider's own default: the whole screen.
                onChanged: (value) => unawaited(controller.setArea(value)),
                semanticLabel: t.settings.styleArea,
              ),
            ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.circle),
              title: t.settings.styleOpacity,
              detail: Text('${(style.opacity * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: style.opacity,
                min: DanmakuStyleRange.opacityMin,
                // The ceiling is the slider's own default: fully opaque.
                onChanged: (value) => unawaited(controller.setOpacity(value)),
                semanticLabel: t.settings.styleOpacity,
              ),
            ),
            DsSwitch(
              value: style.showStroke,
              onChanged: (value) => unawaited(controller.setShowStroke(value: value)),
              label: Text(t.settings.styleStroke),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.rotateCw),
              title: Text(t.settings.styleReset),
              onPressed: () => unawaited(controller.reset()),
            ),
          ],
        ),
      ],
    );
  }
}

/// The sites pane: the platform display (the reference's hot-areas
/// setting) — one switch per site, in the viewer's own order (drag a
/// handle, or Alt+Up/Down, to move one; "restore default" puts the
/// registry's back) and the preferred platform; a switched-off platform
/// leaves the popular and areas tab lists until it is switched back on —
/// with the accounts block under it (the reference keeps accounts with
/// platforms).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.settings.sitesDisplay),
          children: [
            SettingsConfigRow(
              leading: localizedSiteIcon(selectedSite, size: 20) ?? const DsIcon(DsIcons.tv),
              title: t.settings.site,
              controlWidth: 220,
              control: DsSelect<String>(
                value: selectedId,
                // The select reports null only when cleared (clearable is
                // off), so a null never reaches the site setter.
                onChanged: (id) {
                  if (id != null) ref.read(selectedSiteIdProvider.notifier).selected = id;
                },
                options: [
                  for (final site in sites)
                    DsSelectOption(
                      value: site.manifest.id,
                      label: localizedSiteName(site),
                      leading: localizedSiteIcon(site, size: 20),
                    ),
                ],
                placeholder: t.settings.site,
                semanticLabel: t.settings.site,
              ),
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
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.pin),
              title: t.settings.preferPlatform,
              description: t.settings.preferPlatformDesc,
              controlWidth: 220,
              control: DsSelect<String>(
                value: visibleOrder.contains(order.preferred) ? order.preferred : null,
                onChanged: (value) {
                  if (value != null) unawaited(orderController.setPreferred(value));
                },
                options: [
                  for (final id in visibleOrder)
                    DsSelectOption(value: id, label: name(id), leading: localizedSiteIcon(sitesById[id], size: 20)),
                ],
                placeholder: t.settings.preferPlatform,
                semanticLabel: t.settings.preferPlatform,
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.listRestart),
              title: Text(t.settings.sitesOrderReset),
              description: Text(t.settings.sitesOrderResetDesc),
              onPressed: () => unawaited(orderController.resetOrder()),
            ),
          ],
        ),
        const AccountPane(),
      ],
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
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.clock),
          title: t.settings.historyLimit,
          description: t.settings.historyLimitDesc,
          detail: Text('$historyLimit'),
          controlWidth: 160,
          control: DsSelect<int>(
            value: historyLimit,
            onChanged: (value) {
              if (value != null) unawaited(ref.read(historyLimitProvider.notifier).setLimit(value));
            },
            options: [for (final limit in limits) DsSelectOption(value: limit, label: '$limit')],
            semanticLabel: t.settings.historyLimit,
          ),
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
final class _CachePane extends StatefulWidget {
  const _CachePane();

  @override
  State<_CachePane> createState() => _CachePaneState();
}

final class _CachePaneState extends State<_CachePane> {
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
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
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.settings),
          title: t.settings.cacheLimit,
          description: t.settings.cacheLimitDesc,
          control: DsSelect<int>(
            value: _limitMb,
            onChanged: (value) => unawaited(_setLimit(value)),
            options: [
              DsSelectOption(value: 0, label: t.settings.cacheLimitOff),
              for (final mb in const [100, 200, 500, 1024, 2048]) DsSelectOption(value: mb, label: '$mb MB'),
            ],
            semanticLabel: t.settings.cacheLimit,
          ),
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
          leading: const DsIcon(DsIcons.list),
          title: Text(t.settings.releaseHistory),
          description: Text(t.settings.releaseHistoryDesc),
          onPressed: () => unawaited(showReleaseHistory(context)),
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

/// The video pane (the reference's Video): what a room starts on — its
/// quality, its audio and how the picture sits in its box — all applied as
/// the player handle arrives.
final class _VideoPane extends ConsumerWidget {
  const _VideoPane();

  /// The quality labels the picker offers, raw as sites spell them; the
  /// stored value is this label, so the choice matches the site's catalogue.
  static const List<String> _qualities = ['原画', '蓝光', '超清', '高清', '标清', '流畅'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    final controller = ref.read(playbackSettingsProvider.notifier);
    final stored = settings.preferredQuality;
    final choices = {..._qualities, if (stored != null && stored.isNotEmpty) stored}.toList();
    return DsListSection(
      header: Text(t.settings.navVideo),
      children: [
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.gauge),
          title: t.settings.preferredQuality,
          description: t.settings.preferredQualityDesc,
          control: DsSelect<String>(
            value: stored ?? '',
            onChanged: (value) =>
                unawaited(controller.setPreferredQuality(value == null || value.isEmpty ? null : value)),
            options: [
              DsSelectOption(value: '', label: t.settings.qualityAuto),
              for (final quality in choices) DsSelectOption(value: quality, label: _qualityLabel(t, quality)),
            ],
            semanticLabel: t.settings.preferredQuality,
          ),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.volumeOff),
          title: Text(t.settings.defaultMuted),
          description: Text(t.settings.defaultMutedDesc),
          trailing: DsSwitch(
            value: settings.muted,
            onChanged: (value) => unawaited(controller.setMuted(value: value)),
          ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.volume),
          title: t.settings.defaultVolume,
          description: t.settings.defaultVolumeDesc,
          detail: Text('${(settings.volume * 100).round()}%'),
          controlWidth: 220,
          control: DsSlider(
            value: settings.volume,
            onChanged: (value) => unawaited(controller.setVolume(value)),
            semanticLabel: t.settings.defaultVolume,
          ),
        ),
        SettingsConfigRow(
          leading: const DsIcon(DsIcons.rectangleHorizontal),
          title: t.settings.fit,
          description: t.settings.fitDesc,
          controlWidth: 300,
          control: DsSegmentedControl<PlaybackFit>(
            value: settings.fit,
            onChanged: (value) => unawaited(controller.setFit(value)),
            segments: [
              DsSegment(value: PlaybackFit.contain, label: Text(t.settings.fitContain)),
              DsSegment(value: PlaybackFit.cover, label: Text(t.settings.fitCover)),
              DsSegment(value: PlaybackFit.fill, label: Text(t.settings.fitFill)),
            ],
          ),
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
      ],
    );
  }

  /// The picker's words for a site's raw quality label; a label the app
  /// does not know shows as the site spelled it.
  String _qualityLabel(Translations t, String quality) => switch (quality) {
    '原画' => t.settings.qualityOriginal,
    '蓝光' => t.settings.qualityBluRay,
    '超清' => t.settings.qualityUltra,
    '高清' => t.settings.qualityHigh,
    '标清' => t.settings.qualityStandard,
    '流畅' => t.settings.qualitySmooth,
    _ => quality,
  };
}

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
final class _KernelPane extends ConsumerWidget {
  const _KernelPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(playbackSettingsProvider);
    return DsListSection(
      header: Text(t.settings.navKernel),
      children: [
        DsListRow(
          leading: const DsIcon(DsIcons.cpu),
          title: Text(t.settings.engineTitle),
          description: Text(t.settings.engineDesc),
          detail: const Text('mpv · media_kit'),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.gauge),
          title: Text(t.settings.hardwareDecoding),
          description: Text(t.settings.hardwareDecodingDesc),
          trailing: DsSwitch(
            value: settings.hardwareDecoding,
            onChanged: (value) =>
                unawaited(ref.read(playbackSettingsProvider.notifier).setHardwareDecoding(value: value)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
          child: Text(
            t.settings.hardwareDecodingHint,
            style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
          ),
        ),
      ],
    );
  }
}

/// The recording pane (the reference's Recording): the recorder's own settings,
/// shared with the recording centre's header so both surfaces write the
/// same stored truth.
final class _RecordingPane extends StatelessWidget {
  const _RecordingPane();

  @override
  Widget build(BuildContext context) => const RecordingSettingsPane();
}

/// A flat colour preset: a 40×40 swatch, ringed while it is the chosen
/// background.
final class _BackgroundSwatch extends StatelessWidget {
  const _BackgroundSwatch({
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
  });

  final Color color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.all(
            color: selected
                ? colors.accent
                : states.contains(WidgetState.hovered)
                ? colors.textSubtle
                : colors.border,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected ? const Center(child: DsIcon(DsIcons.check, size: 16, color: Color(0xFFFFFFFF))) : null,
      ),
    );
  }
}

/// A gradient preset tile, previewed with its own stops and alignment.
final class _BackgroundGradientSwatch extends StatelessWidget {
  const _BackgroundGradientSwatch({
    required this.colors,
    required this.begin,
    required this.end,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
  });

  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        width: 96,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: begin, end: end),
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.all(
            color: selected
                ? palette.accent
                : states.contains(WidgetState.hovered)
                ? palette.textSubtle
                : palette.border,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected ? const Center(child: DsIcon(DsIcons.check, size: 16, color: Color(0xFFFFFFFF))) : null,
      ),
    );
  }
}

/// One picture from the TV wallpaper set's public deepin collection.
final class _BackgroundGalleryTile extends StatelessWidget {
  const _BackgroundGalleryTile({
    required this.url,
    required this.selected,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String url;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) => Container(
        width: 120,
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.all(
            color: selected
                ? colors.accent
                : states.contains(WidgetState.hovered)
                ? colors.textSubtle
                : colors.border,
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DsImage(
              image: cachedImage(url),
              width: 120,
              height: 68,
              semanticLabel: semanticLabel,
              fallback: ColoredBox(color: colors.control),
            ),
            if (selected)
              const PositionedDirectional(
                top: 4,
                end: 4,
                child: DsIcon(DsIcons.checkCircle, size: 16, color: Color(0xFFFFFFFF)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The background pane: a still image or a looping muted video behind every
/// page, uploaded into the app's data area or loaded from an http(s) URL.
///
/// The pane itself sits over the wallpaper, so every change is its own
/// preview; the display knobs (fit, scrim, blur) apply live.
final class _BackgroundPane extends ConsumerStatefulWidget {
  const _BackgroundPane();

  @override
  ConsumerState<_BackgroundPane> createState() => _BackgroundPaneState();
}

final class _BackgroundPaneState extends ConsumerState<_BackgroundPane> {
  final TextEditingController _imageUrl = TextEditingController();
  final TextEditingController _videoUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(backgroundSettingsProvider);
    _imageUrl.text = settings.imageUrl;
    _videoUrl.text = settings.videoUrl;
  }

  @override
  void dispose() {
    _imageUrl.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(backgroundSettingsProvider);
    final controller = ref.read(backgroundSettingsProvider.notifier);
    final busy = settings.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        if (settings.error.isNotEmpty)
          DsAlert(
            status: DsStatus.danger,
            title: Text(t.settings.backgroundImportFailed),
            description: Text(settings.error, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        if (busy)
          Row(
            spacing: DsSpace.s8,
            children: [
              const SizedBox(width: 14, height: 14, child: DsSpinner()),
              Text(t.settings.backgroundBusy, style: DsTheme.of(context).typography.caption),
            ],
          ),
        DsListSection(
          header: Text(t.settings.backgroundSource),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.wallpaper),
              title: t.settings.backgroundKind,
              description: t.settings.backgroundDescription,
              controlWidth: 300,
              control: DsSegmentedControl<BackgroundKind>(
                value: settings.kind,
                onChanged: controller.selectKind,
                segments: [
                  DsSegment(value: BackgroundKind.none, label: Text(t.settings.backgroundNone)),
                  DsSegment(value: BackgroundKind.solid, label: Text(t.settings.backgroundSolid)),
                  DsSegment(value: BackgroundKind.gradient, label: Text(t.settings.backgroundGradient)),
                  DsSegment(value: BackgroundKind.image, label: Text(t.settings.backgroundImage)),
                  DsSegment(value: BackgroundKind.video, label: Text(t.settings.backgroundVideo)),
                ],
              ),
            ),
          ],
        ),
        if (settings.kind == BackgroundKind.solid)
          DsListSection(
            header: Text(t.settings.backgroundPresets),
            children: [
              Padding(
                padding: const EdgeInsets.all(DsSpace.s12),
                child: Wrap(
                  spacing: DsSpace.s8,
                  runSpacing: DsSpace.s8,
                  children: [
                    for (final color in kBackgroundSolidPresets)
                      _BackgroundSwatch(
                        color: color,
                        selected: settings.solidColor == color,
                        semanticLabel: t.settings.backgroundSolid,
                        onPressed: () => controller.setSolid(color),
                      ),
                  ],
                ),
              ),
            ],
          ),
        if (settings.kind == BackgroundKind.gradient)
          DsListSection(
            header: Text(t.settings.backgroundPresets),
            children: [
              Padding(
                padding: const EdgeInsets.all(DsSpace.s12),
                child: Wrap(
                  spacing: DsSpace.s8,
                  runSpacing: DsSpace.s8,
                  children: [
                    for (final (index, preset) in kBackgroundGradientPresets.indexed)
                      _BackgroundGradientSwatch(
                        colors: preset.colors,
                        begin: preset.begin,
                        end: preset.end,
                        selected: listEquals(settings.gradientColors, preset.colors),
                        semanticLabel: '${t.settings.backgroundGradient} ${index + 1}',
                        onPressed: () => controller.setGradient(preset.colors),
                      ),
                  ],
                ),
              ),
            ],
          ),
        if (settings.kind == BackgroundKind.image || settings.kind == BackgroundKind.none)
          DsListSection(
            header: Text(t.settings.backgroundGallery),
            children: [
              DsListRow(
                leading: const DsIcon(DsIcons.image),
                title: Text(t.settings.backgroundLibraryBrowse),
                description: Text(t.settings.backgroundLibraryNetworkHint),
                onPressed: () => unawaited(showBackgroundLibrary(context)),
                showChevron: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s4),
                child: Text(
                  t.settings.backgroundGalleryHint,
                  style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
                ),
              ),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
                  itemCount: kBackgroundGalleryUrls.length,
                  separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s8),
                  itemBuilder: (context, index) {
                    final url = kBackgroundGalleryUrls[index];
                    return _BackgroundGalleryTile(
                      url: url,
                      selected: settings.imageUrl == url,
                      semanticLabel: '${t.settings.backgroundGallery} ${index + 1}',
                      onPressed: () => controller.setImageUrl(url),
                    );
                  },
                ),
              ),
            ],
          ),
        if (settings.kind == BackgroundKind.image)
          _sourceSection(
            context,
            title: t.settings.backgroundImage,
            addressLabel: t.settings.backgroundImageAddress,
            controller: _imageUrl,
            path: settings.imagePath,
            busy: busy,
            onApply: () => _apply(image: true),
            onUpload: () => _upload(image: true),
          ),
        if (settings.kind == BackgroundKind.video)
          _sourceSection(
            context,
            title: t.settings.backgroundVideo,
            addressLabel: t.settings.backgroundVideoAddress,
            controller: _videoUrl,
            path: settings.videoPath,
            busy: busy,
            onApply: () => _apply(image: false),
            onUpload: () => _upload(image: false),
          ),
        if (settings.kind == BackgroundKind.none)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s4),
            child: Text(
              t.settings.backgroundEmpty,
              style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
            ),
          ),
        DsListSection(
          header: Text(t.settings.backgroundDisplay),
          children: [
            if (settings.kind == BackgroundKind.image || settings.kind == BackgroundKind.video)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.scan),
                title: t.settings.backgroundFit,
                controlWidth: 220,
                control: DsSelect<BoxFit>(
                  value: settings.fit,
                  onChanged: (value) {
                    if (value != null) controller.setFit(value);
                  },
                  options: [for (final fit in kBackgroundFits) DsSelectOption(value: fit, label: _fitLabel(t, fit))],
                  semanticLabel: t.settings.backgroundFit,
                ),
              ),
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.contrast),
              title: t.settings.backgroundMask,
              description: t.settings.backgroundMaskDescription,
              detail: Text('${(settings.maskOpacity * 100).round()}%'),
              controlWidth: 220,
              control: DsSlider(
                value: settings.maskOpacity,
                max: 0.8,
                divisions: 16,
                onChanged: controller.setMaskOpacity,
                semanticLabel: t.settings.backgroundMask,
              ),
            ),
            if (settings.kind == BackgroundKind.image || settings.kind == BackgroundKind.video)
              SettingsConfigRow(
                leading: const DsIcon(DsIcons.waves),
                title: t.settings.backgroundBlur,
                description: t.settings.backgroundBlurDescription,
                detail: Text('${settings.blurSigma.round()}'),
                controlWidth: 220,
                control: DsSlider(
                  value: settings.blurSigma,
                  max: 40,
                  divisions: 40,
                  onChanged: controller.setBlurSigma,
                  semanticLabel: t.settings.backgroundBlur,
                ),
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: controller.clear,
            leading: const DsIcon(DsIcons.eraser),
            child: Text(t.settings.backgroundClear),
          ),
        ),
      ],
    );
  }

  /// One media kind's URL field and actions.
  Widget _sourceSection(
    BuildContext context, {
    required String title,
    required String addressLabel,
    required TextEditingController controller,
    required String path,
    required bool busy,
    required VoidCallback onApply,
    required VoidCallback onUpload,
  }) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsListSection(
      header: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Text(addressLabel, style: theme.typography.body.copyWith(color: colors.text)),
              DsTextField(
                controller: controller,
                placeholder: t.settings.backgroundAddressHint,
                semanticLabel: addressLabel,
                onSubmitted: (_) => onApply(),
              ),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DsButton(
                    onPressed: busy ? null : onApply,
                    leading: const DsIcon(DsIcons.check),
                    child: Text(t.settings.backgroundApply),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    onPressed: busy ? null : onUpload,
                    leading: const DsIcon(DsIcons.upload),
                    child: Text(t.settings.backgroundUpload),
                  ),
                  if (path.isNotEmpty)
                    Text(
                      t.settings.backgroundLocalFile(name: p.basename(path)),
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _apply({required bool image}) {
    final t = context.t;
    final settings = ref.read(backgroundSettingsProvider);
    final url = (image ? _imageUrl : _videoUrl).text.trim();
    // An empty field over an uploaded file is not "remove the file": the
    // upload wrote that source, and a stray Apply should not drop it.
    if (url.isEmpty && (image ? settings.imagePath : settings.videoPath).isNotEmpty) return;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
        showDsToast(context: context, title: t.settings.backgroundInvalidUrl, status: DsStatus.danger);
        return;
      }
    }
    final controller = ref.read(backgroundSettingsProvider.notifier);
    image ? controller.setImageUrl(url) : controller.setVideoUrl(url);
  }

  Future<void> _upload({required bool image}) async {
    final t = context.t;
    final controller = ref.read(backgroundSettingsProvider.notifier);
    if (image) {
      await controller.uploadImage(dialogTitle: t.settings.backgroundUploadImage);
    } else {
      await controller.uploadVideo(dialogTitle: t.settings.backgroundUploadVideo);
    }
    if (!mounted) return;
    final settings = ref.read(backgroundSettingsProvider);
    if (image) {
      _imageUrl.text = settings.imageUrl;
    } else {
      _videoUrl.text = settings.videoUrl;
    }
    if (settings.error.isNotEmpty) {
      showDsToast(
        context: context,
        title: t.settings.backgroundImportFailed,
        description: settings.error,
        status: DsStatus.danger,
      );
    }
  }

  static String _fitLabel(Translations t, BoxFit fit) => switch (fit) {
    BoxFit.cover => t.settings.backgroundFitCover,
    BoxFit.contain => t.settings.backgroundFitContain,
    BoxFit.fill => t.settings.backgroundFitFill,
    BoxFit.fitWidth => t.settings.backgroundFitWidth,
    BoxFit.fitHeight => t.settings.backgroundFitHeight,
    BoxFit.none => t.settings.backgroundFitNone,
    BoxFit.scaleDown => t.settings.backgroundFitScaleDown,
  };
}
