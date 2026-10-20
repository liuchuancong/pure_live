import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaProvider, LiveSite;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/shell/main_layout.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/features/areas/area_card.dart';
import 'package:pure_live/features/hot_areas/hot_areas_page.dart' show HotAreasPage;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/rooms/paging.dart';
import 'package:pure_live/shared/widgets/list_loading.dart' show FeedAutoRefresh;
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

  @override
  Widget build(BuildContext context) {
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
    final capable = HotAreasPage.orderedSites(
      sites,
      preferences.siteOrder,
    ).where((site) => !preferences.hiddenSiteIds.contains(site.manifest.id)).toList();
    final phoneTab = MainPageFrame.showsHomeBarButtons(context, inHome: true);
    if (capable.isEmpty) {
      return PureScaffold(
        appBar: PureAppBar(
          leading: phoneTab ? const HomeMenuButton() : null,
          title: t.tabs.areas,
          actions: phoneTab ? const [CommonAppBarActions()] : const [],
        ),
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
    return PureScaffold(
      appBar: PureAppBar(
        leading: phoneTab ? const HomeMenuButton() : null,
        title: t.tabs.areas,
        titleWidget: PureTabs(
          tabs: [for (final site in capable) PureTab(label: site.manifest.localizedName(_tag(context), 'zh-CN'))],
          index: index,
          isScrollable: true,
          onChanged: (value) => setState(() => _selected = value),
        ),
        actions: phoneTab ? const [CommonAppBarActions()] : const [],
      ),
      body: Stack(
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
          // The followed partitions sit on their own page, so the way in
          // rides along with the catalogue (the reference's floating pill).
          // Wide windows are spending their bottom edge on the pager.
          PositionedDirectional(
            end: MainLayout.gutterOf(context),
            bottom: desktopPagesIn(ref, MediaQuery.sizeOf(context).width) ? 88 : 24,
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
    );
  }

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}

/// One platform's catalogue: its areas, grouped by their parent category.
final class _PlatformAreas extends ConsumerStatefulWidget {
  /// A catalogue for [site].
  const new({required this.site, required this.active, super.key});

  final LiveSite site;

  /// Whether this catalogue's tab is the one on screen; hidden tabs skip
  /// their refresh ticks — the popular page's `_SiteFeed` semantics.
  final bool active;

  @override
  ConsumerState<_PlatformAreas> createState() => _PlatformAreasState();
}

final class _PlatformAreasState extends ConsumerState<_PlatformAreas>
    with AutomaticKeepAliveClientMixin, FeedAutoRefresh<_PlatformAreas> {
  List<LiveArea>? _areas;
  Object? _error;
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
    unawaited(_load());
  }

  @override
  void didUpdateWidget(_PlatformAreas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      // An unattached node ignores the request, which is right off paging.
      _pagerFocus.requestFocus();
    }
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
