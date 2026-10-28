import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoClientProvider, hongguoFailureText;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart'
    show HongguoDiscoveryCursor, HongguoSearchCursor, HongguoWebsiteBoard;

/// One shelf's browse feed: what it holds, the cursor the next page asks,
/// the selection it holds it under, and the ask's state.
typedef HongguoBrowseFeed = ({
  List<HongguoSeries> items,
  HongguoDiscoveryCursor? cursor,
  bool loading,
  bool hasMore,
  String? error,
  Map<String, String> selection,
  List<HongguoFilterRow> groups,
});

const HongguoBrowseFeed _idleFeed = (
  items: [],
  cursor: null,
  loading: false,
  hasMore: true,
  error: null,
  selection: {},
  groups: [],
);

/// The browse feeds, one per shelf, straight from the official landpage:
/// the first page carries the selector panel, later pages ride the cursor.
/// A changed selection resets the feed; a newer ask always wins.
final class HongguoBrowseController extends Notifier<Map<String, HongguoBrowseFeed>> {
  int _generation = 0;

  @override
  Map<String, HongguoBrowseFeed> build() => const {};

  /// The shelf's feed, or the idle one before it first opens.
  HongguoBrowseFeed feedOf(HongguoGenre genre) => state[genre.name] ?? _idleFeed;

  /// Loads the shelf's first page when it has nothing yet.
  Future<void> open(HongguoGenre genre) {
    final feed = feedOf(genre);
    if (feed.items.isEmpty && !feed.loading && feed.error == null) return _load(genre, feed.selection);
    return Future.value();
  }

  /// Asks the shelf's next page.
  Future<void> loadMore(HongguoGenre genre) {
    final feed = feedOf(genre);
    if (feed.loading || !feed.hasMore || feed.cursor == null) return Future.value();
    return _load(genre, feed.selection, cursor: feed.cursor);
  }

  /// Runs the shelf's ask again from its first page.
  Future<void> retry(HongguoGenre genre) => _load(genre, feedOf(genre).selection);

  /// Chooses [id] under [rowType], or clears the dimension when null; the
  /// feed resets and the ask goes out. A new genre discards the previous
  /// shelf's conditions, as the reference does.
  Future<void> select(HongguoGenre genre, String rowType, String? id) {
    final selection = Map<String, String>.of(feedOf(genre).selection);
    if (id == null || id.isEmpty) {
      selection.remove(rowType);
    } else if (rowType == 'genre') {
      selection.clear();
    } else {
      selection[rowType] = id;
    }
    return _load(genre, selection);
  }

  /// Drops every dimension's choice and asks again.
  Future<void> clear(HongguoGenre genre) => _load(genre, const {});

  Future<void> _load(HongguoGenre genre, Map<String, String> selection, {HongguoDiscoveryCursor? cursor}) async {
    final current = feedOf(genre);
    final generation = ++_generation;
    _write(genre, (
      items: cursor == null ? const <HongguoSeries>[] : current.items,
      cursor: cursor,
      loading: true,
      hasMore: current.hasMore,
      error: null,
      selection: selection,
      groups: cursor == null ? const <HongguoFilterRow>[] : current.groups,
    ));
    try {
      final page = await ref
          .read(hongguoClientProvider)
          .discovery(selection: _withGenre(genre, selection), cursor: cursor);
      if (generation != _generation) return;
      _write(genre, (
        items: cursor == null ? page.items : [...current.items, ...page.items],
        cursor: page.next,
        loading: false,
        hasMore: page.hasMore,
        error: null,
        selection: selection,
        groups: cursor == null ? page.groups : current.groups,
      ));
    } on Object catch (error) {
      if (generation != _generation) return;
      _write(genre, (
        items: current.items,
        cursor: null,
        loading: false,
        hasMore: false,
        error: hongguoFailureText(error),
        selection: selection,
        groups: current.groups,
      ));
    }
  }

  /// The shelf's own genre rides along every ask.
  static Map<String, String> _withGenre(HongguoGenre genre, Map<String, String> selection) => {
    if (!selection.containsKey('genre')) 'genre': genre.wire,
    ...selection,
  };

  void _write(HongguoGenre genre, HongguoBrowseFeed feed) {
    state = {...state, genre.name: feed};
  }
}

/// The browse feeds, one entry per shelf.
final hongguoBrowseProvider = NotifierProvider<HongguoBrowseController, Map<String, HongguoBrowseFeed>>(
  HongguoBrowseController.new,
);

