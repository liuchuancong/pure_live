import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowArea;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaProvider, LiveSite;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/features/discovery/areas_common.dart' show areasCatalogProvider, followedAreasProvider;
import 'package:pure_live/features/discovery/site_picker.dart';
import 'package:pure_live/features/room/paging.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/features/discovery/tv_areas_view.dart';
import 'package:pure_live/shared/areas/area_artwork.dart';
import 'package:pure_live/shared/utilities/sites_order.dart' show orderedSites;
import 'package:pure_live/shared/widgets/area_card.dart';
import 'package:pure_live/shared/widgets/list_loading.dart' show FeedAutoRefresh;
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/layout/main_layout.dart';
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Areas: every area-capable platform as a tab over its category catalogue
/// (3.x `AreasPage`); a category tab row splits the platforms that group
/// their areas — one group's tiles at a time, like the reference — while a
/// flat catalogue is one grid. Pull to refresh reloads the catalogue.
final class AreasPage extends ConsumerStatefulWidget {
  /// The areas page.
  const new({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

final class _AreasPageState extends ConsumerState<AreasPage> {
  int _selected = 0;

  /// Whether the preferred-platform jump was already applied.
  bool _appliedPreferred = false;

  @override
  Widget build(BuildContext context) {
    // The TV draws its own focus-first pane instead of the phone catalogue.
    if (ref.read(environmentProvider).runtime.formFactor == FormFactor.tv) {
      return const TvAreasView();
    }
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final sites = ref
        .watch(sitesProvider)
        .registry
        .all
        .where((site) => site.capability<LiveAreaProvider>() != null)
        .toList();
    // The platform display setting: hidden platforms have no tab, the
    // stored order drives the tabs (the reference's availableIds).
    final capable = orderedSites(
      sites,
      preferences.siteOrder,
    ).where((site) => !preferences.hiddenSiteIds.contains(site.manifest.id)).toList();
    // 首选直播平台: the page opens on the preferred platform, once.
    if (!_appliedPreferred) {
      _appliedPreferred = true;
      final preferred = preferences.preferredSiteId;
      final index = capable.indexWhere((site) => site.manifest.id == preferred);
      if (index > 0 && index != _selected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selected = index);
          }
        });
      }
    }
    final phoneTab = MainPageFrame.showsHomeBarButtons(context, inHome: true);
    if (capable.isEmpty) {
      return PureScaffold(
        appBar: PureAppBar(leading: phoneTab ? const HomeMenuButton() : null, title: t.tabs.areas),
        body: PureEmpty(
          title: t.popular.noPlatforms,
          message: t.popular.noPlatformsHint,
          icon: Icons.apps_outlined,
          action: PureButton(
            label: t.hotAreas.title,
            icon: Icons.visibility_outlined,
            onPressed: () => unawaited(const HotAreasRoute().push<void>(context)),
          ),
        ),
      );
    }
    // The catalogue at every width: platform tabs where the title would be
    // (the reference's shape), category tabs under them for grouped
    // platforms, and a category opens its room route.
    final index = _selected.clamp(0, capable.length - 1);
    // The header's site picker and the wide rail answer the reference's
    // 分区 shape: the platform lives in the header, the follows and the hot
    // categories live beside the catalogue.
    final windowWidth = MediaQuery.sizeOf(context).width;
    final showRail = desktopPagesIn(ref, windowWidth) && windowWidth >= 1100;
    final current = capable[index];
    return PureScaffold(
      appBar: PureAppBar(
        leading: phoneTab ? const HomeMenuButton() : null,
        title: t.tabs.areas,
        titleWidget: SitePickerButton(
          key: const ValueKey('areas-site-picker'),
          sites: capable,
          current: current,
          onSelected: (site) => setState(() {
            _selected = capable.indexWhere((candidate) => candidate.manifest.id == site.manifest.id);
          }),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                PureTabView(
                  index: index,
                  onIndexChanged: (value) => setState(() => _selected = value),
                  pages: [
                    for (var position = 0; position < capable.length; position++)
                      _PlatformAreas(
                        key: ValueKey(capable[position].manifest.id),
                        site: capable[position],
                        active: position == index,
                      ),
                  ],
                ),
                // The followed partitions sit on their own page on the narrow
                // layouts; the wide rail below carries them in place.
                if (!showRail)
                  PositionedDirectional(
                    end: MainLayout.gutterOf(context),
                    bottom: desktopPagesIn(ref, windowWidth) ? 88 : 24,
                    child: PureButton(
                      key: const ValueKey('areas-followed-button'),
                      label: t.areas.followedAreas,
                      icon: Icons.favorite_outline,
                      size: ControlSize.sm,
                      onPressed: () => unawaited(const FollowedAreasRoute().push<void>(context)),
                    ),
                  ),
              ],
            ),
          ),
          if (showRail) _AreasRail(site: current),
        ],
      ),
    );
  }
}

