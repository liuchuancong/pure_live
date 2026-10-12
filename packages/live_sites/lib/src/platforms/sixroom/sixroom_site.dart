import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_parser.dart';

/// The 6.cn (六间房) adapter: room page user id → inroom answer flow.
///
/// Not migrated yet: directory, search and the danmaku transport.
final class SixRoomSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
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

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('sixroom search lands with its migration');
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
