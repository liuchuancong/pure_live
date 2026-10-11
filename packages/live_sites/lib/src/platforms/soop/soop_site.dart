import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_parser.dart';

/// The SOOP (formerly AfreecaTV) adapter: player_live_api live/aid and the
/// stream assignment flow.
///
/// Not migrated yet: the station profile, directory, search and the chat
/// WebSocket.
final class SoopSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.soop;

  @override
  String get id => SiteIds.soop;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.soop, displayName: 'SOOP', homeUrl: 'https://www.sooplive.co.kr');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('soop directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('soop directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('soop search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _live(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = room.data == null ? await _live(room.roomId) : room;
    final presets = _presetsOf(fresh.data);
    return [for (final (index, preset) in presets.indexed) LivePlayQuality(label: preset.name, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _live(room.roomId) : room;
    final data = fresh.data;
    if (data is! Map<String, Object?>) {
      throw SiteNotFoundError('soop ${room.roomId}: not live');
    }
    final bno = data['bno']?.toString() ?? '';
    final rmd = data['rmd']?.toString() ?? '';
    final cdn = data['cdn']?.toString() ?? '';
    final presets = _presetsOf(data);
    final preset = presets.where((p) => p.name == quality.label).firstOrNull ?? presets.firstOrNull;
    final presetName = preset?.name ?? quality.label;
    final key = await _aid(room.roomId, bno: bno, quality: presetName);
    final assign = await http.send(
      LiveRequest.get(
        SoopParser.assignUrl(rmd: rmd, cdn: cdn, bno: bno, quality: presetName),
        headers: SoopParser.headers,
        site: id,
      ),
    );
    final playlist = SoopParser.assignedPlaylist(assign.text, status: assign.statusCode);
    return [SoopParser.line(playlist: playlist, aid: key, roomId: room.roomId, cdn: cdn, codec: preset?.codec)];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _live(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _live(String roomId) async {
    final response = await http.send(
      LiveRequest.form(
        SoopParser.playerUrl(roomId),
        fields: SoopParser.playerForm(roomId, type: 'live'),
        headers: SoopParser.headers,
        site: id,
      ),
    );
    return SoopParser.room(response.text, roomId: roomId, status: response.statusCode);
  }

  Future<String> _aid(String roomId, {required String bno, required String quality}) async {
    final response = await http.send(
      LiveRequest.form(
        SoopParser.playerUrl(roomId),
        fields: SoopParser.playerForm(roomId, type: 'aid', bno: bno, quality: quality),
        headers: SoopParser.headers,
        site: id,
      ),
    );
    return SoopParser.aid(response.text, status: response.statusCode);
  }

  static List<({String name, String? codec})> _presetsOf(Object? data) =>
      data is Map<String, Object?> ? SoopParser.presets(data['presets']) : const [];
}
