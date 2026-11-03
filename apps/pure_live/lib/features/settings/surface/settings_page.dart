import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart';
import 'package:pure_live/features/backup/backup.dart';
import 'package:pure_live/features/lan_sync/lan_sync.dart' show LanSyncPane;
import 'package:pure_live/features/settings/pages/font_manager_page.dart' show FontManagerPage;
import 'package:pure_live/features/settings/pages/player_guide_page.dart' show PlayerGuidePage;
import 'package:pure_live/features/settings/pages/wallpaper_download_manager.dart' show WallpaperDownloadsPane;
import 'package:pure_live/features/settings/panes/audience_settings_pane.dart' show AudienceSettingsPane;
import 'package:pure_live/features/settings/panes/background_panes.dart'
    show
        BackgroundColorsPane,
        BackgroundDevicePane,
        BackgroundLibraryPane,
        BackgroundOverviewPane,
        BackgroundRandomPane;
import 'package:pure_live/features/settings/panes/browse_sites_panes.dart';
import 'package:pure_live/features/settings/panes/danmaku_panes.dart' show DanmakuPane, DanmakuTab;
import 'package:pure_live/features/settings/panes/data_cache_panes.dart';
import 'package:pure_live/features/settings/panes/general_panes.dart';
import 'package:pure_live/features/settings/panes/network_pane.dart';
import 'package:pure_live/features/settings/panes/playback_panes.dart';
import 'package:pure_live/features/settings/panes/player_kernel_pane.dart'
    show PlayerKernelAdvancedPane, PlayerKernelPane;
import 'package:pure_live/features/settings/panes/sites_display_pane.dart';
import 'package:pure_live/features/settings/panes/theme_pane.dart';
import 'package:pure_live/features/settings/surface/settings_navigation.dart'
    show openSettingsCategory, openSettingsChild, openSettingsSection, settingsStacksRoutes;
import 'package:pure_live/features/settings/surface/settings_search.dart' show SettingsSearchHit, settingsSearchHits;
import 'package:pure_live/features/settings/surface/settings_sections.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/hongguo.dart';
import 'package:pure_live/modules/iptv/iptv.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/toolbox/toolbox.dart';
import 'package:pure_live/modules/music/music.dart';
import 'package:pure_live/modules/vod/vod.dart';
import 'package:pure_live/shared/shared.dart';

