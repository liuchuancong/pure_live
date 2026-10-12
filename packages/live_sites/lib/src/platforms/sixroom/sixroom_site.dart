import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_session.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_parser.dart';

/// The 6.cn (六间房) adapter: room page user id → inroom answer flow, the
/// mobile-list/subarea/homepage directory, the `search.php` search, and the
/// guest chat socket on one of the room's `getChat.php` servers.
///
/// The directory and search are stateless here: each page reads its own answer
/// and search rows map straight from the page (3.x's remembered-room registry
/// that fills a search card's gaps has no counterpart in the reduced model).
final class SixRoomSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  /// Broadcaster ids resolved from room pages, keyed by room id.
  final Map<String, String> _userIds = {};

  @override
  String get siteId => SiteIds.sixroom;

  @override
  String get id => SiteIds.sixroom;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.sixroom, displayName: '六间房', homeUrl: 'https://v.6.cn');

  /// The catalogue: six constant areas, so no request is spent finding them
  /// out.
  @override
  Future<List<LiveArea>> getAreas() async => SixRoomParser.areas();

  /// Page [page] of the site's recommendations: the mobile list's
  /// `special` type, every live room by popularity.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _mobileList(SixRoomParser.recommendType, page);

  /// Page [page] of one area, from the source the area names: a mobile list
  /// type for most, the web's subarea 10 (one answer) for 星颜, and the
  /// homepage (one answer) for 全部 — the mobile list has no "all". An area
  /// the catalogue does not know is a caller error.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final id = area.id.trim();
    final area_ = SixRoomParser.areaCatalog.where((candidate) => candidate.id == id).firstOrNull;
    if (area_ == null) {
      throw SiteError.invalidRoomId(area.id);
    }
    final type = area_.mobileType;
    if (type != null) {
      return _mobileList(type, page);
    }
    if (area_.subarea case final subarea?) {
      return _subarea(subarea, page);
    }
    return _home(page);
  }

  /// One page of one mobile list type.
  Future<LivePage<LiveRoom>> _mobileList(String type, int page) async {
    if (page < 1 || page > SixRoomParser.maxPage) {
      throw RangeError.range(page, 1, SixRoomParser.maxPage, 'page');
    }
    final response = await http.send(
      LiveRequest.get(
        SixRoomParser.listUrl(type, page: page),
        headers: SixRoomParser.listHeaders,
        site: siteId,
      ),
    );
    return SixRoomParser.list(response.text, type: type, page: page, status: response.statusCode);
  }

  /// The web subarea: every room in one answer, so page 1 asks for it and a
  /// later page is empty without a request.
  Future<LivePage<LiveRoom>> _subarea(int subarea, int page) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(SixRoomParser.subareaUrl(), headers: SixRoomParser.listHeaders, site: siteId),
    );
    return LivePage<LiveRoom>(items: SixRoomParser.subareaRooms(response.text, status: response.statusCode));
  }

  /// The homepage: every live room in one answer, the same single-page rule
  /// as the subarea.
  Future<LivePage<LiveRoom>> _home(int page) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(Uri.parse(SixRoomParser.origin), headers: SixRoomParser.headers, site: siteId),
    );
    return LivePage<LiveRoom>(items: SixRoomParser.homeRooms(response.text, status: response.statusCode));
  }

  /// 3.x's search, page 1 only (the site's search page is not paged here): a
  /// room number or room link is that room (a room the site does not know is
  /// nothing); a blank keyword, a page below 1, a later page or a keyword over
  /// 80 characters gives nothing without a request; anything else is the
  /// `search.php` page.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page < 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final roomId = SixRoomParser.roomIdOf(raw);
    if (roomId != null) {
      if (page != 1) {
        return const LivePage<LiveRoom>(items: []);
      }
      try {
        return LivePage<LiveRoom>(items: [await _read(roomId)]);
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    if (page > 1 || raw.length > SixRoomParser.maxKeywordLength) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(SixRoomParser.searchUrl(raw), headers: SixRoomParser.headers, site: siteId),
    );
    final rooms = SixRoomParser.searchRooms(response.text, status: response.statusCode);
    return LivePage<LiveRoom>(items: rooms.take(SixRoomParser.pageSize).toList(growable: false));
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _read(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _read(room.roomId) : room;
    SixRoomParser.playLines(fresh.data);
    return const [LivePlayQuality(label: '原画')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _read(room.roomId) : room;
    return SixRoomParser.playLines(fresh.data);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _read(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens the guest chat socket for [room].
  ///
  /// The broadcaster id names the room's chat-server list (`getChat.php`) and
  /// the login's `roomid`; it is resolved from the room page and cached. Each
  /// server is tried in turn (see [SixRoomDanmakuSession.connect]).
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final userId = await _broadcasterId(room.roomId);
    final servers = await _chatServers(userId, roomId: room.roomId);
    final guestId = SixRoomDanmakuProtocol.guestId(Random().nextInt(100000000));
    return await SixRoomDanmakuSession.connect(servers: servers, userId: userId, guestId: guestId);
  }

  /// The broadcaster's user id of room [roomId]: cached, or read from the room
  /// page.
  Future<String> _broadcasterId(String roomId) async {
    final cached = _userIds[roomId];
    if (cached != null) {
      return cached;
    }
    final page = await http.send(
      LiveRequest.get(SixRoomParser.roomUrl(roomId), headers: SixRoomParser.headers, site: id),
    );
    return _userIds[roomId] = SixRoomParser.userIdOf(page.text, roomId: roomId, status: page.statusCode);
  }

  /// The room's chat servers, from `getChat.php?rid=<userId>`.
  Future<List<Uri>> _chatServers(String userId, {required String roomId}) async {
    final response = await http.send(
      LiveRequest.get(
        SixRoomDanmakuProtocol.serversUrl.replace(queryParameters: {'rid': userId}),
        headers: {
          'user-agent': SixRoomParser.headers['user-agent']!,
          'accept': 'application/json, text/javascript, */*; q=0.01',
          'referer': SixRoomParser.roomUrl(roomId).toString(),
          'x-requested-with': 'XMLHttpRequest',
        },
        site: id,
      ),
    );
    try {
      return SixRoomDanmakuProtocol.servers(response.text, status: response.statusCode);
    } on FormatException catch (error) {
      throw SiteNotFoundError('sixroom $roomId: ${error.message}');
    }
  }

  /// The room: the broadcaster id (cached) then the inroom POST.
  Future<LiveRoom> _read(String roomId) async {
    if (!SixRoomParser.isRoomId(roomId)) {
      throw SiteNotFoundError('sixroom: "${roomId.trim()}" is not a room id');
    }
    var userId = _userIds[roomId];
    if (userId == null) {
      final page = await http.send(
        LiveRequest.get(SixRoomParser.roomUrl(roomId), headers: SixRoomParser.headers, site: id),
      );
      userId = SixRoomParser.userIdOf(page.text, roomId: roomId, status: page.statusCode);
      _userIds[roomId] = userId;
    }
    final answer = await http.send(
      LiveRequest.form(
        SixRoomParser.inroomUrl,
        fields: SixRoomParser.inroomForm(userId),
        headers: SixRoomParser.headers,
        site: id,
      ),
    );
    return SixRoomParser.room(answer.text, roomId: roomId, userId: userId, status: answer.statusCode);
  }
}
