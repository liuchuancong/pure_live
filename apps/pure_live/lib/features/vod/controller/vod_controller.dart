import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttp;
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart';

/// What the vod page holds: the committed query, its videos, where the next
/// page asks, the in-flight flag, and the last failure.
typedef VodState = ({String query, List<VodVideo> videos, int nextPage, bool hasMore, bool loading, VodFailure? error});

VodState _initial() => (query: '', videos: const [], nextPage: 1, hasMore: true, loading: false, error: null);

/// The vod source's client over the shared transport.
///
/// One pipeline serves the whole module — the `api` profile fits Bilibili's
/// fixed endpoints (bounded retries, caching only where a call opts in) —
/// and the transport stays behind [LiveHttp], so proxies and cookies remain
/// the app shell's business.
final vodClientProvider = Provider<BilibiliVodClient>((ref) {
  final http = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  ref.onDispose(http.close);
  // The same Bilibili sign-in the live site uses: one cookie serves the
  // video site too (higher renditions, login-only archives).
  final credential = ref.watch(accountsProvider).credentials[SiteIds.bilibili];
  final cookie = credential == null
      ? ''
      : credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  return BilibiliVodClient(http, cookie: cookie);
});

/// The vod page's state and requests, paged by scroll like the home feed.
///
/// The vod source only searches — it offers no regions, rankings or
/// recommendations to browse — so the page commits a keyword and pages its
/// hits; with no keyword there is nothing to load, and the page says so
/// instead of asking. A newer query always wins: an answer from a search
/// that was replaced drains without writing. The page asks for every load —
/// a notifier never loads from inside its own build.
final class VodController extends Notifier<VodState> {
  int _generation = 0;
  int _stagnant = 0;

  /// The current sort key (`totalrank`, `click`, `pubdate`, `dm`, `stow`)
  /// and length tier (0 = any) — the search bar's two filters.
  String _order = 'totalrank';
  int _duration = 0;

  @override
  VodState build() => _initial();

  /// Searches [query] from its first page; a blank query clears the results.
  ///
  /// [order] and [duration] are the search bar's filters; they stay for
  /// [loadMore] and [retry] until the viewer changes them.
  Future<void> search(String query, {String? order, int? duration}) {
    if (order != null) _order = order;
    if (duration != null) _duration = duration;
    final word = query.trim();
    if (word.isEmpty) {
      _generation++;
      state = _initial();
      return Future.value();
    }
    return _load(word, 1);
  }

  /// Loads the next page of the committed query when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty) return Future.value();
    return _load(state.query, state.nextPage);
  }

  /// Runs the committed query again from its first page (the retry button).
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, 1);
  }

  Future<void> _load(String query, int page) async {
    final generation = ++_generation;
    state = (
      query: query,
      videos: page == 1 ? const [] : state.videos,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    try {
      final answer = await ref
          .read(vodClientProvider)
          // The site's own window: the client's default page size is what
          // Bilibili asks for, not a number the viewer sets.
          .search(
            query,
            page: page,
            order: _order,
            duration: _duration,
          );
      // A search that was replaced (a newer query) drains its answer
      // without writing it.
      if (!ref.mounted || generation != _generation) return;
      final videos = page == 1 ? answer.videos : [...state.videos];
      if (page > 1) {
        final seen = {for (final video in videos) video.bvid ?? video.id};
        videos.addAll(answer.videos.where((video) => seen.add(video.bvid ?? video.id)));
      }
      // Two pages in a row without a new hit end the walk even when the
      // source keeps claiming more: repeating a page must not spin the
      // grid's load-more forever.
      final fresh = page == 1 || videos.length > state.videos.length;
      _stagnant = fresh ? 0 : _stagnant + 1;
      state = (
        query: query,
        videos: videos,
        nextPage: page + 1,
        hasMore: answer.hasMore && _stagnant < 2,
        loading: false,
        error: null,
      );
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (
        query: query,
        videos: state.videos,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: failure is VodFailure ? failure : VodFailure(failure.toString()),
      );
    }
  }
}

/// The vod page's state.
final vodProvider = NotifierProvider<VodController, VodState>(VodController.new);

/// The three browse feeds the video station opens: the site-wide popular
/// list, a region's ranking (one fixed list), and a region's recommendation
/// feed (paged).
enum VodFeedKind { popular, ranking, region }

