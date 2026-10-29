import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttp;
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart';

/// The search page's tabs: the reference's five result kinds.
enum VodSearchKind {
  /// Archives (`search/type` with `search_type=video`).
  video,

  /// 番剧 seasons (`media_bangumi`).
  bangumi,

  /// 影视 seasons (`media_ft`).
  cinema,

  /// Users (`bili_user`).
  user,

  /// Live rooms (`live_room`).
  liveRoom;

  /// Whether the sort/length filters apply — they are the video endpoint's.
  bool get filterable => this == VodSearchKind.video;
}

/// What the search page holds: the committed query and kind, that kind's
/// results, where the next page asks, the in-flight flag, and the last
/// failure. The four result lists are separate because the platform answers
/// a different shape per kind and only one kind is ever shown.
typedef VodState = ({
  VodSearchKind kind,
  String query,
  List<VodVideo> videos,
  List<VodSeason> seasons,
  List<VodUser> users,
  List<VodLiveRoom> rooms,
  int nextPage,
  bool hasMore,
  bool loading,
  VodFailure? error,
});

VodState _initial(VodSearchKind kind) => (
  kind: kind,
  query: '',
  videos: const [],
  seasons: const [],
  users: const [],
  rooms: const [],
  nextPage: 1,
  hasMore: true,
  loading: false,
  error: null,
);

/// The vod page's state and requests, paged by scroll like the home feed.
///
/// The station's search commits a keyword and pages its hits; with no keyword
/// there is nothing to load, and the page says so instead of asking. A newer
/// query or kind always wins: an answer from a search that was replaced
/// drains without writing. The page asks for every load — a notifier never
/// loads from inside its own build.
final class VodController extends Notifier<VodState> {
  int _generation = 0;
  int _stagnant = 0;

  /// The current sort key (`totalrank`, `click`, `pubdate`, `dm`, `stow`)
  /// and length tier (0 = any) — the video tab's two filters.
  String _order = 'totalrank';
  int _duration = 0;

  @override
  VodState build() => _initial(VodSearchKind.video);

  /// Searches [query] from its first page; a blank query clears the results.
  ///
  /// [kind] switches the result tab (which re-asks the same query); [order]
  /// and [duration] are the video tab's filters. All three stay for
  /// [loadMore] and [retry] until the viewer changes them.
  Future<void> search(String query, {VodSearchKind? kind, String? order, int? duration}) {
    if (order != null) _order = order;
    if (duration != null) _duration = duration;
    final next = kind ?? state.kind;
    final word = query.trim();
    if (word.isEmpty) {
      _generation++;
      state = _initial(next);
      return Future.value();
    }
    return _load(word, next, 1);
  }

