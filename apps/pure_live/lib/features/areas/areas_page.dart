import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaProvider, LiveSite;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/areas/areas_routes.dart';
import 'package:pure_live/app/shell/main_layout.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/features/area_rooms/area_rooms_view.dart' show AreaRoomsView, RoomSort;
import 'package:pure_live/features/areas/area_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart' show FeedAutoRefresh;
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
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
    final sites = ref.watch(sitesProvider);
    final capable = sites.registry.all.where((site) => site.capability<LiveAreaProvider>() != null).toList();
    if (capable.isEmpty) {
      return MainPageFrame(
        title: context.t.tabs.areas,
        actions: const [SettingsEntryButton()],
        body: PureEmpty(title: context.t.common.empty),
      );
    }
    // From the expanded class up the page is a master-detail: sites and their
    // areas as one context column, the chosen area's rooms embedded beside it.
    // Below it, the catalogue: platform tabs over grouped area tiles, and a
    // category opens its room route.
    if (AdaptiveBreakpoints.of(context).isAtLeastExpanded) {
      return _AreasMasterDetail(sites: capable, initialSite: _selected);
    }
    final index = _selected.clamp(0, capable.length - 1);
    return MainPageFrame(
      title: context.t.tabs.areas,
      actions: const [SettingsEntryButton()],
      tabs: [for (final site in capable) PureTab(label: site.manifest.localizedName(_tag(context), 'zh-CN'))],
      tabIndex: index,
      onTabChanged: (value) => setState(() => _selected = value),
      body: PureTabView(
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

  /// The selected parent category, as the reference's category tab index:
  /// a grouped catalogue shows one group at a time and keeps its selection
  /// (clamped) across refreshes.
  int _selectedGroup = 0;

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

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
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
    return Column(
      children: [
        if (groups.length > 1)
          SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
              child: PureTabs(
                index: _selectedGroup,
                onChanged: (value) => setState(() => _selectedGroup = value),
                tabs: [for (final parent in parents) PureTab(label: parent.isEmpty ? context.t.tabs.areas : parent)],
              ),
            ),
          ),
        Expanded(
          child: CustomRefreshIndicator(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = AreaGridMetrics.columnsFor(width);
                const spacing = PureSpacing.sm;
                final itemWidth = (width - 2 * gutter - spacing * (columns - 1)) / columns;
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xl),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: AreaGridMetrics.mainAxisExtent(itemWidth, MediaQuery.textScalerOf(context)),
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final area = visible[index];
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
            ),
          ),
        ),
      ],
    );
  }
}

/// The desktop areas arrangement: sites and their areas in one context
/// column, the chosen area's rooms embedded beside it.
///
/// The catalogue state (areas per site, grouped by parent) is loaded here
/// rather than inside the tiles, because the pane and the detail read the
/// same answer: the pane lists the areas, the detail shows one's rooms.
final class _AreasMasterDetail extends ConsumerStatefulWidget {
  const new({required this.sites, required this.initialSite});

  /// Every area-capable platform.
  final List<LiveSite> sites;

  /// The site index the tabbed form had selected, honoured on first build.
  final int initialSite;

  @override
  ConsumerState<_AreasMasterDetail> createState() => _AreasMasterDetailState();
}

