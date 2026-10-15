import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
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
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_endpoints.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_http.dart';
import 'package:live_sites/src/platforms/sixroom/capabilities/sixroom_area_provider.dart';
import 'package:live_sites/src/platforms/sixroom/capabilities/sixroom_discovery_provider.dart';
import 'package:live_sites/src/platforms/sixroom/capabilities/sixroom_link_resolver.dart';
import 'package:live_sites/src/platforms/sixroom/capabilities/sixroom_playback_provider.dart';
import 'package:live_sites/src/platforms/sixroom/capabilities/sixroom_room_provider.dart';
import 'package:live_sites/src/platforms/sixroom/capabilities/sixroom_search_provider.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku_session.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_room_parser.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The 6.cn (六间房) adapter (parsing in `parsers/`, the chat in `danmaku/`):
/// manifest + capability discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous: no cookie, no account. Every request goes as `sixroom` with the
/// platform's headers ([SixroomHttp]). The requests:
/// - the recommendations and 歌区, 舞区, 脱口秀, 派对 are pages of the app's
///   mobile lists (`special`, `u0`, `u1`, `u2`, `u8`), one request a page.
///   Rooms an earlier page of the list gave since its page 1 are left out;
/// - "全部" is still the homepage (every live room; the app has no such
///   list), 星颜 the web's subarea list (the app's `u10` answers nothing).
///   Both are read whole and paged locally: page 1 loads the list, later
///   pages reuse it for 90 s;
/// - the search is `search.php` (one page); a room number or room link looks
///   the room up instead;
/// - a room is the mobile inroom POST for its broadcaster's user id. The id
///   comes from the rooms the site listed, else from the room page.
///
/// The site remembers the rooms it listed and read, and fills a room
/// answer's missing avatar, cover, area and followers from them, and the
/// popularity and start only while the same broadcast is live.
///
/// Rooms are identified by their room number (`rid`). Failures are
/// [SixroomFailure]s; nothing is disguised as an offline room.
final class SixroomSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [now] dates the snapshots of the lists
  /// read whole, and is injectable for tests.
  SixroomSite({required this.http, this.connect = webSocketConnect, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Transport.
  final SixroomHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  final DateTime Function() _now;

  /// How many rooms the site remembers to fill room answers from and to skip
  /// the room page with.
  static const int _rememberLimit = 2000;

  /// The last room seen of each room number, oldest first.
  final Map<String, SixroomRoom> _known = {};

  /// The lists read whole (the homepage, web subareas) by their URL, and
  /// when they were loaded.
  final Map<Uri, ({List<SixroomRoom> rooms, DateTime at})> _snapshots = {};

  /// The rooms of each page of each mobile list sequence (type and page
  /// size) since its page 1.
  final Map<String, Map<int, Set<String>>> _listed = {};

  /// The stream data of the room that was entered last, by room number: the
  /// stream the capabilities hand out until the next entry.
  final Map<String, SixroomRoomData> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => sixroomManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Directory -----------------------------------------------------------------

  /// [room] filled from the last one remembered of its room number, then
  /// remembered as the latest itself.
  SixroomRoom _remember(SixroomRoom room) {
    final known = _known.remove(room.roomId);
    final merged = known == null ? room : room.enrich(known);
    _known[room.roomId] = merged;
    if (_known.length > _rememberLimit) _known.remove(_known.keys.first);
    return merged;
  }

  /// The rooms of the list [url] read whole ([parse] reads its answer):
  /// loaded for a refresh, else reused while younger than 90 s (and not from
  /// the future).
  Future<List<SixroomRoom>> _whole(
    Uri url,
    List<SixroomRoom> Function(String body, int status) parse, {
    required bool refresh,
  }) async {
    final cached = _snapshots[url];
    final at = _now();
    if (!refresh &&
        cached != null &&
        !at.isBefore(cached.at) &&
        at.difference(cached.at) < SixroomEndpoints.directoryCacheLifetime) {
      return cached.rooms;
    }
    final response = await http.get(url);
    final rooms = parse(response.text, response.status);
    _snapshots[url] = (rooms: rooms, at: _now());
    return rooms;
  }

  /// Page [page] of [pageSize] rooms of a list read whole (the homepage for
  /// all rooms; a web subarea for 星颜), paged locally.
  Future<({List<LiveRoom> rooms, bool hasMore})> _wholePage(
    int page,
    int pageSize,
    Uri url,
    List<SixroomRoom> Function(String body, int status) parse,
  ) async {
    final rooms = await _whole(url, parse, refresh: page == 1);
    final start = (page - 1) * pageSize;
    if (start >= rooms.length) return (rooms: const <LiveRoom>[], hasMore: false);
    final end = (start + pageSize).clamp(0, rooms.length);
    return (
      rooms: [for (final room in rooms.sublist(start, end)) SixroomRoomParser.liveRoom(_remember(room))],
      hasMore: end < rooms.length,
    );
  }

  /// Page [page] of [pageSize] rooms of the mobile list [type]: one request.
  /// Rooms an earlier page of the list at this size gave since its page 1
  /// are left out (the list moves by popularity between pages); a page asked
  /// again is not measured against itself.
  Future<({List<LiveRoom> rooms, bool hasMore})> _listPage(int page, int pageSize, String type) async {
    final response = await http.get(SixroomEndpoints.listUrl(type, page: page, size: pageSize), mobile: true);
    final result = SixroomRoomParser.list(
      response.text,
      type: type,
      page: page,
      size: pageSize,
      status: response.status,
    );
    final key = '$type/$pageSize';
    if (page == 1) _listed.remove(key);
    final pages = _listed.putIfAbsent(key, () => {});
    final earlier = {
      for (final MapEntry(key: number, value: ids) in pages.entries)
        if (number < page) ...ids,
    };
    pages[page] = {for (final room in result.rooms) room.roomId};
    return (
      rooms: [
        for (final room in result.rooms)
          if (!earlier.contains(room.roomId)) SixroomRoomParser.liveRoom(_remember(room)),
      ],
      hasMore: result.hasMore,
    );
  }

  /// Page [page] of [pageSize] rooms of area [areaId], or of the
  /// recommendations when null; the cards are remembered. A page past 10000
  /// or an area that is not one of the six is a caller error, without a
  /// request; a page or size below 1 is an empty page, without a request.
  Future<({List<LiveRoom> rooms, bool hasMore})> directoryPage(int page, int pageSize, {String? areaId}) {
    if (page < 1 || pageSize < 1) return Future.value((rooms: const <LiveRoom>[], hasMore: false));
    if (areaId != null && SixroomEndpoints.areaOf(areaId) == null) {
      throw SixroomFailure(SixroomFailureKind.invalidArgument, 'area "$areaId" is not a Six Rooms area');
    }
    if (page > SixroomEndpoints.maxPage) {
      throw SixroomFailure(SixroomFailureKind.invalidArgument, 'page $page is out of 1–${SixroomEndpoints.maxPage}');
    }
    final type = areaId == null ? SixroomEndpoints.recommendType : SixroomEndpoints.mobileTypeOf(areaId);
    final subarea = areaId == null ? null : SixroomEndpoints.subareaOf(areaId);
    final size = pageSize.clamp(1, SixroomEndpoints.maxPageSize);
    if (type != null) return _listPage(page, size, type);
    if (subarea != null) {
      return _wholePage(
        page,
        size,
        SixroomEndpoints.subareaUrl(subarea),
        (body, status) => SixroomRoomParser.subarea(body, status: status),
      );
    }
    return _wholePage(
      page,
      size,
      SixroomEndpoints.homeUrl,
      (body, status) => SixroomRoomParser.directory(body, status: status),
    );
  }
  // Search --------------------------------------------------------------------

  /// Rooms for [keyword]:
  /// - a blank keyword, a page below 1, or a page size outside 1–100 finds
  ///   nothing, without a request;
  /// - a room number or room link is that room (page 1 only, without its
  ///   stream; a room that does not exist is no result);
  /// - anything else is the first [pageSize] cards of `search.php` (page 1
  ///   only, remembered and filled from what the site knows); a keyword
  ///   over the platform's limit finds nothing.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page < 1 || pageSize < 1 || pageSize > SixroomEndpoints.maxPageSize) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    final roomId = SixroomEndpoints.roomIdOf(raw);
    if (roomId != null) {
      if (page != 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        return (rooms: [await summary(roomId)], hasMore: null);
      } on SixroomFailure catch (failure) {
        if (failure.kind != SixroomFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (page != 1 || raw.length > SixroomEndpoints.maxKeywordLength) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    final response = await http.get(SixroomEndpoints.searchUrl(raw));
    final rooms = SixroomRoomParser.search(response.text, status: response.status);
    // Every result is remembered, the shown ones too.
    final remembered = [for (final room in rooms) _remember(room)];
    return (rooms: [for (final room in remembered.take(pageSize)) SixroomRoomParser.liveRoom(room)], hasMore: null);
  }

  // Rooms ---------------------------------------------------------------------

  /// Room [roomId]: the broadcaster's user id ([knownUserId], else from the
  /// room page) and the inroom answer, with the stream for [media].
  Future<SixroomRoom> _read(String roomId, {required String? knownUserId, required bool media}) async {
    var userId = knownUserId?.trim() ?? '';
    if (!SixroomEndpoints.isUserId(userId)) {
      final page = await http.get(SixroomEndpoints.roomUrl(roomId));
      userId = SixroomRoomParser.userIdOf(page.text, roomId: roomId, status: page.status);
    }
    final answer = await http.postForm(SixroomEndpoints.inroomUrl, SixroomEndpoints.inroomForm(userId));
    return SixroomRoomParser.room(answer.text, roomId: roomId, userId: userId, media: media, status: answer.status);
  }

  /// [roomId] as a room number (a number or room link); anything else is
  /// not-found, without a request.
  String _roomId(String roomId) =>
      SixroomEndpoints.roomIdOf(roomId) ??
      (throw SixroomFailure(SixroomFailureKind.notFound, 'room id "${roomId.trim()}" is not a Six Rooms room'));

  /// The room of [roomId] (its answer, filled from the last one remembered
  /// of the room and then remembered itself), with its stream and its chat's
  /// arguments: room entry. The stream data stays as the playback's source.
  Future<LiveRoom> detail(String roomId) => _detail(roomId, media: true, danmaku: true);

  /// The room of [roomId], read without its stream: what a search by room
  /// number finds, which cannot be played until it is entered.
  Future<LiveRoom> summary(String roomId) => _detail(roomId, media: false, danmaku: false);

  Future<LiveRoom> _detail(String roomId, {required bool media, required bool danmaku}) async {
    final id = _roomId(roomId);
    final room = _remember(await _read(id, knownUserId: _known[id]?.userId, media: media));
    final data = SixroomRoomParser.roomData(room);
    if (media) _streams[id] = data;
    return SixroomRoomParser.liveRoom(
      room,
      data: data,
      danmaku: danmaku ? SixroomDanmakuArgs(roomId: room.roomId, userId: room.userId) : null,
    );
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or a fresh
  /// entry — the capabilities are asked by room id alone.
  Future<SixroomRoomData> _stream(String roomId) async {
    final id = _roomId(roomId);
    final data = _streams[id];
    if (data != null) return data;
    await detail(id);
    return _streams[id]!;
  }

  /// The one quality `FLV 原始线路`, from the stream data room entry brought:
  /// no request. An offline or unknown room, a private or black-screen one,
  /// one with an unusable stream name and one read without its stream say
  /// why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final data = await _stream(roomId);
    final error = data.streamError;
    if (error != null) throw error;
    return [SixroomRoomParser.quality(data.stream!)];
  }

  /// The room's FLV stream as its one line. A quality other than the
  /// platform's `flv:source` is stream-unavailable.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final id = quality?.qualityId ?? SixroomEndpoints.qualityId;
    if (id != SixroomEndpoints.qualityId) {
      throw SixroomFailure(SixroomFailureKind.streamUnavailable, 'quality $id is not offered');
    }
    final data = await _stream(roomId);
    final error = data.streamError;
    if (error != null) throw error;
    return [SixroomRoomParser.line(data.stream!)];
  }

  // Capability wiring ---------------------------------------------------------

  SixroomRoomProvider? _room;
  SixroomAreaProvider? _area;
  SixroomDiscoveryProvider? _discovery;
  SixroomSearchProvider? _search;
  SixroomPlaybackProvider? _playback;
  SixroomDanmakuProvider? _danmaku;
  SixroomLinkResolver? _link;

  /// The capability of type [T], or null when Six Rooms does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= SixroomRoomProvider(site: this);
    final area = _area ??= SixroomAreaProvider(site: this);
    final discovery = _discovery ??= SixroomDiscoveryProvider(site: this);
    final search = _search ??= SixroomSearchProvider(site: this);
    final playback = _playback ??= SixroomPlaybackProvider(site: this);
    final danmaku = _danmaku ??= SixroomDanmakuProvider(site: this);
    final link = _link ??= SixroomLinkResolver(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      _ => null,
    };
  }
}
