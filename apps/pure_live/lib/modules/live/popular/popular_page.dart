import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/popular/popular_controller.dart';
import 'package:pure_live/modules/live/popular/room_card.dart' show RoomCard;
import 'package:pure_live/modules/live/popular/room_card_menu.dart';
import 'package:pure_live/modules/live/search/search.dart';
import 'package:pure_live/shared/shared.dart';

/// How a platform's rooms are ordered on screen: the platform's own
/// recommendation or the largest audience first. The order is local — the
/// catalogue is already in hand, so switching never refetches.
enum _PopularSort { platform, audience }

/// One platform's audience figure for the sort: the figure the card shows,
/// else zero. The choice and the real-online policy are the same ones the
/// cards use, so the order follows what the viewer sees.
int _audienceRank(LiveRoom room, AudienceMetricChoice choice, AudiencePolicy policy) =>
    audienceFigureOf(room, choice, policy: policy) ?? 0;

/// [rooms] in [sort]'s order; the platform's own order is left untouched,
/// and the audience order is stable (ties keep the platform's order).
List<LiveRoom> _sortedRooms(
  List<LiveRoom> rooms,
  _PopularSort sort, {
  required AudienceMetricChoice choice,
  required AudiencePolicy policy,
}) {
  if (sort == _PopularSort.platform) return rooms;
  final indexed = rooms.indexed.toList()
    ..sort((a, b) {
      final byAudience = _audienceRank(b.$2, choice, policy).compareTo(_audienceRank(a.$2, choice, policy));
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

  /// A return from the background after this long refreshes the shown
  /// platform (the reference's resume rule).
  static const Duration _resumeRefreshAfter = Duration(seconds: 15);

  DateTime? _backgroundedAt;

  /// Whether a platform-display fallback is already waiting for the frame:
  /// one move per hidden selection, not one per build.
  bool _platformFallbackScheduled = false;

  /// The local order of each platform's rooms.
  _PopularSort _sort = _PopularSort.platform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The feed never loads from inside its own build; the page asks, and
    // only for the platform the viewer is looking at.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(popularCatalogProvider.notifier).open(ref.read(popularSiteProvider)));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  /// The shown platform was hidden in the settings while another one is
  /// still visible: move to the first visible one and load its feed, rather
  /// than leaving the hidden platform's rooms behind an absent tab.
  void _schedulePlatformFallback() {
    if (_platformFallbackScheduled) return;
    _platformFallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _platformFallbackScheduled = false;
      if (!mounted) return;
      final current = ref.read(popularSiteProvider);
      final visible = ref.read(popularCatalogProvider.notifier).platformIds();
      if (visible.isEmpty || visible.contains(current)) return;
      final next = visible.first;
      ref.read(popularSiteProvider.notifier).selected = next;
      unawaited(ref.read(popularCatalogProvider.notifier).open(next));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final platform = ref.watch(popularSiteProvider);
    // The platform list and its order are settings this page follows live:
    // watching the notifier alone would leave the tabs stale until another
    // rebuild.
    ref
      ..watch(sitesDisplayProvider)
      ..watch(sitesOrderProvider);
    final ids = ref.watch(popularCatalogProvider.notifier).platformIds();
    // The platform list can change under an open page (the settings hide
    // the shown platform, or a backup restores another display set): move
    // to a visible one instead of showing rooms behind an absent tab.
    if (ids.isNotEmpty && !ids.contains(platform)) _schedulePlatformFallback();
    final inline = ref.watch(popularInlineSearchProvider);
    // An inline search (the toolbar's word) takes the page: the platform's
    // own results grid under a search bar, browsing one keypress away.
    // The platform is watched, not frozen, so a tab switch during the
    // search re-runs it there.
    if (inline != null) {
      return _InlineSearchFeed(platform: platform, query: inline);
    }
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
                  unawaited(context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location)),
              child: Text(t.settings.sitesDisplay),
            ),
          ],
        ),
      );
    }

    void choosePlatform(String id) {
      ref.read(popularSiteProvider.notifier).selected = id;
      unawaited(ref.read(popularCatalogProvider.notifier).open(id));
    }

    void chooseSort(_PopularSort value) {
      if (value == _sort) return;
      setState(() => _sort = value);
      final controller = _scrolls[platform];
      if (controller?.hasClients ?? false) controller!.jumpTo(0);
    }

    void managePlatforms() =>
        unawaited(context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location));
    final sort = SizedBox(
      width: 148,
      child: AdaptiveChoiceField<_PopularSort>(
        value: _sort,
        title: t.popular.sortLabel,
        onChanged: chooseSort,
        options: [
          DsSelectOption(value: _PopularSort.platform, label: t.popular.sortPlatform),
          DsSelectOption(value: _PopularSort.audience, label: t.popular.sortAudience),
        ],
        placeholder: t.popular.sortLabel,
        semanticLabel: t.popular.sortLabel,
      ),
    );
    // The sort's own choices, for the menu a narrow toolbar keeps instead of
    // the field beside the tabs.
    final sortItems = [
      for (final value in _PopularSort.values)
        DsMenuItem(
          label: Text(value == _PopularSort.platform ? t.popular.sortPlatform : t.popular.sortAudience),
          checked: _sort == value,
          onPressed: () => chooseSort(value),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          // The tabs and the sort share a row when the toolbar has room; a
          // small screen keeps the tab bar alone and puts the sort, the
          // layout and the platform wall behind one more icon.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = LiveWindow.stacksToolbar(constraints.maxWidth);
              final tabs = PlatformTabRow(
                platforms: ids,
                current: platform,
                nameOf: _platformName,
                semanticLabel: t.navigation.hot,
                showPlatformWall: !narrow,
                showLayoutToggle: !narrow,
                onManagePlatforms: managePlatforms,
                onChanged: choosePlatform,
              );
              if (!narrow) {
                return Row(
                  spacing: DsSpace.s12,
                  children: [
                    Expanded(child: tabs),
                    sort,
                  ],
                );
              }
              return SizedBox(
                height: 44,
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(child: tabs),
                    PlatformToolbarMore(
                      platforms: ids,
                      current: platform,
                      nameOf: _platformName,
                      onChanged: choosePlatform,
                      onManagePlatforms: managePlatforms,
                      items: sortItems,
                    ),
                  ],
                ),
              );
            },
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
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(popularCatalogProvider.notifier);
    final feed = ref.watch(popularCatalogProvider.select((catalog) => catalog[platform]));

    final settings = ref.watch(browseSettingsProvider);
    final state =
        feed ??
        (
          rooms: const <LiveRoom>[],
          page: 1,
          pageSize: roomFeedRequestSize(platform),
          hidden: 0,
          hasMore: true,
          loading: false,
          error: null,
        );
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    // The chosen order is applied to the catalogue before the desktop
    // slices it, so a page holds the right rooms rather than a reordered
    // window of one page.
    final ordered = _sortedRooms(
      state.rooms,
      sort,
      choice: ref.watch(audienceMetricProvider),
      policy: ref.watch(audiencePolicyProvider),
    );
    // Desktop pages slice the platform catalogue locally, so fixed-window
    // platforms (Douyu 40, Huya ~120) and asked-size ones page the same
    // way, and the viewer's page size never moves a server boundary.
    final rooms = wide ? roomPageOf(ordered, state.page, state.pageSize) : ordered;
    Widget cardFor(BuildContext context, LiveRoom room, {bool listRow = false}) {
      void open() => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: rooms);
      return RoomCardMenu(
        room: room,
        onOpen: open,
        child: RoomCard(room: room, listRow: listRow, onOpen: open),
      );
    }

    final grid = CardGrid<LiveRoom>(
      scrollController: scrollController,
      items: rooms,
      layout: ref.watch(browseLayoutProvider),
      listMatchesGridWidth: true,
      listMainAxisExtent: kRoomCardListDesignHeight,
      listItemBuilder: (context, room) => cardFor(context, room, listRow: true),
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: state.loading,
      // The end of the list pages it in both layouts: the phone appends the
      // platform's next block, the desktop asks the pager for its next page —
      // the same ask its arrows and numbers make — so the wheel and
      // DsPagination never disagree about which page is shown.
      hasMore: state.hasMore,
      // Desktop: the wheel's end is the pager's next page, so it only moves
      // on a scroll that really reached the bottom.
      pagesOnScrollToEnd: wide,
      onLoadMore: () async {
        if (!wide) {
          await controller.loadMore(platform);
          return;
        }
        final next = state.page + 1;
        await controller.loadPage(platform, next);
        // Only a page that really moved starts at its head; a load the feed
        // refused (still working) leaves the viewer where they are.
        if (ref.read(popularCatalogProvider)[platform]?.page == next && (scrollController?.hasClients ?? false)) {
          scrollController!.jumpTo(0);
        }
      },
      error: state.error?.message,
      onRetry: () => controller.refresh(platform),
      // A pull reloads the first page; a failure keeps the rooms and is
      // explained in the bar over them.
      onRefresh: () => controller.refresh(platform),
      refreshError: state.error?.message,
      itemBuilder: cardFor,
    );
    // The reference's hidden-count line: rooms the discovery filter keeps
    // out of the page are counted, not dropped silently, and one action
    // turns the setting over so they show.
    final hiddenNote = state.hidden > 0 && !ref.watch(showUnplayableProvider)
        ? Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, wide ? DsSpace.s4 : DsSpace.s20),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                DsIcon(DsIcons.circleAlert, size: 16, color: colors.textMuted),
                Expanded(
                  child: Text(
                    t.popular.hiddenUnplayable(count: state.hidden),
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                ),
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => ref.read(showUnplayableProvider.notifier).setShow(value: true),
                  child: Text(t.common.show),
                ),
              ],
            ),
          )
        : null;
    // The grid keeps one ancestry: the note is an optional row of the same
    // Column, never a wrapper that swaps the Column in over the bare grid —
    // a swap would tear the grid's element down and reset its scroll.
    final feedView = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: grid),
        ?hiddenNote,
      ],
    );
    // A wide window pages by number (the reference's desktop feed) — the
    // kit's pagination: numbers with gaps, arrows at the ends; a narrow
    // one keeps the infinite scroll, thumbs do not page. The count is the
    // local slices plus one while the platform may still have rooms.
    if (!wide) return feedView;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: feedView),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
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

  /// The size the page number is measured in: search stays on the server's
  /// own window, so a display page is one request's worth of rooms.
  final int _pageSize = searchRequestSize;

  /// The results grid's scroll position across page jumps.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
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
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final search = ref.watch(searchProvider);
    final settings = ref.watch(browseSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          // The toolbar's word as the kit's callout, the areas page's own
          // line: what is being searched and the way back to the feed.
          child: DsAlert(
            title: Text(t.popular.inlineAt(platform: _platformName(), query: widget.query)),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                if (search.loading) const SizedBox(width: 14, height: 14, child: DsSpinner()),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => ref.read(popularInlineSearchProvider.notifier).clear(),
                  leading: const DsIcon(DsIcons.x, size: 14),
                  child: Text(t.popular.backToBrowse),
                ),
              ],
            ),
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
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final page = wide ? _page : 1;
    final pageSize = _pageSize;
    final rooms = wide ? roomPageOf(search.rooms, page, pageSize) : search.rooms;
    Widget cardFor(BuildContext context, LiveRoom room, {bool listRow = false}) {
      void open() => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: rooms);
      return RoomCardMenu(
        room: room,
        onOpen: open,
        child: RoomCard(room: room, listRow: listRow, onOpen: open),
      );
    }

    final grid = CardGrid<LiveRoom>(
      scrollController: _scroll,
      items: rooms,
      layout: ref.watch(browseLayoutProvider),
      listMatchesGridWidth: true,
      listMainAxisExtent: kRoomCardListDesignHeight,
      listItemBuilder: (context, room) => cardFor(context, room, listRow: true),
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: search.loading,
      // The end of the results pages them, exactly as the browse feed does:
      // the phone appends, the desktop moves its pager one page.
      hasMore: search.hasMore,
      pagesOnScrollToEnd: wide,
      onLoadMore: () async {
        if (!wide) {
          await ref.read(searchProvider.notifier).loadMore();
          return;
        }
        final next = page + 1;
        await _showPage(next, pageSize);
        // A page that really moved starts at its head.
        if (_page == next && _scroll.hasClients) _scroll.jumpTo(0);
      },
      error: search.error?.message,
      onRetry: () => ref.read(searchProvider.notifier).retry(),
      emptyIcon: DsIcons.searchX,
      emptyTitle: t.search.noResultsTitle,
      itemBuilder: cardFor,
    );
    if (!wide) return grid;
    final last = roomLastPage(search.rooms.length, pageSize);
    final shown = search.hasMore ? page : math.min(page, last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: grid),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s12),
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
