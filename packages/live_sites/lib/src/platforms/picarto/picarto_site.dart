import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_session.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_parser.dart';

/// The Picarto adapter: one channel/detail request per room, plus the chat
/// socket over a GraphQL-issued token.
///
/// Not migrated yet: the multistream overlay, the broadcast start from the
/// public API, and the directory.
final class PicartoSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.picarto;

  @override
  String get id => SiteIds.picarto;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.picarto, displayName: 'Picarto', homeUrl: 'https://picarto.tv');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('picarto directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('picarto directory lands with its migration');
  }

  /// The site's channel search: one `api/search` (`searchProfiles`) page of
  /// thirty at [page], live and offline profiles alike. A blank keyword is
  /// nothing without a request; the site pages by its own cursor, so a page
  /// past the results is an empty answer.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    const size = 30;
    final response = await http.send(
      LiveRequest.get(
        PicartoParser.searchUrl(text, page: page < 1 ? 1 : page, pageSize: size),
        headers: PicartoParser.headers,
        site: siteId,
      ),
    );
    return LivePage<LiveRoom>(
      items: PicartoParser.search(response.text, pageSize: size, status: response.statusCode),
    );
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _detail(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    // One master playlist; the player picks the variant.
    return const [LivePlayQuality(label: 'master')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _detail(room.roomId) : room;
    return PicartoParser.playLines(fresh.data, room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _detail(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens the chat socket for [room].
  ///
  /// The channel's numeric id comes from the detail answer and lets the
  /// decoder drop a `stream` frame naming another channel; a room with no
  /// detail yet fetches one here. The session asks its own JWT token.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final data = room.data ?? (await _detail(room.roomId)).data;
    final channelId = PicartoParser.channelIdOf(data) ?? 0;
    return await PicartoDanmakuSession.connect(http, channelName: room.roomId, channelId: channelId);
  }

  Future<LiveRoom> _detail(String roomId) async {
    if (!PicartoParser.isChannelName(roomId)) {
      throw SiteNotFoundError('picarto: "$roomId" is not a channel name');
    }
    final response = await http.send(
      LiveRequest.get(PicartoParser.detailUrl(roomId), headers: PicartoParser.headers, site: id),
    );
    return PicartoParser.room(response.text, requestedId: roomId, status: response.statusCode);
  }
}
