import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_parser.dart';

/// The Weibo adapter: one broadcast per live id (every broadcast has its
/// own link, so a room id is a broadcast id).
///
/// Not migrated yet: search, directory and the danmaku transport.
final class WeiboSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.weibo;

  @override
  String get id => SiteIds.weibo;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.weibo, displayName: '微博直播', homeUrl: 'https://weibo.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('weibo directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('weibo directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('weibo search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _detail(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _detail(room.roomId) : room;
    final lines = WeiboParser.playLines(fresh.data, room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label.toUpperCase(), sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _detail(room.roomId) : room;
    final lines = WeiboParser.playLines(fresh.data, room.roomId);
    final matching = lines.where((line) => line.lineId?.toUpperCase() == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _detail(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _detail(String liveId) async {
    final response = await http.send(
      LiveRequest.get(WeiboParser.detailUrl(liveId), headers: WeiboParser.headers, site: id),
    );
    return WeiboParser.room(response.text, liveId: liveId, status: response.statusCode);
  }
}
