import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_session.dart';
import 'package:live_sites/src/platforms/niconico/niconico_models.dart';
import 'package:live_sites/src/platforms/niconico/niconico_playback.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_parser.dart';

/// The Niconico adapter: watch-page program status and access, the
/// recent-programs directory, and a watching-seat (WebSocket) for playback.
///
/// Playback opens a seat, reads its `abr` HLS master and hands it back with the
/// master's path cookies. Because the seat's stream grant is per-viewer and
/// revocable, only the master is fetchable after the seat closes; the
/// reference delivers the stream as an *owned input* the player holds the seat
/// open for (the app layer), which this site adapter does not own. The comments
/// ([connect]) use the same seat only to name the comment server (the parser
/// surfaces its `webSocketUrl`), then read it over HTTP.
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

  /// The seat's stream grants are per-viewer and revocable, so this opens a
  /// seat, reads its `abr` master, and closes it. It offers the master as one
  /// adaptive quality (the tree's HLS precedent); the reference instead parses
  /// the master into exact per-variant recipes (a `NiconicoQuality`), which a
  /// held-seat player selects.
  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final watch = await _watchWithSeat(room.roomId);
    final socket = watch.socketUrl;
    if (socket == null) {
      throw SiteStreamUnavailableError('niconico ${room.roomId}: not watchable (offline, restricted or gone)');
    }
    final seat = await NiconicoStreamSeat.open(Uri.parse(socket));
    try {
      seat.current; // Fails if the seat ended before it granted a stream.
    } finally {
      await seat.close();
    }
    return const [LivePlayQuality(label: '自动', sort: 1000)];
  }

  /// The seat's master playlist with its path's cookies and the lease until
  /// they run out. A room the watch page gives no seat for is a
  /// [SiteStreamUnavailableError]. NOTE: the master and every segment below it
  /// need the cookies of a *live* seat; this tree hands back a URL, so only the
  /// master plays while the seat's cookies hold. Full segment playback needs the
  /// reference's owned-input seat held by the player (the app layer), which this
  /// site adapter does not own.
  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final watch = await _watchWithSeat(room.roomId);
    final socket = watch.socketUrl;
    if (socket == null) {
      throw SiteStreamUnavailableError('niconico ${room.roomId}: not watchable (offline, restricted or gone)');
    }
    final seat = await NiconicoStreamSeat.open(Uri.parse(socket));
    final NiconicoGrant grant;
    try {
      grant = seat.current;
    } finally {
      await seat.close();
    }
    final uri = grant.uri;
    final cookie = grant.cookieHeaderFor(uri);
    return [
      LivePlayLine(
        url: uri.toString(),
        headers: {...NiconicoParser.headers, if (cookie != null && cookie.isNotEmpty) 'cookie': cookie},
        format: StreamFormat.hls,
        lease: _grantLease(grant, uri),
      ),
    ];
  }

  /// The lease of a grant's master [uri]: it runs out when the earliest cookie
  /// on the master's path does (and the seat cannot be re-used after), else a
  /// short fixed window.
  static PlayLease _grantLease(NiconicoGrant grant, Uri uri) {
    final cookie = grant.cookieHeaderFor(uri);
    if (cookie == null || cookie.isEmpty) {
      return const PlayLease(cutsConnection: true);
    }
    return PlayLease(expiresAt: DateTime.now().add(_masterLifetime), cutsConnection: true);
  }

  /// The window a returned niconico master stays fetchable after its seat
  /// closes; the cookies' true expiry may be longer, but the tree's URL player
  /// cannot renew them.
  static const Duration _masterLifetime = Duration(minutes: 5);

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
  Future<({LiveRoom room, String? socketUrl, String programId})> _watchWithSeat(String roomId) async {
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
