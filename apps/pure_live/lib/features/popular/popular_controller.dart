import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/settings/sites_display_provider.dart' show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/shared/paging/room_paging.dart';

/// What one platform's popular feed holds: every room fetched so far, the
/// desktop page shown over them, and the size that page is measured in.
///
/// The rooms are the catalogue, not one server page: fixed-window platforms
/// (Douyu's 40, Huya's ~120) and page-numbered ones both accumulate here,
/// and the desktop pager slices the list locally. That makes the viewer's
/// page size honest on both kinds of platform and stops a size change from
/// sliding the server's page boundaries under an open feed.
typedef PopularFeedState = ({
  List<LiveRoom> rooms,
  int page,
  int pageSize,
  bool hasMore,
  bool loading,
  LiveSiteError? error,
});

/// The page a feed is showing — the desktop pager's number.
int pageOf(PopularFeedState feed) => feed.page;

/// The pages the pager may offer: every locally available slice, plus one
/// while the platform may still have more.
int pageCountOf(PopularFeedState feed) =>
    roomPageCount(page: feed.page, roomCount: feed.rooms.length, pageSize: feed.pageSize, hasMore: feed.hasMore);

PopularFeedState _initial(int pageSize) =>
    (rooms: const [], page: 1, pageSize: pageSize, hasMore: true, loading: false, error: null);

/// The popular page's catalogues: one feed per platform, kept while the
/// app runs (the reference's `PopularCatalog`), so switching tabs or
/// coming back never fetches the same first page again.
///
/// The page asks — `open` the shown platform, `loadMore` near the end,
/// `loadPage` from the pager, `refresh` on pull or resume — a notifier
/// never loads from inside its own build.
///
/// Each platform walks its own pages through a [RoomWalk] at the platform's
/// request window (`roomFeedRequestSize`), with cursors where the platform
/// uses them and identity dedupe across pages. The phone shows the whole
/// catalogue as it grows; the desktop shows one page of the chosen size.
final class PopularCatalogController extends Notifier<Map<String, PopularFeedState>> {
  /// Each platform's walk through its own pages and cursor.
  final Map<String, RoomWalk> _walks = {};

  /// Every room identity already in a platform's catalogue.
  final Map<String, Set<String>> _seen = {};

  @override
  Map<String, PopularFeedState> build() => const {};

  /// The ids of the platforms that have recommendations, in registry
  /// order; the tabs show these.
  List<String> platformIds() {
    final display = ref.read(sitesDisplayProvider.notifier);
    // The viewer's order is the menu's order: a drag in the settings
    // reorders these tabs too.
    final order = ref.read(sitesOrderProvider).order;
    final sites = {for (final site in ref.read(sitesProvider).all) site.manifest.id: site};
    return [
      for (final id in order)
        if (sites[id] case final site? when site.capability<LiveDiscoveryProvider>() != null && display.shown(id)) id,
    ];
  }

  /// The feed of [platform], made on first ask with the current page size.
  PopularFeedState feedOf(String platform) =>
      state[platform] ?? _initial(ref.read(browseSettingsProvider).homePageSize);

  /// Opens [platform]: its first rooms load when the feed is still empty
  /// and idle. Re-selecting a loaded tab is a no-op.
  Future<void> open(String platform) async {
    final feed = feedOf(platform);
    if (feed.rooms.isNotEmpty || feed.loading) return;
    await _refresh(platform);
  }

  /// Loads [platform]'s catalogue again from its first page (pull to
  /// refresh, resume, retry). A failure keeps the old catalogue on screen.
  Future<void> refresh(String platform) => _refresh(platform);

  /// Warms [platform]'s first rooms when its catalogue is still empty and
  /// idle: the page's settle timer calls this for the tab after the shown
  /// one, so the next platform's rooms are already in hand when the viewer
  /// swipes (the reference's 700 ms warm-up).
  Future<void> warm(String platform) async {
    final feed = feedOf(platform);
    if (feed.rooms.isEmpty && !feed.loading) await _refresh(platform);
  }

