import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';

/// The SHOWROOM adapter: profile + live_info + streaming_url flow.
///
/// Not migrated yet: directory, search, the gift catalog and the danmaku
/// transport (bcsvr WebSocket).
final class ShowroomSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  /// Room ids resolved from url keys.
  final Map<String, int> _keys = {};

  @override
  String get siteId => SiteIds.showroom;

  @override
  String get id => SiteIds.showroom;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.showroom, displayName: 'SHOWROOM', homeUrl: 'https://www.showroom-live.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('showroom directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('showroom directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('showroom search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final roomId = await _roomId(room.roomId);
    final (profile, info) = await _profileAndInfo(roomId);
    final fresh = ShowroomParser.room(profile, info, roomId: roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final lines = await _lines(room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final lines = await _lines(room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final roomId = await _roomId(room.roomId);
    final (profile, info) = await _profileAndInfo(roomId);
    return room.mergeFrom(ShowroomParser.room(profile, info, roomId: roomId));
  }

  /// The numeric room id of [reference]: digits pass through, url keys are
  /// resolved once via `room/status` and remembered.
  Future<int> _roomId(String reference) async {
    final direct = ShowroomParser.roomNumber(reference);
    if (direct != null) {
      return direct;
    }
    if (!ShowroomParser.isUrlKey(reference)) {
      throw SiteNotFoundError('showroom: "${reference.trim()}" is not a room');
    }
    final cached = _keys[reference];
    if (cached != null) {
      return cached;
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.showroom-live.com', '/api/room/status', {'room_url_key': reference}),
        headers: ShowroomParser.headers,
        site: id,
      ),
    );
    final roomId = ShowroomParser.roomIdOfStatus(response.text, status: response.statusCode);
    return _keys[reference] = roomId;
  }

  Future<(Map<String, Object?>, Map<String, Object?>)> _profileAndInfo(int roomId) async {
    final query = {'room_id': '$roomId'};
    final responses = await Future.wait([
      http.send(
        LiveRequest.get(
          Uri.https('www.showroom-live.com', '/api/room/profile', query),
          headers: ShowroomParser.headers,
          site: id,
        ),
      ),
      http.send(
        LiveRequest.get(
          Uri.https('www.showroom-live.com', '/api/live/live_info', query),
          headers: ShowroomParser.headers,
          site: id,
        ),
      ),
    ]);
    return (
      ShowroomParser.data(responses[0].text, status: responses[0].statusCode, what: 'room/profile'),
      ShowroomParser.data(responses[1].text, status: responses[1].statusCode, what: 'live_info'),
    );
  }

  Future<List<LivePlayLine>> _lines(String reference) async {
    final roomId = await _roomId(reference);
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.showroom-live.com', '/api/live/streaming_url', {'room_id': '$roomId', 'abr_available': '1'}),
        headers: ShowroomParser.headers,
        site: id,
      ),
    );
    return ShowroomParser.playLines(response.text, roomId: roomId, status: response.statusCode);
  }
}