final class _AreasMasterDetailState extends ConsumerState<_AreasMasterDetail> {
  late int _siteIndex = widget.initialSite.clamp(0, widget.sites.length - 1);
  List<LiveArea>? _areas;
  Object? _error;
  LiveArea? _selectedArea;
  RoomSort _sort = RoomSort.platform;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  LiveSite get _site => widget.sites[_siteIndex];

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    final capability = _site.capability<LiveAreaProvider>();
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
          if (_areas == null) {
            _error = error;
          }
        },
        (areas) {
          _areas = areas;
          // A dropped area selection follows the catalogue: whatever the
          // refresh did, the detail shows an area the site still lists.
          final kept = _selectedArea;
          _selectedArea = kept == null
              ? null
              : areas.where((area) => area.platform == kept.platform && area.areaId == kept.areaId).firstOrNull;
        },
      );
    });
  }

  void _selectSite(int index) {
    if (index == _siteIndex) {
      return;
    }
    setState(() {
      _siteIndex = index;
      _areas = null;
      _selectedArea = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final areas = _areas;
    return MainPageFrame(
      title: context.t.tabs.areas,
      actions: [
        if (_selectedArea != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _SortToggle(sort: _sort, onChanged: (value) => setState(() => _sort = value)),
          ),
        const SettingsEntryButton(),
      ],
      pane: _AreasPane(
        sites: widget.sites,
        selectedSiteId: _site.manifest.id,
        onSiteSelected: (site) => _selectSite(widget.sites.indexOf(site)),
        areas: areas,
        error: _error,
        onRetry: _load,
        selectedArea: _selectedArea,
        onAreaSelected: (area) => setState(() => _selectedArea = area),
      ),
      body: _selectedArea == null
          ? PureEmpty(
              title: context.t.areas.empty,
              icon: Icons.apps_outlined,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PureSpacing.md,
                    PureSpacing.xs,
                    PureSpacing.md,
                    PureSpacing.sm,
                  ),
                  child: Text(
                    _selectedArea!.areaName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PureTheme.of(context).text.title,
                  ),
                ),
                Expanded(
                  child: AreaRoomsView(
                    key: ValueKey('${_selectedArea!.platform}:${_selectedArea!.areaId}'),
                    siteId: _selectedArea!.platform,
                    areaId: _selectedArea!.areaId,
                    areaName: _selectedArea!.areaName,
                    sort: _sort,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The master-detail context column: the site switcher, then the chosen
/// site's areas grouped by parent - the tile catalogue's tree, re-embodied as
/// navigation tiles.
final class _AreasPane extends StatelessWidget {
  const new({
    required this.sites,
    required this.selectedSiteId,
    required this.onSiteSelected,
    required this.areas,
    required this.error,
    required this.onRetry,
    required this.selectedArea,
    required this.onAreaSelected,
  });

  final List<LiveSite> sites;
  final String selectedSiteId;
  final ValueChanged<LiveSite> onSiteSelected;
  final List<LiveArea>? areas;
  final Object? error;
  final VoidCallback onRetry;
  final LiveArea? selectedArea;
  final ValueChanged<LiveArea> onAreaSelected;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (final site in sites)
        PureNavigationTile(
          destination: PureNavDestination(
            id: site.manifest.id,
            label: site.manifest.localizedName(
              Localizations.localeOf(context).toLanguageTag(),
              'zh-CN',
            ),
            icon: Icons.live_tv_outlined,
          ),
          selected: site.manifest.id == selectedSiteId,
          onTap: () => onSiteSelected(site),
        ),
    ];

    final areaList = areas;
    if (areaList == null) {
      if (error != null) {
        tiles.add(
          Padding(
            padding: const EdgeInsets.only(top: PureSpacing.sm),
            child: PureError(message: context.t.errors.network, onRetry: onRetry, retryLabel: context.t.common.retry),
          ),
        );
      } else {
        tiles.add(const Padding(padding: EdgeInsets.only(top: PureSpacing.sm), child: PureLoading()));
      }
      return ListView(padding: const EdgeInsets.symmetric(vertical: PureSpacing.xs), children: tiles);
    }

    // Areas grouped by parent, in the site's own order; the first area of
    // each parent group carries the divider the wide column shows.
    final seenParents = <String>{};
    for (final area in areaList) {
      final parent = area.parentAreaName ?? '';
      final startsGroup = seenParents.add(parent);
      final grouped = startsGroup && seenParents.length > 1;
      tiles.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (grouped)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: PureSpacing.xs),
                child: Divider(height: 1, color: PureTheme.of(context).colors.border),
              ),
            PureNavigationTile(
              destination: PureNavDestination(
                id: '${area.platform}:${area.areaId}',
                label: area.areaName,
                icon: Icons.category_outlined,
                startsGroup: grouped,
              ),
              selected: selectedArea?.platform == area.platform && selectedArea?.areaId == area.areaId,
              onTap: () => onAreaSelected(area),
            ),
          ],
        ),
      );
    }
    return ListView(padding: const EdgeInsets.symmetric(vertical: PureSpacing.xs), children: tiles);
  }
}

/// The room sort the detail header carries, rendered only when a room list is
/// on screen.
final class _SortToggle extends StatelessWidget {
  const new({required this.sort, required this.onChanged});

  final RoomSort sort;
  final ValueChanged<RoomSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PureSegmented(
      labels: [context.t.room.sortPlatform, context.t.room.sortViewers],
      index: sort == RoomSort.platform ? 0 : 1,
      onChanged: (index) => onChanged(index == 0 ? RoomSort.platform : RoomSort.viewers),
    );
  }
}
