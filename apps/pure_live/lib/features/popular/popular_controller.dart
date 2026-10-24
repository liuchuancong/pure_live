import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/settings/sites_display_provider.dart' show sitesDisplayProvider;

/// What one platform's popular feed holds: the rooms shown so far and
/// where the next page asks.
typedef PopularFeedState = ({
  List<LiveRoom> rooms,
  int nextPage,
  bool hasMore,
  bool loading,
  LiveSiteError? error,
});

/// The page a feed is showing — the desktop pager's number. Derived from
/// nextPage on the first load, kept as the load that produced the rooms.
int pageOf(PopularFeedState feed) => feed.rooms.isEmpty ? 1 : feed.nextPage - 1;

PopularFeedState _initial() => (rooms: const [], nextPage: 1, hasMore: true, loading: false, error: null);

/// The popular page's catalogues: one feed per platform, kept while the
/// app runs (the reference's `PopularCatalog`), so switching tabs or
/// coming back never fetches the same first page again.
///
/// The page asks — `open` the shown platform, `loadMore` near the end,
/// `refresh` on pull or resume — a notifier never loads from inside its
/// own build.
final class PopularCatalogController extends Notifier<Map<String, PopularFeedState>> {
  @override
  Map<String, PopularFeedState> build() => const {};

  /// The ids of the platforms that have recommendations, in registry
  /// order; the tabs show these.
  List<String> platformIds() {
    final display = ref.read(sitesDisplayProvider.notifier);
    return [
      for (final site in ref.read(sitesProvider).all)
        if (site.capability<LiveDiscoveryProvider>() != null && display.shown(site.manifest.id))
          site.manifest.id,
    ];
  }

  /// The feed of [platform], made on first ask.
  PopularFeedState feedOf(String platform) => state[platform] ?? _initial();

  /// Opens [platform]: its first page loads when the feed is still empty
  /// and idle. Re-selecting a loaded tab is a no-op.
  Future<void> open(String platform) async {
    final feed = feedOf(platform);
    if (feed.rooms.isNotEmpty || feed.loading) return;
    await _load(platform, page: 1);
  }

  /// Loads [platform]'s first page again (pull to refresh, resume, retry).
  Future<void> refresh(String platform) => _load(platform, page: 1);

  /// Warms [platform]'s first page when it is still empty and idle: the
  /// page's settle timer calls this for the tab after the shown one, so
  /// the next platform's rooms are already in hand when the viewer swipes
  /// (the reference's 700 ms warm-up).
  Future<void> warm(String platform) async {
    final feed = feedOf(platform);
    if (feed.rooms.isEmpty && !feed.loading) {
      await _load(platform, page: 1);
    }
  }

  /// Loads the next page of [platform] when one is left.
  Future<void> loadMore(String platform) {
    final feed = feedOf(platform);
    if (!feed.loading && feed.hasMore) return _load(platform, page: feed.nextPage);
    return Future.value();
  }

  /// Loads [page] of [platform] for the desktop pager: the shown page is
  /// replaced whole (page 1 keeps the infinite scroll's append behaviour,
  /// which the phone and the pager's first arrow share).
  Future<void> loadPage(String platform, int page) {
    final feed = feedOf(platform);
    if (feed.loading || page < 1) return Future.value();
    if (page == feed.nextPage) return loadMore(platform);
    return _load(platform, page: page);
  }

  Future<void> _load(String platform, {required int page}) async {
    final current = feedOf(platform);
    if (current.loading) return;
    state = {...state, platform: _with(current, loading: true, clearError: true)};
    final site = ref.read(sitesProvider).getById(platform);
    final discovery = site?.capability<LiveDiscoveryProvider>();
    if (discovery == null) {
      state = {
        ...state,
        platform: _with(current, loading: false, hasMore: false, error: LiveSiteError.unsupported(siteId: platform, message: 'no discovery capability')),
      };
      return;
    }
    final answer = await discovery.getRecommendedRooms(
      request: LivePageRequest.of(page: page, pageSize: ref.read(browseSettingsProvider).homePageSize),
    );
    // The shown tab may have moved on while the page was in flight.
    final open = state[platform];
    if (open == null) return;
    answer.match(
      (error) => state = {...state, platform: _with(open, loading: false, error: error)},
      (pageAnswer) => state = {
        ...state,
        platform: _with(
          open,
          // A continuous turn appends; a jump (the pager's arrows, an
          // out-of-order retry) replaces the page whole.
          rooms: page == 1 || page != current.nextPage
              ? pageAnswer.items.toList()
              : [...open.rooms, ...pageAnswer.items],
          nextPage: page + 1,
          hasMore: pageAnswer.hasMore ?? pageAnswer.items.isNotEmpty,
          loading: false,
          clearError: true,
        ),
      },
    );
  }

  PopularFeedState _with(
    PopularFeedState from, {
    List<LiveRoom>? rooms,
    int? nextPage,
    bool? hasMore,
    bool? loading,
    LiveSiteError? error,
    bool clearError = false,
  }) {
    return (
      rooms: rooms ?? from.rooms,
      nextPage: nextPage ?? from.nextPage,
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