  /// Loads at least one more room for the phone's endless list. A chunk is
  /// shown whole: the platform's own window decides its size.
  Future<void> loadMore(String platform) async {
    final feed = feedOf(platform);
    if (feed.loading || !feed.hasMore || feed.rooms.isEmpty) return;
    await _fill(platform, target: feed.rooms.length + 1, page: feed.page, pageSize: feed.pageSize);
  }

  /// Shows [page] of the catalogue for the desktop pager, fetching as many
  /// platform pages as that page needs. Local pages made of already-fetched
  /// rooms move without a request.
  Future<void> loadPage(String platform, int page) async {
    final feed = feedOf(platform);
    if (page < 1 || feed.loading) return;
    final target = page * feed.pageSize;
    if (feed.rooms.length >= target || !feed.hasMore) {
      final last = roomLastPage(feed.rooms.length, feed.pageSize);
      final shown = feed.hasMore ? page : math.min(page, last);
      state = {...state, platform: _with(feed, page: shown)};
      return;
    }
    await _fill(platform, target: target, page: page, pageSize: feed.pageSize);
  }

  /// Re-measures the catalogue in [pageSize] rooms per page, keeping the
  /// first room of the shown page in view (the reference's page-size change).
  Future<void> resize(String platform, int pageSize) async {
    final feed = feedOf(platform);
    if (pageSize < 1 || feed.pageSize == pageSize || feed.loading) return;
    final first = (feed.page - 1) * feed.pageSize;
    final requested = first ~/ pageSize + 1;
    final last = roomLastPage(feed.rooms.length, pageSize);
    final page = feed.hasMore ? requested : math.min(requested, last);
    state = {...state, platform: _with(feed, page: page, pageSize: pageSize)};
    if (feed.rooms.length >= page * pageSize || !feed.hasMore) return;
    await _fill(platform, target: page * pageSize, page: page, pageSize: pageSize);
  }

  /// Builds a fresh catalogue from page 1. A failure keeps whatever the
  /// feed showed before; an empty feed then shows the error itself.
  Future<void> _refresh(String platform) async {
    final current = feedOf(platform);
    if (current.loading) return;
    final pageSize = ref.read(browseSettingsProvider).homePageSize;
    final discovery = ref.read(sitesProvider).getById(platform)?.capability<LiveDiscoveryProvider>();
    if (discovery == null) {
      state = {
        ...state,
        platform: _with(
          current,
          loading: false,
          hasMore: false,
          error: LiveSiteError.unsupported(siteId: platform, message: 'no discovery capability'),
        ),
      };
      return;
    }
    final walk = RoomWalk(
      fetch: (request) => discovery.getRecommendedRooms(request: request),
      pageSize: roomFeedRequestSize(platform),
    );
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    state = {...state, platform: _with(current, loading: true, clearError: true)};
    final failure = await fillRoomFeed(walk: walk, rooms: rooms, seen: seen, target: pageSize);
    final open = state[platform];
    if (open == null) return;
    if (failure != null) {
      state = {...state, platform: _with(open, loading: false, error: failure)};
      return;
    }
    _walks[platform] = walk;
    _seen[platform] = seen;
    state = {
      ...state,
      platform: (
        rooms: List.unmodifiable(rooms),
        page: 1,
        pageSize: pageSize,
        hasMore: walk.hasMore,
        loading: false,
        error: null,
      ),
    };
  }

