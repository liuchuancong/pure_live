import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// One board's feed: the website's pages, walked page by page.
typedef HongguoRankState = ({
  HongguoWebsiteBoard board,
  List<HongguoSeries> items,
  int page,
  bool loading,
  bool hasMore,
  String? error,
});

/// The website's four boards, one at a time.
final class HongguoRankController extends Notifier<HongguoRankState> {
  @override
  HongguoRankState build() =>
      (board: HongguoWebsiteBoard.all, items: const [], page: 1, loading: false, hasMore: true, error: null);

  /// Loads [board]'s first page when it is not the one already held.
  Future<void> open(HongguoWebsiteBoard board) {
    if (state.board == board && (state.items.isNotEmpty || state.loading || state.error == null)) {
      return Future.value();
    }
    return _load(board, 1, const []);
  }

  /// The board's next page.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore) return Future.value();
    return _load(state.board, state.page, state.items);
  }

  /// Runs the held board's ask again.
  Future<void> retry() => _load(state.board, 1, const []);

  Future<void> _load(HongguoWebsiteBoard board, int page, List<HongguoSeries> held) async {
    state = (board: board, items: held, page: page, loading: true, hasMore: true, error: null);
    try {
      final result = await ref.read(hongguoClientProvider).websiteRank(board, page: page);
      state = (
        board: board,
        items: [...held, ...result.items],
        page: page + 1,
        loading: false,
        hasMore: result.hasMore,
        error: null,
      );
    } on Object catch (error) {
      state = (board: board, items: held, page: page, loading: false, hasMore: false, error: hongguoFailureText(error));
    }
  }
}

/// The website's boards.
final hongguoRankProvider = NotifierProvider<HongguoRankController, HongguoRankState>(HongguoRankController.new);

/// What the search view holds: the committed query, its hits, the cursor the
/// next page asks, and the ask's state.
typedef HongguoSearchState = ({
  String query,
  List<HongguoSeries> items,
  HongguoSearchCursor? cursor,
  bool hasMore,
  bool loading,
  String? error,
});

/// The station's search: the app's own endpoint (the richer one), paged by
/// the tab's cursor; the website's page answers the first page whenever the
/// app endpoint cannot. A newer query always wins.
final class HongguoSearchController extends Notifier<HongguoSearchState> {
  int _generation = 0;

  @override
  HongguoSearchState build() => (query: '', items: const [], cursor: null, hasMore: false, loading: false, error: null);

  /// Commits [query] from its first page; a blank query clears the results.
  Future<void> search(String query) {
    final word = query.trim();
    if (word.isEmpty) {
      _generation++;
      state = (query: '', items: const [], cursor: null, hasMore: false, loading: false, error: null);
      return Future.value();
    }
    return _load(word, null, const []);
  }

  /// Loads the next page of the committed query when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty || state.cursor == null) return Future.value();
    return _load(state.query, state.cursor, state.items);
  }

  /// Runs the committed query again from its first page.
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, null, const []);
  }

  Future<void> _load(String query, HongguoSearchCursor? cursor, List<HongguoSeries> held) async {
    final generation = ++_generation;
    state = (query: query, items: held, cursor: cursor, hasMore: true, loading: true, error: null);
    try {
      final result = await ref.read(hongguoClientProvider).appSearch(query, cursor: cursor);
      if (generation != _generation) return;
      state = (
        query: query,
        items: [...held, ...result.items],
        cursor: result.next,
        hasMore: result.hasMore,
        loading: false,
        error: null,
      );
    } on Object catch (error) {
      // The website's page covers a first page the app endpoint could not
      // serve; deeper pages simply report the app endpoint's failure.
      if (cursor == null) {
        try {
          final fallback = await ref.read(hongguoClientProvider).websiteSearch(query);
          if (generation != _generation) return;
          state = (
            query: query,
            items: fallback.items,
            cursor: const HongguoSearchCursor(page: 2),
            hasMore: fallback.hasMore,
            loading: false,
            error: null,
          );
          return;
        } on Object {
          // Falls through with the app endpoint's own words below.
        }
      }
      if (generation != _generation) return;
      state = (
        query: query,
        items: held,
        cursor: cursor,
        hasMore: false,
        loading: false,
        error: hongguoFailureText(error),
      );
    }
  }
}

/// The station's search.
final hongguoSearchProvider = NotifierProvider<HongguoSearchController, HongguoSearchState>(
  HongguoSearchController.new,
);
