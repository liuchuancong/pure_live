import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' show max, min;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_source.dart'
    show musicSourceListProvider, musicSourceProvider;
import 'package:pure_live/modules/music/controller/sources/music_hot_words.dart' show MusicHotWords;

/// What the library view holds: the committed query, its songs, where the
/// next page asks, the in-flight flag and the last failure.
typedef MusicSearchState = ({
  String query,
  List<audio.MusicTrack> songs,
  int nextPage,
  bool hasMore,
  bool loading,
  String? error,
});

MusicSearchState _initial() =>
    (query: '', songs: const <audio.MusicTrack>[], nextPage: 1, hasMore: true, loading: false, error: null);

/// The page-source choice that searches every platform at once — the
/// reference's 'all' source.
const String kMusicSearchAllSourceId = 'all';

/// The search page's own source: [kMusicSearchAllSourceId] aggregates every
/// platform, a platform id searches only it. Page-local on purpose — it
/// starts on the viewer's default source and never follows it afterwards.
final class MusicSearchSourceController extends Notifier<String> {
  @override
  String build() => ref.read(musicSourceProvider).id;

  /// The page's source choice.
  String get source => state;

  /// Picks [id] for this page's searches.
  set source(String id) => state = id;
}

/// The library search page's source.
final musicSearchSourceIdProvider = NotifierProvider<MusicSearchSourceController, String>(
  MusicSearchSourceController.new,
);

/// The library view's search, paged the way the station's own search pages.
///
/// A newer query always wins: an answer from a search that was replaced
/// drains without writing, so a slow page cannot overwrite a newer one.
final class MusicSearchController extends Notifier<MusicSearchState> {
  int _generation = 0;

  @override
  MusicSearchState build() => _initial();

  /// Searches [query] from its first page; a blank query clears the results.
  Future<void> search(String query) {
    final word = query.trim();
    if (word.isEmpty) {
      _generation++;
      state = _initial();
      return Future.value();
    }
    unawaited(ref.read(musicSearchHistoryProvider.notifier).record(word));
    return _load(word, 1);
  }

  /// Loads the next page when one is left.
  Future<void> loadMore() {
    if (state.loading || !state.hasMore || state.query.isEmpty) return Future.value();
    return _load(state.query, state.nextPage);
  }

  /// Runs the committed query again from its first page.
  Future<void> retry() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, 1);
  }

  Future<void> _load(String query, int page) async {
    final generation = ++_generation;
    state = (
      query: query,
      songs: page == 1 ? const <audio.MusicTrack>[] : state.songs,
      nextPage: state.nextPage,
      hasMore: state.hasMore,
      loading: true,
      error: null,
    );
    try {
      final sourceId = ref.read(musicSearchSourceIdProvider);
      final answer = sourceId == kMusicSearchAllSourceId
          ? await _searchAll(query, page)
          : await _sourceOf(sourceId).search(query, page: page);
      if (!ref.mounted || generation != _generation) return;
      final songs = page == 1 ? <audio.MusicTrack>[] : [...state.songs];
      final seen = {for (final song in songs) '${song.sourceId}:${song.id}'};
      songs.addAll(answer.items.where((song) => seen.add('${song.sourceId}:${song.id}')));
      state = (query: query, songs: songs, nextPage: page + 1, hasMore: answer.hasMore, loading: false, error: null);
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (query: query, songs: state.songs, nextPage: page, hasMore: false, loading: false, error: '$failure');
    }
  }

  audio.MusicSource _sourceOf(String id) {
    for (final source in ref.read(musicSourceListProvider)) {
      if (source.id == id) return source;
    }
    throw StateError('no music source $id');
  }

  /// The reference's 'all' search: every platform answers the same page
  /// concurrently, a refusal counts as an empty answer, and the merged batch
  /// ranks by how closely `title artist` matches the keyword.
  Future<audio.MusicSourcePage<audio.MusicTrack>> _searchAll(String query, int page) async {
    final answers = await Future.wait([
      for (final source in ref.read(musicSourceListProvider))
        source
            .search(query, page: page)
            .catchError((Object _) => const audio.MusicSourcePage<audio.MusicTrack>.empty()),
    ]);
    final merged = <audio.MusicTrack>[];
    final seen = <String>{};
    var total = 0;
    var hasMore = false;
    for (final answer in answers) {
      total = max(total, answer.total ?? 0);
      hasMore = hasMore || answer.hasMore;
      for (final song in answer.items) {
        if (seen.add('${song.sourceId}:${song.id}')) merged.add(song);
      }
    }
    merged.sort(
      (a, b) => _similarity(query, '${b.title} ${b.artist}').compareTo(_similarity(query, '${a.title} ${a.artist}')),
    );
    return audio.MusicSourcePage(items: merged, page: page, total: total, hasMore: hasMore);
  }

  /// lx-music's `similar`: one minus the normalized edit distance, the rank
  /// the merged 'all' answers sort by.
  static double _similarity(String left, String right) {
    var a = left;
    var b = right;
    if (a.isEmpty || b.isEmpty) return 0;
    if (a.length > b.length) (a, b) = (b, a);
    final bl = b.length;
    final row = List<int>.generate(bl + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      var top = row[0];
      row[0] += 1;
      final ai = a.codeUnitAt(i - 1);
      for (var j = 1; j <= bl; j++) {
        final tmp = min(min(row[j] + 1, row[j - 1] + 1), top + (ai == b.codeUnitAt(j - 1) ? 0 : 1));
        top = row[j];
        row[j] = tmp;
      }
    }
    return 1 - row[bl] / bl;
  }
}

