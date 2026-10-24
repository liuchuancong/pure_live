import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/popular/popular_controller.dart';
import 'package:pure_live/features/popular/room_card.dart' show RoomCard;
import 'package:pure_live/features/search/search_controller.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/platforms/platform_picker.dart';

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
  late final Map<String, String> _names = {
    for (final site in ref.watch(sitesProvider).all) site.manifest.id: site.manifest.name['zh-CN'] ?? site.manifest.id,
  };
  /// How long the viewer looks at a platform before the next one warms.
  static const Duration _warmDelay = Duration(milliseconds: 700);

  /// A return from the background after this long refreshes the shown
  /// platform (the reference's resume rule).
  static const Duration _resumeRefreshAfter = Duration(seconds: 15);

  Timer? _warmTimer;
  DateTime? _backgroundedAt;

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
      final away = _backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundedAt!);
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
      return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(t.common.empty)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
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
        Expanded(
          child: _PlatformFeed(
            key: ValueKey(platform),
            platform: platform,
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
  const _PlatformFeed({required this.platform, this.scrollController, super.key});

  /// The platform whose recommendations show.
  final String platform;

  /// The kept controller of this platform's tab (see the page's state).
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(popularCatalogProvider.notifier);
    final feed = ref.watch(popularCatalogProvider.select((catalog) => catalog[platform]));
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    final state =
        feed ?? (rooms: const <LiveRoom>[], nextPage: 1, hasMore: true, loading: false, error: null);
    final grid = CardGrid<LiveRoom>(
      scrollController: scrollController,
      items: state.rooms,
      cardExtent: cardExtent,
      isLoading: state.loading,
      hasMore: state.hasMore,
      onLoadMore: () => controller.loadMore(platform),
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
    // one keeps the infinite scroll, thumbs do not page. The feed only
    // knows whether one more page exists, so the count sits one ahead:
    // the last number answers "is there a next" and the pager never
    // offers a page past the end.
    final wide = MediaQuery.sizeOf(context).width >= 768;
    if (!wide) return grid;
    final page = pageOf(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: grid),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
          child: Center(
            child: DsPagination(
              page: page,
              pageCount: state.hasMore ? page + 1 : page,
              onChanged: state.loading ? null : (next) => controller.loadPage(platform, next),
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
  @override
  void initState() {
    super.initState();
    // The search runs on arrival (and on a re-word, when the widget is
    // rebuilt by the provider) — pinned to the browsed platform.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchSiteIdProvider.notifier).selected = widget.platform;
      unawaited(ref.read(searchProvider.notifier).search(widget.query));
    });
  }

  @override
  void didUpdateWidget(_InlineSearchFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.platform != widget.platform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchSiteIdProvider.notifier).selected = widget.platform;
        unawaited(ref.read(searchProvider.notifier).search(widget.query));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final search = ref.watch(searchProvider);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
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
              if (search.loading)
                const SizedBox(width: 14, height: 14, child: DsSpinner()),
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => ref.read(popularInlineSearchProvider.notifier).clear(),
                leading: const DsIcon(DsIcons.x, size: 14),
                child: Text(t.popular.backToBrowse),
              ),
            ],
          ),
        ),
        Expanded(
          child: _pagedResults(context, search, cardExtent),
        ),
      ],
    );
  }

  /// The results grid; a wide window pages it by number exactly like the
  /// browse feed, a narrow one scrolls forever.
  Widget _pagedResults(BuildContext context, SearchState search, double cardExtent) {
    final t = context.t;
    final grid = CardGrid<LiveRoom>(
      items: search.rooms,
      cardExtent: cardExtent,
      isLoading: search.loading,
      hasMore: search.hasMore,
      onLoadMore: () => ref.read(searchProvider.notifier).loadMore(),
      error: search.error?.message,
      onRetry: () => ref.read(searchProvider.notifier).retry(),
      emptyIcon: DsIcons.searchX,
      emptyTitle: t.search.noResultsTitle,
      itemBuilder: (context, room) => RoomCard(
        room: room,
        onOpen: () => context.push(
          RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location,
        ),
      ),
    );
    final wide = MediaQuery.sizeOf(context).width >= 768;
    if (!wide) return grid;
    final page = search.rooms.isEmpty ? 1 : search.nextPage - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: grid),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
          child: Center(
            child: DsPagination(
              page: page,
              pageCount: search.hasMore ? page + 1 : page,
              onChanged: search.loading
                  ? null
                  : (next) => ref.read(searchProvider.notifier).loadPage(next),
            ),
          ),
        ),
      ],
    );
  }

  String _platformName() {
    final site = ref.read(sitesProvider).getById(widget.platform);
    return site?.manifest.name['zh-CN'] ?? widget.platform;
  }
}
