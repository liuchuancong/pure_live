import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_parser.dart';

/// The Niconico adapter: watch-page program status and access.
///
/// Playback is not migrated yet: a Niconico stream is delivered through a
/// "seat" — a WebSocket session against the relive server whose stream
/// grants are per-viewer and revocable — so
/// [getPlayQualities]/[getPlayUrls] throw until the seat transport lands
/// (the parser already surfaces the seat's `webSocketUrl` in `room.data`).
final class NiconicoSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.niconico;

  @override
  String get id => SiteIds.niconico;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.niconico, displayName: 'niconico', homeUrl: 'https://live.nicovideo.jp');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('niconico directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('niconico directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('niconico search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _watch(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    throw UnimplementedError('niconico playback needs the seat WebSocket transport');
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    throw UnimplementedError('niconico playback needs the seat WebSocket transport');
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _watch(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _watch(String roomId) async {
    final response = await http.send(
      LiveRequest.get(Uri.parse(NiconicoParser.watchUrl(roomId)), headers: NiconicoParser.headers, site: id),
    );
    return NiconicoParser.watch(response.text, roomId: roomId, status: response.statusCode).room;
  }
}
