import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/shared/shared.dart';

/// What one platform's popular feed holds: every room fetched so far, the
/// desktop page shown over them, the size that page is measured in, and how
/// many of the fetched rooms the viewer's discovery filter hides.
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
  int hidden,
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
    (rooms: const [], page: 1, pageSize: pageSize, hidden: 0, hasMore: true, loading: false, error: null);

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

  /// Each platform's fetched rooms in full, before the discovery filter.
  ///
  /// The filter is the viewer's answer, not the platform's, so it must not
  /// cost requests and must be reversible in place: the catalogue stays
  /// whole here and the feed's `rooms` is what passes the rule.
  final Map<String, List<LiveRoom>> _fullRooms = {};

  /// Whether [room] belongs on a discovery page as the settings stand: the
  /// reference keeps such rooms out of 热门/分区 unless the viewer shows
  /// them, and a stored credential makes a 需要登录/成年 room playable.
  bool _playable(LiveRoom room) {
    if (ref.read(showUnplayableProvider)) return true;
    final signedIn = ref.read(accountsProvider).credentials.containsKey(room.ref.platform);
    return !cannotPlayHere(room, signedIn: signedIn);
  }

  /// Re-applies the discovery filter to every loaded feed (the settings'
  /// "显示不能直接播放的直播" changed, or a sign-in altered the login part).
  /// A walk that hid rooms under the old answer starts a fresh walk for the
  /// next fill, since its seen set holds the ones it never published.
  void refreshVisibility() {
    for (final entry in state.entries.toList()) {
      final platform = entry.key;
      final feed = entry.value;
      final full = _fullRooms[platform] ?? feed.rooms;
      final visible = [
        for (final room in full)
          if (_playable(room)) room,
      ];
      if (visible.length == feed.rooms.length && visible.length == full.length) continue;
      state = {...state, platform: _with(feed, rooms: visible, hidden: full.length - visible.length)};
      _walks.remove(platform);
      _seen.remove(platform);
    }
  }

  @override
  Map<String, PopularFeedState> build() {
    // The filter answer and the sign-ins live outside this controller: a
    // change re-runs the rule over the loaded catalogues at once (the
    // reference's setting-change listener + `visibilityChanged`).
    ref
      ..listen(showUnplayableProvider, (_, _) => refreshVisibility())
      ..listen(accountsProvider, (_, _) => refreshVisibility());
    return const {};
  }

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

  /// The feed of [platform], made on first ask measured in that platform's
  /// own feed window: the pager's size follows the site, not a setting.
  PopularFeedState feedOf(String platform) => state[platform] ?? _initial(roomFeedRequestSize(platform));

  /// Opens [platform]: its first rooms load when the feed is still empty
  /// and idle. Re-selecting a loaded tab is a no-op.
  Future<void> open(String platform) async {
    final feed = feedOf(platform);
    if (_accumulated(platform).isNotEmpty || feed.loading) return;
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
    if (_accumulated(platform).isEmpty && !feed.loading) await _refresh(platform);
  }

  /// Loads at least one more room for the phone's endless list. A chunk is
  /// shown whole: the platform's own window decides its size.
  Future<void> loadMore(String platform) async {
    final feed = feedOf(platform);
    if (feed.loading || !feed.hasMore || _accumulated(platform).isEmpty) return;
    await _fill(platform, target: _accumulated(platform).length + 1, page: feed.page, pageSize: feed.pageSize);
  }

  /// Shows [page] of the catalogue for the desktop pager, fetching as many
  /// platform pages as that page needs. Local pages made of already-fetched
  /// rooms move without a request.
  Future<void> loadPage(String platform, int page) async {
    final feed = feedOf(platform);
    if (page < 1 || feed.loading) return;
    final held = _accumulated(platform).length;
    final target = page * feed.pageSize;
    if (held >= target || !feed.hasMore) {
      final last = roomLastPage(held, feed.pageSize);
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
    final held = _accumulated(platform).length;
    final first = (feed.page - 1) * feed.pageSize;
    final requested = first ~/ pageSize + 1;
    final last = roomLastPage(held, pageSize);
    final page = feed.hasMore ? requested : math.min(requested, last);
    state = {...state, platform: _with(feed, page: page, pageSize: pageSize)};
    if (held >= page * pageSize || !feed.hasMore) return;
    await _fill(platform, target: page * pageSize, page: page, pageSize: pageSize);
  }

  /// Builds a fresh catalogue from page 1. A failure keeps whatever the
  /// feed showed before; an empty feed then shows the error itself.
  Future<void> _refresh(String platform) async {
    final current = feedOf(platform);
    if (current.loading) return;
    // One display page is one of the platform's own windows, so the pager
    // and the walk agree on the size without a viewer setting it.
    final pageSize = roomFeedRequestSize(platform);
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
    // The whole fetched catalogue publishes through the discovery filter,
    // so a settings change re-shows hidden rooms without another request.
    void publish({required bool loading, required bool hasMore}) {
      _walks[platform] = walk;
      _seen[platform] = seen;
      _fullRooms[platform] = List<LiveRoom>.unmodifiable(rooms);
      final visible = [
        for (final room in rooms)
          if (_playable(room)) room,
      ];
      state = {
        ...state,
        platform: (
          rooms: List.unmodifiable(visible),
          page: 1,
          pageSize: pageSize,
          hidden: rooms.length - visible.length,
          hasMore: hasMore,
          loading: loading,
          error: null,
        ),
      };
    }

    final failure = await fillRoomFeed(
      walk: walk,
      rooms: rooms,
      seen: seen,
      target: pageSize,
      onProgress: () => publish(loading: true, hasMore: walk.hasMore),
    );
    if (state[platform] == null) return;
    if (failure != null) {
      // A failure keeps what arrived: the catalogue and the shown page stay.
      _fullRooms[platform] = List<LiveRoom>.unmodifiable(rooms);
      state = {...state, platform: _with(state[platform]!, loading: false, error: failure)};
      return;
    }
    publish(loading: false, hasMore: walk.hasMore);
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
    final seen = _seen[platform] ??= {for (final room in _accumulated(platform)) room.identityKey};
    final rooms = [..._accumulated(platform)];
    state = {...state, platform: _with(current, loading: true, clearError: true, pageSize: pageSize)};
    // Each fetched page lands at once: a later failure keeps the rooms and
    // the walk stays on the page that failed, so nothing is stranded.
    void publishProgress() {
      _seen[platform] = seen;
      _fullRooms[platform] = List<LiveRoom>.unmodifiable(rooms);
      final visible = [
        for (final room in rooms)
          if (_playable(room)) room,
      ];
      state = {
        ...state,
        platform: (
          rooms: List.unmodifiable(visible),
          page: math.min(page, roomLastPage(visible.length, pageSize)),
          pageSize: pageSize,
          hidden: rooms.length - visible.length,
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
      _fullRooms[platform] = List<LiveRoom>.unmodifiable(rooms);
      state = {...state, platform: _with(open, loading: false, error: failure)};
      return;
    }
    _seen[platform] = seen;
    _fullRooms[platform] = List<LiveRoom>.unmodifiable(rooms);
    final visible = [
      for (final room in rooms)
        if (_playable(room)) room,
    ];
    final last = roomLastPage(visible.length, pageSize);
    final shown = walk.hasMore ? page : math.min(page, last);
    state = {
      ...state,
      platform: (
        rooms: List.unmodifiable(visible),
        page: shown,
        pageSize: pageSize,
        hidden: rooms.length - visible.length,
        hasMore: walk.hasMore,
        loading: false,
        error: null,
      ),
    };
  }

  /// The catalogue as fetched, hidden rooms included.
  List<LiveRoom> _accumulated(String platform) => _fullRooms[platform] ?? const [];

  PopularFeedState _with(
    PopularFeedState from, {
    List<LiveRoom>? rooms,
    int? page,
    int? pageSize,
    int? hidden,
    bool? hasMore,
    bool? loading,
    LiveSiteError? error,
    bool clearError = false,
  }) {
    return (
      rooms: rooms ?? from.rooms,
      page: page ?? from.page,
      pageSize: pageSize ?? from.pageSize,
      hidden: hidden ?? from.hidden,
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
