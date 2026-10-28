import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';

/// One shelf's browse feed: the window it holds, the filter selection it
/// holds it under, and the state of the ask.
typedef HongguoBrowseFeed = ({
  List<HongguoSeries> items,
  int loaded,
  bool loading,
  bool hasMore,
  String? error,
  Map<String, String> selection,
});

const HongguoBrowseFeed _idleFeed = (
  items: [],
  loaded: 0,
  loading: false,
  hasMore: true,
  error: null,
  selection: {},
);

/// The browse feeds, one per shelf. The endpoint answers a whole window at
/// once, so "more" is the same ask with a larger window — raised a step at a
/// time until the answer comes back short. A changed selection resets the
/// window; a newer ask always wins over an older one's answer.
final class HongguoBrowseController extends Notifier<Map<String, HongguoBrowseFeed>> {
  static const int _step = 30;
  static const int _cap = 180;

  int _generation = 0;

  @override
  Map<String, HongguoBrowseFeed> build() => const {};

  /// The shelf's feed, or the idle one before it first opens.
  HongguoBrowseFeed feedOf(HongguoGenre genre) => state[genre.name] ?? _idleFeed;

  /// Loads the shelf's first window when it has nothing yet.
  Future<void> open(HongguoGenre genre) {
    final feed = feedOf(genre);
    if (feed.items.isEmpty && !feed.loading && feed.error == null) return _load(genre);
    return Future.value();
  }

  /// Asks for the next step of the window.
  Future<void> loadMore(HongguoGenre genre) {
    final feed = feedOf(genre);
    if (feed.loading || !feed.hasMore) return Future.value();
    return _load(genre);
  }

  /// Runs the shelf's ask again from its first window.
  Future<void> retry(HongguoGenre genre) => _load(genre, fresh: true);

  /// Chooses [id] under [rowType], or clears the dimension when null; the
  /// window resets and the ask goes out.
  Future<void> select(HongguoGenre genre, String rowType, String? id) {
    final selection = Map<String, String>.of(feedOf(genre).selection);
    if (id == null || id.isEmpty) {
      selection.remove(rowType);
    } else {
      selection[rowType] = id;
    }
    return _load(genre, selection: selection, fresh: true);
  }

  /// Drops every dimension's choice and asks again.
  Future<void> clear(HongguoGenre genre) => _load(genre, selection: const {}, fresh: true);

  Future<void> _load(HongguoGenre genre, {Map<String, String>? selection, bool fresh = false}) async {
    final current = feedOf(genre);
    final chosen = selection ?? current.selection;
    final limit = fresh ? _step : (current.loaded + _step).clamp(_step, _cap);
    final generation = ++_generation;
    _write(genre, (
      items: fresh ? const <HongguoSeries>[] : current.items,
      loaded: limit,
      loading: true,
      hasMore: current.hasMore,
      error: null,
      selection: chosen,
    ));
    try {
      final items = await ref.read(hongguoClientProvider).browse(genre: genre, selection: chosen, limit: limit);
      if (_stale(genre, generation, chosen)) return;
      _write(genre, (
        items: items,
        loaded: limit,
        loading: false,
        hasMore: items.length >= limit && limit < _cap,
        error: null,
        selection: chosen,
      ));
    } on Object catch (error) {
      if (_stale(genre, generation, chosen)) return;
      _write(genre, (
        items: current.items,
        loaded: limit,
        loading: false,
        hasMore: false,
        error: error is HongguoFailure ? error.message : '$error',
        selection: chosen,
      ));
    }
  }

  /// Whether an answer arrived after the shelf moved on: another ask of this
  /// shelf started, or the selection it was asked under is gone.
  bool _stale(HongguoGenre genre, int generation, Map<String, String> selection) {
    if (generation != _generation) return true;
    final feed = feedOf(genre);
    return !_sameSelection(feed.selection, selection) && feed.loading;
  }

  static bool _sameSelection(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _write(HongguoGenre genre, HongguoBrowseFeed feed) {
    state = {...state, genre.name: feed};
  }
}

/// The browse feeds, one entry per shelf.
final hongguoBrowseProvider =
    NotifierProvider<HongguoBrowseController, Map<String, HongguoBrowseFeed>>(HongguoBrowseController.new);

/// One shelf's selector panel and the state of the ask that carries it.
typedef HongguoPanelState = ({List<HongguoFilterRow> rows, bool loading, String? error});

/// The selector panels, one per shelf, loaded once on the shelf's first
/// browse view; the source's own panel is live, but a shelf's dimensions
/// do not change under a session.
final class HongguoFilterPanelController extends Notifier<Map<String, HongguoPanelState>> {
  @override
  Map<String, HongguoPanelState> build() => const {};

  /// The shelf's panel, or nothing before it first opens.
  HongguoPanelState panelOf(HongguoGenre genre) =>
      state[genre.name] ?? (rows: const [], loading: false, error: null);

  /// Loads the shelf's panel when it has none yet.
  Future<void> open(HongguoGenre genre) {
    final panel = panelOf(genre);
    if (panel.rows.isNotEmpty || panel.loading) return Future.value();
    _write(genre, (rows: panel.rows, loading: true, error: null));
    return ref
        .read(hongguoClientProvider)
        .filters(genre)
        .then((rows) => _write(genre, (rows: rows, loading: false, error: null)))
        .catchError((
          Object error,
        ) {
          _write(genre, (rows: const [], loading: false, error: error is HongguoFailure ? error.message : '$error'));
        });
  }

