import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/areas/controllers/areas_controller.dart';
import 'package:pure_live/modules/live/areas/data/area_follow_repository.dart';
import 'package:pure_live/shared/shared.dart';

/// The areas page (the reference's `AreasPage`): the platforms' own
/// catalogues — one tab per platform, each loaded when its tab first
/// shows and kept while the app runs — beside the followed areas, the
/// segmented control switching between the two views.
final class AreasPage extends ConsumerStatefulWidget {
  /// The areas page.
  const AreasPage({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

/// The two views the segmented control switches between.
enum _AreasView { platform, followed }

final class _AreasPageState extends ConsumerState<AreasPage> with WidgetsBindingObserver {
  _AreasView _view = _AreasView.platform;

  /// When the viewer last left the app, so a long absence refreshes on return.
  DateTime? _backgroundedAt;

  /// Warms the next platform after the viewer settles on this one.
  Timer? _warmTimer;

  /// Whether a platform-display fallback is already waiting for the frame:
  /// one move per hidden selection, not one per build.
  bool _platformFallbackScheduled = false;

  static const Duration _warmDelay = Duration(milliseconds: 800);
  static const Duration _resumeRefreshAfter = Duration(seconds: 15);

  /// One scroll controller per platform (the catalogue grid keeps each
  /// platform's place across tab switches); released with the page.
  final Map<String, ScrollController> _scrolls = {};

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warmTimer?.cancel();
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (away >= _resumeRefreshAfter) {
        unawaited(ref.read(areasCatalogProvider.notifier).refresh(ref.read(areasSiteProvider)));
      }
    }
  }

  /// The platform after the shown one (or before, at the end) loads its
  /// catalogue once the viewer has settled.
  void _armWarmUp() {
    _warmTimer?.cancel();
    final ids = ref.read(areasCatalogProvider.notifier).platformIds();
    if (ids.length < 2) return;
    final index = ids.indexOf(ref.read(areasSiteProvider));
    if (index < 0) return;
    final next = index + 1 < ids.length ? index + 1 : index - 1;
    _warmTimer = Timer(_warmDelay, () {
      if (mounted) unawaited(ref.read(areasCatalogProvider.notifier).warm(ids[next]));
    });
  }

  ScrollController _scrollOf(String platform) => _scrolls[platform] ??= ScrollController();

  /// The shown platform was hidden in the settings while another one is
  /// still visible: move to the first visible one and load its catalogue,
  /// rather than leaving the hidden platform's areas behind an absent tab.
  void _schedulePlatformFallback() {
    if (_platformFallbackScheduled) return;
    _platformFallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _platformFallbackScheduled = false;
      if (!mounted) return;
      final current = ref.read(areasSiteProvider);
      final visible = ref.read(areasCatalogProvider.notifier).platformIds();
      if (visible.isEmpty || visible.contains(current)) return;
      final next = visible.first;
      ref.read(areasSiteProvider.notifier).selected = next;
      unawaited(ref.read(areasCatalogProvider.notifier).open(next));
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The catalogue never loads from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(areasCatalogProvider.notifier).open(ref.read(areasSiteProvider)));
      _armWarmUp();
    });
    ref.listenManual(areasSiteProvider, (_, _) => _armWarmUp());
    // A word from the toolbar searches this page's areas, which the
    // platform view carries.
    ref.listenManual(areasInlineSearchProvider, (_, word) {
      if (word != null && _view != _AreasView.platform) setState(() => _view = _AreasView.platform);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final platform = ref.watch(areasSiteProvider);
    // The platform list and its order are settings this page follows live:
    // watching the notifier alone would leave the tabs stale until another
    // rebuild.
    ref
      ..watch(sitesDisplayProvider)
      ..watch(sitesOrderProvider);
    final ids = ref.watch(areasCatalogProvider.notifier).platformIds();
    // The platform list can change under an open page (the settings hide
    // the shown platform, or a backup restores another display set): move
    // to a visible one instead of showing areas behind an absent tab.
    if (ids.isNotEmpty && !ids.contains(platform)) _schedulePlatformFallback();
    final query = ref.watch(areasInlineSearchProvider);
    final views = DsSegmentedControl<_AreasView>(
      segments: [
        DsSegment(value: _AreasView.platform, label: Text(t.areas.viewPlatform)),
        DsSegment(value: _AreasView.followed, label: Text(t.areas.viewFollowed)),
      ],
      value: _view,
      onChanged: (view) => setState(() => _view = view),
    );
    // The catalogue's tile form: the poster with the picture above its
    // name, or the row with the picture beside it. The areas page's own
    // pair of shapes, so the platform row adds no second layout switch.
    final layoutSwitch = DsSegmentedControl<AreaCardLayout>(
      segments: [
        DsSegment(value: AreaCardLayout.tile, icon: const DsIcon(DsIcons.layoutGrid), semanticLabel: t.areas.iconTop),
        DsSegment(value: AreaCardLayout.row, icon: const DsIcon(DsIcons.layoutList), semanticLabel: t.areas.iconLeft),
      ],
      value: ref.watch(areaLayoutProvider),
      onChanged: (layout) => unawaited(ref.read(areaLayoutProvider.notifier).set(layout)),
    );
    final platformTabs = _view == _AreasView.platform && ids.isNotEmpty
        ? PlatformTabRow(
            platforms: ids,
            current: platform,
            nameOf: _platformName,
            semanticLabel: t.areas.allAreas,
            // The catalogue's own layout switch is the page's, so the row
            // keeps its two controls: the tabs and the platform wall.
            showLayoutToggle: false,
            // The panel's way to the hide/reorder setting.
            onManagePlatforms: () =>
                unawaited(context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location)),
            onChanged: (id) {
              ref.read(areasSiteProvider.notifier).selected = id;
              unawaited(ref.read(areasCatalogProvider.notifier).open(id));
              _armWarmUp();
            },
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The platform tabs take the row's leftover width — the
              // popular page's measure — so names read whole. Only a narrow
              // window stacks them under the view switch.
              if (constraints.maxWidth >= 720) {
                return SizedBox(
                  height: 44,
                  child: Row(
                    spacing: DsSpace.s12,
                    children: [
                      views,
                      if (platformTabs != null) Expanded(child: platformTabs) else const Spacer(),
                      layoutSwitch,
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s8,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [views, layoutSwitch]),
                  ?platformTabs,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: _view == _AreasView.platform
              ? (ids.isEmpty
                    ? Center(
                        child: DsEmptyState(
                          icon: const DsIcon(DsIcons.antenna),
                          title: Text(t.areas.noPlatforms),
                          actions: [
                            DsButton(
                              variant: DsButtonVariant.secondary,
                              size: DsSize.sm,
                              leading: const DsIcon(DsIcons.antenna, size: 16),
                              onPressed: () => unawaited(
                                context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location),
                              ),
                              child: Text(t.settings.sitesDisplay),
                            ),
                          ],
                        ),
                      )
                    : _PlatformAreas(
                        key: ValueKey('areas-$platform'),
                        platform: platform,
                        scrollController: _scrollOf(platform),
                        query: query,
                      ))
              : const _FollowedAreas(),
        ),
      ],
    );
  }

  String _platformName(String id) {
    final site = ref.watch(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }
}

