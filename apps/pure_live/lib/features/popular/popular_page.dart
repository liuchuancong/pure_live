import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute, SettingsSectionRoute;
import 'package:pure_live/features/popular/popular_controller.dart';
import 'package:pure_live/features/popular/room_card.dart' show RoomCard;
import 'package:pure_live/features/search/search_controller.dart';
import 'package:pure_live/features/settings/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/paging/room_paging.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteName;
import 'package:pure_live/shared/platforms/platform_picker.dart';

/// How a platform's rooms are ordered on screen: the platform's own
/// recommendation or the largest audience first. The order is local — the
/// catalogue is already in hand, so switching never refetches.
enum _PopularSort { platform, audience }

/// One platform's audience figure for the sort: the shown metric's figure,
/// else any figure the source gave, else zero.
int _audienceRank(LiveRoom room) =>
    room.audience.onlineViewers ?? room.audience.popularity ?? room.audience.totalViewers ?? 0;

/// [rooms] in [sort]'s order; the platform's own order is left untouched,
/// and the audience order is stable (ties keep the platform's order).
List<LiveRoom> _sortedRooms(List<LiveRoom> rooms, _PopularSort sort) {
  if (sort == _PopularSort.platform) return rooms;
  final indexed = rooms.indexed.toList()
    ..sort((a, b) {
      final byAudience = _audienceRank(b.$2).compareTo(_audienceRank(a.$2));
      return byAudience != 0 ? byAudience : a.$1.compareTo(b.$1);
    });
  return [for (final (_, room) in indexed) room];
}

/// The popular page (the reference's `PopularPage`): one tab per platform
/// of the discovery-capable sites, each tab holding its own paged feed of
/// recommendations — the feeds stay while the app runs, so switching tabs
/// never refetches; the ⌄ at the tabs' end opens every platform in a menu.
///
/// A platform without recommendations says so in the feed's place instead
/// of failing silently.
final class PopularPage extends ConsumerStatefulWidget {
  /// The popular page.
  const PopularPage({super.key});

  @override
  ConsumerState<PopularPage> createState() => _PopularPageState();
}

final class _PopularPageState extends ConsumerState<PopularPage> with WidgetsBindingObserver {
  /// One scroll controller per platform, kept while the page lives: a
  /// platform left and returned to lands where the viewer left it (the
  /// reference's TabBarView behaviour).
  final Map<String, ScrollController> _scrolls = {};

  /// Platform display names, built once per build from the registry
  /// instead of a linear lookup per tab.
  Map<String, String> get _names => {
    for (final site in ref.watch(sitesProvider).all) site.manifest.id: localizedSiteName(site),
  };

  /// How long the viewer looks at a platform before the next one warms.
  static const Duration _warmDelay = Duration(milliseconds: 700);

  /// A return from the background after this long refreshes the shown
  /// platform (the reference's resume rule).
  static const Duration _resumeRefreshAfter = Duration(seconds: 15);

  Timer? _warmTimer;
  DateTime? _backgroundedAt;

