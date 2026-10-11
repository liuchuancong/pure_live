import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_session.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_parser.dart';

/// The Kuaishou adapter: rooms parsed from the page's embedded
/// `window.__INITIAL_STATE__`.
///
/// The directory (home, boards, streamer search) and the comment feed are
/// migrated; the feed is polled over HTTP rather than opened as a socket,
/// which is what the site's own mobile client does.
///
/// Not migrated yet: the desktop WebSocket danmaku (it needs a signed
/// browser bootstrap), the session cookie dance and the gift catalog.
final class KuaishouSite
    with SiteRoomGuard
    implements
        LiveSite,
        LiveDirectoryCapability,
        LiveSearchCapability,
        LiveDanmakuCapability,
        LiveAreaCatalog,
        LiveAnchorSearch {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  String? _lastHtml;
  String? _lastRoomId;

  @override
  String get siteId => SiteIds.kuaishou;

  @override
  String get id => SiteIds.kuaishou;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.kuaishou, displayName: '快手直播', homeUrl: 'https://live.kuaishou.com');

  /// The home listing.
  ///
  /// The endpoint answers everything it has in one answer — it has no second
  /// page — so a request past the first is an empty page rather than a
  /// repeat of the first.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page > 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final root = await _json('/live_api/home/list');
    return KuaishouParser.homeRooms(root);
  }

  /// The rooms of one game area.
  ///
  /// Deliberately not migrated yet: the board listing's path segment is the
  /// board the site groups a game under, and the game ids the category
  /// endpoint hands out do not map onto it one-to-one — guessing the path
  /// produced a 404 for every area, which is worse than saying so. The home
  /// listing and streamer search cover browsing until that mapping is read
  /// from the site's own page.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    throw UnimplementedError('kuaishou board listings land with the board-path migration');
  }

  /// The game categories of the site's own boards, which is what a caller
  /// browses by before it has an area to ask for.
  ///
  /// The endpoint pages its categories, so a first page that still reports
  /// more is followed: a caller that asks for the categories gets all of
  /// them, because a half-filled side bar is worse than a slow one.
  @override
  Future<List<LiveArea>> getAreas() => _areas();

  /// The same catalogue for a board type other than the default.
  Future<List<LiveArea>> _areas({String type = '1', int maxPages = 4}) async {
    final areas = <LiveArea>[];
    final seen = <String>{};
    for (var page = 1; page <= maxPages; page++) {
      final root = await _json('/live_api/category/data', {'type': type, 'page': '$page', 'size': '30'});
      final pageAreas = KuaishouParser.areas(root, what: 'category/data');
      var added = false;
      for (final area in pageAreas) {
        if (seen.add(area.id)) {
          areas.add(area);
          added = true;
        }
      }
      final hasMore = SiteCounts.flag(KuaishouParser.listPayload(root, what: 'category/data')['hasMore']) ?? false;
      if (!hasMore || !added) {
        break;
      }
    }
    return areas;
  }

  /// Streamer search, at most one page of results.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final number = page < 1 ? 1 : page;
    // Built by hand: `Uri` drops the `=` of an empty value and the site
    // expects `lssid=` (it answers a different listing without it).
    final encoded = Uri.encodeQueryComponent(text);
    final url = Uri.parse('https://$_webHost/live_api/search/author?keyword=$encoded&page=$number&lssid=');
    final response = await http.send(
      LiveRequest.get(
        url,
        headers: {...KuaishouParser.webHeaders, 'referer': 'https://$_webHost/search?keyword=$encoded'},
        site: siteId,
      ),
    );
    return KuaishouParser.roomList(
      KuaishouParser.json(response.text, status: response.statusCode, what: 'search/author'),
      what: 'search/author',
    );
  }

  /// The streamers matching [keyword], as anchors.
  ///
  /// Kuaishou searches *people*: the endpoint is the author search, and a
  /// room exists for an author only while they are broadcasting, which is
  /// why the room-shaped reading of this same answer had to invent a room
  /// for everybody else. Here the two are separate facts — an anchor with
  /// the room to open when there is one — and the live flag is the card's
  /// own, not a guess from the presence of a stream.
  @override
  Future<LivePage<LiveAnchor>> searchAnchors(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveAnchor>(items: []);
    }
    final number = page < 1 ? 1 : page;
    final encoded = Uri.encodeQueryComponent(text);
    final url = Uri.parse('https://$_webHost/live_api/search/author?keyword=$encoded&page=$number&lssid=');
    final response = await http.send(
      LiveRequest.get(
        url,
        headers: {...KuaishouParser.webHeaders, 'referer': 'https://$_webHost/search?keyword=$encoded'},
        site: siteId,
      ),
    );
    final root = KuaishouParser.json(response.text, status: response.statusCode, what: 'search/author');
    return KuaishouParser.anchorList(root);
  }

  /// One JSON directory request.
  Future<Map<String, Object?>> _json(String path, [Map<String, String> query = const {}]) async {
    final response = await http.send(
      LiveRequest.get(Uri.https(_webHost, path, query), headers: KuaishouParser.webHeaders, site: siteId),
    );
    return KuaishouParser.json(response.text, status: response.statusCode, what: path);
  }

  /// Opens the room's comment feed.
  ///
  /// The feed is polled with the broadcast's live stream id, and on this
  /// platform that id *is* the room id: the directory's own cards carry it as
  /// their `id`, which is why a card read from the home listing is a complete
  /// danmaku argument on its own. Nothing is fetched to start a session —
  /// which also matters, because the room page answers a verification
  /// challenge to an anonymous client often enough that reading it here would
  /// fail sessions that need nothing from it.
  ///
  /// The emote table does come from the page, and only from the page: emotes
  /// are decoration, so a page that refuses to be read costs the session its
  /// emotes and nothing else.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    return await KuaishouDanmakuSession.connect(
      http: http,
      liveStreamId: room.roomId,
      emotes: await _emoteTable(room.roomId),
    );
  }

  /// The room page's emote table, or an empty table when the page cannot be
  /// read (risk control, or a page layout this build does not know).
  Future<Map<String, String>> _emoteTable(String roomId) async {
    try {
      final state = KuaishouParser.initialState(await _page(roomId));
      return KuaishouParser.emoteTable(state);
    } on Object {
      return const {};
    }
  }

  /// The web host the directory endpoints live on.
  static const String _webHost = 'live.kuaishou.com';

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return room.mergeFrom(KuaishouParser.roomDetail(html, requestedId: room.roomId));
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
    final html = await _page(room.roomId);
    return room.mergeFrom(KuaishouParser.roomDetail(html, requestedId: room.roomId));
  }

  Future<List<LivePlayLine>> _lines(String roomId) async {
    final html = await _page(roomId);
    final state = KuaishouParser.initialState(html);
    return KuaishouParser.playLinesFromRoom(KuaishouParser.playItem(state));
  }

  Future<String> _page(String roomId) async {
    if (_lastRoomId == roomId && _lastHtml != null) {
      return _lastHtml!;
    }
    final response = await http.send(
      LiveRequest.get(Uri.https('live.kuaishou.com', '/u/$roomId'), headers: KuaishouParser.webHeaders, site: id),
    );
    _lastRoomId = roomId;
    return _lastHtml = response.text;
  }
}
