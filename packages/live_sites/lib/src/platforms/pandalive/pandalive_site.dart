import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_parser.dart';

/// The PandaLive adapter: member/bj + live/play flow.
///
/// Not migrated yet: directory, search, the password/fan-room refusals
/// detail and the chat WebSocket.
final class PandaLiveSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.pandalive;

  @override
  String get id => SiteIds.pandalive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.pandalive, displayName: 'PandaTV', homeUrl: 'https://www.pandalive.co.kr');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('pandalive directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('pandalive directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('pandalive search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final member = await _member(room.roomId);
    return room.mergeFrom(PandaLiveParser.room(member));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final masters = await _masters(room.roomId);
    return [for (final (index, _) in masters.indexed) LivePlayQuality(label: 'HLS-$index', sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final lines = PandaLiveParser.playLines(await _masters(room.roomId), room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final member = await _member(room.roomId);
    return room.mergeFrom(PandaLiveParser.room(member));
  }

  Future<
    ({String userId, int index, String nick, String? avatar, bool live, String? title, Map<String, Object?> media})
  >
  _member(String roomId) async {
    final response = await http.send(
      LiveRequest.form(
        Uri.https(PandaLiveParser.apiHost, '/v1/member/bj'),
        fields: PandaLiveParser.memberForm(roomId),
        headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.roomUrl(roomId)},
        site: id,
      ),
    );
    return PandaLiveParser.member(response.text, userId: roomId, status: response.statusCode);
  }

  Future<List<String>> _masters(String roomId) async {
    final response = await http.send(
      LiveRequest.form(
        Uri.https(PandaLiveParser.apiHost, '/v1/live/play'),
        fields: PandaLiveParser.playForm(roomId),
        headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.roomUrl(roomId)},
        site: id,
      ),
    );
    final masters = PandaLiveParser.masters(response.text, status: response.statusCode);
    if (masters.isEmpty) {
      throw SiteNotFoundError('pandalive $roomId: no master playlist');
    }
    return masters;
  }
}