/// The newest arrivals: the landpage sorted by shelf time with its
/// seven-day window chosen — the freshest list the platform offers a shelf.
typedef HongguoLatestFeed = ({
  List<HongguoSeries> items,
  HongguoDiscoveryCursor? cursor,
  bool loading,
  bool hasMore,
  String? error,
});

/// The newest-arrivals feed per shelf, the browse feed with the time sort
/// pinned.
final class HongguoLatestController extends Notifier<Map<String, HongguoLatestFeed>> {
  @override
  Map<String, HongguoLatestFeed> build() => const {};

  HongguoLatestFeed feedOf(HongguoGenre genre) =>
      state[genre.name] ?? (items: const [], cursor: null, loading: false, hasMore: true, error: null);

  Future<void> open(HongguoGenre genre) {
    final feed = feedOf(genre);
    if (feed.items.isEmpty && !feed.loading && feed.error == null) return _load(genre, null);
    return Future.value();
  }

  Future<void> loadMore(HongguoGenre genre) {
    final feed = feedOf(genre);
    if (feed.loading || !feed.hasMore || feed.cursor == null) return Future.value();
    return _load(genre, feed.cursor);
  }

  Future<void> retry(HongguoGenre genre) => _load(genre, null);

  Future<void> _load(HongguoGenre genre, HongguoDiscoveryCursor? cursor) async {
    final current = feedOf(genre);
    _write(genre, (
      items: cursor == null ? const [] : current.items,
      cursor: cursor,
      loading: true,
      hasMore: current.hasMore,
      error: null,
    ));
    try {
      final page = await ref
          .read(hongguoClientProvider)
          .discovery(selection: {'genre': genre.wire, 'sort': 'online_time', 'online_time': 'days_7'}, cursor: cursor);
      _write(genre, (
        items: cursor == null ? page.items : [...current.items, ...page.items],
        cursor: page.next,
        loading: false,
        hasMore: page.hasMore,
        error: null,
      ));
    } on Object catch (error) {
      _write(genre, (
        items: current.items,
        cursor: null,
        loading: false,
        hasMore: false,
        error: hongguoFailureText(error),
      ));
    }
  }

  void _write(HongguoGenre genre, HongguoLatestFeed feed) {
    state = {...state, genre.name: feed};
  }
}

/// The newest-arrivals feeds.
final hongguoLatestProvider = NotifierProvider<HongguoLatestController, Map<String, HongguoLatestFeed>>(
  HongguoLatestController.new,
);

/// One board's snapshot: its whole list, when it was read, and the ask's
/// shape — a renewal keeps the rows on screen while the new read runs.
typedef HongguoRankFeed = ({List<HongguoSeries> items, int readAt, bool loading, bool renewing, String? error});

const HongguoRankFeed _idleRank = (items: [], readAt: 0, loading: false, renewing: false, error: null);

/// One topic of a board, and how many of its rows carry it.
typedef HongguoRankTopic = ({String topic, int count});

/// The website's four boards, each held as a whole-list session snapshot.
/// A board read is one call at a time; a stale board shows its rows and
/// renews behind them, and only an explicit refresh forces a new read.
final class HongguoRankController extends Notifier<Map<String, HongguoRankFeed>> {
  /// How long a board's snapshot answers without another read.
  static const Duration ttl = Duration(minutes: 10);

  final Set<String> _inFlight = {};

  @override
  Map<String, HongguoRankFeed> build() => const {};

  /// The board's snapshot.
  HongguoRankFeed feedOf(HongguoWebsiteBoard board) => state[board.name] ?? _idleRank;

  /// The board's rows under [topic] (empty for all of them); the rows keep
  /// the place the board gave them.
  List<HongguoSeries> rowsOf(HongguoWebsiteBoard board, String topic) {
    final items = feedOf(board).items;
    if (topic.isEmpty) return items;
    return [
      for (final series in items)
        if (_topicsOf(series).contains(topic)) series,
    ];
  }