  void _write(HongguoGenre genre, HongguoPanelState panel) {
    state = {...state, genre.name: panel};
  }
}

/// The selector panels, one entry per shelf.
final hongguoFilterPanelProvider =
    NotifierProvider<HongguoFilterPanelController, Map<String, HongguoPanelState>>(HongguoFilterPanelController.new);

/// The board the boards view holds, its ranked list, and the ask's state.
typedef HongguoRankState = ({HongguoBoard board, List<HongguoSeries> items, bool loading, String? error});

/// The comic boards: one board at a time, chosen by the view's chips.
final class HongguoRankController extends Notifier<HongguoRankState> {
  @override
  HongguoRankState build() => (board: HongguoBoard.recommend, items: const [], loading: false, error: null);

  /// Loads [board] when it is not the one already held.
  Future<void> open(HongguoBoard board) {
    if (state.board == board && (state.items.isNotEmpty || state.loading || state.error == null)) {
      return Future.value();
    }
    return _load(board);
  }

  /// Runs the held board's ask again.
  Future<void> retry() => _load(state.board);

  Future<void> _load(HongguoBoard board) async {
    state = (board: board, items: const [], loading: true, error: null);
    try {
      final items = await ref.read(hongguoClientProvider).rank(board);
      state = (board: board, items: items, loading: false, error: null);
    } on Object catch (error) {
      state = (board: board, items: const [], loading: false, error: error is HongguoFailure ? error.message : '$error');
    }
  }
}

/// The comic boards.
final hongguoRankProvider = NotifierProvider<HongguoRankController, HongguoRankState>(HongguoRankController.new);

/// The new-arrivals view: one shelf at a time and, on the live-action shelf,
/// whether only today's arrivals are asked for.
typedef HongguoLatestState = ({
  HongguoGenre genre,
  bool onlyToday,
  List<HongguoSeries> items,
  bool loading,
  String? error,
});

/// The newest shelf: one shelf at a time, chosen by the view's chips. The
/// live-action shelf answers a real 今日 window; the other two answer their
/// seven-day window whatever ask's own `onlyToday` says.
final class HongguoLatestController extends Notifier<HongguoLatestState> {
  @override
  HongguoLatestState build() =>
      (genre: HongguoGenre.shortPlay, onlyToday: true, items: const [], loading: false, error: null);

  /// Loads [genre] (and its [onlyToday] window) when it is not the ask
  /// already held.
  Future<void> open(HongguoGenre genre, {bool? onlyToday}) {
    final today = onlyToday ?? state.onlyToday;
    if (state.genre == genre && state.onlyToday == today && (state.items.isNotEmpty || state.loading)) {
      return Future.value();
    }
    return _load(genre, today);
  }

  /// Runs the held ask again.
  Future<void> retry() => _load(state.genre, state.onlyToday);

  Future<void> _load(HongguoGenre genre, bool onlyToday) async {
    state = (genre: genre, onlyToday: onlyToday, items: const [], loading: true, error: null);
    try {
      final items = await ref.read(hongguoClientProvider).latest(genre, onlyToday: onlyToday);
      state = (genre: genre, onlyToday: onlyToday, items: items, loading: false, error: null);
    } on Object catch (error) {
      state = (genre: genre, onlyToday: onlyToday, items: const [], loading: false, error: error is HongguoFailure ? error.message : '$error');
    }
  }
}

/// The newest shelf.
final hongguoLatestProvider = NotifierProvider<HongguoLatestController, HongguoLatestState>(
  HongguoLatestController.new,
);

/// What the search view holds: the committed query, its hits, the cursor the
/// next page asks, and the ask's state.
typedef HongguoSearchState = ({
  String query,
  List<HongguoSeries> items,
  String? cursor,
  bool hasMore,
  bool loading,
  String? error,
});

/// The station's search, paged by the cursor the answer carries. A newer
/// query always wins: an answer from a search that was replaced drains
/// without writing.
final class HongguoSearchController extends Notifier<HongguoSearchState> {
  int _generation = 0;

  @override
  HongguoSearchState build() =>
      (query: '', items: const [], cursor: null, hasMore: false, loading: false, error: null);

  /// Commits [query] from its first page; a blank query clears the results.
  Future<void> search(String query) {
    final word = query.trim();
    if (word.isEmpty) {
      _generation++;
      state = (query: '', items: const [], cursor: null, hasMore: false, loading: false, error: null);
      return Future.value();
    }
    return _load(word, null);
  }

  /// Loads the next page of the committed query when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty) return Future.value();
    return _load(state.query, state.cursor);
  }

  /// Runs the committed query again from its first page.
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, null);
  }

  Future<void> _load(String query, String? cursor) async {
    final generation = ++_generation;
    state = (
      query: query,
      items: cursor == null ? const <HongguoSeries>[] : state.items,
      cursor: cursor,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    try {
      final page = await ref.read(hongguoClientProvider).searchPage(query, cursor: cursor);
      if (generation != _generation) return;
      state = (
        query: query,
        items: cursor == null ? page.items : [...state.items, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        loading: false,
        error: null,
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      state = (
        query: query,
        items: state.items,
        cursor: cursor,
        hasMore: false,
        loading: false,
        error: error is HongguoFailure ? error.message : '$error',
      );
    }
  }
}

/// The station's search.
final hongguoSearchProvider = NotifierProvider<HongguoSearchController, HongguoSearchState>(
  HongguoSearchController.new,
);