/// The catalogue tile's width over height in each form: the poster is nearly
/// square, the row keeps its wide band.
double _areaAspect(AreaCardLayout layout) => layout == AreaCardLayout.tile ? 0.86 : 3.4;

/// The widest a poster tile gets; the window fits as many as it can side by
/// side.
const double _areaTileWidth = 170;

/// One platform's areas catalogue: the platform's secondary category tabs
/// (the reference's category row) over the card grid. A category the
/// platform does not nest leaves the row away.
final class _PlatformAreas extends ConsumerStatefulWidget {
  const _PlatformAreas({required this.platform, this.scrollController, this.query, super.key});

  /// The platform whose areas show.
  final String platform;

  /// The kept controller of this platform's tab.
  final ScrollController? scrollController;

  /// The toolbar's word, when the page is searching its areas; null browses
  /// the catalogue by category.
  final String? query;

  @override
  ConsumerState<_PlatformAreas> createState() => _PlatformAreasState();
}

final class _PlatformAreasState extends ConsumerState<_PlatformAreas> {
  /// The chosen parent category id, '' for every area.
  String _category = '';

  /// Moves the category tab one step, wrapping at both ends; a swipe left
  /// goes forward, a swipe right back.
  void _stepCategory(List<(String, String)> categories, int delta) {
    final order = ['', for (final (id, _) in categories) id];
    final index = order.indexOf(_category);
    final next = order[(index + delta) % order.length];
    if (next == _category) return;
    setState(() => _category = next);
    if (widget.scrollController?.hasClients ?? false) widget.scrollController!.jumpTo(0);
  }

