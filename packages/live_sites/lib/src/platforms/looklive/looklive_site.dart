import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_parser.dart';

/// The Look (网易 LOOK) adapter: the weapi room flow with the NetEase
/// request envelope (double AES-128-CBC + encSecKey).
///
/// Not migrated yet: the directory lists, search and the danmaku
/// transport (the chat servers come from a separate address endpoint).
final class LookLiveSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.looklive;

  @override
  String get id => SiteIds.looklive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.looklive, displayName: 'LOOK直播', homeUrl: 'https://look.163.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('looklive directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('looklive directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('looklive search lands with its migration');
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
    final lines = LookLiveParser.playLines(_liveUrlOf(fresh.data), room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [
      for (final (index, label) in labels.indexed) LivePlayQuality(label: label == 'hls' ? 'HLS' : 'FLV', sort: -index),
    ];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _room(room.roomId) : room;
    final lines = LookLiveParser.playLines(_liveUrlOf(fresh.data), room.roomId);
    final wantHls = quality.label == 'HLS';
    final matching = lines.where((line) => (line.format == StreamFormat.hls) == wantHls).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// The liveUrl of a room whose data is the roomInfo map.
  static Object? _liveUrlOf(Object? data) => data is Map<String, Object?> ? data['liveUrl'] : null;

  Future<LiveRoom> _room(String roomId) async {
    final body = await LookLiveParser.formBody({'liveRoomNo': roomId});
    final response = await http.send(
      LiveRequest.custom(
        url: Uri.parse('${LookLiveParser.apiOrigin}${LookLiveParser.roomPath}'),
        method: 'POST',
        headers: LookLiveParser.requestHeaders,
        body: body,
        site: id,
      ),
    );
    return LookLiveParser.room(response.text, roomId: roomId, status: response.statusCode);
  }
}
