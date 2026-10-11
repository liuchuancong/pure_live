import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_parser.dart';

/// The 6.cn (六间房) adapter: room page user id → inroom answer flow.
///
/// Not migrated yet: directory, search and the danmaku transport.
final class SixRoomSite with SiteRoomGuard implements LiveSite {
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

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('sixroom directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('sixroom directory lands with its migration');
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