  @override
  void didUpdateWidget(_PlatformAreas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      // A new word starts its results at their head, as the room search's
      // feed does.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (widget.scrollController?.hasClients ?? false)) widget.scrollController!.jumpTo(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(areasCatalogProvider.notifier);
    final catalog = ref.watch(areasCatalogProvider.select((map) => map[widget.platform]));
    final settings = ref.watch(browseSettingsProvider);
    final tileLayout = ref.watch(areaLayoutProvider);
    final followed = ref.watch(followedAreasProvider);
    final followedKeys = {for (final area in followed.areas) area.identityKey};
    final state = catalog ?? (areas: const <LiveArea>[], loading: false, error: null);
    // The platform's own nesting: first-seen order, unique parents.
    final categories = <(String, String)>[];
    for (final area in state.areas) {
      final id = area.parentAreaId;
      final name = area.parentAreaName;
      if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
      if (!categories.any((category) => category.$1 == id)) categories.add((id, name));
    }
    final query = widget.query;
    final searching = query != null && query.isNotEmpty;
    final site = ref.watch(sitesProvider).getById(widget.platform);
    final platformName = site == null ? widget.platform : localizedSiteName(site);
    final category = categories.any((entry) => entry.$1 == _category) ? _category : '';
    // A search reads the whole platform catalogue, not only the shown
    // category: the word names the area the viewer wants, wherever the
    // platform nests it.
    final items = searching
        ? _matchingAreas(state.areas, query)
        : category.isEmpty
        ? state.areas
        : [
            for (final area in state.areas)
              if (area.parentAreaId == category) area,
          ];
    Widget cardBuilder(BuildContext context, LiveArea area) {
      final followed = followedKeys.contains(area.identityKey);
      void open() => unawaited(
        context.push(
          AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location,
          extra: area,
        ),
      );
      void toggle() => unawaited(ref.read(followedAreasProvider.notifier).toggle(area));
      return DsContextMenuRegion(
        semanticLabel: context.t.common.more,
        items: _areaMenuItems(context, followed: followed, onOpen: open, onToggle: toggle),
        child: AreaCard(
          area: area,
          filled: true,
          layout: tileLayout,
          onPressed: open,
          // The heart is the followed state, not an offer — the room card's
          // rule: an area the viewer does not follow says nothing there and
          // is followed from the card's menu instead.
          trailing: followed ? AreaFollowButton(followed: true, onPressed: toggle) : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            // The toolbar's word as the kit's callout: what is being
            // searched and the way back to the catalogue.
            child: DsAlert(
              title: Text(context.t.areas.searchAt(platform: platformName, query: query)),
              action: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.x, size: 14),
                onPressed: () => ref.read(areasInlineSearchProvider.notifier).clear(),
                child: Text(context.t.areas.backToBrowse),
              ),
            ),
          )
        else if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DsTabs<String>(
                value: category,
                onChanged: (value) => setState(() => _category = value),
                tabs: [
                  DsTab<String>(value: '', label: Text(context.t.areas.categoryAll)),
                  for (final (id, name) in categories) DsTab<String>(value: id, label: Text(name)),
                ],
              ),
            ),
          ),
        Expanded(
          // A horizontal swipe changes the category tab: the reference's
          // category pager, without moving the platform's own tab.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: searching || categories.isEmpty
                ? null
                : (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() < 240) return;
                    _stepCategory(categories, velocity < 0 ? 1 : -1);
                  },
            child: CardGrid<LiveArea>(
              scrollController: widget.scrollController,
              items: items,
              crossSpacing: settings.crossSpacing,
              mainSpacing: settings.mainSpacing,
              aspectRatio: _areaAspect(tileLayout),
              // Poster tiles are small: their own measure fits several
              // across a window, while the row keeps the feed's card width.
              cardExtent: tileLayout == AreaCardLayout.tile ? _areaTileWidth : null,
              isLoading: state.loading,
              error: state.error?.message,
              onRetry: () => controller.refresh(widget.platform),
              // A pull reloads the catalogue; a failure keeps the areas and
              // is explained in the bar over them.
              onRefresh: () => controller.refresh(widget.platform),
              refreshError: state.error?.message,
              emptyIcon: searching ? DsIcons.searchX : DsIcons.layoutGrid,
              emptyTitle: searching ? context.t.areas.searchEmpty : context.t.areas.noAreas,
              itemBuilder: cardBuilder,
            ),
          ),
        ),
      ],
    );
  }
}

