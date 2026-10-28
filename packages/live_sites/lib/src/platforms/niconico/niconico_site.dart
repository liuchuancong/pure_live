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
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_http.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_area_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_discovery_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_link_resolver.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_playback_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_room_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_room_refresh.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_search_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_status_check.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_danmaku_session.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_seat_session.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

// The adapter spells its class name in its constructor; the `.new` shorthand
// would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The niconico adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2); requests in `api/`, parsing in `parsers/`, features
/// in `capabilities/`, the watching seat and the comment feed in `danmaku/`.
///
/// Everything runs anonymously (no cookie is sent to any page or API); a
/// program whose watch page grants an anonymous viewer access is playable, one
/// that needs a login, is country-restricted, or is private, paid or
/// followers-only reports the matching [NiconicoFailure] instead of a stream.
final class NiconicoSite implements LiveSite {
  /// Creates the adapter over [http]; [now] is injectable for tests, and so is
  /// [seatConnector] (the seat's own socket opener — the shipped one is
  /// `webSocketConnect`, a test's own otherwise, since a seat never
  /// reconnects and is not worth a fake transport for).
  NiconicoSite({required this.http, SocketConnector? seatConnector, DateTime Function()? now})
    : seatConnector = seatConnector ?? webSocketConnect,
      now = now ?? DateTime.now;

  /// Transport (the capabilities' and the comment feed's).
  final NiconicoHttp http;

  /// The seat WebSocket opener (`webSocketConnect` unless a test gave one).
  final SocketConnector seatConnector;

  /// Injectable clock (the seat grant's cookies expire against it).
  final DateTime Function() now;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => niconicoManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Pages ---------------------------------------------------------------------

  /// GETs the watch page of [roomId] and parses it into a [NiconicoWatch].
  Future<NiconicoWatch> watch(String roomId) async {
    final id = roomId.trim();
    if (!NiconicoEndpoints.isRoomId(id)) {
      throw NiconicoFailure(NiconicoFailureKind.notFound, 'room id "$id" is not a niconico room');
    }
    final response = await http.get(NiconicoEndpoints.watchPage(id), headers: NiconicoEndpoints.headers);
    return NiconicoRoomParser.watch(response.text, roomId: id, status: response.status);
  }

  /// The room at [roomId], its watch snapshot riding in the room's runtime
  /// handles for the seat, and — when an anonymous viewer may watch it — kept
  /// briefly as the seat's bootstrap, so entering a room and then playing it
  /// costs one page read rather than two.
  Future<LiveRoom> detail(String roomId) async {
    final snapshot = await watch(roomId);
    final room = NiconicoRoomParser.room(snapshot);
    if (snapshot.socket != null) {
      // Keyed by the id the caller gets back, because that is the id the seat
      // is opened with — the watch page's own program id is often another one
      // (a broadcaster's `user/<id>` owns whatever program is on air).
      _bootstraps
        ..remove(room.roomId)
        ..[room.roomId] = (watch: snapshot, readAt: now());
      if (_bootstraps.length > maxBootstraps) _bootstraps.remove(_bootstraps.keys.first);
    }
    return room;
  }

  /// How long a kept watch page still opens a seat: the seat's own bootstrap
  /// is short-lived, so a page older than this is read again rather than
  /// handed to the seat server.
  static const Duration bootstrapLifetime = Duration(seconds: 60);

  /// How many rooms keep a bootstrap (the app enters a list of rooms; only
  /// the ones it plays matter).
  static const int maxBootstraps = 8;

  final Map<String, ({NiconicoWatch watch, DateTime readAt})> _bootstraps = {};

  /// One recent-tab page of [tab]. A tab niconico does not have — including
  /// the `niconico` category the tabs are parented under — is the caller's
  /// mistake and is refused without a request; so is a page outside the
  /// platform's bounds (1–10000).
  Future<({List<LiveRoom> rooms, bool hasMore})> recent(String tab, int page) async {
    if (!NiconicoEndpoints.tabs.contains(tab)) {
      throw NiconicoFailure(NiconicoFailureKind.invalidArgument, '"$tab" is not a niconico tab');
    }
    checkPaging(page);
    final response = await http.get(NiconicoEndpoints.recentPrograms(tab, page), headers: NiconicoEndpoints.headers);
    return NiconicoRoomParser.listPage(response.text, page: page, search: false, status: response.status);
  }