  /// The topics the whole board carries, most frequent first.
  List<HongguoRankTopic> topicsOf(HongguoWebsiteBoard board) {
    final counts = <String, int>{};
    for (final series in feedOf(board).items) {
      for (final topic in _topicsOf(series)) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    final topics = [for (final entry in counts.entries) (topic: entry.key, count: entry.value)]
      ..sort((a, b) => b.count.compareTo(a.count));
    return topics;
  }

  /// Reads the board when nothing answers yet, and renews it quietly when
  /// the held snapshot has gone stale.
  Future<void> open(HongguoWebsiteBoard board) async {
    final feed = feedOf(board);
    if (feed.loading || _inFlight.contains(board.name)) return;
    if (feed.items.isEmpty) {
      await _load(board, renew: false);
      return;
    }
    if (DateTime.now().millisecondsSinceEpoch - feed.readAt > ttl.inMilliseconds) {
      unawaited(_load(board, renew: true));
    }
  }

  /// Reads the board again, in front of the viewer.
  Future<void> refresh(HongguoWebsiteBoard board) {
    if (_inFlight.contains(board.name)) return Future.value();
    return _load(board, renew: feedOf(board).items.isNotEmpty);
  }

  Future<void> _load(HongguoWebsiteBoard board, {required bool renew}) async {
    final held = feedOf(board);
    final key = board.name;
    _inFlight.add(key);
    _write(board, (
      items: held.items,
      readAt: held.readAt,
      loading: !renew,
      renewing: renew,
      error: renew ? held.error : null,
    ));
    try {
      final items = await ref.read(hongguoClientProvider).websiteRankSnapshot(board);
      _write(board, (
        items: items,
        readAt: DateTime.now().millisecondsSinceEpoch,
        loading: false,
        renewing: false,
        error: null,
      ));
    } on Object catch (error) {
      // A read that failed leaves the board the viewer was looking at.
      _write(board, (
        items: held.items,
        readAt: held.readAt,
        loading: false,
        renewing: false,
        error: hongguoFailureText(error),
      ));
    } finally {
      _inFlight.remove(key);
    }
  }

  static List<String> _topicsOf(HongguoSeries series) => [
    for (final tag in series.category.split(RegExp(r'\s*/\s*')))
      if (tag.trim().isNotEmpty && !RegExp(r'^[0-9.]+$').hasMatch(tag.trim())) tag.trim(),
  ];

  void _write(HongguoWebsiteBoard board, HongguoRankFeed feed) {
    state = {...state, board.name: feed};
  }
}

/// The website's boards, one snapshot each.
final hongguoRankProvider =
    NotifierProvider<HongguoRankController, Map<String, HongguoRankFeed>>(HongguoRankController.new);

/// What the search view holds: the committed query, the shelf it was asked
/// of, its hits, the cursor the next page asks, the words the platform
/// suggests for the half-typed query, and the machine's own search history.
typedef HongguoSearchState = ({
  String query,
  HongguoGenre genre,
  List<HongguoSeries> items,
  HongguoSearchCursor? cursor,
  bool hasMore,
  bool loading,
  String? error,
  List<String> suggestions,
  bool suggesting,
  String? suggestionError,
  List<String> history,
});

/// The most words the suggestion call answers, and the most searches kept on
/// this machine — the reference's own numbers.
const int kHongguoSuggestionCount = 8;
const int kHongguoHistoryCount = 20;

const String _kHistoryKey = 'hongguo.search.history';

/// One search state, with everything the caller did not name cleared.
HongguoSearchState _searchState({
  String query = '',
  HongguoGenre genre = HongguoGenre.shortPlay,
  List<HongguoSeries> items = const [],
  HongguoSearchCursor? cursor,
  bool hasMore = false,
  bool loading = false,
  String? error,
  List<String> suggestions = const [],
  bool suggesting = false,
  String? suggestionError,
  List<String> history = const [],
}) => (
  query: query,
  genre: genre,
  items: items,
  cursor: cursor,
  hasMore: hasMore,
  loading: loading,
  error: error,
  suggestions: suggestions,
  suggesting: suggesting,
  suggestionError: suggestionError,
  history: history,
);

/// The station's search: the app's own endpoint (the richer one), paged by
/// the tab's cursor; the website's page answers the first page whenever the
/// app endpoint cannot. Suggestions ride the platform's word list once the
/// typing pauses, and a newer query always wins.
final class HongguoSearchController extends Notifier<HongguoSearchState> {
  int _generation = 0;
  int _suggestGeneration = 0;
  Timer? _suggestTimer;

  @override
  HongguoSearchState build() {
    // The pending suggestion ask belongs to this scope: a page that goes
    // away stops asking.
    ref.onDispose(() => _suggestTimer?.cancel());
    return _searchState(history: _readHistory());
  }

  /// Commits [query] from its first page, over [genre]'s shelf; a blank
  /// query clears the results.
  Future<void> search(String query, {HongguoGenre genre = HongguoGenre.shortPlay}) {
    final word = query.trim();
    _suggestTimer?.cancel();
    if (word.isEmpty) {
      _generation++;
      state = _searchState(history: state.history);
      return Future.value();
    }
    return _load(word, genre, null, const []);
  }