  /// Fetches from the platform's walk until [target] rooms are held, then
  /// publishes the catalogue measured in [pageSize] for [page].
  Future<void> _fill(String platform, {required int target, required int page, required int pageSize}) async {
    final current = feedOf(platform);
    if (current.loading) return;
    final discovery = ref.read(sitesProvider).getById(platform)?.capability<LiveDiscoveryProvider>();
    if (discovery == null) {
      state = {
        ...state,
        platform: _with(
          current,
          loading: false,
          hasMore: false,
          error: LiveSiteError.unsupported(siteId: platform, message: 'no discovery capability'),
        ),
      };
      return;
    }
    final walk = _walks[platform] ??= RoomWalk(
      fetch: (request) => discovery.getRecommendedRooms(request: request),
      pageSize: roomFeedRequestSize(platform),
    );
    final seen = _seen[platform] ??= {for (final room in current.rooms) room.identityKey};
    final rooms = [...current.rooms];
    state = {...state, platform: _with(current, loading: true, clearError: true, pageSize: pageSize)};
    // Each fetched page lands at once: a later failure keeps the rooms and
    // the walk stays on the page that failed, so nothing is stranded.
    void publishProgress() {
      _seen[platform] = seen;
      state = {
        ...state,
        platform: (
          rooms: List.unmodifiable(rooms),
          page: math.min(page, roomLastPage(rooms.length, pageSize)),
          pageSize: pageSize,
          hasMore: walk.hasMore,
          loading: true,
          error: null,
        ),
      };
    }

    final failure = await fillRoomFeed(
      walk: walk,
      rooms: rooms,
      seen: seen,
      target: target,
      onProgress: publishProgress,
    );
    final open = state[platform];
    if (open == null) return;
    if (failure != null) {
      state = {...state, platform: _with(open, loading: false, error: failure)};
      return;
    }
    _seen[platform] = seen;
    final last = roomLastPage(rooms.length, pageSize);
    final shown = walk.hasMore ? page : math.min(page, last);
    state = {
      ...state,
      platform: (
        rooms: List.unmodifiable(rooms),
        page: shown,
        pageSize: pageSize,
        hasMore: walk.hasMore,
        loading: false,
        error: null,
      ),
    };
  }

  PopularFeedState _with(
    PopularFeedState from, {
    List<LiveRoom>? rooms,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? loading,
    LiveSiteError? error,
    bool clearError = false,
  }) {
    return (
      rooms: rooms ?? from.rooms,
      page: page ?? from.page,
      pageSize: pageSize ?? from.pageSize,
      hasMore: hasMore ?? from.hasMore,
      loading: loading ?? from.loading,
      error: clearError ? null : (error ?? from.error),
    );
  }
}

/// The popular page's per-platform feeds.
final popularCatalogProvider = NotifierProvider<PopularCatalogController, Map<String, PopularFeedState>>(
  PopularCatalogController.new,
);

/// The popular page's shown platform, remembered across visits under
/// `browse.popular.site`; the first platform when never chosen.
final class PopularSiteController extends Notifier<String> {
  @override
  String build() {
    final stored = _readStored();
    final ids = ref.read(popularCatalogProvider.notifier).platformIds();
    if (stored != null && ids.contains(stored)) return stored;
    // No local choice yet: the settings' preferred platform opens first.
    final preferred = ref.read(sitesOrderProvider).preferred;
    if (preferred.isNotEmpty && ids.contains(preferred)) return preferred;
    return ids.isEmpty ? '' : ids.first;
  }

  static String? _readStored() {
    try {
      return StoragePrefs.getString('browse.popular.site');
    } on Object {
      return null;
    }
  }

  /// The shown platform.
  String get selected => state;

  /// Moves the shown platform, writing the choice through.
  set selected(String id) {
    state = id;
    unawaited(StoragePrefs.setString('browse.popular.site', id));
  }
}

/// The popular page's shown platform.
final popularSiteProvider = NotifierProvider<PopularSiteController, String>(PopularSiteController.new);

/// The popular page's inline search word, or null while it browses: the
/// toolbar's field submits into the page itself — the results grid takes
/// the feed's place under a search bar, ESC or the × returns to browsing.
final class PopularInlineSearchController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Searches [word] inline (null or empty returns to browsing).
  void search(String? word) => state = (word == null || word.trim().isEmpty) ? null : word.trim();

  /// Returns to browsing.
  void clear() => state = null;
}

/// The popular page's inline search word.
final popularInlineSearchProvider = NotifierProvider<PopularInlineSearchController, String?>(
  PopularInlineSearchController.new,
);
