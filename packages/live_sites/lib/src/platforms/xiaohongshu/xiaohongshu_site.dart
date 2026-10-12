import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_parser.dart';

/// The Xiaohongshu adapter: the share page's hydration state per
/// broadcast (every broadcast has a new room id).
///
/// Xiaohongshu has no anonymous directory: [getRecommendRooms] is empty and
/// [getCategoryRooms] is a caller error, as 3.x refused it. Not migrated yet:
/// the share/short-link search (which runs through room resolution) and the
/// danmaku transport.
final class XiaohongshuSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.xiaohongshu;

  @override
  String get id => SiteIds.xiaohongshu;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.xiaohongshu, displayName: '小红书直播', homeUrl: 'https://www.xiaohongshu.com');

  /// Always empty: no public directory is reachable anonymously, and nothing
  /// is requested. A page below one is a caller error, as 3.x refused it.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    return const LivePage<LiveRoom>(items: []);
  }

  /// Xiaohongshu has no categories, so any area is a caller error refused
  /// before a request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    throw SiteError.invalidRoomId(area.id);
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('xiaohongshu search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _page(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _page(room.roomId) : room;
    final lines = XiaohongshuParser.playLines(fresh.data, room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _page(room.roomId) : room;
    final lines = XiaohongshuParser.playLines(fresh.data, room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _page(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _page(String roomId) async {
    final response = await http.send(
      LiveRequest.get(XiaohongshuParser.roomUrl(roomId), headers: XiaohongshuParser.headers, site: id),
    );
    return XiaohongshuParser.room(response.text, roomId: roomId, status: response.statusCode);
  }
}
