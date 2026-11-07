import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_sites/live_sites.dart' show SiteIds;
import 'package:live_vod/live_vod.dart'
    show HuyaArchiveApi, HuyaArchiveVideo, ReplayCollection, SoopArchiveApi, SoopArchiveVideo, VodArchive, VodVideo;

import 'package:pure_live/app/app.dart' show networkFactoryProvider;
import 'package:pure_live/features/account/account.dart' show accountsProvider;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;

/// One row of the replay catalog: what the list renders and what a pick
/// opens. A recording rides as its display model plus its own platform's
/// metadata, because the two stations open replays differently — Bilibili
/// hands the bvid to the video station's player, SOOP keeps its parts and
/// renditions for the archive player.
typedef ArchivePick = ({VodVideo display, VodArchive? bilibili, SoopArchiveVideo? soop, HuyaArchiveVideo? huya});

/// The replay catalog's whole state: the creator's collections, the one
/// being read, and its recordings. The walk's guards are per request, so a
/// collection switched mid-load never lands a stale answer.
typedef ArchiveCatalogState = ({
  String? siteId,
  String? creator,
  List<ReplayCollection> collections,
  String? selectedKey,
  bool opening,
  Object? openingError,
  List<ArchivePick> recordings,
  int page,
  bool hasMore,
  bool loading,
  bool loadingMore,
  Object? error,
});

