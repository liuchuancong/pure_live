import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;

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
      final answer = await ref.read(musicSourceProvider).search(query, page: page);
      if (!ref.mounted || generation != _generation) return;
      final songs = page == 1 ? <audio.MusicTrack>[] : [...state.songs];
      final seen = {for (final song in songs) song.id};
      songs.addAll(answer.items.where((song) => seen.add(song.id)));
      state = (query: query, songs: songs, nextPage: page + 1, hasMore: answer.hasMore, loading: false, error: null);
    } on Object catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = (query: query, songs: state.songs, nextPage: page, hasMore: false, loading: false, error: '$failure');
    }
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