// The entry row lives on its own so a pane can offer a subpage without
// importing this page (and, with it, every other pane).
export 'settings_child_entry.dart';

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
                  // A category carrying one page opens it instead of listing it.
                  final sole = settingsSolePageOf(group);
                  if (sole != null) {
                    openSettingsChild(context, ref, sole);
                    return;
                  }
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
          child: Center(
            child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.settings.searchNoResults)),
          ),
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
      SettingsSection.theme || SettingsSection.personalization || SettingsSection.appearance => const ThemePane(),
      SettingsSection.typography => const ThemePane(),
      SettingsSection.fontApp => const FontManagerPage(),
      SettingsSection.background => const BackgroundOverviewPane(),
      SettingsSection.backgroundImages => const BackgroundLibraryPane(video: false),
      SettingsSection.backgroundRandom => const BackgroundRandomPane(),
      SettingsSection.backgroundVideos => const BackgroundLibraryPane(video: true),
      SettingsSection.backgroundColors => const BackgroundColorsPane(),
      SettingsSection.backgroundDevice => const BackgroundDevicePane(),
      SettingsSection.backgroundDownloads => const WallpaperDownloadsPane(),
      SettingsSection.nav => const NavPane(),
      SettingsSection.navHomeMenu => const NavHomeMenuPane(),
      SettingsSection.navToolOrder => const NavToolOrderPane(),
      SettingsSection.browsing || SettingsSection.general => const BrowsingPane(),
      // The card's page is the sample itself: the browsing entry opens it.
      SettingsSection.roomCard => const BrowsingPane(),
      SettingsSection.sites || SettingsSection.live || SettingsSection.sources => const SitesPane(),
      SettingsSection.sitesDisplay => const SitesDisplayPane(),
      SettingsSection.nodes => const PlatformNodesPane(),
      SettingsSection.accounts => const AccountPane(),
      SettingsSection.refresh => const RefreshPane(),
      SettingsSection.followTags => const FollowTagsPane(),
      SettingsSection.danmaku || SettingsSection.miniDanmaku => const DanmakuPane(),
      SettingsSection.fontDanmaku => const FontManagerPage(danmaku: true),
      // The merged page's categories keep their own deep links: a stored link
      // or a search hit opens the page on the matching segment.
      SettingsSection.danmakuDisplay => const DanmakuPane(initialTab: DanmakuTab.list),
      SettingsSection.shield => const DanmakuPane(initialTab: DanmakuTab.shield),
      SettingsSection.recording => const RecordingPane(),
      SettingsSection.quality ||
      SettingsSection.playback ||
      SettingsSection.video ||
      SettingsSection.audio => const QualityAudioPane(),
      SettingsSection.picture => const PicturePane(),
      SettingsSection.floatingWindow => const FloatingWindowPane(),
      SettingsSection.audience => const AudienceSettingsPane(),
      SettingsSection.kernel => const PlayerKernelPane(),
      SettingsSection.kernelAdvanced => const PlayerKernelAdvancedPane(),
      SettingsSection.playerGuide => const PlayerGuidePage(),
      SettingsSection.startup || SettingsSection.system => const StartupPane(),
      SettingsSection.window => const WindowPane(),
      SettingsSection.network => const NetworkPane(),
      SettingsSection.dataCache || SettingsSection.data || SettingsSection.cache => const DataCachePane(),
      SettingsSection.storageFolders => const StorageFoldersSection(),
      SettingsSection.logs => const LogSettingsSection(),
      SettingsSection.backup => const BackupPane(),
      SettingsSection.localBackup => const LocalBackupPane(),
      SettingsSection.lanSync => const LanSyncPane(),
      SettingsSection.webdavSync => const WebDavFileManager(),
      SettingsSection.webdavHelp => const WebDavHelpPage(),
      SettingsSection.cloudBackup => const CloudBackupPane(),
      SettingsSection.cloudAdmin => const CloudAdminPane(),
      SettingsSection.about => const AboutPane(),
      SettingsSection.iptv => const IptvSettingsPane(),
      SettingsSection.iptvBrowse => const IptvBrowsePane(),
      SettingsSection.iptvGroups => const IptvGroupsPane(),
      SettingsSection.vod => const VodSettingsPane(),
      SettingsSection.vodPlayback => const VodPlaybackPane(),
      SettingsSection.vodDownload => const VodDownloadsPane(),
      SettingsSection.vodInterface => const VodInterfacePane(),
      SettingsSection.music => const MusicSettingsPane(),
      SettingsSection.hongguo => const HongguoSettingsPane(),
      SettingsSection.hongguoInterface => const HongguoInterfacePane(),
      SettingsSection.hongguoDownload => const HongguoDownloadsPane(),
      SettingsSection.hongguoDanmaku => const HongguoDanmakuPane(),
      SettingsSection.hongguoDevice => const HongguoDevicePane(),
      SettingsSection.musicSources => const MusicSourcesPane(),
      SettingsSection.musicDownload => const MusicDownloadPane(),
      SettingsSection.musicLyric => const MusicLyricPane(),
      // The desktop window is a segment of that page now; a search hit or a
      // stored deep link still opens it on the right half.
      SettingsSection.musicDesktopLyric => const MusicLyricPane(initialTab: MusicLyricTab.desktop),
      SettingsSection.musicHotkeys => const MusicHotkeysPane(),
      SettingsSection.musicSync => const MusicSyncPane(),
      SettingsSection.musicEq => const MusicEqPane(),
    };
    final inset = LiveWindow.isCompact(MediaQuery.sizeOf(context).width) ? DsSpace.s16 : DsSpace.s24;
    final padding = EdgeInsets.fromLTRB(inset, DsSpace.s20, inset, DsSpace.s24);
    // Some pages own their height instead of scrolling the whole pane with
    // it: a wallpaper page fills the window with as many whole rows as fit,
    // and the font manager pins its filters over a table that scrolls by
    // itself; the accounts table keeps its pages in view the same way.
    if (section == SettingsSection.webdavSync ||
        section == SettingsSection.cloudAdmin ||
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

/// The two faces of the network page.
