import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:live_vod/live_vod.dart' show VodFailure;
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
      state = (
        query: query,
        songs: state.songs,
        nextPage: page,
        hasMore: false,
        loading: false,
        error: failure is VodFailure ? failure.message : '$failure',
      );
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
