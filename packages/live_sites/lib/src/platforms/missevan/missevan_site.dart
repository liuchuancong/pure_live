import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_session.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_parser.dart';

/// The Missevan (猫耳 FM) adapter: the `live/{id}` room, its channel pull
/// URLs and the `chatroom/open/list` directory.
///
/// Not migrated yet: search. The danmaku ([connect]) joins the room's NetEase
/// IM chatroom as a guest (its frames carry a Brotli-compressed payload).
final class MissevanSite
    with SiteRoomGuard
    implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability, LiveDanmakuCapability {
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

  /// Page [page] (1–10000) of the site's recommendations: every live room,
  /// in the site's own order.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory(null, page);

  /// Page [page] of one area, filtered by the parameter its namespace names
  /// (`catalog_id`, `tag_id` or `list_type`).
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) => _directory(area, page);

  /// One `chatroom/open/list` page, of the recommendations when [area] is
  /// null.
  Future<LivePage<LiveRoom>> _directory(LiveArea? area, int page) async {
    if (page < 1 || page > MissevanParser.maxPage) {
      throw RangeError.range(page, 1, MissevanParser.maxPage, 'page');
    }
    final query = {'p': '$page', ...MissevanParser.areaQuery(area)};
    final response = await http.send(
      LiveRequest.get(
        Uri.https('fm.missevan.com', '/api/v2/chatroom/open/list', query),
        headers: MissevanParser.headers,
        site: id,
      ),
    );
    return MissevanParser.roomList(response.text, page: page, status: response.statusCode);
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

  /// The [LiveRoom] of one room answer's `live/{id}` document.
  Future<LiveRoom> _live(String roomId) async {
    final response = await http.send(
      LiveRequest.get(MissevanParser.detailUrl(roomId), headers: MissevanParser.headers, site: id),
    );
    return MissevanParser.room(response.text, roomId: roomId, status: response.statusCode);
  }

  /// Joins the room's Missevan (猫耳FM) chat: one room detail answers both the
  /// on-air state and the chat socket (its `websocket`); the session then takes
  /// the guest `FM_SESS` cookie the handshake needs. A room not on air ends with
  /// a [SiteNotFoundError].
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final response = await http.send(
      LiveRequest.get(MissevanParser.detailUrl(room.roomId), headers: MissevanParser.headers, site: id),
    );
    final detail = MissevanParser.room(response.text, roomId: room.roomId, status: response.statusCode);
    if (detail.status != LiveStatus.live) {
      throw SiteNotFoundError('missevan ${room.roomId}: not on air');
    }
    final socket = MissevanParser.chatSocket(response.text, roomId: room.roomId, status: response.statusCode);
    return await MissevanDanmakuSession.connect(
      MissevanDanmakuArgs(
        roomId: room.roomId.trim(),
        url: Uri.parse(socket ?? 'wss://im.missevan.com/ws'),
        headers: MissevanParser.headers,
      ),
      http,
    );
  }
}
