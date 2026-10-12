import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_session.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_parser.dart';

/// The Huya adapter: room state and streams read from the room page's
/// embedded config blobs (TT_ROOM_DATA / HYPlayerConfig), plus the Tars chat
/// socket.
///
/// Not migrated yet: the Wup token flow for higher qualities and the headline
/// (super chat) board on the danmaku socket.
final class HuyaSite
    with SiteRoomGuard
    implements
        LiveSite,
        LiveDanmakuCapability,
        LiveDirectoryCapability,
        LiveSearchCapability,
        LiveAnchorSearch,
        LiveAreaCatalog {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.huya;

  @override
  String get id => SiteIds.huya;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.huya, displayName: '虎牙直播', homeUrl: 'https://www.huya.com');

  /// The site's own front page: the same `getLiveListByPage` call the web
  /// client makes, without a game filter. The recommendation list is the
  /// one endpoint here that wants an `Origin`/`Referer` pair — the CDN
  /// answers 403 to a bare request for it — so the headers are attached
  /// only for this call, where they are needed.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) =>
      _liveList(page, headers: const {'origin': _web, 'referer': '$_web/'});

  /// The same list filtered by the area's game id.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) => _liveList(page, gameId: area.id);

  /// Live search.
  ///
  /// The search CDN answers `403 Not allowed` to a request without a
  /// User-Agent, which is why the browser UA is attached here (and only
  /// here — the directory works without it). A blank keyword asks nothing.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    const rows = 30;
    final start = ((page < 1 ? 1 : page) - 1) * rows;
    final url = Uri.https('search.cdn.huya.com', '/', {
      'm': 'Search',
      'do': 'getSearchContent',
      'q': text,
      'uid': '0',
      'v': '4',
      'typ': '-5',
      'livestate': '0',
      'rows': '$rows',
      'start': '$start',
    });
    final response = await http.send(LiveRequest.get(url, headers: const {'user-agent': _userAgent}, site: siteId));
    final root = _json(response, what: 'getSearchContent');
    final payload = root['response'];
    if (payload is! Map<String, Object?>) {
      throw const SiteApiChangedError('huya search: no response object');
    }
    return HuyaParser.searchRooms(payload, start: start, rows: rows);
  }

  /// Decodes an endpoint's JSON envelope.
  ///
  /// Huya's directory and search endpoints answer with the payload at the
  /// top level (there is no `code` field to check), so the rules here are
  /// the transport's: a non-200 status or a body that is not an object is
  /// an API change, not an empty page.
  Map<String, Object?> _json(LiveResponse response, {required String what}) {
    if (response.statusCode != 200) {
      throw SiteApiChangedError('huya $what: HTTP ${response.statusCode}');
    }
    final Object? root;
    try {
      root = jsonDecode(response.text);
    } on FormatException catch (error) {
      throw SiteApiChangedError('huya $what: body is not JSON (${error.message})');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('huya $what: body is not an object');
    }
    return root;
  }

  /// The site's boards and every board's areas, flattened.
  ///
  /// One request per board — four of them, in parallel — because the site
  /// offers no endpoint that lists a board's areas together with the others;
  /// a board whose request fails is skipped rather than failing the whole
  /// catalogue, since three boards of areas still browse.
  @override
  Future<List<LiveArea>> getAreas() async {
    final results = await Future.wait([for (final board in HuyaParser.boards) _boardAreas(board)]);
    return [for (final areas in results) ...areas];
  }

  /// One board's areas, or none when its request fails.
  Future<List<LiveArea>> _boardAreas(({String id, String name}) board) async {
    try {
      final response = await http.send(
        LiveRequest.get(
          Uri.https('live.cdn.huya.com', '/liveconfig/game/bussLive', {'bussType': board.id}),
          headers: const {'user-agent': _userAgent},
          site: siteId,
        ),
      );
      return HuyaParser.areas(_json(response, what: 'bussLive'), board: board);
    } on Object {
      return const [];
    }
  }

  /// The streamers matching [keyword], live or not.
  ///
  /// The same endpoint as the room search with the other document set
  /// selected (`v=1` asks for streamers, `v=4` for rooms): the site answers
  /// both in one payload, which is why the parser reads the set it needs
  /// rather than the answer being requested twice.
  @override
  Future<LivePage<LiveAnchor>> searchAnchors(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveAnchor>(items: []);
    }
    const rows = 30;
    final start = ((page < 1 ? 1 : page) - 1) * rows;
    final url = Uri.https('search.cdn.huya.com', '/', {
      'm': 'Search',
      'do': 'getSearchContent',
      'q': text,
      'uid': '0',
      'v': '1',
      'typ': '-5',
      'livestate': '0',
      'rows': '$rows',
      'start': '$start',
    });
    final response = await http.send(LiveRequest.get(url, headers: const {'user-agent': _userAgent}, site: siteId));
    final root = _json(response, what: 'getSearchContent');
    final payload = root['response'];
    if (payload is! Map<String, Object?>) {
      throw const SiteApiChangedError('huya search: no response object');
    }
    return HuyaParser.searchAnchors(payload);
  }

  /// `cache.php?m=LiveList&do=getLiveListByPage`, 120 rooms a page.
  Future<LivePage<LiveRoom>> _liveList(int page, {String? gameId, Map<String, String> headers = const {}}) async {
    final number = page < 1 ? 1 : page;
    final url = Uri.https('www.huya.com', '/cache.php', {
      'm': 'LiveList',
      'do': 'getLiveListByPage',
      'tagAll': '0',
      'gameId': ?gameId,
      'page': '$number',
    });
    final response = await http.send(LiveRequest.get(url, headers: headers, site: siteId));
    final root = _json(response, what: 'getLiveListByPage');
    final data = root['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('huya directory: no data object');
    }
    return HuyaParser.roomList(data, page: number);
  }

  /// The site origin, used for the recommendation request's headers.
  static const String _web = 'https://www.huya.com';

  /// The browser User-Agent the search CDN requires.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return room.mergeFrom(HuyaParser.roomDetail(html, requestedId: room.roomId));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return HuyaParser.playQualities(html);
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    final lines = HuyaParser.playLines(html);
    return quality.quality == null
        ? lines
        : lines
              .where(
                (line) =>
                    line.url.contains('ratio=${quality.quality}&') || line.url.contains('ratio=${quality.quality}'),
              )
              .toList();
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final html = await _page(room.roomId);
    return room.mergeFrom(HuyaParser.roomDetail(html, requestedId: room.roomId));
  }

  /// Opens the Tars chat socket for [room].
  ///
  /// The streamer's numeric uid comes from the room page (TT_ROOM_DATA) and
  /// names the chat groups the socket registers; the board channel id
  /// (`lChannelId`, topSid) names the headline board a super-chat notice
  /// fetches. A room the page gives no uid for cannot join; one with no
  /// topSid reads only inline board panels.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final detail = HuyaParser.roomDetail(await _page(room.roomId), requestedId: room.roomId);
    final data = detail.data;
    final uid = data is Map<String, Object?> ? SiteCounts.integer(data['uid']) : null;
    final topSid = data is Map<String, Object?> ? SiteCounts.integer(data['topSid']) ?? 0 : 0;
    if (uid == null || uid <= 0) {
      throw SiteNotFoundError('huya ${room.roomId}: no streamer uid to register');
    }
    final board = topSid > 0 ? () => _headLineBoard(topSid) : null;
    return await HuyaDanmakuSession.connect(uid, board: board);
  }

  /// Fetches the room's headline (super chat) board: a `wupui.
  /// getHeadLineMessageBoard` WUP packet over HTTP, decoded back into
  /// super-chat messages.
  Future<List<LiveMessage>> _headLineBoard(int topSid) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'POST',
        url: HuyaDanmakuProtocol.wupEndpoint,
        bodyBytes: HuyaDanmakuProtocol.messageBoardRequest(topSid),
        headers: HuyaDanmakuProtocol.wupHeaders,
        site: id,
      ),
    );
    return HuyaDanmakuProtocol.superChats(response.bodyBytes, now: DateTime.now(), status: response.statusCode);
  }

  Future<String> _page(String roomId) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.huya.com', '/$roomId'),
        headers: const {
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
        site: id,
      ),
    );
    if (response.statusCode != 200) {
      throw SiteApiChangedError('huya/$roomId: HTTP ${response.statusCode}');
    }
    return response.text;
  }
}
