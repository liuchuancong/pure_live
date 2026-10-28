import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_http.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_area_provider.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_discovery_provider.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_link_resolver.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_playback_provider.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_room_provider.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_room_refresh.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_search_provider.dart';
import 'package:live_sites/src/platforms/showroom/capabilities/showroom_status_check.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_session.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One page of a local slice: its rooms and whether the list goes on.
typedef ShowroomPage = ({List<LiveRoom> rooms, bool hasMore});

/// The SHOWROOM adapter (parsing in `parsers/`, the chat in `danmaku/`):
/// manifest + capability discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous: no cookie and no account. Every request carries
/// [ShowroomEndpoints.headers] and goes as `showroom`, so the app routes the
/// platform through its proxy setting. The requests are the reference's:
/// - the catalog, the areas, the directory, the recommendations and the
///   search are all the `live/onlives` snapshot of every live room, paged
///   locally. Page 1 of the directory and of the search (the pull to
///   refresh) always asks anew; every other call reuses a snapshot younger
///   than [ShowroomEndpoints.snapshotLifetime], so the pages after the first
///   come from the same snapshot as the first;
/// - a room is `room/profile` and `live/live_info` (asked together), after
///   `room/status` when it is named by its key; room entry also asks
///   `live/streaming_url` for a live room, and the rows and the comment
///   arguments ([ShowroomDanmakuArgs]) travel on the room's runtime handles;
/// - the qualities ask `live/streaming_url` alone when the entry kept no
///   rows.
///
/// Rooms are identified by their numeric room id, which is what the details
/// return whatever the room was asked for by. Failures are
/// [ShowroomFailure]s; nothing is disguised as an offline room.
final class ShowroomSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [now] (the snapshot's age) is injectable
  /// for tests.
  ShowroomSite({required this.http, this.connect = webSocketConnect, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Transport.
  final ShowroomHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  final DateTime Function() _now;

  /// The last snapshot, while it is fetched or young; a failed one is
  /// forgotten.
  Future<ShowroomSnapshot>? _snapshot;
  DateTime? _snapshotAt;

  /// The stream data of the room whose entry is the most recent, by room id:
  /// the rows the capabilities hand out until the next entry.
  final Map<String, ShowroomStreamData> _streams = {};

  /// Rooms whose gift tables are kept, by room id; the least recent goes
  /// first.
  final Map<String, ({Future<ShowroomGiftCatalog> gifts, DateTime at, bool failed})> _giftLists = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => showroomManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Snapshot ------------------------------------------------------------------

  Future<ShowroomSnapshot> _fetchSnapshot() async {
    final response = await http.get(ShowroomEndpoints.onlivesUrl());
    return ShowroomParser.snapshot(response.text, status: response.status);
  }

  /// The `onlives` snapshot.
  ///
  /// [fresh] (page 1 of the directory or the search: the pull to refresh)
  /// always asks anew. Otherwise the last snapshot is reused while it is
  /// younger than [ShowroomEndpoints.snapshotLifetime] after it arrived,
  /// whoever fetched it — the pages after the first neither repeat nor skip
  /// rooms of page 1. A fetch under way is shared with every caller; the
  /// latest successful fetch becomes the shared snapshot, and a failed one is
  /// forgotten.
  Future<ShowroomSnapshot> snapshotFor({bool fresh = false}) {
    if (!fresh) {
      final cached = _snapshot;
      final at = _snapshotAt;
      if (cached != null && (at == null || _young(at))) return cached;
    }
    return _share();
  }

  bool _young(DateTime at) {
    final age = _now().difference(at);
    return age >= Duration.zero && age < ShowroomEndpoints.snapshotLifetime;
  }

  /// A new fetch, shared with every caller until it arrives, and then for
  /// [ShowroomEndpoints.snapshotLifetime]; a failed one is forgotten.
  Future<ShowroomSnapshot> _share() {
    late final Future<ShowroomSnapshot> fetch;
    fetch = _fetchSnapshot().then(
      (snapshot) {
        if (identical(_snapshot, fetch)) _snapshotAt = _now();
        return snapshot;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_snapshot, fetch)) {
          _snapshot = null;
          _snapshotAt = null;
        }
        return Error.throwWithStackTrace(error, stack);
      },
    );
    _snapshot = fetch;
    _snapshotAt = null;
    return fetch;
  }

  /// The genre id [areaId] names; null for the recommendations. A genre
  /// number is its own area id; anything else is a caller error, without a
  /// request.
  static int? _genreId(String? areaId) => areaId == null ? null : _genreOf(areaId);

  /// The genre id [areaId] names; anything else than a genre number is a
  /// caller error, without a request.
  static int _genreOf(String areaId) {
    final genre = int.tryParse(areaId);
    if (genre == null || genre < 0) {
      throw ShowroomFailure(ShowroomFailureKind.invalidArgument, 'area "$areaId" is not a SHOWROOM genre');
    }
    return genre;
  }

  /// The lives of [genre]; a genre the snapshot no longer has is not-found.
  static List<ShowroomLive> _genre(ShowroomSnapshot snapshot, int genre) =>
      snapshot.genre(genre) ??
      (throw ShowroomFailure(ShowroomFailureKind.notFound, 'genre $genre is not in the snapshot'));

  // Catalog and directory -----------------------------------------------------

  /// Page [page] of [ShowroomEndpoints.directoryPageSize] rooms of genre
  /// [areaId], or of the recommendations when it is null. A page below 1 or
  /// an area that is not a SHOWROOM genre is a caller error, without a
  /// request; a genre the snapshot no longer has is not-found. Page 1 (the
  /// pull to refresh) asks for a new snapshot.
  Future<ShowroomPage> directory(int page, {String? areaId}) async {
    if (page < 1) {
      throw ShowroomFailure(ShowroomFailureKind.invalidArgument, 'page $page is below 1');
    }
    final genre = _genreId(areaId);
    final snapshot = await snapshotFor(fresh: page == 1);
    return ShowroomParser.directoryPage(genre == null ? snapshot.popular : _genre(snapshot, genre), page: page);
  }

  /// Slice [page] of [pageSize] of the Popularity genre (a page or size
  /// below 1, or a size over [ShowroomEndpoints.maxPageSize], gives nothing,
  /// without a request), from the shared snapshot.
  Future<ShowroomPage> recommend(int page, int pageSize) async {
    if (!ShowroomParser.validSlice(page: page, pageSize: pageSize)) {
      return (rooms: const <LiveRoom>[], hasMore: false);
    }
    final snapshot = await snapshotFor();
    final lives = snapshot.popular;
    return (
      rooms: [
        for (final live in ShowroomParser.slice(lives, page: page, pageSize: pageSize)) ShowroomParser.card(live),
      ],
      hasMore: page * pageSize < lives.length,
    );
  }

  /// As [recommend], for the genre [areaId]; a genre the snapshot no longer
  /// has is not-found.
  Future<ShowroomPage> genreRooms(String areaId, int page, int pageSize) async {
    final genre = _genreOf(areaId);
    if (!ShowroomParser.validSlice(page: page, pageSize: pageSize)) {
      return (rooms: const <LiveRoom>[], hasMore: false);
    }
    final snapshot = await snapshotFor();
    final lives = _genre(snapshot, genre);
    return (
      rooms: [
        for (final live in ShowroomParser.slice(lives, page: page, pageSize: pageSize)) ShowroomParser.card(live),
      ],
      hasMore: page * pageSize < lives.length,
    );
  }

  // Search --------------------------------------------------------------------

  /// The snapshot's lives matching [keyword] (see [ShowroomParser.search]),
  /// slice [page] of [pageSize]. SHOWROOM has no search API: only live rooms
  /// are found, and a link is a keyword like any other. Page 1 asks for a new
  /// snapshot; later pages come from the last one while it is young. A blank
  /// keyword or a slice the reference served nothing for gives nothing,
  /// without a request.
  Future<ShowroomPage> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final query = keyword.trim();
    if (query.isEmpty || !ShowroomParser.validSlice(page: page, pageSize: pageSize)) {
      return (rooms: const <LiveRoom>[], hasMore: false);
    }
    final snapshot = await snapshotFor(fresh: page == 1);
    final matches = ShowroomParser.search(snapshot, query);
    return (
      rooms: [
        for (final live in ShowroomParser.slice(matches, page: page, pageSize: pageSize)) ShowroomParser.card(live),
      ],
      hasMore: page * pageSize < matches.length,
    );
  }

  // Rooms ---------------------------------------------------------------------

  /// The room id the room key [key] names (`room/status`), for the link
  /// resolver: a key is never read as a room id, not even a key made of
  /// digits only; an unknown key is not-found.
  Future<int> resolveRoomKey(String key) async {
    final response = await http.get(ShowroomEndpoints.roomStatusUrl(key));
    return ShowroomParser.roomIdOfStatus(response.text, status: response.status);
  }

  Future<int> _roomNumber(String reference) async {
    final text = reference.trim();
    final number = ShowroomParser.roomNumber(text);
    if (number != null) return number;
    if (!ShowroomEndpoints.keyPattern.hasMatch(text)) {
      throw ShowroomFailure(ShowroomFailureKind.notFound, 'not a room id or key: "$text"');
    }
    final response = await http.get(ShowroomEndpoints.roomStatusUrl(text));
    return ShowroomParser.roomIdOfStatus(response.text, status: response.status);
  }

  /// Room entry: `room/profile` and `live/live_info` asked together, after
  /// `room/status` when [roomId] is a key. A live room also asks
  /// `live/streaming_url`, whose rows are kept for the qualities and travel
  /// on the room's stream handle with the comment arguments; when that
  /// request fails the room still opens, and the qualities ask again. An
  /// offline room is its profile, offline.
  Future<LiveRoom> detail(String roomId) async {
    final number = await _roomNumber(roomId);
    final id = '$number';
    final answers = await Future.wait([
      http.get(ShowroomEndpoints.roomProfileUrl(id)),
      http.get(ShowroomEndpoints.liveInfoUrl(id)),
    ]);
    final profile = ShowroomParser.profile(answers[0].text, roomId: number, status: answers[0].status);
    final info = ShowroomParser.liveInfo(answers[1].text, roomId: number, status: answers[1].status);
    final room = ShowroomParser.room(profile, info);
    if (!info.live) {
      _streams[id] = ShowroomStreamData(roomId: id, offline: true);
      return room;
    }
    var rows = const <Object?>[];
    var failed = false;
    try {
      rows = await _streamRows(id);
    } on ShowroomFailure {
      failed = true;
    }
    final data = ShowroomStreamData(roomId: id, rows: failed ? null : rows);
    _streams[id] = data;
    return room.rebuild(
      (b) => b..runtime = RoomRuntime.of(streamHandle: data, danmakuHandle: info.danmaku).toBuilder(),
    );
  }

  /// A refresh: the room's profile and live info only, without the stream
  /// rows a first visit reads when the room is live.
  Future<LiveRoom> refreshRoom(String roomId) async {
    final number = await _roomNumber(roomId);
    final id = '$number';
    final answers = await Future.wait([
      http.get(ShowroomEndpoints.roomProfileUrl(id)),
      http.get(ShowroomEndpoints.liveInfoUrl(id)),
    ]);
    final profile = ShowroomParser.profile(answers[0].text, roomId: number, status: answers[0].status);
    final info = ShowroomParser.liveInfo(answers[1].text, roomId: number, status: answers[1].status);
    return ShowroomParser.room(profile, info);
  }

  // Gifts ---------------------------------------------------------------------

  /// Room [roomId]'s gift table (`live/gift_list`), fetched once for
  /// concurrent callers and reused for
  /// [ShowroomEndpoints.giftListLifetime]; one that fails counts as empty and
  /// is asked for again after [ShowroomEndpoints.giftRetryAfter]. Never
  /// throws: without a table gifts keep their ids and pictures.
  Future<ShowroomGiftCatalog> giftCatalog(String roomId) {
    final id = roomId.trim();
    final cached = _giftLists.remove(id);
    if (cached != null) {
      final age = _now().difference(cached.at);
      if (age >= Duration.zero &&
          age < (cached.failed ? ShowroomEndpoints.giftRetryAfter : ShowroomEndpoints.giftListLifetime)) {
        _giftLists[id] = cached;
        return cached.gifts;
      }
    }
    final at = _now();
    late final Future<ShowroomGiftCatalog> gifts;
    gifts = () async {
      try {
        final response = await http.get(ShowroomEndpoints.giftListUrl(id));
        return ShowroomParser.giftList(response.text, status: response.status);
      } on Object {
        if (identical(_giftLists[id]?.gifts, gifts)) {
          _giftLists[id] = (gifts: Future.value(ShowroomGiftCatalog.empty), at: _now(), failed: true);
        }
        return ShowroomGiftCatalog.empty;
      }
    }();
    _giftLists[id] = (gifts: gifts, at: at, failed: false);
    while (_giftLists.length > ShowroomEndpoints.giftListRooms) {
      _giftLists.remove(_giftLists.keys.first);
    }
    return gifts;
  }

  // Streams -------------------------------------------------------------------

  Future<List<Object?>> _streamRows(String roomId) async {
    final response = await http.get(ShowroomEndpoints.streamingUrlUrl(roomId));
    return ShowroomParser.streamRows(response.text, status: response.status);
  }

  /// The stream tiers of [roomId]: the rows its room entry brought, or a
  /// fresh `live/streaming_url` — the capabilities are asked by room id
  /// alone. A room entry called offline has no stream, without a request.
  Future<List<ShowroomTier>> _tiers(String roomId) async {
    final data = _streams[roomId];
    if (data != null) {
      if (data.offline) {
        throw ShowroomFailure(ShowroomFailureKind.streamUnavailable, '$roomId is offline');
      }
      if (data.rows != null) return ShowroomParser.tiers(data.rows!);
    }
    return ShowroomParser.tiers(await _streamRows('${await _roomNumber(roomId)}'));
  }

  /// The qualities of [roomId], best first (see [ShowroomParser.tiers]).
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async => [
    for (final tier in await _tiers(roomId)) ShowroomParser.quality(tier),
  ];

  /// The line of [quality] (the best one when it is null) among [roomId]'s
  /// tiers; a quality the room does not offer is stream-unavailable.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final tiers = await _tiers(roomId);
    final id = quality?.qualityId;
    final tier = id == null
        ? tiers.first
        : tiers.where((offered) => offered.quality.id == id).firstOrNull ??
              (throw ShowroomFailure(ShowroomFailureKind.streamUnavailable, 'quality $id is not offered'));
    return [ShowroomParser.line(tier)];
  }

  // Capability wiring ---------------------------------------------------------

  ShowroomRoomProvider? _room;
  ShowroomAreaProvider? _area;
  ShowroomDiscoveryProvider? _discovery;
  ShowroomSearchProvider? _search;
  ShowroomPlaybackProvider? _playback;
  ShowroomDanmakuProvider? _danmaku;
  ShowroomLinkResolver? _link;
  ShowroomRoomRefresh? _refresh;
  ShowroomStatusCheck? _status;

  /// The capability of type [T], or null when SHOWROOM does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site; the site
  /// has no hot list, anchor lookup or web search of its own, so those stay
  /// null.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= ShowroomRoomProvider(site: this);
    final area = _area ??= ShowroomAreaProvider(site: this);
    final discovery = _discovery ??= ShowroomDiscoveryProvider(site: this);
    final search = _search ??= ShowroomSearchProvider(site: this);
    final playback = _playback ??= ShowroomPlaybackProvider(site: this);
    final danmaku = _danmaku ??= ShowroomDanmakuProvider(site: this);
    final link = _link ??= ShowroomLinkResolver(site: this);
    final refresh = _refresh ??= ShowroomRoomRefresh(site: this);
    final status = _status ??= ShowroomStatusCheck(refresh: refresh);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}
