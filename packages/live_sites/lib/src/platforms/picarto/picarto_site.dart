import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_session.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_parser.dart';

/// The Picarto adapter: one channel/detail request per room, plus the chat
/// socket over a GraphQL-issued token.
///
/// Not migrated yet: the multistream overlay and the broadcast start from the
/// public API.
final class PicartoSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog, LiveDirectoryCapability {
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

  /// The catalogue: the public directory first, then the platform's
  /// categories from `languages-categories`.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https(PicartoParser.apiHost, '/api/languages-categories'),
        headers: PicartoParser.headers,
        site: siteId,
      ),
    );
    return [PicartoParser.publicDirectoryArea, ...PicartoParser.categories(response.text, status: response.statusCode)];
  }

  /// Page [page] of the public directory: live, non-adult channels by
  /// viewers, thirty a page.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _explore(page: page);

  /// Page [page] of one category's live channels; the public directory when
  /// [area] is that area, and a caller error for anything else.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) =>
      _explore(page: page, categoryId: _categoryId(area));

  Future<LivePage<LiveRoom>> _explore({required int page, int? categoryId}) async {
    const size = PicartoParser.pageSize;
    final response = await http.send(
      LiveRequest.get(
        PicartoParser.exploreUrl(page: page < 1 ? 1 : page, pageSize: size, categoryId: categoryId),
        headers: PicartoParser.headers,
        site: siteId,
      ),
    );
    return PicartoParser.directoryPage(
      response.text,
      page: page < 1 ? 1 : page,
      pageSize: size,
      categoryId: categoryId,
      status: response.statusCode,
    );
  }

  /// The category id of [area]: null for the public directory, else a positive
  /// category id. Anything else is a caller error, refused before a request.
  int? _categoryId(LiveArea area) {
    final id = area.id.trim();
    if (id == PicartoParser.publicDirectoryId) {
      return null;
    }
    final number = int.tryParse(id);
    if (number == null || number <= 0) {
      throw SiteError.invalidRoomId(area.id);
    }
    return number;
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
