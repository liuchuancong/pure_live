import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_vod/live_vod.dart' show ReplayCollection, VodArchive;

import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;

/// One replay catalog's walk: the recordings read so far and where the
/// paging stands.
typedef ArchiveRecordings = ({List<VodArchive> items, int page, bool hasMore, bool loading, Object? error});

/// The replay catalog's whole state: the creator's collections, the one
/// being read, and its recordings. The walk's guards are per request, so a
/// collection switched mid-load never lands a stale answer.
typedef ArchiveCatalogState = ({
  List<ReplayCollection> collections,
  String? selectedKey,
  bool opening,
  Object? openingError,
  List<VodArchive> recordings,
  int page,
  bool hasMore,
  bool loading,
  bool loadingMore,
  Object? error,
});

ArchiveCatalogState _catalogInitial() => (
  collections: const [],
  selectedKey: null,
  opening: false,
  openingError: null,
  recordings: const [],
  page: 1,
  hasMore: true,
  loading: false,
  loadingMore: false,
  error: null,
);

/// The creator's replay catalog, opened by a room: the collections the
/// platform labels as broadcast recordings, and the selected one's
/// recordings. The client is the video station's — one Bilibili sign-in
/// serves both, and the replays open through the video station's own
/// player.
final class ArchiveCatalogController extends Notifier<ArchiveCatalogState> {
  int _mid = 0;
  int _epoch = 0;

  @override
  ArchiveCatalogState build() => _catalogInitial();

  /// Reads the creator's collections, then opens the freshest one.
  Future<void> start(int mid) async {
    if (mid <= 0) return;
    if (_mid == mid) return;
    _mid = mid;
    _epoch++;
    final epoch = _epoch;
    state = _catalogInitial();
    try {
      final client = ref.read(vodClientProvider);
      final answer = await client.replayCollections(mid);
      if (_mid != mid || epoch != _epoch) return;
      final collections = answer.items;
      if (collections.isEmpty) {
        // An empty answer is honest: the creator keeps no collection the
        // platform labels as replays.
        state = _catalogInitial();
        return;
      }
      state = (
        collections: collections,
        selectedKey: collections.first.key,
        opening: false,
        openingError: null,
        recordings: const [],
        page: 1,
        hasMore: true,
        loading: true,
        loadingMore: false,
        error: null,
      );
      await _load(collections.first, 1);
    } on Object catch (failure) {
      if (_mid != mid || epoch != _epoch) return;
      state = (
        collections: const [],
        selectedKey: null,
        opening: false,
        openingError: failure,
        recordings: const [],
        page: 1,
        hasMore: true,
        loading: false,
        loadingMore: false,
        error: null,
      );
    }
  }

  /// Reads another collection from its head.
  Future<void> select(String key) async {
    if (key == state.selectedKey || state.loading) return;
    final collection = state.collections.where((item) => item.key == key).firstOrNull;
    if (collection == null) return;
    _epoch++;
    state = (
      collections: state.collections,
      selectedKey: key,
      opening: false,
      openingError: null,
      recordings: const [],
      page: 1,
      hasMore: true,
      loading: true,
      loadingMore: false,
      error: null,
    );
    await _load(collection, 1);
  }

  /// Reloads the selected collection from its head (the pull gesture, and
  /// the retry after a failure).
  Future<void> reload() async {
    final key = state.selectedKey;
    if (key == null || state.loading) return;
    final collection = state.collections.where((item) => item.key == key).firstOrNull;
    if (collection == null) return;
    _epoch++;
    state = (
      collections: state.collections,
      selectedKey: key,
      opening: false,
      openingError: null,
      recordings: const [],
      page: 1,
      hasMore: true,
      loading: true,
      loadingMore: false,
      error: null,
    );
    await _load(collection, 1);
  }

  /// Appends the next block when the source may have one.
  Future<void> loadMore() async {
    final key = state.selectedKey;
    if (key == null || state.loading || state.loadingMore || !state.hasMore) return;
    final collection = state.collections.where((item) => item.key == key).firstOrNull;
    if (collection == null) return;
    final epoch = _epoch;
    final page = state.page + 1;
    final mid = _mid;
    state = (
      collections: state.collections,
      selectedKey: key,
      opening: false,
      openingError: null,
      recordings: state.recordings,
      page: state.page,
      hasMore: state.hasMore,
      loading: false,
      loadingMore: true,
      error: null,
    );
    try {
      final client = ref.read(vodClientProvider);
      final answer = await client.replayArchives(mid, collection, page: page);
      if (epoch != _epoch) return;
      state = (
        collections: state.collections,
        selectedKey: key,
        opening: false,
        openingError: null,
        recordings: [...state.recordings, ...answer.items],
        page: page,
        hasMore: answer.hasMore,
        loading: false,
        loadingMore: false,
        error: null,
      );
    } on Object catch (failure) {
      if (epoch != _epoch) return;
      state = (
        collections: state.collections,
        selectedKey: key,
        opening: false,
        openingError: null,
        recordings: state.recordings,
        page: state.page,
        hasMore: state.hasMore,
        loading: false,
        loadingMore: false,
        error: failure,
      );
    }
  }

  /// Lands one page's answer on the selected collection's walk.
  Future<void> _load(ReplayCollection collection, int page) async {
    final epoch = _epoch;
    final mid = _mid;
    try {
      final client = ref.read(vodClientProvider);
      final answer = await client.replayArchives(mid, collection, page: page);
      if (epoch != _epoch) return;
      state = (
        collections: state.collections,
        selectedKey: state.selectedKey,
        opening: false,
        openingError: null,
        recordings: [...state.recordings, ...answer.items],
        page: page,
        hasMore: answer.hasMore,
        loading: false,
        loadingMore: false,
        error: null,
      );
    } on Object catch (failure) {
      if (epoch != _epoch) return;
      state = (
        collections: state.collections,
        selectedKey: state.selectedKey,
        opening: false,
        openingError: null,
        recordings: state.recordings,
        page: page,
        hasMore: state.hasMore,
        loading: false,
        loadingMore: false,
        error: failure,
      );
    }
  }
}

/// The app's one replay catalog.
final archiveCatalogProvider = NotifierProvider<ArchiveCatalogController, ArchiveCatalogState>(
  ArchiveCatalogController.new,
);
