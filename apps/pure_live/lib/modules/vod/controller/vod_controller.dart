import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttp;
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
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
  user;

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
            nextPage: page + 1,
            hasMore: hasMore && _freshWins(page, users.length),
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
  return BilibiliVodClient(http, cookie: cookie, log: appLog.forCategory('vod.api'));
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

/// One UP主's space videos, paged: what a live room's anchor door opens
/// onto, and the station's own space listing besides.
final class VodUploaderState {
  /// A page over [mid]'s uploads.
  const VodUploaderState({
    this.mid = '',
    this.videos = const [],
    this.nextPage = 1,
    this.hasMore = true,
    this.loading = false,
    this.error,
    this.total,
  });

  /// The uploader's mid, as the route carried it.
  final String mid;

  /// Every page answered so far, in order.
  final List<VodVideo> videos;

  /// The next page the source is asked for.
  final int nextPage;

  /// Whether the source may still have more.
  final bool hasMore;

  /// Whether a page is in flight.
  final bool loading;

  /// The last failure; a [VodFailure] carries its own sentence.
  final Object? error;

  /// The space's whole size, said by the source's first page.
  final int? total;
}

/// One UP主's space videos, paged.
final class VodUploaderController extends Notifier<VodUploaderState> {
  @override
  VodUploaderState build() => const VodUploaderState();

  /// Opens [mid]'s space; another mid starts it over.
  Future<void> open(String mid) async {
    if (state.mid == mid && (state.videos.isNotEmpty || state.loading)) return;
    state = VodUploaderState(mid: mid);
    await _load(1);
  }

  /// Loads the next page.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(state.nextPage);
  }

  /// Reads the page again from its first page.
  Future<void> refresh() => _load(1);

  Future<void> _load(int page) async {
    if (state.loading) return;
    final mid = state.mid;
    state = VodUploaderState(
      mid: mid,
      videos: state.videos,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
    );
    try {
      final number = int.tryParse(mid) ?? 0;
      final answer = number <= 0
          ? const VodSearchPage(videos: [])
          : await ref.read(vodClientProvider).spaceVideos(number, page: page);
      if (!ref.mounted || state.mid != mid) return;
      final merged = page == 1 ? [...answer.videos] : [...state.videos];
      if (page > 1) {
        final seen = {for (final video in merged) video.id};
        merged.addAll(answer.videos.where((video) => seen.add(video.id)));
      }
      state = VodUploaderState(
        mid: mid,
        videos: List<VodVideo>.unmodifiable(merged),
        nextPage: page + 1,
        hasMore: answer.hasMore,
        total: page == 1 ? answer.total : state.total,
      );
    } on Object catch (failure) {
      if (!ref.mounted || state.mid != mid) return;
      state = VodUploaderState(
        mid: mid,
        videos: state.videos,
        nextPage: state.nextPage,
        hasMore: false,
        error: failure,
      );
    }
  }
}

/// One UP主's space page.
final vodUploaderProvider = NotifierProvider<VodUploaderController, VodUploaderState>(VodUploaderController.new);

/// The preference key the viewer's recent vod searches live under.
const String kVodSearchHistoryKey = 'vod.search.history';

/// How many searches the station page remembers.
const int kVodSearchHistoryLimit = 20;

/// The queries the viewer searched, newest first — the reference's
/// 搜索历史, the same list the other stations keep about themselves.
final class VodSearchHistoryController extends Notifier<List<String>> {
  @override
  List<String> build() {
    try {
      final raw = StoragePrefs.getString(kVodSearchHistoryKey);
      if (raw == null || raw.isEmpty) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final entry in json)
          if (entry is String && entry.trim().isNotEmpty) entry,
      ];
    } on Object {
      return const [];
    }
  }

  /// Puts [query] at the front, dropping an older copy. The duplicate test
  /// reads case-insensitively, the way the live search's history does — a
  /// re-ask of "abc" after "ABC" is one search said twice, not two words.
  Future<void> record(String query) async {
    final word = query.trim();
    if (word.isEmpty) return;
    if (state.isNotEmpty && state.first.toLowerCase() == word.toLowerCase()) return;
    state = [
      word,
      ...state.where((entry) => entry.toLowerCase() != word.toLowerCase()),
    ].take(kVodSearchHistoryLimit).toList();
    await _save();
  }

  /// Forgets one query.
  Future<void> remove(String query) async {
    state = [
      for (final entry in state)
        if (entry != query) entry,
    ];
    await _save();
  }

  /// Forgets every query.
  Future<void> clear() async {
    state = const [];
    await _save();
  }

  Future<void> _save() async {
    try {
      await StoragePrefs.setString(kVodSearchHistoryKey, jsonEncode(state));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's recent searches.
final vodSearchHistoryProvider = NotifierProvider<VodSearchHistoryController, List<String>>(
  VodSearchHistoryController.new,
);
