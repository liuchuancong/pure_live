import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';
import 'package:live_sites/src/platforms/soop/api/soop_http.dart';
import 'package:live_sites/src/platforms/soop/capabilities/soop_area_provider.dart';
import 'package:live_sites/src/platforms/soop/capabilities/soop_auth_provider.dart';
import 'package:live_sites/src/platforms/soop/capabilities/soop_discovery_provider.dart';
import 'package:live_sites/src/platforms/soop/capabilities/soop_link_resolver.dart';
import 'package:live_sites/src/platforms/soop/capabilities/soop_playback_provider.dart';
import 'package:live_sites/src/platforms/soop/capabilities/soop_room_provider.dart';
import 'package:live_sites/src/platforms/soop/capabilities/soop_search_provider.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_session.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_link.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_room_parser.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The SOOP (formerly AfreecaTV) adapter (parsing in `parsers/`, the chat in
/// `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Every request goes as `soop`, so the app routes the whole platform through
/// its proxy setting, and carries [SoopEndpoints.apiHeaders] with the user's
/// login cookie ([login]) when one is applied or configured — as 3.x and the
/// reference do, since the player API reads that cookie as the viewer's
/// identity and answers an age-restricted broadcast, and the presets above the
/// guest ones, only for a signed-in viewer. Without a login every request is
/// the signed-out website's. The chat socket deliberately carries no cookie at
/// all (see `SoopDanmakuArgs`). The requests are the website's:
/// - the catalog is one category (热门, id 1) whose areas are read in pages
///   of [SoopEndpoints.categoryPageSize] while `is_more` says so, at most
///   [SoopEndpoints.maxCategoryPages] pages;
/// - an area's lives and the site-wide recommendations are plain page
///   numbers; the lists end with an empty page;
/// - a room is the page's `player_live_api` answer (one request), which
///   holds everything streams need; room entry also reads the streamer's
///   station (profile, viewers, unknown streamers), asked for at the same
///   time. A stream is the assigned playlist with a key (`aid`) asked for
///   per quality.
///
/// Restricted broadcasts (age, password, subscribers) are live rooms marked
/// with the restriction; asking for their stream explains it. Failures are
/// [SoopFailure]s; nothing is disguised as an offline room.
final class SoopSite implements LiveSite {
  /// Creates the adapter over [http]. [loginCookie] supplies the user's cookie
  /// (null: every request goes out as a guest), read per request so a changed
  /// login applies at once; [connect] makes the chat's socket (default
  /// [webSocketConnect]); [now] (the cover's cache buster) is injectable for
  /// tests.
  factory SoopSite({
    required SoopHttp http,
    String Function()? loginCookie,
    SocketConnector? connect,
    DateTime Function()? now,
  }) => SoopSite._(http, loginCookie ?? _guest, connect ?? webSocketConnect, now ?? DateTime.now);

  SoopSite._(this.http, this.loginCookie, this.connect, this._now);

  static String _guest() => '';

  /// Transport.
  final SoopHttp http;

  /// The user's stored login cookie, read per request so a changed login
  /// applies at once ('' when the viewer is signed out).
  final String Function() loginCookie;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  final DateTime Function() _now;

  /// The areas the catalog named, by id, so an area page can carry its name.
  final Map<String, LiveArea> _areas = {};

  /// The stream data of the room entered last, by streamer id: the stream
  /// requests the capabilities hand out until the next entry.
  final Map<String, SoopRoomData> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => soopManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Session -------------------------------------------------------------------

  /// The user's cookie ('' when signed out), control characters and a pasted
  /// `Cookie:` prefix stripped: the credential applied through
  /// [applyLoginCredential] wins over the constructor's [loginCookie] until
  /// [clearLoginCredential].
  String login() {
    final raw = _appliedLogin ?? loginCookie();
    final stripped = String.fromCharCodes(raw.codeUnits.where((unit) => unit >= 0x20 && unit != 0x7F)).trim();
    return stripped.toLowerCase().startsWith('cookie:') ? stripped.substring(7).trim() : stripped;
  }

