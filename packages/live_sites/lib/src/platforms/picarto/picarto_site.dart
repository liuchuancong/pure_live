import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_parser.dart';

/// The Picarto adapter: one channel/detail request per room.
///
/// Not migrated yet: the multistream overlay, the broadcast start from
/// the public API, directory, search and the danmaku transport.
final class PicartoSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.picarto;

  @override
  String get id => SiteIds.picarto;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.picarto, displayName: 'Picarto', homeUrl: 'https://picarto.tv');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('picarto directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('picarto directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('picarto search lands with its migration');
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
    // One master playlist; the player picks the variant.
    return const [LivePlayQuality(label: 'master')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _detail(room.roomId) : room;
    return PicartoParser.playLines(fresh.data, room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _detail(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _detail(String roomId) async {
    if (!PicartoParser.isChannelName(roomId)) {
      throw SiteNotFoundError('picarto: "$roomId" is not a channel name');
    }
    final response = await http.send(
      LiveRequest.get(PicartoParser.detailUrl(roomId), headers: PicartoParser.headers, site: id),
    );
    return PicartoParser.room(response.text, requestedId: roomId, status: response.statusCode);
  }
}
