import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_parser.dart';

/// The FC2 Live adapter: one member-API request per room.
///
/// Playback is not migrated yet: an FC2 stream is authorized through the
/// control WebSocket (`wss://<node>.live.fc2.com/control/channels/<id>`)
/// and played through a relay recipe, so
/// [getPlayQualities]/[getPlayUrls] throw until that transport lands.
final class Fc2LiveSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.fc2Live;

  @override
  String get id => SiteIds.fc2Live;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.fc2Live, displayName: 'FC2 Live', homeUrl: 'https://live.fc2.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('fc2live directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('fc2live directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('fc2live search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _member(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    throw UnimplementedError('fc2live playback needs the control WebSocket transport');
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    throw UnimplementedError('fc2live playback needs the control WebSocket transport');
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _member(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// The member-API request of [roomId].
  Future<LiveRoom> _member(String roomId) async {
    final channelId = Fc2LiveParser.channelId(roomId);
    if (channelId == null) {
      throw SiteNotFoundError('fc2live: "${roomId.trim()}" is not an FC2 channel');
    }
    final response = await http.send(
      LiveRequest.form(
        Uri.https('live.fc2.com', Fc2LiveParser.memberPath),
        fields: {'channel': '1', 'profile': '1', 'user': '1', 'streamid': channelId},
        headers: Fc2LiveParser.headers,
        site: id,
      ),
    );
    return Fc2LiveParser.room(response.text, channelId: channelId, status: response.statusCode);
  }
}
