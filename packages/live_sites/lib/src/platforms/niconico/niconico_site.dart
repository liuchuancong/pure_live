import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_parser.dart';

/// The Niconico adapter: watch-page program status and access, plus the
/// recent-programs directory.
///
/// Playback is not migrated yet: a Niconico stream is delivered through a
/// "seat" — a WebSocket session against the relive server whose stream
/// grants are per-viewer and revocable — so
/// [getPlayQualities]/[getPlayUrls] throw until the seat transport lands
/// (the parser already surfaces the seat's `webSocketUrl` in `room.data`).
final class NiconicoSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
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

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('niconico search lands with its migration');
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

  Future<LiveRoom> _watch(String roomId) async {
    final response = await http.send(
      LiveRequest.get(Uri.parse(NiconicoParser.watchUrl(roomId)), headers: NiconicoParser.headers, site: id),
    );
    return NiconicoParser.watch(response.text, roomId: roomId, status: response.statusCode).room;
  }
}