/// One platform's catalogue: its areas, grouped by their parent category.
final class _PlatformAreas extends ConsumerStatefulWidget {
  /// A catalogue for [site].
  const new({required this.site, required this.active, super.key});

  final LiveSite site;

  /// Whether this catalogue's tab is the one on screen; a hidden tab neither
  /// fetches nor ticks — the popular page's `_SiteFeed` semantics.
  final bool active;

  @override
  ConsumerState<_PlatformAreas> createState() => _PlatformAreasState();
}

final class _PlatformAreasState extends ConsumerState<_PlatformAreas>
    with AutomaticKeepAliveClientMixin, FeedAutoRefresh<_PlatformAreas> {
  List<LiveArea>? _areas;
  Object? _error;
  bool _started = false;
  final ScrollController _scroll = ScrollController();

  /// The selected parent category, as the reference's category tab index:
  /// a grouped catalogue shows one group at a time and keeps its selection
  /// (clamped) across refreshes.
  int _selectedGroup = 0;

  /// The shown page and the pager's per-page pick (the reference's local
  /// `_page`/`_pageSize`: numbered pages over the catalogue on wide windows).
  int _page = 1;
  int? _pageSizeOverride;

  /// Whether a catalogue load runs — the pager's busy mark.
  bool _loading = false;

  /// The node the paged mode's ← → keys land on; every platform tab is kept
  /// alive, so the focus is taken on selection rather than by autofocus
  /// alone (`Focus(autofocus:)` only fires when the node first attaches).
  final FocusNode _pagerFocus = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  bool get feedVisible => widget.active;

  @override
  Future<void> feedRefresh() => _load();

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(_PlatformAreas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _maybeLoad();
      // An unattached node ignores the request, which is right off paging.
      _pagerFocus.requestFocus();
    }
  }

  /// A catalogue fetches when its platform first becomes the selected tab —
  /// the popular page's `shouldLoad`: the `IndexedStack` builds every tab at
  /// once, so an ungated first load would ask every site for its catalogue
  /// in the same frame.
  void _maybeLoad() {
    if (_started || !widget.active) {
      return;
    }
    _started = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pagerFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final capability = widget.site.capability<LiveAreaProvider>();
      if (capability == null) {
        return;
      }
      final result = await capability.getAreas();
      if (!mounted) {
        return;
      }
      setState(() {
        result.fold(
          (error) {
            // A refresh over shown tiles keeps them; only a first load surfaces
            // the failure as a full view.
            if (_areas == null) {
              _error = error;
            }
          },
          (areas) {
            _areas = areas;
            // Every catalogue that loads teaches the picture registry, so an
            // area without artwork can borrow one by name.
            AreaPictures.instance.remember(areas);
          },
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _goTo(int page) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final areas = _areas;
    if (areas == null) {
      if (_error != null) {
        return PureError(message: context.t.errors.network, onRetry: _load, retryLabel: context.t.common.retry);
      }
      return const PureLoading();
    }
    // The parent groups, in the order the site presents them; a platform
    // without parents is one group and shows no tab row.
    final groups = <String, List<LiveArea>>{};
    for (final area in areas) {
      final parent = area.parentAreaName ?? '';
      groups.putIfAbsent(parent, () => []).add(area);
    }
    if (areas.isEmpty) {
      return PureEmpty(
        title: context.t.areas.empty,
        icon: Icons.apps_outlined,
        action: PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _load),
      );
    }
    _selectedGroup = _selectedGroup.clamp(0, groups.length - 1);
    final parents = groups.keys.toList(growable: false);
    final selectedParent = parents[_selectedGroup];
    final visible = groups.length > 1 ? groups[selectedParent]! : groups.values.expand((list) => list).toList();
    final gutter = MainLayout.gutterOf(context);
    // The shared paging rule (the reference's `platform_areas_view`): wide
    // windows page the catalogue with numbers, ← → and the settings' size
    // selector and goto; phones and narrow windows keep pull to refresh.
    final windowWidth = MediaQuery.sizeOf(context).width;
    final desktop = desktopPagesIn(ref, windowWidth);
    final preferences = ref.watch(appPreferencesProvider);
    final sizes = pageSizesOf(preferences, windowWidth);
    final pageSize = _pageSizeOverride ?? sizes.size;
    final lastPage = visible.isEmpty ? 1 : (visible.length / pageSize).ceil();
    final page = _page.clamp(1, lastPage);
    final shown = desktop
        ? visible.sublist((page - 1) * pageSize, (page * pageSize).clamp(0, visible.length))
        : visible;

    Widget catalogue(List<LiveArea> areas) => LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = AreaGridMetrics.columnsFor(width);
        const spacing = PureSpacing.sm;
        final itemWidth = (width - 2 * gutter - spacing * (columns - 1)) / columns;
        return GridView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xl),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: AreaGridMetrics.mainAxisExtent(itemWidth, MediaQuery.textScalerOf(context)),
          ),
          itemCount: areas.length,
          itemBuilder: (context, index) {
            final area = areas[index];
            return AreaCard(
              key: ValueKey('${area.platform}:${area.areaId}'),
              area: area,
              onOpen: () => AreaRoomsRoute(
                siteId: area.platform,
                areaId: area.areaId,
                areaName: area.areaName,
              ).push<void>(context),
            );
          },
        );
      },
    );

    final Widget body;
    if (desktop) {
      body = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (page > 1) {
              _goTo(page - 1);
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (page < lastPage) {
              _goTo(page + 1);
            }
          },
        },
        child: Focus(
          focusNode: _pagerFocus,
          autofocus: widget.active,
          child: Column(
            children: [
              Expanded(child: catalogue(shown)),
              PurePaginationBar(
                page: page,
                lastPage: lastPage,
                canNext: page < lastPage,
                busy: _loading,
                pageSize: pageSize,
                pageSizes: preferences.pageShowSizeSelector ? sizes.options : null,
                showGoto: preferences.pageShowGoto,
                onPage: _goTo,
                onPageSize: (size) {
                  // Keep the first tile of the page in view (3.x).
                  final first = (page - 1) * pageSize;
                  setState(() {
                    _pageSizeOverride = size;
                    _page = first ~/ size + 1;
                  });
                },
                onRefresh: () => unawaited(_load()),
              ),
            ],
          ),
        ),
      );
    } else {
      body = CustomRefreshIndicator(
        onRefresh: _load,
        builder: (context, child, indicator) => Stack(
          alignment: Alignment.topCenter,
          children: [
            child,
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              // The bar needs bounded constraints: a Positioned pinned on
              // `top` alone hands its child unbounded constraints, which a
              // progress bar cannot resolve to a size — a kept-alive
              // off-screen tab then crashes the hit test. Pinning the sides
              // and fixing the width keeps the box laid out in every state.
              child: Center(
                child: SizedBox(
                  width: 140,
                  child: Opacity(
                    opacity: indicator.value.clamp(0, 1),
                    child: IgnorePointer(child: PureProgress(value: indicator.isLoading ? null : indicator.value)),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: catalogue(shown),
      );
    }

    return Column(
      children: [
        if (groups.length > 1)
          SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
              child: PureTabs(
                index: _selectedGroup,
                isScrollable: true,
                onChanged: (value) => setState(() => _selectedGroup = value),
                tabs: [for (final parent in parents) PureTab(label: parent.isEmpty ? context.t.tabs.areas : parent)],
              ),
            ),
          ),
        Expanded(child: body),
      ],
    );
  }
}

/// The wide catalogue's side rail (the reference's right column): the
/// followed partitions of this site, the site's biggest categories, and the
/// connection footer. Everything on it opens a room list or moves the
/// catalogue's group tab; nothing here fetches a second copy of what the
/// grid already shows.
final class _AreasRail extends ConsumerWidget {
  /// A rail beside the catalogue of [site].
  const new({required this.site});

  /// The site whose catalogue shows now.
  final LiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = PureTheme.of(context);
    final follows = ref.watch(followedAreasProvider).value ?? const <FollowArea>[];
    final mine = [
      for (final area in follows)
        if (area.platform == site.manifest.id) area,
    ];
    final catalog = ref.watch(areasCatalogProvider(site.manifest.id));
    // The parent categories by how much the site puts in them, biggest first.
    final groups = <String, int>{};
    for (final area in catalog.value ?? const <LiveArea>[]) {
      final parent = area.parentAreaName ?? '';
      groups[parent] = (groups[parent] ?? 0) + 1;
    }
    final hot = (groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    return SizedBox(
      width: 264,
      child: ColoredBox(
        color: theme.colors.bgLayout,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: [
            _RailCard(
              icon: Icons.favorite_outline,
              title: context.t.areas.myFollows,
              badge: '${mine.length}',
              children: mine.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                        child: Text(
                          context.t.areas.noFollowsInSite,
                          style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                        ),
                      ),
                    ]
                  : [
                      for (final area in mine)
                        PureListRow(
                          key: ValueKey('areas-rail-follow-${area.areaId}'),
                          title: area.name,
                          trailing: Icon(Icons.chevron_right, size: 18, color: theme.colors.textSecondary),
                          onTap: () => unawaited(
                            AreaRoomsRoute(
                              siteId: area.platform,
                              areaId: area.areaId,
                              areaName: area.name,
                            ).push<void>(context),
                          ),
                          divided: area != mine.last,
                        ),
                    ],
            ),
            const SizedBox(height: 12),
            _RailCard(
              icon: Icons.local_fire_department_outlined,
              title: context.t.areas.hotGroups,
              children: [
                for (final entry in hot)
                  PureListRow(
                    key: ValueKey('areas-rail-hot-${entry.key}'),
                    title: entry.key.isEmpty ? context.t.tabs.areas : entry.key,
                    subtitle: context.t.areas.areaCount(count: '${entry.value}'),
                    trailing: Icon(Icons.chevron_right, size: 18, color: theme.colors.textSecondary),
                    onTap: () {
                      final areas = catalog.value ?? const <LiveArea>[];
                      final first = areas.isEmpty ? null : areas.first;
                      if (first == null) {
                        return;
                      }
                      unawaited(
                        AreaRoomsRoute(
                          siteId: site.manifest.id,
                          areaId: first.areaId,
                          areaName: entry.key,
                        ).push<void>(context),
                      );
                    },
                    divided: entry != hot.last,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 14, color: theme.colors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.t.areas.connected(site: site.manifest.localizedName(_tag(context), 'zh-CN')),
                      style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}

/// One rail card: a title row with its icon and badge over the rows.
final class _RailCard extends StatelessWidget {
  const new({required this.icon, required this.title, required this.children, this.badge});

  final IconData icon;
  final String title;
  final String? badge;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return PureCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: theme.colors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.text.title)),
                if (badge != null) Text(badge!, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