  /// The credential applied through [applyLoginCredential], or null while the
  /// constructor's [loginCookie] answers (in-memory only: storing a login is
  /// the application's business).
  String? _appliedLogin;

  /// Makes every API request carry [cookie] as the user's login. The streams
  /// the guest answers named go with it: the presets and keys are what the
  /// player API hands out per viewer, so a login that arrives later must not
  /// inherit the ones asked for without it (see [_broadcast]).
  void applyLoginCredential(String cookie) {
    _appliedLogin = cookie;
    _streams.clear();
  }

  /// Drops the applied login; requests go back to what the constructor was
  /// given (the signed-out website when that is empty), and the stream data
  /// the login named goes with it.
  void clearLoginCredential() {
    _appliedLogin = null;
    _streams.clear();
  }

  // Catalog and directory -----------------------------------------------------

  /// The catalog: the one category with every area, read in pages of 120
  /// while `is_more` says so. A failing first page fails the catalog (3.x
  /// showed an empty one); a later one ends it with the areas so far, as in
  /// 3.x.
  Future<List<LiveArea>> areas() async {
    final byId = <String, LiveArea>{};
    for (var page = 1; page <= SoopEndpoints.maxCategoryPages; page++) {
      final ({List<LiveArea> areas, bool hasMore}) result;
      try {
        final response = await http.get(SoopEndpoints.categoryListUrl(page), cookie: login());
        result = SoopRoomParser.categoryPage(response.text, status: response.status);
      } on SoopFailure {
        if (page == 1) rethrow;
        break;
      }
      var added = false;
      for (final area in result.areas) {
        if (byId.containsKey(area.areaId)) continue;
        byId[area.areaId] = area;
        added = true;
      }
      _areas
        ..clear()
        ..addAll(byId);
      if (!result.hasMore || !added) break;
    }
    return [...byId.values];
  }

  /// Live rooms of area [areaId] by viewers, page [page] of [pageSize] rows
  /// ([pageSize] sent, limited to 1–60; a page below 1 asked as 1, as 3.x
  /// did). An empty page is the last.
  Future<({List<LiveRoom> rooms, bool hasMore})> areaRooms(String areaId, {int page = 1, int pageSize = 30}) async {
    if (areaId.trim().isEmpty) {
      throw const SoopFailure(SoopFailureKind.invalidArgument, 'area id is empty');
    }
    final response = await http.get(
      SoopEndpoints.areaRoomsUrl(
        areaId: areaId.trim(),
        page: page < 1 ? 1 : page,
        pageSize: pageSize.clamp(1, SoopEndpoints.areaPageSizeMax),
      ),
      cookie: login(),
    );
    final rooms = SoopRoomParser.areaRooms(
      response.text,
      areaName: _areas[areaId.trim()]?.areaName ?? '',
      status: response.status,
    );
    return (rooms: rooms, hasMore: rooms.isNotEmpty);
  }

