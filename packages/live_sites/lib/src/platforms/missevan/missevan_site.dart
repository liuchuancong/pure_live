import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_parser.dart';

/// The Missevan (猫耳 FM) adapter: the `live/{id}` room and its channel
/// pull URLs.
///
/// Not migrated yet: the directory, search and the danmaku transport
/// (Missevan frames carry a brotli-compressed payload).
final class MissevanSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.missevan;

  @override
  String get id => SiteIds.missevan;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.missevan, displayName: '猫耳FM', homeUrl: 'https://fm.missevan.com');

  /// The site's areas: one request carries every namespace (partition, team
  /// broadcast and tag), and the namespace is kept as the area's parent so a
  /// picker can group them the way the site does.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(Uri.https('fm.missevan.com', '/api/v2/meta/data'), headers: MissevanParser.headers, site: siteId),
    );
    // The catalogue uses the site's other envelope (`info`, with the tabs),
    // so it is decoded here rather than through the room reader — which
    // insists on `data` and would reject a perfectly good answer.
    if (response.statusCode != 200) {
      throw SiteApiChangedError('missevan meta/data: HTTP ${response.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.text);
    } on FormatException {
      throw const SiteApiChangedError('missevan meta/data: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('missevan meta/data: body is not an object');
    }
    final code = SiteCounts.integer(decoded['code']);
    if (code != null && code != 0) {
      throw SiteApiChangedError('missevan meta/data: code $code');
    }
    return MissevanParser.areas(decoded);
  }

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('missevan directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('missevan directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('missevan search lands with its migration');
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
    final fresh = await _live(room.roomId);
    final lines = MissevanParser.playLines(fresh.data, room.roomId);
    return [for (final line in lines) LivePlayQuality(label: line.format == StreamFormat.hls ? 'HLS' : 'FLV')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = await _live(room.roomId);
    final lines = MissevanParser.playLines(fresh.data, room.roomId);
    final format = quality.label == 'HLS' ? StreamFormat.hls : StreamFormat.flv;
    final matching = lines.where((line) => line.format == format).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _live(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _live(String roomId) async {
    final response = await http.send(
      LiveRequest.get(MissevanParser.detailUrl(roomId), headers: MissevanParser.headers, site: id),
    );
    return MissevanParser.room(response.text, roomId: roomId, status: response.statusCode);
  }
}
