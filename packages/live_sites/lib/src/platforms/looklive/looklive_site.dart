import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
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
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_http.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_area_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_discovery_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_link_resolver.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_play_recovery.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_playback_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_room_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_room_refresh.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_search_provider.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_status_check.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_session.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many rooms are kept to complete later answers (3.x kept every room
/// it saw).
const int _knownLimit = 2000;

/// One page of a room list.
typedef LookliveListing = ({List<LiveRoom> rooms, bool hasMore});

/// One page of a search: the rooms; a keyword page says nothing about more.
typedef LookliveSearchPage = ({List<LiveRoom> rooms, bool? hasMore});

/// The LOOK Live (NetEase) adapter (3.x's `LookLiveSite` and `LookLiveApi`;
/// parsing in `parsers/`, the chat in `danmaku/`).
///
/// Anonymous: no cookie and no account. Every request is a form POST of
/// NetEase's `weapi` envelope with the web client's headers and a 20 s
/// deadline, sent as `looklive` (so the app routes the platform through its
/// proxy setting). The requests:
/// - the video and voice recommendation lists, 20 rooms a page, paged
///   natively. The recommendations and the search ask both lists for the
///   same page and merge them (video first); an area asks its own list. The
///   merged pages remember which list has ended and no longer ask it (page
///   1 starts over);
/// - a room is `room/get/v3` (one request at every depth); recovery asks it
///   again. The streams are read at room entry and recording only.
///
/// Rooms seen in the lists complete later answers of the same broadcast
/// (heat and viewers, which the room answer lacks, while it is live).
/// Rooms are identified by the room number asked for. Failures are
/// [LookliveFailure]s; nothing is disguised as an offline room.
final class LookliveSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]).
  LookliveSite({required this.http, this.connect = webSocketConnect});

  /// Transport.
  final LookliveHttp http;

  /// How the chat's socket is connected (after the socket.io session).
  final SocketConnector connect;

  /// The last card or answer of each room, oldest first.
  final Map<String, LookLiveRoom> _known = {};

  /// The page at which each list answered "no more" in the merged pages;
  /// cleared by the next merged page 1.
  final Map<LookLiveKind, int> _ended = {};

  /// The room answer of the room entered (or recorded) last, by room
  /// number: the streams the capabilities hand out until the next entry.
  final Map<String, LookLiveRoom> _entered = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => lookliveManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Requests ------------------------------------------------------------------

  /// [rooms] completed from what was seen of each before, and remembered,
  /// dropping the oldest past [_knownLimit].
  List<LookLiveRoom> _remember(Iterable<LookLiveRoom> rooms) => [for (final room in rooms) _keep(room)];

  LookLiveRoom _keep(LookLiveRoom room) {
    final known = _known.remove(room.roomId);
    final kept = known == null ? room : room.enrich(known);
    _known[room.roomId] = kept;
    if (_known.length > _knownLimit) _known.remove(_known.keys.first);
    return kept;
  }

  // Lists ---------------------------------------------------------------------

  /// Page [page] of the list of [kind]. A page past
  /// [LookliveEndpoints.maxPage] is a caller error.
  Future<LookLivePage> _list(LookLiveKind kind, int page) async {
    if (page > LookliveEndpoints.maxPage) {
      throw LookliveFailure(LookliveFailureKind.invalidArgument, 'page $page is past ${LookliveEndpoints.maxPage}');
    }
    final response = await http.post(LookliveEndpoints.listPath(kind), LookliveEndpoints.listPayload(page));
    return LookliveRoomParser.directory(response.text, kind: kind, status: response.status);
  }

  /// Page [page] of [kind]'s list, or of both merged when null: the
  /// requests in turn, video rooms first, each room once; another page when
  /// either list has one. A page below 1 is empty without a request.
  ///
  /// Merged, a list that answered "no more" on an earlier page is not asked
  /// again. Page 1 always asks both and starts the record over, so pulling
  /// to refresh sees a list that has grown again.
  Future<LookLivePage> _page(int page, LookLiveKind? kind) async {
    if (page < 1) return LookLivePage.empty;
    if (kind != null) return await _list(kind, page);
    final asked = [
      for (final list in LookLiveKind.values)
        if (_ended[list] case final end when end == null || page <= end) list,
    ];
    final results = [for (final list in asked) await _list(list, page)];
    if (page == 1) _ended.clear();
    for (final (index, list) in asked.indexed) {
      if (!results[index].hasMore) {
        _ended[list] = page;
      } else if (_ended[list] case final end? when end <= page) {
        _ended.remove(list);
      }
    }
    final rooms = <String, LookLiveRoom>{};
    for (final result in results) {
      for (final room in result.rooms) {
        rooms.putIfAbsent(room.roomId, () => room);
      }
    }
    return LookLivePage(rooms: rooms.values, hasMore: results.any((result) => result.hasMore));
  }

  /// Page [page] of the rooms: [kind]'s list, or both merged (video first)
  /// for the recommendations, each room completed from what was seen of it
  /// before, cut to [pageSize] (at least 1; anything less is nothing
  /// without a request).
  Future<LookliveListing> listing(int page, {LookLiveKind? kind, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final result = await _page(page, kind);
    return (
      rooms: [for (final room in _remember(result.rooms).take(pageSize)) LookliveRoomParser.liveRoom(room)],
      hasMore: result.hasMore,
    );
  }

  // Search --------------------------------------------------------------------

  /// LOOK's search (page 1 only): a room number or room link finds that
  /// room (a room the site does not know is no result); another keyword
  /// filters the first page of both lists by number, name and title, case
  /// ignored, up to [pageSize]. A blank keyword, another page, a page size
  /// below 1 or over [LookliveEndpoints.maxSearchSize], or a link of
  /// another site gives nothing without a request.
  Future<LookliveSearchPage> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page != 1 || pageSize < 1 || pageSize > LookliveEndpoints.maxSearchSize) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    final roomId = LookliveEndpoints.roomIdOf(raw);
    if (roomId != null) {
      try {
        return (rooms: [await refresh(roomId)], hasMore: null);
      } on LookliveFailure catch (failure) {
        if (failure.kind != LookliveFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (_isLink(raw)) return (rooms: const <LiveRoom>[], hasMore: null);
    final query = raw.toLowerCase();
    final rooms = _remember((await _page(1, null)).rooms);
    return (
      rooms: [
        for (final room in rooms.where((room) => LookliveRoomParser.matches(room, query)).take(pageSize))
          LookliveRoomParser.liveRoom(room),
      ],
      hasMore: null,
    );
  }

  /// Whether [input] is a link (`scheme://…`) rather than a keyword: the
  /// lists are filtered with words, which never match one.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // Rooms ---------------------------------------------------------------------

  /// [roomId] as a room number (a room link is read too); anything else is
  /// not-found without a request.
  String _roomId(String roomId) =>
      LookliveEndpoints.roomIdOf(roomId) ??
      (throw LookliveFailure(LookliveFailureKind.notFound, 'room id "${roomId.trim()}" is not a room number'));

  /// The room answer of [roomId], with its streams when [withMedia] and
  /// live, completed from the last card or answer of the room, which it
  /// then replaces.
  Future<LookLiveRoom> _answer(String roomId, {required bool withMedia}) async {
    final number = _roomId(roomId);
    final response = await http.post(LookliveEndpoints.roomPath, LookliveEndpoints.roomPayload(number));
    return _keep(LookliveRoomParser.room(response.text, roomId: number, withMedia: withMedia, status: response.status));
  }

  /// Room entry: the room answer with its streams (one request); the room
  /// carries its answer as the stream handle and its chat as the danmaku
  /// handle, and the answer is what the capabilities hand out until the
  /// next entry.
  Future<LiveRoom> detail(String roomId) async {
    final room = await _answer(roomId, withMedia: true);
    _entered[room.roomId] = room;
    return _withHandles(room);
  }

  /// The room without streams or handles (one request).
  Future<LiveRoom> refresh(String roomId) async => LookliveRoomParser.liveRoom(await _answer(roomId, withMedia: false));

  /// [room] with its answer and chat as the runtime handles.
  LiveRoom _withHandles(LookLiveRoom room) =>
      LookliveRoomParser.liveRoom(room)
          .rebuild((b) => b..runtime = RoomRuntime.of(streamHandle: room, danmakuHandle: room.danmakuArgs).toBuilder());

  /// Whether the room answer says live (one request): live rooms that
  /// cannot be played here (app-only, ticketed) are live too. A banned room
  /// is not live; an unknown state is api-changed, never "offline".
  Future<bool> liveStatus(String roomId) async {
    final room = await _answer(roomId, withMedia: false);
    return switch (room.state) {
      LookLiveState.live => true,
      LookLiveState.offline || LookLiveState.banned => false,
      LookLiveState.unknown => throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        '${room.roomId}: unknown liveStatus',
      ),
    };
  }

  // Streams -------------------------------------------------------------------

  /// The room answer a room entry brought, when [room] can be played (no
  /// request): a LOOK room, not offline now, with the answer of a room entry
  /// or recording (a card or refresh has none), live with streams.
  /// Otherwise stream-unavailable with the reason; another platform's room
  /// is a caller error.
  LookLiveRoom _playable(LiveRoom room) {
    if (room.platform != lookliveSiteId) {
      throw LookliveFailure(LookliveFailureKind.invalidArgument, 'room ${room.platform} is not a LOOK Live room');
    }
    final roomId = _roomId(room.roomId);
    if (room.broadcast.isExplicitlyOfflineNow) {
      throw LookliveFailure(
        LookliveFailureKind.streamUnavailable,
        '$roomId is ${room.broadcast.effectiveLiveStatus.name}',
      );
    }
    final data = _entered[roomId];
    if (data == null || data.roomId != roomId) {
      throw LookliveFailure(LookliveFailureKind.streamUnavailable, '$roomId has no room answer; open the room first');
    }
    final reason = data.unavailableReason;
    if (reason != null) throw LookliveFailure(LookliveFailureKind.streamUnavailable, reason);
    return data;
  }

  /// The qualities of a playable [room]: one per stream (HLS, then FLV), no
  /// request.
  List<LivePlayQuality> qualities(LiveRoom room) => LookliveRoomParser.qualities(_playable(room));

  /// The lines of [quality] (the room's first stream when null) from the
  /// room's streams, no request. A room that cannot be played says why;
  /// another quality is a caller error.
  List<LivePlayLine> lines(LiveRoom room, {LivePlayQuality? quality}) {
    final data = _playable(room);
    final id = quality?.qualityId ?? (data.variants.firstOrNull?.id ?? LookliveEndpoints.hlsId);
    return [LookliveRoomParser.line(data, id)];
  }

  /// Fresh lines for a room that was playable: one new room answer (the
  /// entry it replaces is what the lines come from), then the line of
  /// [quality]. Another quality is a caller error, before any request.
  Future<List<LivePlayLine>> refetchLines(LiveRoom room, {LivePlayQuality? quality}) async {
    final roomId = _playable(room).roomId;
    final id = quality?.qualityId ?? LookliveEndpoints.hlsId;
    if (id != LookliveEndpoints.hlsId && id != LookliveEndpoints.flvId) {
      throw LookliveFailure(LookliveFailureKind.invalidArgument, 'quality "$id" is not a LOOK Live quality');
    }
    final fresh = await detail(roomId);
    return [LookliveRoomParser.line(_playable(fresh), id)];
  }

  // Links ---------------------------------------------------------------------

  /// A room link of `look.163.com`; null for anything else.
  String? roomFromUrl(String url) => LookliveEndpoints.roomIdFromUrl(url);

  // Capability wiring ---------------------------------------------------------

  LookliveRoomProvider? _room;
  LookliveAreaProvider? _area;
  LookliveDiscoveryProvider? _discovery;
  LookliveSearchProvider? _search;
  LooklivePlaybackProvider? _playback;
  LooklivePlayRecovery? _recovery;
  LookliveDanmakuProvider? _danmaku;
  LookliveLinkResolver? _link;
  LookliveRoomRefresh? _refresh;
  LookliveStatusCheck? _status;

  /// The capability of type [T], or null when LOOK Live does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= LookliveRoomProvider(site: this);
    final area = _area ??= LookliveAreaProvider(site: this);
    final discovery = _discovery ??= LookliveDiscoveryProvider(site: this);
    final search = _search ??= LookliveSearchProvider(site: this);
    final playback = _playback ??= LooklivePlaybackProvider(site: this);
    final recovery = _recovery ??= LooklivePlayRecovery(playback: playback);
    final danmaku = _danmaku ??= LookliveDanmakuProvider(site: this);
    final link = _link ??= LookliveLinkResolver(site: this);
    final refresh = _refresh ??= LookliveRoomRefresh(site: this);
    final status = _status ??= LookliveStatusCheck(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LivePlayRecovery) => recovery as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}
