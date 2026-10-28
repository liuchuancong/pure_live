import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// ignore_for_file: switch_on_type
// is the contract here (ARCHITECTURE.md §4.1).

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_http.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_area_provider.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_discovery_provider.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_link_resolver.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_play_lease_lookup.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_playback_provider.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_room_provider.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_room_refresh.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_search_provider.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_status_check.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_session.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_directory.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One page of a room list.
typedef KugouliveListing = ({List<LiveRoom> rooms, bool hasMore});

/// One page of a search: the rooms, and whether the answer says there are
/// more (a keyword page does not, an exact find says nothing).
typedef KugouliveSearchPage = ({List<LiveRoom> rooms, bool? hasMore});

/// How long pages after the first reuse the keyword search page 1 fetched:
/// the pages of one browse cut one answer, a new page 1 (a pull to refresh)
/// asks anew.
const _snapshotLifetime = Duration(seconds: 30);

/// Keywords whose answers are kept.
const _snapshotLimit = 8;

/// The Kugou Live (酷狗直播, 繁星) adapter (parsing in `parsers/`, the chat
/// in `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// A room is its number (3 to 11 digits), as asked for; a room link names
/// its number. Anonymous: no cookie, no account; every request carries
/// [KugouliveEndpoints.apiHeaders] and goes as `kugoulive`, so the app
/// routes the platform through its proxy setting. The requests:
/// - the catalog is the home page's area links, read once and kept; a
///   directory page is one room list (`index/list` for 推荐, `list_v4` for
///   an area);
/// - search is one `getEnterRoomInfo` for a room number or link (page 1),
///   else one `type_all.jsonp` of 200 streamers, paged here: page 1 asks
///   anew, later pages reuse it while it is young;
/// - room entry adds `streamaddr` while the room is live, whose variants
///   the playback hands out.
///
/// Failures are [KugouliveFailure]s; nothing is disguised as an offline
/// room.
final class KugouliveSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [preferH264] reads "优先 H.264" each time
  /// the qualities are listed; [now] (the search callback's and the stream
  /// request's clock values, the search snapshots' age) is injectable for
  /// tests.
  KugouliveSite({
    required this.http,
    this.connect = webSocketConnect,
    bool Function()? preferH264,
    DateTime Function()? now,
  }) : _preferH264 = preferH264 ?? (() => true),
       _now = now ?? DateTime.now;

  /// Transport.
  final KugouliveHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  final bool Function() _preferH264;
  final DateTime Function() _now;

  /// The last answer of each keyword and when it arrived.
  final Map<String, ({DateTime at, List<LiveRoom> rooms})> _searches = {};

  /// The home page's areas, read once for the adapter's lifetime; a failed
  /// read is asked again next time.
  Future<List<LiveArea>>? _areas;

  /// The stream data of the room entered last, by room number: what the
  /// playback hands out until the next entry.
  final Map<String, KugouliveRoomData> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => kugouliveManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Catalog and directory -----------------------------------------------------

  /// The home page's areas; a failed read is asked again next time.
  Future<List<LiveArea>> catalog() => _areas ??= () async {
    try {
      final response = await http.get(KugouliveEndpoints.homeUrl());
      return KugouliveRoomParser.areas(response.text, status: response.status);
    } on Object {
      _areas = null;
      rethrow;
    }
  }();

  /// Page `page` of `pageSize` rooms of the area list (推荐 when null). A
  /// page below 1 is empty without a request; another platform's area or an
  /// id that is not 1–8 digits is a caller error, as is a page past the
  /// platform's last, both before any request.
  Future<KugouliveListing> directory(int page, {String? areaId}) async {
    if (page < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final id = KugouliveRoomParser.areaIdOf(areaId);
    if (id == null) {
      throw KugouliveFailure(KugouliveFailureKind.invalidArgument, 'area "$areaId" is not a Kugou Live area');
    }
    if (page > KugouliveEndpoints.maxPage) {
      throw KugouliveFailure(
        KugouliveFailureKind.invalidArgument,
        'page $page is past ${KugouliveEndpoints.maxPage} (a constant cannot carry it)',
      );
    }
    final response = await http.get(KugouliveEndpoints.directoryUrl(page, id));
    final (:rooms, :hasMore) = kugouliveDirectoryPage(response.text, page: page, status: response.status);
    return (rooms: rooms, hasMore: hasMore);
  }

  // Search --------------------------------------------------------------------

  /// Anchors for [keyword]:
  /// - a blank keyword, a page below 1 or a page size outside 1–100 finds
  ///   nothing;
  /// - a room number or room link finds that room on page 1 (one
  ///   `getEnterRoomInfo`); nothing when there is no such room;
  /// - a keyword over the platform's limit is a caller error;
  /// - else one `type_all.jsonp` answering 200 streamers, live or not, of
  ///   which page [page] of [pageSize] is returned. Page 1 always asks; a
  ///   later page cuts the answer of the same keyword while it is young,
  ///   else asks again.
  Future<KugouliveSearchPage> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final text = keyword.trim();
    if (text.isEmpty || page < 1 || pageSize < 1 || pageSize > KugouliveEndpoints.maxSearchPageSize) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    final roomId = KugouliveEndpoints.parseRoomId(text);
    if (roomId != null) {
      if (page != 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        return (rooms: [(await info(roomId)).room], hasMore: null);
      } on KugouliveFailure catch (failure) {
        if (failure.kind != KugouliveFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (text.length > KugouliveEndpoints.maxKeywordLength) {
      throw const KugouliveFailure(KugouliveFailureKind.invalidArgument, 'keyword longer than 100 characters');
    }
    final rooms = await _keywordRooms(text, page: page);
    return (
      rooms: rooms.skip((page - 1) * pageSize).take(pageSize).toList(),
      hasMore: (page - 1) * pageSize + pageSize < rooms.length ? true : null,
    );
  }

  /// The streamers [keyword] finds: the kept answer for a page after the
  /// first while it is young, else a new request, kept when it succeeds.
  Future<List<LiveRoom>> _keywordRooms(String keyword, {required int page}) async {
    final kept = _searches[keyword];
    if (page > 1 && kept != null) {
      final age = _now().difference(kept.at);
      if (age >= Duration.zero && age < _snapshotLifetime) return kept.rooms;
    }
    final callback = 'pureLive${_now().microsecondsSinceEpoch}';
    final response = await http.get(KugouliveEndpoints.searchUrl(keyword, callback));
    final rooms = KugouliveRoomParser.searchRooms(response.text, callback: callback, status: response.status);
    _searches
      ..remove(keyword)
      ..[keyword] = (at: _now(), rooms: rooms);
    if (_searches.length > _snapshotLimit) _searches.remove(_searches.keys.first);
    return rooms;
  }

  // Rooms ---------------------------------------------------------------------

  /// [roomId] as a room number (a room link names one); anything else is
  /// not-found without a request.
  String _checkedId(String roomId) =>
      KugouliveEndpoints.parseRoomId(roomId) ??
      (throw KugouliveFailure(KugouliveFailureKind.notFound, 'not a Kugou Live room: "$roomId"'));

  /// The room info of [roomId].
  Future<({LiveRoom room, KugouliveState state})> info(String roomId) async {
    final id = _checkedId(roomId);
    final response = await http.get(KugouliveEndpoints.roomInfoUrl(id));
    return KugouliveRoomParser.roomInfo(response.text, roomId: id, status: response.status);
  }

  /// Room entry: `getEnterRoomInfo`, then, while the room is live,
  /// `streamaddr`, whose variants go into the stream data. A room that
  /// cannot be played is entered; its stream says why. A live room carries
  /// what the stream answer tells: `none` with a stream, `needsLogin`,
  /// `unplayable` without a stream. A live room also carries its chat
  /// arguments, whatever its stream answer said.
  Future<LiveRoom> detail(String roomId) async {
    final id = _checkedId(roomId);
    final (:room, :state) = await info(id);
    final refused = KugouliveRoomParser.playbackError(state, id);
    if (refused != null) {
      final data = KugouliveRoomData(roomId: id, unavailable: refused);
      _streams[id] = data;
      return room.rebuild((b) => b..runtime = RoomRuntime.of(streamHandle: data).toBuilder());
    }
    final response = await http.get(KugouliveEndpoints.streamUrl(id, millis: _now().millisecondsSinceEpoch));
    final (restriction, data) = _resolvePlayback(id, response);
    _streams[id] = data;
    return KugouliveRoomParser.withRestriction(room, restriction).rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: data,
          danmakuHandle: KugouliveDanmakuArgs(roomId: id),
        ).toBuilder(),
    );
  }

  /// A refresh: the room info alone, without the stream request a first visit
  /// makes.
  Future<LiveRoom> refreshRoom(String roomId) async => (await info(_checkedId(roomId))).room;

  (LiveRestriction, KugouliveRoomData) _resolvePlayback(String roomId, KugouliveResponse response) {
    try {
      final variants = KugouliveRoomParser.variants(response.text, roomId: roomId, status: response.status);
      return (LiveRestriction.none, KugouliveRoomData(roomId: roomId, variants: variants));
    } on KugouliveFailure catch (failure) {
      switch (failure.kind) {
        case KugouliveFailureKind.needsLogin:
          return (LiveRestriction.needsLogin, KugouliveRoomData(roomId: roomId, unavailable: failure));
        case KugouliveFailureKind.streamUnavailable:
          return (LiveRestriction.unplayable, KugouliveRoomData(roomId: roomId, unavailable: failure));
        case KugouliveFailureKind.notFound:
        case KugouliveFailureKind.apiChanged:
        case KugouliveFailureKind.network:
        case KugouliveFailureKind.riskControl:
        case KugouliveFailureKind.regionBlocked:
        case KugouliveFailureKind.rateLimited:
        case KugouliveFailureKind.invalidArgument:
          rethrow;
      }
    }
  }

  // Streams -------------------------------------------------------------------

  /// The variants of [roomId]: the ones room entry kept, or a fresh entry —
  /// the capabilities are asked by room id alone. A room the platform called
  /// offline has no stream, without a request.
  Future<List<KugouliveVariant>> _variants(String roomId) async {
    final id = _checkedId(roomId);
    final kept = _streams[id];
    if (kept != null) {
      if (kept.unavailable case final error?) throw error;
      return kept.variants;
    }
    await detail(id);
    final data = _streams[id]!;
    if (data.unavailable case final error?) throw error;
    return data.variants;
  }

  /// The qualities (H.264 first while "优先 H.264" is on) from the variants
  /// room entry kept: no request.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async =>
      KugouliveRoomParser.qualities(await _variants(roomId), preferH264: _preferH264());

  /// The lines of [quality] (by its id) with the media headers and the lease
  /// of each URL; a quality the room does not offer is stream-unavailable.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final variants = await _variants(roomId);
    final id = quality?.qualityId;
    final variant = id == null ? variants.firstOrNull : variants.where((entry) => entry.id == id).firstOrNull;
    if (variant == null) {
      throw KugouliveFailure(KugouliveFailureKind.streamUnavailable, 'quality $id is not offered');
    }
    return variant.lines;
  }

  // Capability wiring ---------------------------------------------------------

  KugouliveRoomProvider? _room;
  KugouliveAreaProvider? _area;
  KugouliveDiscoveryProvider? _discovery;
  KugouliveSearchProvider? _search;
  KugoulivePlaybackProvider? _playback;
  KugoulivePlayLeaseLookup? _lease;
  KugouliveDanmakuProvider? _danmaku;
  KugouliveLinkResolver? _link;
  KugouliveRoomRefresh? _refresh;
  KugouliveStatusCheck? _status;

  /// The capability of type [T], or null when Kugou Live does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= KugouliveRoomProvider(site: this);
    final area = _area ??= KugouliveAreaProvider(site: this);
    final discovery = _discovery ??= KugouliveDiscoveryProvider(site: this);
    final search = _search ??= KugouliveSearchProvider(site: this);
    final playback = _playback ??= KugoulivePlaybackProvider(site: this);
    final lease = _lease ??= const KugoulivePlayLeaseLookup();
    final danmaku = _danmaku ??= KugouliveDanmakuProvider(site: this);
    final link = _link ??= KugouliveLinkResolver(site: this);
    final refresh = _refresh ??= KugouliveRoomRefresh(site: this);
    final status = _status ??= KugouliveStatusCheck(refresh: refresh);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LivePlayLeaseLookup) => lease as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}