/// The library view's search.
final musicSearchProvider = NotifierProvider<MusicSearchController, MusicSearchState>(MusicSearchController.new);

/// The boards the module's source advertises (its 排行榜 catalogs).
final musicCatalogsProvider = FutureProvider<List<audio.MusicCatalog>>(
  (ref) => ref.watch(musicSourceProvider).catalogs(),
);

/// One board's songs; a board is one answer and has no pages.
final FutureProviderFamily<List<audio.MusicTrack>, audio.MusicCatalog> musicCatalogItemsProvider =
    FutureProvider.family<List<audio.MusicTrack>, audio.MusicCatalog>((ref, catalog) async {
      final answer = await ref.watch(musicSourceProvider).catalogItems(catalog);
      return answer.items;
    });

/// The source's top searches, shown while the query box is empty.
///
/// A source that cannot answer simply has none; the idle page then shows only
/// the history, so a failed hot-word request never blocks searching.
final musicHotSearchesProvider = FutureProvider<List<String>>((ref) async {
  try {
    final source = ref.watch(musicSourceProvider);
    if (source case final MusicHotWords hot) return await hot.hotSearches();
    return const <String>[];
  } on Object {
    return const [];
  }
});

/// The completions for the text in the query box; an empty query has none and
/// a source without the capability answers none.
final FutureProviderFamily<List<String>, String> musicSearchSuggestionsProvider = FutureProvider.family<List<String>, String>(
  (ref, query) async {
  final word = query.trim();
  if (word.isEmpty) return const <String>[];
  try {
    final source = ref.watch(musicSourceProvider);
    if (source case final MusicHotWords hot) return await hot.suggestions(word);
    return const <String>[];
    } on Object {
      return const [];
    }
  },
);

/// The preference the recent searches are kept under.
const String kMusicSearchHistoryKey = 'music.search.history';

/// How many searches the module remembers.
const int kMusicSearchHistoryLimit = 20;

/// The queries the viewer searched, newest first — the reference's 搜索历史.
final class MusicSearchHistoryController extends Notifier<List<String>> {
  @override
  List<String> build() {
    try {
      final raw = StoragePrefs.getString(kMusicSearchHistoryKey);
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

  /// Puts [query] at the front, dropping an older copy.
  Future<void> record(String query) async {
    final word = query.trim();
    if (word.isEmpty) return;
    if (state.isNotEmpty && state.first == word) return;
    state = [word, ...state.where((entry) => entry != word)].take(kMusicSearchHistoryLimit).toList();
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
      await StoragePrefs.setString(kMusicSearchHistoryKey, jsonEncode(state));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The viewer's recent searches.
final musicSearchHistoryProvider = NotifierProvider<MusicSearchHistoryController, List<String>>(
  MusicSearchHistoryController.new,
);