ArchiveCatalogState _catalogInitial() => (
  siteId: null,
  creator: null,
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
/// recordings. Bilibili reads the video station's client (one sign-in
/// serves both modes); SOOP reads its own review list on the shared
/// transport.
final class ArchiveCatalogController extends Notifier<ArchiveCatalogState> {
  int? _mid;
  int _epoch = 0;
  String? _cookie;

  @override
  ArchiveCatalogState build() => _catalogInitial();

  /// Reads the creator's collections, then opens the freshest one (or, on
  /// SOOP, the review list itself).
  Future<void> start({required String siteId, required String creator}) async {
    if (creator.isEmpty) return;
    if (state.siteId == siteId && state.creator == creator) return;
    _epoch++;
    final epoch = _epoch;
    _mid = siteId == SiteIds.bilibili ? int.tryParse(creator) : null;
    _cookie = siteId == SiteIds.soop ? _soopCookie() : '';
    state = (
      siteId: siteId,
      creator: creator,
      collections: const [],
      selectedKey: null,
      opening: true,
      openingError: null,
      recordings: const [],
      page: 1,
      hasMore: true,
      loading: false,
      loadingMore: false,
      error: null,
    );
    try {
      if (siteId == SiteIds.soop) {
        final answer = await SoopArchiveApi(
          ref.read(networkFactoryProvider).create(profile: ClientProfile.api),
          cookie: _cookie ?? '',
        ).list(creator);
        if (epoch != _epoch) return;
        state = _with(
          recordings: _soopPicks(answer.videos),
          page: 1,
          hasMore: answer.hasMore,
          opening: false,
          loading: false,
        );
        return;
      }
      if (siteId == SiteIds.huya) {
        final answer = await HuyaArchiveApi(ref.read(networkFactoryProvider).create(profile: ClientProfile.api))
            .list(creator);
        if (epoch != _epoch) return;
        state = _with(
          recordings: _huyaPicks(answer.videos),
          page: 1,
          hasMore: answer.hasMore,
          opening: false,
          loading: false,
        );
        return;
      }
      final mid = _mid ?? 0;
      final client = ref.read(vodClientProvider);
      final answer = await client.replayCollections(mid);
      if (epoch != _epoch) return;
      final collections = answer.items;
      if (collections.isEmpty) {
        // An empty answer is honest: the creator keeps no collection the
        // platform labels as replays.
        state = _with(opening: false, hasMore: false);
        return;
      }
      state = _with(collections: collections, selectedKey: collections.first.key, opening: false, loading: true);
      await _load(collections.first, 1);
    } on Object catch (failure) {
      if (epoch != _epoch) return;
      state = _with(opening: false, openingError: failure, loading: false, loadingMore: false);
    }
  }

  /// Reads another collection from its head.
  Future<void> select(String key) async {
    if (key == state.selectedKey || state.loading) return;
    final collection = state.collections.where((item) => item.key == key).firstOrNull;
    if (collection == null) return;
    _epoch++;
    state = _with(
      selectedKey: key,
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
    state = _with(recordings: const [], page: 1, hasMore: true, loading: true, loadingMore: false, error: null);
    await _load(collection, 1);
  }

  /// Appends the next block when the source may have one.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final epoch = _epoch;
    final page = state.page + 1;
    final siteId = state.siteId;
    try {
      List<ArchivePick> next;
      var more = false;
      if (siteId == SiteIds.soop) {
        final creator = state.creator ?? '';
        final answer = await SoopArchiveApi(
          ref.read(networkFactoryProvider).create(profile: ClientProfile.api),
          cookie: _cookie ?? '',
        ).list(creator, page: page);
        next = _soopPicks(answer.videos);
        more = answer.hasMore;
      } else if (siteId == SiteIds.huya) {
        final creator = state.creator ?? '';
        final answer = await HuyaArchiveApi(ref.read(networkFactoryProvider).create(profile: ClientProfile.api))
            .list(creator, page: page);
        next = _huyaPicks(answer.videos);
        more = answer.hasMore;
      } else {
        final key = state.selectedKey;
        final collection = state.collections.where((item) => item.key == key).firstOrNull;
        if (collection == null) return;
        final client = ref.read(vodClientProvider);
        final answer = await client.replayArchives(_mid ?? 0, collection, page: page);
        next = [
          for (final archive in answer.items) (display: archive.asVideo(), bilibili: archive, soop: null, huya: null),
        ];
        more = answer.hasMore;
      }
      if (epoch != _epoch) return;
      state = _with(
        recordings: [...state.recordings, ...next],
        page: page,
        hasMore: more,
        loading: false,
        loadingMore: false,
      );
    } on Object catch (failure) {
      if (epoch != _epoch) return;
      state = _with(loading: false, loadingMore: false, error: failure);
    }
  }

  /// Lands one page's answer on the selected collection's walk.
  Future<void> _load(ReplayCollection collection, int page) async {
    final epoch = _epoch;
    final mid = _mid ?? 0;
    try {
      final client = ref.read(vodClientProvider);
      final answer = await client.replayArchives(mid, collection, page: page);
      if (epoch != _epoch) return;
      state = _with(
        recordings: [
          ...state.recordings,
          ...[
            for (final archive in answer.items) (display: archive.asVideo(), bilibili: archive, soop: null, huya: null),
          ],
        ],
        page: page,
        hasMore: answer.hasMore,
        loading: false,
        loadingMore: false,
      );
    } on Object catch (failure) {
      if (epoch != _epoch) return;
      state = _with(loading: false, loadingMore: false, error: failure);
    }
  }

  List<ArchivePick> _soopPicks(List<SoopArchiveVideo> videos) => [
    for (final video in videos) (display: video.asVideo(), bilibili: null, soop: video, huya: null),
  ];

  List<ArchivePick> _huyaPicks(List<HuyaArchiveVideo> videos) => [
    for (final video in videos) (display: video.asVideo(), bilibili: null, soop: null, huya: video),
  ];

  /// The viewer's SOOP login, the same credential the live site uses, in
  /// the cookie shape the station's web API reads.
  String _soopCookie() {
    try {
      final credential = ref.read(accountsProvider).credentials[SiteIds.soop];
      if (credential == null) return '';
      return credential.cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
    } on Object {
      return '';
    }
  }

  /// The state with only the given fields moved; an error field named with
  /// null is cleared, which is what the walk means every time it writes
  /// one. A sentinel field left out keeps the state's own value.
  ArchiveCatalogState _with({
    List<ReplayCollection>? collections,
    String? selectedKey,
    bool? opening,
    Object? openingError = _keep,
    List<ArchivePick>? recordings,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Object? error = _keep,
  }) => (
    siteId: state.siteId,
    creator: state.creator,
    collections: collections ?? state.collections,
    selectedKey: selectedKey ?? state.selectedKey,
    opening: opening ?? state.opening,
    openingError: openingError == _keep ? state.openingError : openingError,
    recordings: recordings ?? state.recordings,
    page: page ?? state.page,
    hasMore: hasMore ?? state.hasMore,
    loading: loading ?? state.loading,
    loadingMore: loadingMore ?? state.loadingMore,
    error: error == _keep ? state.error : error,
  );
}

/// The merge sentinel: a field left at [_keep] keeps the state's value,
/// because a record's nullable fields cannot say "cleared" any other way.
const _keep = _Keep();

final class _Keep {
  const _Keep();
}

/// The app's one replay catalog.
final archiveCatalogProvider = NotifierProvider<ArchiveCatalogController, ArchiveCatalogState>(
  ArchiveCatalogController.new,
);