  /// The local order of each platform's rooms.
  _PopularSort _sort = _PopularSort.platform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The feed never loads from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(popularCatalogProvider.notifier).open(ref.read(popularSiteProvider)));
      _armWarmUp();
    });
    // A platform chosen elsewhere (the tabs) re-arms the warm-up; the
    // listen lands outside build, where a timer belongs.
    ref.listenManual(popularSiteProvider, (_, _) => _armWarmUp());
  }

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

  ScrollController _scrollOf(String platform) => _scrolls[platform] ??= ScrollController();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (away >= _resumeRefreshAfter) {
        unawaited(ref.read(popularCatalogProvider.notifier).refresh(ref.read(popularSiteProvider)));
      }
    }
  }

  /// The tab after the shown one (or the one before, at the end) warms its
  /// first page once the viewer has settled on this one.
  void _armWarmUp() {
    _warmTimer?.cancel();
    final ids = ref.read(popularCatalogProvider.notifier).platformIds();
    if (ids.length < 2) return;
    final index = ids.indexOf(ref.read(popularSiteProvider));
    if (index < 0) return;
    final next = index + 1 < ids.length ? index + 1 : index - 1;
    _warmTimer = Timer(_warmDelay, () {
      if (!mounted) return;
      unawaited(ref.read(popularCatalogProvider.notifier).warm(ids[next]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final platform = ref.watch(popularSiteProvider);
    final inline = ref.watch(popularInlineSearchProvider);
    // An inline search (the toolbar's word) takes the page: the platform's
    // own results grid under a search bar, browsing one keypress away.
    // The platform is watched, not frozen, so a tab switch during the
    // search re-runs it there.
    if (inline != null) {
      return _InlineSearchFeed(platform: platform, query: inline);
    }
    final ids = ref.watch(popularCatalogProvider.notifier).platformIds();
    if (ids.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.tv),
          title: Text(t.common.empty),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.antenna, size: 16),
              onPressed: () =>
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.sites.name).location)),
              child: Text(t.settings.sitesDisplay),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: PlatformTabRow(
                  platforms: ids,
                  current: platform,
                  nameOf: _platformName,
                  semanticLabel: t.navigation.hot,
                  onChanged: (id) {
                    ref.read(popularSiteProvider.notifier).selected = id;
                    unawaited(ref.read(popularCatalogProvider.notifier).open(id));
                  },
                ),
              ),
              const SizedBox(width: DsSpace.s12),
              SizedBox(
                width: 148,
                child: DsSelect<_PopularSort>(
                  value: _sort,
                  onChanged: (value) {
                    if (value == null || value == _sort) return;
                    setState(() => _sort = value);
                    final controller = _scrolls[platform];
                    if (controller?.hasClients ?? false) controller!.jumpTo(0);
                  },
                  options: [
                    DsSelectOption(value: _PopularSort.platform, label: t.popular.sortPlatform),
                    DsSelectOption(value: _PopularSort.audience, label: t.popular.sortAudience),
                  ],
                  placeholder: t.popular.sortLabel,
                  semanticLabel: t.popular.sortLabel,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _PlatformFeed(
            key: ValueKey(platform),
            platform: platform,
            sort: _sort,
            scrollController: _scrollOf(platform),
          ),
        ),
      ],
    );
  }

  String _platformName(String id) => _names[id] ?? id;
}

/// One platform's feed: the home feed's own card grid over the catalogue's
/// entry for [platform].
final class _PlatformFeed extends ConsumerWidget {
  const _PlatformFeed({required this.platform, required this.sort, this.scrollController, super.key});

  /// The platform whose recommendations show.
  final String platform;

  /// The local order the page's selector chose.
  final _PopularSort sort;

