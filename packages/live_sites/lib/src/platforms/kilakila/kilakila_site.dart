import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_parser.dart';

/// The KilaKila (奇秀) adapter: one getRoomInfo request per broadcast.
///
/// Not migrated yet: directory, search, the personal profile completion
/// and the danmaku transport.
final class KilakilaSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.kilakila;

  @override
  String get id => SiteIds.kilakila;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.kilakila, displayName: '奇秀直播', homeUrl: 'https://live.kilakila.cn');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('kilakila directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('kilakila directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('kilakila search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _info(room.roomId) : room;
    final lines = KilakilaParser.playLines(fresh.data);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label.toUpperCase(), sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _info(room.roomId) : room;
    final lines = KilakilaParser.playLines(fresh.data);
    final matching = lines.where((line) => line.lineId?.toUpperCase() == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _info(String broadcastId) async {
    final response = await http.send(
      LiveRequest.get(KilakilaParser.roomInfoUrl(broadcastId), headers: KilakilaParser.headers, site: id),
    );
    return KilakilaParser.room(response.text, broadcastId: broadcastId, status: response.statusCode);
  }
}
