import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_parser.dart';

/// The TikTok adapter: the user/room flow (the answer carries the room
/// state and its stream tiers).
///
/// Not migrated yet: the share-link → room-info resolution, directory,
/// search and the danmaku transport.
final class TikTokSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.tiktok;

  @override
  String get id => SiteIds.tiktok;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.tiktok, displayName: 'TikTok Live', homeUrl: 'https://www.tiktok.com/live');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('tiktok directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('tiktok directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('tiktok search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _room(room.roomId) : room;
    final lines = TikTokParser.playLines(fresh.data, room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _room(room.roomId) : room;
    final lines = TikTokParser.playLines(fresh.data, room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _room(String roomId) async {
    final username = TikTokParser.normalizeUsername(roomId);
    if (username == null) {
      throw SiteNotFoundError('tiktok: "$roomId" is not a username');
    }
    final response = await http.send(
      LiveRequest.get(
        TikTokParser.userRoomUrl(username),
        headers: TikTokParser.headers(username: username),
        site: id,
      ),
    );
    return TikTokParser.room(response.text, username: username, status: response.statusCode);
  }
}