/// One feed's videos, the next page it asks, and its load state.
typedef VodFeedState = ({List<VodVideo> videos, int nextPage, bool hasMore, bool loading, VodFailure? error});

VodFeedState _feedInitial() => (videos: const [], nextPage: 1, hasMore: true, loading: false, error: null);

/// A feed's cache key: `popular`, `ranking:<rid>` or `region:<tid>`.
String vodFeedKey(VodFeedKind kind, {int id = 0}) => switch (kind) {
  VodFeedKind.popular => 'popular',
  VodFeedKind.ranking => 'ranking:$id',
  VodFeedKind.region => 'region:$id',
};

/// The station's browse feeds, cached per key (switching tabs keeps what
/// was loaded). Each feed loads its first page on `open`; the page asks,
/// never the build.
final class VodFeedController extends Notifier<Map<String, VodFeedState>> {
  /// Pages in a row that brought nothing new, per feed key.
  final Map<String, int> _stagnant = {};

  @override
  Map<String, VodFeedState> build() => const {};

  VodFeedState feedOf(String key) => state[key] ?? _feedInitial();

  /// Loads the feed behind [key]'s first page when it is empty and idle.
  Future<void> open(String key) async {
    final feed = feedOf(key);
    if (feed.videos.isNotEmpty || feed.loading) return;
    await _load(key, 1);
  }

  /// Loads the next page when the source may have one.
  Future<void> loadMore(String key) async {
    final feed = feedOf(key);
    if (feed.loading || !feed.hasMore) return;
    await _load(key, feed.nextPage);
  }

  /// Reloads the feed from its first page (the pull gesture).
  Future<void> refresh(String key) => _load(key, 1);

  Future<void> _load(String key, int page) async {
    final current = feedOf(key);
    if (current.loading) return;
    final parts = key.split(':');
    final ranking = parts.first == 'ranking';
    // A leaderboard is one fixed list: only its first page exists, and the
    // refusal must come before the loading flag is raised.
    if (ranking && page > 1) return;
    state = {...state, key: _with(current, loading: true, clearError: true)};
    final client = ref.read(vodClientProvider);
    try {
      final VodVideoPage answer;
      switch (parts.first) {
        case 'ranking':
          final videos = await client.ranking(rid: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0);
          answer = VodVideoPage(videos: videos);
        case 'region':
          answer = await client.regionFeed(tid: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0, page: page);
        default:
          // Again the client's own window for the popular list.
          answer = await client.popular(page: page);
      }
      if (!ref.mounted) return;
      final open = state[key];
      if (open == null) return;
      // Feeds can overlap across pages: a video the feed already holds is
      // not appended a second time.
      final merged = page == 1 ? answer.videos : [...open.videos];
      if (page > 1) {
        final seen = {for (final video in merged) video.bvid ?? video.id};
        merged.addAll(answer.videos.where((video) => seen.add(video.bvid ?? video.id)));
      }
      // The walk ends after two unchanged pages even if the source still
      // claims more, so a feed that ignores its page argument cannot spin
      // the grid's load-more.
      final fresh = page == 1 || merged.length > open.videos.length;
      final stagnant = fresh ? 0 : (_stagnant[key] ?? 0) + 1;
      _stagnant[key] = stagnant;
      state = {
        ...state,
        key: _with(open, videos: merged, nextPage: page + 1, hasMore: answer.hasMore && stagnant < 2, loading: false),
      };
    } on Object catch (failure) {
      if (!ref.mounted) return;
      final open = state[key];
      if (open == null) return;
      state = {
        ...state,
        key: _with(
          open,
          loading: false,
          hasMore: false,
          error: failure is VodFailure ? failure : VodFailure(failure.toString()),
        ),
      };
    }
  }

  VodFeedState _with(
    VodFeedState from, {
    List<VodVideo>? videos,
    int? nextPage,
    bool? hasMore,
    bool? loading,
    VodFailure? error,
    bool clearError = false,
  }) => (
    videos: videos ?? from.videos,
    nextPage: nextPage ?? from.nextPage,
    hasMore: hasMore ?? from.hasMore,
    loading: loading ?? from.loading,
    error: clearError ? null : (error ?? from.error),
  );
}

/// The video station's browse feeds.
final vodFeedProvider = NotifierProvider<VodFeedController, Map<String, VodFeedState>>(VodFeedController.new);