  /// The whole site by viewers, 60 a page (the platform's own size, which
  /// the caller's page size does not change); the list ends with an empty
  /// page.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend({int page = 1}) async {
    final response = await http.get(SoopEndpoints.recommendUrl(page < 1 ? 1 : page), cookie: login());
    final rooms = SoopRoomParser.recommendRooms(response.text, status: response.status);
    return (rooms: rooms, hasMore: rooms.isNotEmpty);
  }

  // Search --------------------------------------------------------------------

  /// Live search; [pageSize] is sent, limited to 1–50. A blank keyword gives
  /// nothing without a request; an empty page is the last (the platform's
  /// own flag stays true there).
  Future<({List<LiveRoom> rooms, bool hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final text = keyword.trim();
    if (text.isEmpty) return (rooms: const <LiveRoom>[], hasMore: false);
    final response = await http.get(
      SoopEndpoints.searchUrl(
        text,
        page: page < 1 ? 1 : page,
        pageSize: pageSize.clamp(1, SoopEndpoints.searchPageSizeMax),
      ),
      cookie: login(),
    );
    final rooms = SoopRoomParser.searchRooms(response.text, status: response.status);
    return (rooms: rooms, hasMore: rooms.isNotEmpty);
  }

  // Rooms ---------------------------------------------------------------------

  /// [roomId] trimmed, or not-found without a request when it is no
  /// streamer id.
  String _checked(String roomId) {
    final id = roomId.trim();
    if (!SoopEndpoints.roomIdPattern.hasMatch(id)) {
      throw SoopFailure(SoopFailureKind.notFound, 'room id "$id" is not a SOOP streamer id');
    }
    return id;
  }

  /// `player_live_api.php` `type=live` for [roomId]: the room alone, without
  /// the station. The login cookie travels with it — the player API reads the
  /// viewer out of it, which is what makes an age-restricted broadcast
  /// answer instead of refusing.
  Future<SoopDetail> _detail(String roomId, {bool withDanmaku = false}) async {
    final id = _checked(roomId);
    final response = await http.postForm(
      SoopEndpoints.playerLiveUrl(id),
      SoopEndpoints.playerFields(id, type: 'live'),
      cookie: login(),
    );
    return SoopRoomParser.roomDetail(
      response.text,
      requestedId: id,
      now: _now(),
      withDanmaku: withDanmaku,
      status: response.status,
    );
  }

  /// The station of streamer [id]: `missing` when the platform says there is
  /// no such streamer; `station` null when the request failed or was
  /// cancelled (the room then stays the player API's answer). Never
  /// completes with an exception, so it can run beside the player API.
  Future<({SoopStation? station, bool missing})> _stationOf(String id) async {
    try {
      final response = await http.get(SoopEndpoints.stationUrl(id), cookie: login());
      return (station: SoopRoomParser.station(response.text, status: response.status), missing: false);
    } on SoopFailure catch (failure) {
      if (failure.kind == SoopFailureKind.notFound) return (station: null, missing: true);
      return (station: null, missing: false);
    } on Object {
      // A cancelled transport: the answer stands alone.
      return (station: null, missing: false);
    }
  }

  /// Room entry: the player API's answer and the streamer's station, asked
  /// for at the same time (one request more than 3.x, at room entry only):
  /// the profile picture, tagline, viewers, and for a restricted broadcast
  /// the name and cover the player API leaves out
  /// ([SoopRoomParser.withStation]). The room carries its stream data and
  /// the chat's arguments as its handles.
  ///
  /// A streamer who is not broadcasting is offline and a blocked one banned;
  /// an unknown streamer, which the player API answers like an offline one,
  /// is not-found when the station says so; when the station fails the room
  /// is offline. Restricted broadcasts are live with their restriction.
  Future<LiveRoom> detail(String roomId) async {
    final id = _checked(roomId);
    final pending = _detail(id, withDanmaku: true);
    final station = _stationOf(id);
    final answer = await pending;
    final found = await station;
    if (found.missing && answer.room.broadcast.effectiveLiveStatus == LiveStatus.offline) {
      throw SoopFailure(SoopFailureKind.notFound, 'station: no streamer "$id"');
    }
    final room = found.station == null
        ? answer.room
        : SoopRoomParser.withStation(answer.room, answer.data, found.station!, now: _now());
    if (answer.data != null) _streams[id] = answer.data!;
    return room.rebuild(
      (b) => b..runtime = RoomRuntime.of(streamHandle: answer.data, danmakuHandle: answer.danmaku).toBuilder(),
    );
  }

  // Streams -------------------------------------------------------------------

  /// The broadcast [roomId]'s streams come from: the one its room entry
  /// brought, else the player API's. A room without one fails with the
  /// reason ([SoopRoomParser.noStream]): an age-restricted broadcast needs a
  /// login; a password, subscribers-only or ended one is stream-unavailable.
  Future<SoopRoomData> _broadcast(String roomId) async {
    final id = _checked(roomId);
    final held = _streams[id];
    if (held != null) return held;
    final answer = await _detail(id);
    if (answer.data != null && answer.room.broadcast.isLiveNow) {
      _streams[id] = answer.data!;
      return answer.data!;
    }
    throw SoopRoomParser.noStream(answer.room);
  }

  /// The qualities [roomId] offers now (a room without one, like a list
  /// card, asks the player API first). A broadcast without a usable preset
  /// says why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final qualities = SoopRoomParser.qualities((await _broadcast(roomId)).presets);
    if (qualities.isEmpty) {
      throw SoopFailure(SoopFailureKind.streamUnavailable, 'VIEWPRESET: no quality for ${roomId.trim()}');
    }
    return qualities;
  }

  /// The line of [quality] (the best one when it is null): the playlist
  /// assigned for the preset, then its key — 3.x's order. A broadcast that
  /// ended since its entry keeps its number: the key request refuses it, and
  /// recovery re-enters the room.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final data = await _broadcast(roomId);
    if (data.bno.isEmpty || data.rmd.isEmpty) {
      throw const SoopFailure(SoopFailureKind.apiChanged, 'player_live_api: no BNO or RMD');
    }
    final name = quality?.qualityId ?? SoopRoomParser.qualities(data.presets).firstOrNull?.qualityId ?? '';
    if (name.isEmpty) {
      throw SoopFailure(SoopFailureKind.streamUnavailable, 'VIEWPRESET: no quality for ${roomId.trim()}');
    }
    final assign = await http.get(
      SoopRoomParser.assignUrl(rmd: data.rmd, cdn: data.cdn, bno: data.bno, quality: name),
      cookie: login(),
    );
    final playlist = SoopRoomParser.assignedPlaylist(assign.text, status: assign.status);
    final key = await http.postForm(
      SoopEndpoints.playerLiveUrl(roomId.trim()),
      SoopEndpoints.playerFields(roomId, type: 'aid', bno: data.bno, quality: name),
      cookie: login(),
    );
    return [
      SoopRoomParser.resolution(
        playlist: playlist,
        aid: SoopRoomParser.aid(key.text, status: key.status, password: data.password),
        roomId: roomId.trim(),
        cdn: data.cdn,
        codec: data.codecOf(name),
      ),
    ];
  }

  // Links ---------------------------------------------------------------------

  /// The room page of the streamer [uri] names, canonicalized without a
  /// request; null when [uri] is no SOOP streamer page.
  Uri? canonicalRoomUrl(Uri uri) {
    final id = SoopLink.roomIdFromUrl(uri);
    return id == null ? null : Uri.parse(SoopEndpoints.roomPageUrl(id));
  }

  /// Whether [uri] is on one of SOOP's hosts (so a link there that names no
  /// room is this site's, not a foreign one).
  static bool ownsHost(Uri uri) => SoopLink.isOwnHost(uri.host.toLowerCase());

  // Capability wiring ---------------------------------------------------------

  SoopRoomProvider? _room;
  SoopAreaProvider? _area;
  SoopDiscoveryProvider? _discovery;
  SoopSearchProvider? _search;
  SoopPlaybackProvider? _playback;
  SoopDanmakuProvider? _danmaku;
  SoopLinkResolver? _link;
  SoopAuthProvider? _auth;

  /// The capability of type [T], or null when SOOP does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= SoopRoomProvider(site: this);
    final area = _area ??= SoopAreaProvider(site: this);
    final discovery = _discovery ??= SoopDiscoveryProvider(site: this);
    final search = _search ??= SoopSearchProvider(site: this);
    final playback = _playback ??= SoopPlaybackProvider(site: this);
    final danmaku = _danmaku ??= SoopDanmakuProvider(site: this);
    final link = _link ??= SoopLinkResolver(site: this);
    final auth = _auth ??= SoopAuthProvider(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveAuthCapability) => auth as T,
      _ => null,
    };
  }
}