  /// One on-air search page for [keyword] (a blank keyword answers empty
  /// without a request). The keyword length and the page bounds are niconico's
  /// own; outside them nothing is sent.
  Future<({List<LiveSearchResult> items, bool hasMore})> search(String keyword, int page) async {
    final text = keyword.trim();
    if (text.isEmpty) return const (items: <LiveSearchResult>[], hasMore: false);
    if (text.length > NiconicoEndpoints.maxKeywordLength) {
      const tooLong = 'a niconico keyword has at most ${NiconicoEndpoints.maxKeywordLength} characters';
      throw const NiconicoFailure(NiconicoFailureKind.invalidArgument, tooLong);
    }
    checkPaging(page);
    final response = await http.get(NiconicoEndpoints.searchPrograms(text, page), headers: NiconicoEndpoints.headers);
    return NiconicoRoomParser.searchRooms(response.text, status: response.status, page: page);
  }

  /// Pages 1–10000 (and sizes 1–100): niconico's API stops answering past
  /// them, so asking is a caller's mistake, not a request to make.
  static void checkPaging(int page, [int pageSize = 1]) {
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > 100) {
      throw NiconicoFailure(NiconicoFailureKind.invalidArgument, 'invalid niconico page $page of $pageSize');
    }
  }

  /// GETs [url] with [headers] (the playback provider's media transport),
  /// bounded by [timeout] when given.
  Future<NiconicoResponse> httpGet(Uri url, {Map<String, String> headers = const {}, Duration? timeout}) =>
      http.get(url, headers: headers, timeout: timeout);

  // Seat ----------------------------------------------------------------------

  /// Opens a watching seat on [roomId]'s program: on the watch page the room
  /// entry kept (taken once, while fresh), else on one read now; then the seat
  /// WebSocket, which names the comment server. A seat that fails on a kept
  /// bootstrap is opened once more on a fresh page. A room that cannot be
  /// watched now (offline, restricted, gone) throws a [NiconicoFailure] of the
  /// matching kind, never a seat.
  Future<NiconicoSeat> openSeat(String roomId) async {
    final id = roomId.trim();
    final kept = _bootstraps.remove(id);
    if (kept != null && now().difference(kept.readAt) <= bootstrapLifetime) {
      try {
        return await _seatOn(kept.watch);
      } on NiconicoFailure {
        // The bootstrap expired or the seat server refused it: the page is
        // read again below. Only a kept bootstrap gets that second try.
      }
    }
    return await _seatOn(await watch(id));
  }

  /// Opens a seat on the [snapshot]'s socket; a snapshot that grants no seat
  /// is the room's own unreadability, not a transport failure.
  Future<NiconicoSeat> _seatOn(NiconicoWatch snapshot) async {
    final socket = snapshot.socket;
    if (socket == null) throw _notPlayable(snapshot);
    final seat = NiconicoSeat(socket, now: now, connector: seatConnector);
    await seat.connect();
    return seat;
  }

  /// Why an on-air [snapshot]'s stream cannot be opened anonymously.
  static NiconicoFailure _notPlayable(NiconicoWatch snapshot) => switch (snapshot.restriction) {
    LiveRestriction.regionBlocked => NiconicoFailure(
      NiconicoFailureKind.regionBlocked,
      '${snapshot.programId}: country restriction',
    ),
    LiveRestriction.needsLogin => NiconicoFailure(NiconicoFailureKind.needsLogin, '${snapshot.programId}: needLogin'),
    LiveRestriction.private => NiconicoFailure(NiconicoFailureKind.streamUnavailable, '${snapshot.programId}: private'),
    LiveRestriction.paid => NiconicoFailure(NiconicoFailureKind.streamUnavailable, '${snapshot.programId}: paid'),
    LiveRestriction.subscribersOnly => NiconicoFailure(
      NiconicoFailureKind.streamUnavailable,
      '${snapshot.programId}: followers-only',
    ),
    _ => NiconicoFailure(NiconicoFailureKind.streamUnavailable, '${snapshot.programId} is ${snapshot.status.name}'),
  };

  // Capability wiring ---------------------------------------------------------

  NiconicoRoomProvider? _room;
  NiconicoAreaProvider? _area;
  NiconicoDiscoveryProvider? _discovery;
  NiconicoSearchProvider? _search;
  NiconicoPlaybackProvider? _playback;
  NiconicoDanmakuProvider? _danmaku;
  NiconicoLinkResolver? _link;
  NiconicoRoomRefresh? _refresh;
  NiconicoStatusCheck? _status;

  /// The capability of type [T], or null when niconico does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= NiconicoRoomProvider(site: this);
    final area = _area ??= NiconicoAreaProvider(site: this);
    final discovery = _discovery ??= NiconicoDiscoveryProvider(site: this);
    final search = _search ??= NiconicoSearchProvider(site: this);
    final playback = _playback ??= NiconicoPlaybackProvider(site: this);
    final danmaku = _danmaku ??= NiconicoDanmakuProvider(site: this);
    final link = _link ??= NiconicoLinkResolver(site: this);
    final refresh = _refresh ??= NiconicoRoomRefresh(site: this);
    final status = _status ??= NiconicoStatusCheck(refresh: refresh);
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
