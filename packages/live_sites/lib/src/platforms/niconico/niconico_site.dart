import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_session.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_parser.dart';

/// The Niconico adapter: watch-page program status and access, plus the
/// recent-programs directory.
///
/// Playback is not migrated yet: a Niconico stream is delivered through a
/// "seat" — a WebSocket session against the relive server whose stream
/// grants are per-viewer and revocable — so
/// [getPlayQualities]/[getPlayUrls] throw until the grant side of the seat
/// lands. The comments ([connect]) use the same seat only to name the comment
/// server (the parser surfaces its `webSocketUrl`), then read it over HTTP.
final class NiconicoSite
    with SiteRoomGuard
    implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.niconico;

  @override
  String get id => SiteIds.niconico;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.niconico, displayName: 'niconico', homeUrl: 'https://live.nicovideo.jp');

  /// The catalogue: the site's seven constant tabs, so no request is spent
  /// finding them out.
  @override
  Future<List<LiveArea>> getAreas() async => NiconicoParser.areas();

  /// Page [page] of the `common` tab, which is what the site recommends.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _programs('common', page);

  /// Page [page] of one tab; an area that is not a tab is a caller error
  /// rather than a request that cannot work.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final tab = area.id.trim();
    if (!NiconicoParser.isTab(tab)) {
      throw SiteError.invalidRoomId(area.id);
    }
    return _programs(tab, page);
  }

  /// One page of the on-air programs of [tab].
  ///
  /// The site pages by offset, one page of seventy programs, and it also
  /// reports the total, so the last page is known without asking for it —
  /// but the offset is the *page number* here, which is what makes a
  /// stateless `page: N` request one request rather than N.
  Future<LivePage<LiveRoom>> _programs(String tab, int page) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final response = await http.send(
      LiveRequest.get(
        NiconicoParser.directoryUrl(tab: tab, page: page),
        headers: NiconicoParser.headers,
        site: siteId,
      ),
    );
    return NiconicoParser.directoryPage(response.text, tab: tab, page: page, status: response.statusCode);
  }

  /// Programs on air matching [keyword]: one `search/v1/programs` page of
  /// forty at [page], read like a directory page. A blank keyword is nothing
  /// without a request; a keyword over 500 characters or a page below one is
  /// the caller's mistake, as in 3.x.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (keyword.length > 500) {
      throw ArgumentError('A niconico keyword has at most 500 characters');
    }
    final term = keyword.trim();
    if (term.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(NiconicoParser.searchUrl(term, page), headers: NiconicoParser.headers, site: siteId),
    );
    return NiconicoParser.directoryPage(response.text, page: page, search: true, status: response.statusCode);
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _watch(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    throw UnimplementedError('niconico playback needs the seat WebSocket transport');
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    throw UnimplementedError('niconico playback needs the seat WebSocket transport');
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _watch(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _watch(String roomId) async => (await _watchWithSeat(roomId)).room;

  /// The watch page and the seat WebSocket it names (null when the room is not
  /// watchable). [connect] needs the seat address; the other paths only the
  /// room.
  Future<({LiveRoom room, String? socketUrl})> _watchWithSeat(String roomId) async {
    final response = await http.send(
      LiveRequest.get(Uri.parse(NiconicoParser.watchUrl(roomId)), headers: NiconicoParser.headers, site: id),
    );
    return NiconicoParser.watch(response.text, roomId: roomId, status: response.statusCode);
  }

  /// Opens niconico's comments: the watch page names the watching seat's
  /// WebSocket, whose handshake names the comment server the session then
  /// follows. A room the watch page gives no seat for (offline, restricted,
  /// gone) ends with a [SiteNotFoundError].
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final watch = await _watchWithSeat(room.roomId);
    final socket = watch.socketUrl;
    if (socket == null) {
      throw SiteNotFoundError('niconico ${room.roomId}: no seat (offline, restricted or gone)');
    }
    return await NiconicoDanmakuSession.connect(
      NiconicoDanmakuArgs(roomId: room.roomId, seatSocket: Uri.parse(socket)),
      http,
    );
  }
}