  /// The next page of the committed query when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty || state.cursor == null) return Future.value();
    return _load(state.query, state.genre, state.cursor, state.items);
  }

  /// Runs the committed query again from its first page.
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, state.genre, null, const []);
  }

  /// Asks for words matching [word] once the typing pauses. A blank field
  /// drops the pending ask and the held words; a failed read only says so —
  /// the viewer can still search what they typed.
  void suggest(String word) {
    _suggestTimer?.cancel();
    final clean = word.trim();
    if (clean.isEmpty) {
      _suggestGeneration++;
      state = _copy(suggestions: const [], suggesting: false);
      return;
    }
    _suggestTimer = Timer(const Duration(milliseconds: 350), () => _suggest(clean));
  }

  /// Forgets the machine's own search words; the platform keeps nothing.
  void clearHistory() {
    state = _copy(history: const []);
    try {
      unawaited(StoragePrefs.remove(_kHistoryKey));
    } on Object {
      // A closed store loses the history; nothing else is affected.
    }
  }

  Future<void> _suggest(String word) async {
    final generation = ++_suggestGeneration;
    state = _copy(suggesting: true);
    try {
      final words = await ref.read(hongguoClientProvider).searchSuggestions(word);
      if (generation != _suggestGeneration) return;
      state = _copy(suggestions: words, suggesting: false);
    } on Object catch (error) {
      if (generation != _suggestGeneration) return;
      state = _copy(suggestions: const [], suggesting: false, suggestionError: hongguoFailureText(error));
    }
  }

  Future<void> _load(String query, HongguoGenre genre, HongguoSearchCursor? cursor, List<HongguoSeries> held) async {
    final generation = ++_generation;
    final history = cursor == null ? _remember(query) : state.history;
    state = _searchState(
      query: query,
      genre: genre,
      items: held,
      cursor: cursor,
      hasMore: true,
      loading: true,
      history: history,
    );
    try {
      final result = await ref.read(hongguoClientProvider).appSearch(query, cursor: cursor, genre: genre);
      if (generation != _generation) return;
      state = _searchState(
        query: query,
        genre: genre,
        items: [...held, ...result.items],
        cursor: result.next,
        hasMore: result.hasMore,
        history: history,
      );
    } on Object catch (error) {
      // The website's page covers a first page the app endpoint could not
      // serve; deeper pages simply report the app endpoint's failure.
      if (cursor == null) {
        try {
          final fallback = await ref.read(hongguoClientProvider).websiteSearch(query);
          if (generation != _generation) return;
          state = _searchState(
            query: query,
            genre: genre,
            items: fallback.items,
            cursor: const HongguoSearchCursor(page: 2),
            hasMore: fallback.hasMore,
            history: history,
          );
          return;
        } on Object {
          // Falls through with the app endpoint's own words below.
        }
      }
      if (generation != _generation) return;
      state = _searchState(
        query: query,
        genre: genre,
        items: held,
        cursor: cursor,
        history: history,
        error: hongguoFailureText(error),
      );
    }
  }

  /// The held state with only the named parts changed.
  HongguoSearchState _copy({
    List<String>? suggestions,
    bool? suggesting,
    String? suggestionError,
    List<String>? history,
  }) => _searchState(
    query: state.query,
    genre: state.genre,
    items: state.items,
    cursor: state.cursor,
    hasMore: state.hasMore,
    loading: state.loading,
    error: state.error,
    suggestions: suggestions ?? state.suggestions,
    suggesting: suggesting ?? state.suggesting,
    suggestionError: suggestionError == null && suggestions != null ? null : suggestionError ?? state.suggestionError,
    history: history ?? state.history,
  );

  /// The committed word moves to the head of the history, once each.
  List<String> _remember(String query) {
    final history = [query, ...state.history.where((word) => word != query)].take(kHongguoHistoryCount).toList();
    try {
      unawaited(StoragePrefs.setString(_kHistoryKey, jsonEncode(history)));
    } on Object {
      // A closed store keeps the history for this run only.
    }
    return history;
  }

  static List<String> _readHistory() {
    try {
      final raw = StoragePrefs.getString(_kHistoryKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const [];
      return [for (final word in decoded.take(kHongguoHistoryCount)) if (word is String && word.isNotEmpty) word];
    } on Object {
      return const [];
    }
  }
}

/// The station's search.
final hongguoSearchProvider = NotifierProvider<HongguoSearchController, HongguoSearchState>(
  HongguoSearchController.new,
);
