import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_session.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_parser.dart';

/// The AcFun adapter: the visitor-session → startPlay play flow.
///
/// Not migrated yet: the paid-show ticket flow.
final class AcfunSite
    with SiteRoomGuard
    implements LiveSite, LiveDirectoryCapability, LiveAreaCatalog, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  String? _deviceId;
  ({String userId, String token, String security})? _visitor;

  @override
  String get siteId => SiteIds.acfun;

  @override
  String get id => SiteIds.acfun;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.acfun, displayName: 'AcFun直播', homeUrl: 'https://live.acfun.cn');

  /// The site's channel filters, flattened.
  ///
  /// They arrive with any listing answer (`channelFilters`), which is why
  /// this asks for the smallest one the site can give — a single room —
  /// rather than a dedicated catalogue endpoint the site does not have. The
  /// display group's name is kept as the area's parent, so a picker can group
  /// the filters the way the site itself does.
  @override
  Future<List<LiveArea>> getAreas() async {
    final url = Uri.https('live.acfun.cn', '/api/channel/list', {'count': '1'});
    final response = await http.send(LiveRequest.get(url, headers: AcfunParser.apiHeaders, site: siteId));
    final root = AcfunParser.root(response.text, status: response.statusCode, what: 'channel/list');
    return AcfunParser.channelAreas(root);
  }

  /// Every live room, by popularity.
  ///
  /// The listing endpoint pages by an opaque cursor and not by page number,
  /// so a stateless `page: N` request is served by walking the cursors from
  /// the first page to the requested one. The chains are cached per filter
  /// (one entry per distinct listing, oldest evicted), which is what makes
  /// "next page" cost one request instead of N: without the cache, every
  /// scroll step would re-fetch every page before it.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _listing(page, filters: null);

  /// The rooms of one area.
  ///
  /// An area whose filter id is "everything" lists the same rooms as the
  /// recommendations, so it is requested without a filter — the site sorts
  /// the same list either way, and a filter that means "no filter" only adds
  /// a parameter to disagree about.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final id = SiteCounts.integer(area.id);
    if (id == null || id == AcfunParser.allFilterId) {
      return _listing(page, filters: null);
    }
    final type = SiteCounts.integer(area.parentId) ?? id;
    return _listing(
      page,
      filters: AcfunParser.filterQuery(type: type, id: id),
    );
  }

  /// Page [page] of the listing selected by [filters].
  ///
  /// The answer is the *last* page walked, not the concatenation: a request
  /// for page 2 of a listing that ended on page 1 is an empty page, and
  /// returning page 1's rooms there would make an infinite scroll repeat
  /// itself forever.
  Future<LivePage<LiveRoom>> _listing(int page, {required String? filters}) async {
    final number = page < 1 ? 1 : page;
    final chain = _chainFor(filters);
    List<LiveRoom>? pageRooms;
    for (var current = 1; current <= number; current++) {
      final cached = chain.pages[current];
      if (cached != null) {
        pageRooms = cached;
        continue;
      }
      if (chain.ended) {
        // The listing ran out before this page: an empty page, not an error.
        return const LivePage<LiveRoom>(items: []);
      }
      final cursor = chain.cursors[current];
      if (cursor == null) {
        // No cursor opens this page (the chain was evicted): stop rather
        // than guess one.
        return const LivePage<LiveRoom>(items: []);
      }
      final result = await _directoryPage(cursor: cursor, filters: filters);
      chain.pages[current] = result.rooms;
      chain.cursors[current + 1] = result.nextCursor;
      chain.ended = result.nextCursor == null;
      pageRooms = result.rooms;
    }
    return LivePage<LiveRoom>(
      items: pageRooms ?? const [],
      hasMore: !chain.ended,
      nextPage: chain.ended ? null : number + 1,
    );
  }

  /// One request of the listing at [cursor].
  Future<({List<LiveRoom> rooms, String? nextCursor})> _directoryPage({
    required String cursor,
    required String? filters,
  }) async {
    final url = Uri.https('live.acfun.cn', '/api/channel/list', {
      'count': '$_directoryPageSize',
      'pcursor': cursor,
      'filters': ?filters,
    });
    final response = await http.send(LiveRequest.get(url, headers: AcfunParser.apiHeaders, site: siteId));
    return AcfunParser.directory(
      response.text,
      (item) => SiteText.trimmed(item['authorId']),
      status: response.statusCode,
    );
  }

  /// The cursor chain for [filters], created on first use and evicted oldest
  /// first.
  _AcfunChain _chainFor(String? filters) {
    final key = filters ?? '';
    final existing = _chains[key];
    if (existing != null) {
      return existing;
    }
    final created = _AcfunChain()..cursors[1] = '';
    _chains[key] = created;
    while (_chains.length > _maxChains) {
      _chains.remove(_chains.keys.first);
    }
    return created;
  }

  /// How many rooms one directory request asks for (the endpoint's maximum).
  static const int _directoryPageSize = 60;

  /// How many cursor chains are kept; a handful covers the pages a user can
  /// reach in one sitting without growing without bound.
  static const int _maxChains = 8;

  final Map<String, _AcfunChain> _chains = {};

  /// 3.x's author search: the `www.acfun.cn/search?type=user` page at
  /// [page], an HTML fragment of `.search-up` cards parsed by
  /// [AcfunParser.searchPage]. A blank keyword gives nothing without a request;
  /// the site pages by server page, so a logical page is that server page
  /// (thirty cards), and more follow while the total extends past it.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.get(AcfunParser.searchUrl(text, page), headers: AcfunParser.searchHeaders, site: siteId),
    );
    final result = AcfunParser.searchPage(response.text, page: page, status: response.statusCode);
    final hasMore = page * AcfunParser.searchPageSize < result.total;
    return LivePage<LiveRoom>(
      items: result.rooms,
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: result.total,
    );
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    // The quality list rides in the startPlay answer; one default until
    // the quality-table migration.
    return const [LivePlayQuality(label: '原画')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final play = await _startPlay(room.roomId);
    return AcfunParser.playLines(play.body, status: play.status);
  }

  /// A fresh visitor session and `startPlay` for [authorId], as the web
  /// client asks them: the same request serves the streams and the danmaku
  /// link's join parameters.
  Future<({String body, int status})> _startPlay(String authorId) async {
    final visitor = await _session();
    final deviceId = _deviceId!;
    final response = await http.send(
      LiveRequest.form(
        Uri.https('api.kuaishouzt.com', '/rest/zt/live/web/startPlay', {
          'subBiz': 'mainApp',
          'kpn': 'ACFUN_APP',
          'kpf': 'PC_WEB',
          'userId': visitor.userId,
          'did': deviceId,
          'acfun.api.visitor_st': visitor.token,
        }),
        fields: {'authorId': authorId, 'pullStreamType': 'FLV'},
        headers: AcfunParser.apiHeaders,
        site: id,
      ),
    );
    return (body: response.text, status: response.statusCode);
  }

  /// Opens AcFun's live link for [room]: the visitor session (whose
  /// `acSecurity` seals the register exchange) and the `startPlay` answer
  /// (its broadcast id, tickets and enter attachment) the streams come from
  /// too. A visitor without `acSecurity`, or a broadcast with no ticket,
  /// leaves the link unable to join, so this ends with a [SiteApiChangedError]
  /// rather than opening a socket that cannot register.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final visitor = await _session();
    final play = AcfunParser.danmakuParams((await _startPlay(room.roomId)).body);
    return await AcfunDanmakuSession.connect(
      AcfunDanmakuArgs(
        userId: visitor.userId,
        deviceId: _deviceId!,
        token: visitor.token,
        security: visitor.security,
        liveId: play.liveId,
        tickets: play.tickets,
        enterRoomAttach: play.enterRoomAttach,
      ),
    );
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _info(room.roomId);
    return room.mergeFrom(fresh);
  }

  Future<LiveRoom> _info(String authorId) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('live.acfun.cn', '/api/live/info', {'authorId': authorId}),
        headers: AcfunParser.apiHeaders,
        site: id,
      ),
    );
    return AcfunParser.roomDetail(response.text, authorId: authorId, status: response.statusCode);
  }

  /// The visitor session; a refused one is replaced on the next call.
  Future<({String userId, String token, String security})> _session() async {
    final cached = _visitor;
    if (cached != null) {
      return cached;
    }
    final deviceId = _deviceId ??= AcfunParser.deviceId();
    final response = await http.send(
      LiveRequest.form(
        Uri.https('id.app.acfun.cn', '/rest/app/visitor/login'),
        fields: const {'sid': 'acfun.api.visitor'},
        headers: {...AcfunParser.apiHeaders, 'cookie': '_did=$deviceId;'},
        site: id,
      ),
    );
    final visitor = AcfunParser.visitor(response.text, status: response.statusCode);
    return _visitor = visitor;
  }
}

/// One listing's cursor chain: which cursor opens each page, and the pages
/// already read.
///
/// AcFun pages by cursor, so page N is only reachable through the cursor the
/// previous page handed back. Keeping the chain is what turns the stateless
/// page API into one request per page instead of N.
class _AcfunChain {
  /// The cursor that opens each page (page 1 opens with the empty cursor);
  /// a page whose cursor is unknown cannot be reached yet.
  final Map<int, String?> cursors = {};

  /// The rooms of each page, once read.
  final Map<int, List<LiveRoom>> pages = {};

  /// Whether the site said there are no more pages.
  bool ended = false;
}