  /// The kept controller of this platform's tab (see the page's state).
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(popularCatalogProvider.notifier);
    final feed = ref.watch(popularCatalogProvider.select((catalog) => catalog[platform]));
    final settings = ref.watch(browseSettingsProvider);
    final state =
        feed ??
        (
          rooms: const <LiveRoom>[],
          page: 1,
          pageSize: settings.homePageSize,
          hasMore: true,
          loading: false,
          error: null,
        );
    // The viewer may change the display page size anywhere; re-measure the
    // open catalogue (the first room of the page stays in view) and do the
    // same for a tab that was loaded under another size.
    ref.listen(browseSettingsProvider.select((s) => s.homePageSize), (previous, next) {
      if (previous != next) {
        if (scrollController?.hasClients ?? false) scrollController!.jumpTo(0);
        unawaited(controller.resize(platform, next));
      }
    });
    if (state.pageSize != settings.homePageSize && !state.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(controller.resize(platform, settings.homePageSize));
      });
    }
    final wide = MediaQuery.sizeOf(context).width >= 768;
    // The chosen order is applied to the catalogue before the desktop
    // slices it, so a page holds the right rooms rather than a reordered
    // window of one page.
    final ordered = _sortedRooms(state.rooms, sort);
    // Desktop pages slice the platform catalogue locally, so fixed-window
    // platforms (Douyu 40, Huya ~120) and asked-size ones page the same
    // way, and the viewer's page size never moves a server boundary.
    final rooms = wide ? roomPageOf(ordered, state.page, state.pageSize) : ordered;
    final grid = CardGrid<LiveRoom>(
      scrollController: scrollController,
      items: rooms,
      layout: ref.watch(browseLayoutProvider),
      listItemBuilder: (context, room) => RoomCard(
        room: room,
        compact: true,
        onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
      ),
      cardExtent: settings.homeCardExtent,
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: state.loading,
      // The desktop grid holds exactly one page: the pager fetches the
      // next one, not the grid's end.
      hasMore: !wide && state.hasMore,
      onLoadMore: wide ? null : () => controller.loadMore(platform),
      error: state.error?.message,
      onRetry: () => controller.refresh(platform),
      // A pull reloads the first page; a failure keeps the rooms and is
      // explained in the bar over them.
      onRefresh: () => controller.refresh(platform),
      refreshError: state.error?.message,
      itemBuilder: (context, room) => RoomCard(
        room: room,
        onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
      ),
    );
    // A wide window pages by number (the reference's desktop feed) — the
    // kit's pagination: numbers with gaps, arrows at the ends; a narrow
    // one keeps the infinite scroll, thumbs do not page. The count is the
    // local slices plus one while the platform may still have rooms.
    if (!wide) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: grid),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                SizedBox(
                  width: 108,
                  child: DsSelect<int>(
                    value: state.pageSize,
                    onChanged: state.loading
                        ? null
                        : (value) {
                            if (value != null) ref.read(browseSettingsProvider.notifier).homePageSize = value;
                          },
                    options: [
                      for (final size in const [20, 30, 40, 60, 80])
                        DsSelectOption(value: size, label: t.popular.pageSize(size: size)),
                    ],
                    placeholder: t.popular.perPage,
                    semanticLabel: t.popular.perPage,
                  ),
                ),
                if (state.loading) const SizedBox(width: 14, height: 14, child: DsSpinner()),
                DsPagination(
                  page: state.page,
                  pageCount: pageCountOf(state),
                  onChanged: state.loading
                      ? null
                      : (next) {
                          // A new page starts at its head, as desktop pagers do.
                          if (scrollController?.hasClients ?? false) scrollController!.jumpTo(0);
                          unawaited(controller.loadPage(platform, next));
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The popular page's inline search results: the search controller runs
/// over the browsed platform (rooms), the results as the feed's own card
/// grid, the search bar above naming the word and the platform with the
/// way back.
final class _InlineSearchFeed extends ConsumerStatefulWidget {
  const _InlineSearchFeed({required this.platform, required this.query});

  /// The platform whose rooms are searched (the browsed one).
  final String platform;

  /// The word handed by the toolbar.
  final String query;

  @override
  ConsumerState<_InlineSearchFeed> createState() => _InlineSearchFeedState();
}

final class _InlineSearchFeedState extends ConsumerState<_InlineSearchFeed> {
  /// The desktop page shown, a local slice of the accumulated results.
  int _page = 1;

  /// The size the page number is measured in; the viewer's display size,
  /// never a server page size.
  int _pageSize = 0;

  /// The results grid's scroll position across page jumps.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageSize = ref.read(browseSettingsProvider).homePageSize;
    // The search runs on arrival (and on a re-word, when the widget is
    // rebuilt by the provider) — pinned to the browsed platform.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_InlineSearchFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.platform != widget.platform) {
      _page = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
    }
  }

  /// Runs the search from page 1 and fills the first display page.
  Future<void> _run() async {
    if (!mounted) return;
    ref.read(searchSiteIdProvider.notifier).selected = widget.platform;
    await ref.read(searchProvider.notifier).search(widget.query);
    if (!mounted) return;
    _pageSize = ref.read(browseSettingsProvider).homePageSize;
    await _ensurePage();
  }

  /// Fetches whatever the shown page of [_pageSize] hits still needs, then
  /// clamps the local page when the walk ended short.
  Future<void> _ensurePage() async {
    if (!mounted) return;
    await ref.read(searchProvider.notifier).ensureResultsFor(page: _page, pageSize: _pageSize);
    if (!mounted) return;
    final search = ref.read(searchProvider);
    if (!search.hasMore) {
      final last = roomLastPage(search.rooms.length, _pageSize);
      if (_page > last) setState(() => _page = last);
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final search = ref.watch(searchProvider);
    final settings = ref.watch(browseSettingsProvider);
    // A changed display size re-measures the page around its first room and
    // fills it if the new page reaches past what is accumulated.
    if (_pageSize != settings.homePageSize && _pageSize > 0) {
      final first = (_page - 1) * _pageSize;
      _page = first ~/ settings.homePageSize + 1;
      _pageSize = settings.homePageSize;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_ensurePage()));
    } else if (_pageSize == 0) {
      _pageSize = settings.homePageSize;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              DsIcon(DsIcons.search, size: 16, color: colors.textMuted),
              Expanded(
                child: Text(
                  t.popular.inlineAt(platform: _platformName(), query: widget.query),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.text),
                ),
              ),
              if (search.loading) const SizedBox(width: 14, height: 14, child: DsSpinner()),
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => ref.read(popularInlineSearchProvider.notifier).clear(),
                leading: const DsIcon(DsIcons.x, size: 14),
                child: Text(t.popular.backToBrowse),
              ),
            ],
          ),
        ),
        Expanded(child: _pagedResults(context, search, settings)),
      ],
    );
  }

  /// The results grid; a wide window pages it by number exactly like the
  /// browse feed, a narrow one scrolls forever. The pages are local slices
  /// of the accumulated results, so the viewer's page size never moves a
  /// server page boundary.
  Widget _pagedResults(BuildContext context, SearchState search, BrowseSettings settings) {
    final t = context.t;
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final page = wide ? _page : 1;
    final pageSize = settings.homePageSize;
    final rooms = wide ? roomPageOf(search.rooms, page, pageSize) : search.rooms;
    final grid = CardGrid<LiveRoom>(
      scrollController: _scroll,
      items: rooms,
      layout: ref.watch(browseLayoutProvider),
      listItemBuilder: (context, room) => RoomCard(
        room: room,
        compact: true,
        onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
      ),
      cardExtent: settings.homeCardExtent,
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: search.loading,
      // The desktop grid holds one local page; its pager fetches the rest.
      hasMore: !wide && search.hasMore,
      onLoadMore: wide ? null : () => ref.read(searchProvider.notifier).loadMore(),
      error: search.error?.message,
      onRetry: () => ref.read(searchProvider.notifier).retry(),
      emptyIcon: DsIcons.searchX,
      emptyTitle: t.search.noResultsTitle,
      itemBuilder: (context, room) => RoomCard(
        room: room,
        onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
      ),
    );
    if (!wide) return grid;
    final last = roomLastPage(search.rooms.length, pageSize);
    final shown = search.hasMore ? page : math.min(page, last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: grid),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                if (search.loading) const SizedBox(width: 14, height: 14, child: DsSpinner()),
                DsPagination(
                  page: shown,
                  pageCount: roomPageCount(
                    page: shown,
                    roomCount: search.rooms.length,
                    pageSize: pageSize,
                    hasMore: search.hasMore,
                  ),
                  onChanged: search.loading
                      ? null
                      : (next) {
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                          unawaited(_showPage(next, pageSize));
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Moves to [page], fetching more results first when the local catalogue
  /// does not reach it.
  Future<void> _showPage(int page, int pageSize) async {
    await ref.read(searchProvider.notifier).ensureResultsFor(page: page, pageSize: pageSize);
    if (!mounted) return;
    final search = ref.read(searchProvider);
    final last = roomLastPage(search.rooms.length, pageSize);
    final shown = search.hasMore ? page : math.min(page, last);
    if (shown != _page) setState(() => _page = shown);
  }

  String _platformName() {
    final site = ref.read(sitesProvider).getById(widget.platform);
    return site == null ? widget.platform : localizedSiteName(site);
  }
}
