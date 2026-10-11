import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_parser.dart';

/// The Kick adapter: one channel request per room (the answer carries the
/// stream and the signed IVS master).
///
/// Not migrated yet: directory, search and the chat WebSocket.
final class KickSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.kick;

  @override
  String get id => SiteIds.kick;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.kick, displayName: 'Kick', homeUrl: 'https://kick.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('kick directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('kick directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('kick search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _channel(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return const [LivePlayQuality(label: 'master')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _channel(room.roomId) : room;
    return KickParser.playLines(fresh.data, room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _channel(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _channel(String roomId) async {
    final slug = KickParser.normalizeSlug(roomId);
    if (slug == null) {
      throw SiteNotFoundError('kick: "${roomId.trim()}" is not a channel');
    }
    final response = await http.send(
      LiveRequest.get(KickParser.channelUrl(slug), headers: KickParser.headers, site: id),
    );
    return KickParser.room(response.text, requestedSlug: slug, status: response.statusCode);
  }
}