  /// Loads the next page of the committed query when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty) return Future.value();
    return _load(state.query, state.kind, state.nextPage);
  }

  /// Runs the committed query again from its first page (the retry button).
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, state.kind, 1);
  }

  Future<void> _load(String query, VodSearchKind kind, int page) async {
    final generation = ++_generation;
    state = (
      kind: kind,
      query: query,
      videos: page == 1 ? const [] : state.videos,
      seasons: page == 1 ? const [] : state.seasons,
      users: page == 1 ? const [] : state.users,
      rooms: page == 1 ? const [] : state.rooms,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    try {
      final client = ref.read(vodClientProvider);
      final bool hasMore;
      switch (kind) {
        case VodSearchKind.video:
          final answer = await client.search(query, page: page, order: _order, duration: _duration);
          hasMore = answer.hasMore;
          if (!ref.mounted || generation != _generation) return;
          final videos = _merged(state.videos, answer.videos, page == 1, (video) => video.bvid ?? video.id);
          state = (
            kind: kind,
            query: query,
            videos: videos,
            seasons: const [],
            users: const [],
            rooms: const [],
            nextPage: page + 1,
            hasMore: hasMore && _freshWins(page, videos.length),
            loading: false,
            error: null,
          );
        case VodSearchKind.bangumi:
        case VodSearchKind.cinema:
          final answer = await client.searchMedia(query, bangumi: kind == VodSearchKind.bangumi, page: page);
          hasMore = answer.hasMore;
          if (!ref.mounted || generation != _generation) return;
          final seasons = _merged(state.seasons, answer.seasons, page == 1, (season) => '${season.seasonId}');
          state = (
            kind: kind,
            query: query,
            videos: const [],
            seasons: seasons,
            users: const [],
            rooms: const [],
            nextPage: page + 1,
            hasMore: hasMore && _freshWins(page, seasons.length),
            loading: false,
            error: null,
          );
        case VodSearchKind.user:
          final answer = await client.searchUsers(query, page: page);
          hasMore = answer.hasMore;
          if (!ref.mounted || generation != _generation) return;
          final users = _merged(state.users, answer.users, page == 1, (user) => '${user.mid}');
          state = (
            kind: kind,
            query: query,
            videos: const [],
            seasons: const [],
            users: users,
            rooms: const [],
            nextPage: page + 1,
            hasMore: hasMore && _freshWins(page, users.length),
            loading: false,
            error: null,
          );
        case VodSearchKind.liveRoom:
          final answer = await client.searchLiveRooms(query, page: page);
          hasMore = answer.hasMore;
          if (!ref.mounted || generation != _generation) return;
          final rooms = _merged(state.rooms, answer.rooms, page == 1, (room) => '${room.roomId}');
          state = (
            kind: kind,
            query: query,
            videos: const [],
            seasons: const [],
            users: const [],
            rooms: rooms,
            nextPage: page + 1,
            hasMore: hasMore && _freshWins(page, rooms.length),
            loading: false,
            error: null,
          );
      }
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (
        kind: kind,
        query: query,
        videos: state.videos,
        seasons: state.seasons,
        users: state.users,
        rooms: state.rooms,
        nextPage: state.nextPage,
        hasMore: false,
        loading: false,
        error: failure is VodFailure ? failure : VodFailure(failure.toString()),
      );
    }
  }

  /// Appends [incoming] to [current], dropping what is already held; a first
  /// page replaces the list.
  static List<T> _merged<T>(List<T> current, List<T> incoming, bool first, String Function(T) keyOf) {
    final merged = first ? <T>[] : [...current];
    final seen = {for (final item in merged) keyOf(item)};
    merged.addAll(incoming.where((item) => seen.add(keyOf(item))));
    return merged;
  }

  /// Two pages in a row without a new hit end the walk even when the source
  /// keeps claiming more: repeating a page must not spin the grid's load-more
  /// forever.
  bool _freshWins(int page, int total) {
    final fresh = page == 1 || total > _lastTotal;
    _lastTotal = total;
    _stagnant = fresh ? 0 : _stagnant + 1;
    return _stagnant < 2;
  }

  int _lastTotal = 0;
}

/// The vod source's client over the shared transport.
///
/// One pipeline serves the whole module — the `api` profile fits Bilibili's
/// fixed endpoints (bounded retries, caching only where a call opts in) —
/// and the transport stays behind [LiveHttp], so proxies and cookies remain
/// the app shell's business.
final vodClientProvider = Provider<BilibiliVodClient>((ref) {
  // The transport is the process's own: [DioFactory.create] hands the same
  // instance to every `api` caller, so closing it here — which this provider
  // recomputes on every sign-in — would kill the next request of the whole
  // app and leave the freshly signed-in account reading as signed out.
  final http = ref.watch(networkFactoryProvider).create(profile: ClientProfile.api);
  // The same Bilibili sign-in the live site uses: one cookie serves the
  // video site too (higher renditions, login-only archives).
  final credential = ref.watch(accountsProvider).credentials[SiteIds.bilibili];
  final cookie = credential == null
      ? ''
      : credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  return BilibiliVodClient(http, cookie: cookie);
});

/// The vod page's state.
final vodProvider = NotifierProvider<VodController, VodState>(VodController.new);

/// The browse feeds the video station opens: the home recommendation feed,
/// the site-wide popular list, and a region's recommendation feed (paged).
enum VodFeedKind { recommend, popular, region }

/// One feed's videos, the next page it asks, and its load state.
typedef VodFeedState = ({List<VodVideo> videos, int nextPage, bool hasMore, bool loading, VodFailure? error});

VodFeedState _feedInitial() => (videos: const [], nextPage: 1, hasMore: true, loading: false, error: null);

/// A feed's cache key: `recommend`, `popular` or `region:<tid>`.
String vodFeedKey(VodFeedKind kind, {int id = 0}) => switch (kind) {
  VodFeedKind.recommend => 'recommend',
  VodFeedKind.popular => 'popular',
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
    state = {...state, key: _with(current, loading: true, clearError: true)};
    final client = ref.read(vodClientProvider);
    try {
      final VodVideoPage answer;
      switch (parts.first) {
        case 'recommend':
          final pageAnswer = await client.recommend(page: page);
          answer = VodVideoPage(videos: pageAnswer.videos, hasMore: pageAnswer.videos.isNotEmpty);
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