/// The followed areas: the areas the viewer follows, the platform they
/// belong to named under each one; pressing the heart unfollows.
final class _FollowedAreas extends ConsumerWidget {
  const _FollowedAreas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final followed = ref.watch(followedAreasProvider);
    final settings = ref.watch(browseSettingsProvider);
    final tileLayout = ref.watch(areaLayoutProvider);
    if (!followed.ready) {
      return CardGrid<LiveArea>(
        items: const [],
        crossSpacing: settings.crossSpacing,
        mainSpacing: settings.mainSpacing,
        aspectRatio: _areaAspect(tileLayout),
        cardExtent: tileLayout == AreaCardLayout.tile ? _areaTileWidth : null,
        isLoading: true,
        itemBuilder: (_, _) => const SizedBox.shrink(),
      );
    }
    if (followed.areas.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.heart),
          title: Text(t.areas.followedEmpty),
          description: Text(t.areas.followedEmptyHint),
        ),
      );
    }
    Widget cardBuilder(BuildContext context, LiveArea area) => _FollowedAreaCard(
      area: area,
      layout: tileLayout,
      onUnfollow: () => unawaited(ref.read(followedAreasProvider.notifier).remove(area.identityKey)),
      onSelect: () => unawaited(
        context.push(
          AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location,
          extra: area,
        ),
      ),
    );
    return CardGrid<LiveArea>(
      items: followed.areas,
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      aspectRatio: _areaAspect(tileLayout),
      cardExtent: tileLayout == AreaCardLayout.tile ? _areaTileWidth : null,
      itemBuilder: cardBuilder,
    );
  }
}

/// The followed area's card: the area card with an active heart that
/// unfollows on press.
final class _FollowedAreaCard extends StatelessWidget {
  const _FollowedAreaCard({required this.area, required this.layout, required this.onUnfollow, required this.onSelect});

  final LiveArea area;
  final AreaCardLayout layout;
  final VoidCallback onUnfollow;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return DsContextMenuRegion(
      semanticLabel: context.t.common.more,
      items: _areaMenuItems(context, followed: true, onOpen: onSelect, onToggle: onUnfollow),
      child: AreaCard(
        area: area,
        filled: true,
        layout: layout,
        onPressed: onSelect,
        trailing: AreaFollowButton(followed: true, onPressed: onUnfollow),
      ),
    );
  }
}

/// Areas of [areas] whose name, short name or parent category matches
/// [query]: every space-separated word must be found, case ignored, and
/// each area appears once.
List<LiveArea> _matchingAreas(Iterable<LiveArea> areas, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return areas.toList();
  final seen = <String>{};
  return [
    for (final area in areas)
      if (words.every(
            (word) =>
                '${area.areaName} ${area.shortName ?? ''} ${area.parentAreaName ?? ''}'.toLowerCase().contains(word),
          ) &&
          seen.add(area.identityKey))
        area,
  ];
}

/// An area card's menu, the room card's in its own words: open the area's
/// rooms, then follow it or let it go.
List<Widget> _areaMenuItems(
  BuildContext context, {
  required bool followed,
  required VoidCallback onOpen,
  required VoidCallback onToggle,
}) {
  final t = context.t;
  return [
    DsMenuItem(leading: const DsIcon(DsIcons.layoutGrid), label: Text(t.areas.open), onPressed: onOpen),
    DsMenuItem(
      leading: DsIcon(followed ? DsIcons.heartCrack : DsIcons.heart),
      label: Text(followed ? t.areas.unfollow : t.areas.follow),
      destructive: followed,
      onPressed: onToggle,
    ),
  ];
}
