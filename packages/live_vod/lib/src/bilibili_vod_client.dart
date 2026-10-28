import 'dart:convert' show jsonDecode;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse;
import 'package:live_vod/src/bilibili_wbi.dart';
import 'package:live_vod/src/vod_models.dart';

export 'package:live_vod/src/vod_models.dart';

/// The Bilibili video source: search, the page list that names the first
/// part's cid, the progressive play address, the signed-in viewer's feeds and
/// lists, and the cinema (PGC) pages.
///
/// The client speaks only [LiveHttp] and JSON, so the transport (proxies,
/// retries, cookies) stays the app's business. A play address is the
/// progressive mp4 (`fnval=1`): it carries its audio with the picture, which
/// is what a single-surface player needs; the DASH audio ladder is served
/// separately for the music mode.
final class BilibiliVodClient {
  /// A client over [http].
  new(this.http, {this.userAgent = _defaultUserAgent, this.cookie = ''});

  /// The transport.
  final LiveHttp http;

  /// The browser string the endpoints expect.
  final String userAgent;

  /// The signed-in Bilibili cookie (`SESSDATA=...; bili_jct=...`), or empty
  /// for guest reads. The same credential the live site uses, so one sign-in
  /// serves both modes.
  final String cookie;

  /// The guest fingerprint cookies a search needs, fetched once when the
  /// viewer has not signed in: the search endpoint risk-controls a bare
  /// request (HTTP 412), while the popular, ranking and view endpoints do
  /// not ask for them.
  String? _guestCookies;

  /// The WBI keys the signed endpoints sign with, and when they were read —
  /// the nav answer rotates them, and six hours is well inside the rotation.
  ({String imgKey, String subKey})? _wbiKeys;
  DateTime? _wbiFetchedAt;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  /// The headers every Bilibili web endpoint wants.
  Map<String, String> get _headers => {
    'user-agent': userAgent,
    'referer': 'https://www.bilibili.com',
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

  /// The headers an address this client resolved must be opened with — the
  /// CDN checks the referer and the sign-in.
  Map<String, String> get playHeaders => _headers;

  /// The general popular feed (`x/web-interface/popular`), paged.
  ///
  /// The endpoint refuses a window above 50; a viewer's display page size
  /// may be larger, so the request is clamped rather than failed.
  Future<VodVideoPage> popular({int page = 1, int pageSize = 20}) async {
    final window = pageSize.clamp(1, 50);
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/popular', {'pn': '$page', 'ps': '$window'}),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    final list = data is Map ? (data['list'] as List<Object?>?) ?? const [] : const <Object?>[];
    return VodVideoPage(
      videos: [
        for (final item in list)
          if (item is Map) ?_listVideoOf(item),
      ],
      // The popular endpoint says directly whether the walk is over; an
      // empty page also ends it, for an answer that omitted the flag.
      hasMore: list.isNotEmpty && (data is! Map || data['no_more'] != true),
    );
  }

  /// A region's leaderboard (`x/web-interface/ranking/v2`), one fixed list.
  Future<List<VodVideo>> ranking({int rid = 0}) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/ranking/v2', {'rid': '$rid', 'type': 'all'}),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    final list = data is Map ? (data['list'] as List<Object?>?) ?? const [] : const <Object?>[];
    return [
      for (final item in list)
        if (item is Map) ?_listVideoOf(item),
    ];
  }

  /// A region's recommendation feed (`x/web-interface/region/feed/rcmd`),
  /// paged by [page]; [requestCount] is the window the endpoint returns.
  ///
  /// [tid] is a top-level *channel* id (1005 animation, 1008 games, and so
  /// on), not the classic partition id the ranking endpoint takes — the
  /// feed refuses the old ids with `-400`. An empty `archives` ends it.
  Future<VodVideoPage> regionFeed({required int tid, int page = 1, int requestCount = 15}) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/region/feed/rcmd', {
          'display_id': '$page',
          'request_cnt': '$requestCount',
          'from_region': '$tid',
          'device': 'web',
          'plat': '30',
        }),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    final list = data is Map ? (data['archives'] as List<Object?>?) ?? const [] : const <Object?>[];
    return VodVideoPage(
      videos: [
        for (final item in list)
          if (item is Map) ?_listVideoOf(item),
      ],
      // The feed carries no end flag; an empty page is the end.
      hasMore: list.isNotEmpty,
    );
  }

  /// One archive's full metadata and parts (`x/web-interface/view`).
  Future<VodDetail> detail(String bvid) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/view', {'bvid': bvid}),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    if (data is! Map) throw const VodFailure('the view answer carried no data');
    final owner = data['owner'];
    final stat = data['stat'];
    final pages = (data['pages'] as List<Object?>?) ?? const [];
    return VodDetail(
      bvid: bvid,
      aid: (data['aid'] as num?)?.toInt() ?? 0,
      title: '${data['title'] ?? ''}',
      coverUrl: _coverOf(data['pic']),
      description: '${data['desc'] ?? ''}'.trim(),
      uploader: owner is Map ? '${owner['name'] ?? ''}' : null,
      uploaderMid: owner is Map ? (owner['mid'] as num?)?.toInt() : null,
      uploaderAvatar: owner is Map ? _coverOf(owner['face']) : null,
      playCount: stat is Map ? (stat['view'] as num?)?.toInt() : null,
      danmakuCount: stat is Map ? (stat['danmaku'] as num?)?.toInt() : null,
      likeCount: stat is Map ? (stat['like'] as num?)?.toInt() : null,
      coinCount: stat is Map ? (stat['coin'] as num?)?.toInt() : null,
      favoriteCount: stat is Map ? (stat['favorite'] as num?)?.toInt() : null,
      duration: _durationOf('${data['duration'] ?? ''}'),
      parts: [
        for (final page in pages)
          if (page is Map && (page['cid'] as num?) != null)
            VodPart(
              cid: (page['cid'] as num).toInt(),
              page: (page['page'] as num?)?.toInt() ?? 1,
              title: '${page['part'] ?? ''}',
              duration: _durationOf('${page['duration'] ?? ''}'),
            ),
      ],
      publishedAt: (data['pubdate'] as num?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((data['pubdate'] as num).toInt() * 1000),
    );
  }

  /// The archives related to [bvid] (`archive/related`).
  Future<List<VodVideo>> related(String bvid) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/archive/related', {'bvid': bvid}),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    final list = data is List
        ? data
        : data is Map
        ? (data['list'] as List<Object?>?) ?? const <Object?>[]
        : const <Object?>[];
    return [
      for (final item in list)
        if (item is Map) ?_listVideoOf(item),
    ];
  }

  /// Searches the site's videos for [keyword]; [page] starts at 1.
  ///
  /// [order] is the web's sort key (`totalrank`, `click`, `pubdate`, `dm`,
  /// `stow`); [duration] is the length tier (0 = any, 1 = under 10 min,
  /// 2 = 10–30, 3 = 30–60, 4 = over 60). The endpoint refuses a window
  /// above 50, so a larger display page is clamped.
  Future<VodSearchPage> search(
    String keyword, {
    int page = 1,
    int pageSize = 20,
    String order = 'totalrank',
    int duration = 0,
  }) async {
    final window = pageSize.clamp(1, 50);
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/search/type', {
          'search_type': 'video',
          'keyword': keyword,
          'page': '$page',
          'page_size': '$window',
          'order': order,
          if (duration > 0) 'duration': '$duration',
        }),
        headers: await _searchHeaders(),
      ),
    );
    final json = _body(response);
    final data = json['data'];
    if (data is! Map) {
      return const VodSearchPage(videos: []);
    }
    final results = (data['result'] as List<Object?>?) ?? const [];
    final videos = [
      for (final hit in results)
        if (hit is Map) ?_videoOf(hit),
    ];
    final numResults = (data['numResults'] as num?)?.toInt() ?? videos.length;
    return VodSearchPage(videos: videos, hasMore: page * window < numResults);
  }

  /// Resolves [video]'s first part to a progressive address.
  Future<VodPlayInfo> play(VodVideo video, {int? cid, int qn = 64}) async {
    final bvid = video.bvid ?? video.id;
    final partCid = cid ?? int.tryParse(await _firstCid(video)) ?? 0;
    if (partCid <= 0) throw const VodFailure('the first part names no cid');
    return await playPart(bvid: bvid, cid: partCid, qn: qn);
  }

  /// Resolves one part's progressive address.
  ///
  /// `fnval=1` asks for the muxed mp4: picture and sound in one stream, which
  /// a single-surface player can open. When the source only answers a DASH
  /// ladder (some login-gated renditions) the first video rendition is returned
  /// with [VodPlayInfo.silent] set, rather than pretending the answer has audio.
  Future<VodPlayInfo> playPart({required String bvid, required int cid, int qn = 64}) async {
    final play = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/player/playurl', {
          'bvid': bvid,
          'cid': '$cid',
          'qn': '$qn',
          'fnval': '1',
          'fnver': '0',
          'fourk': '1',
          'platform': 'oc',
          'otype': 'json',
          if (cookie.isEmpty) ..._guestParams,
        }),
        headers: _headers,
      ),
    );
    final data = _body(play)['data'];
    if (data is! Map) {
      throw const VodFailure('the source returned no play data');
    }
    return _playInfoOf(data, qn: qn);
  }

  /// The anonymous preview parameters the web player sends when no cookie is
  /// present (the reference TV client's risk-control lesson).
  Map<String, String> get _guestParams => const {
    'web_location': '1315873',
    'gaia_source': 'pre-load',
    'isGaiaAvoided': 'true',
    'try_look': '1',
  };

  /// The headers a search asks with: Bilibili's search endpoint wants the
  /// search site as its referer, and risk-controls a bare request — a guest
  /// gets through once the fingerprint cookies are there.
  Future<Map<String, String>> _searchHeaders() async {
    final headers = {..._headers, 'referer': 'https://search.bilibili.com'};
    if (cookie.trim().isNotEmpty) return headers;
    final guest = _guestCookies ?? await _fetchGuestCookies();
    if (guest.isNotEmpty) {
      _guestCookies = guest;
      headers['cookie'] = guest;
    }
    return headers;
  }

  /// The 番剧/影视 hits of a search — the platform names seasons here, so the
  /// cards open a season's page rather than an archive. [bangumi] picks
  /// 番剧 (`media_bangumi`) over 影视 (`media_ft`).
  Future<VodSeasonSearchPage> searchMedia(
    String keyword, {
    required bool bangumi,
    int page = 1,
    int pageSize = 20,
  }) async {
    final answer = await _searchType(
      keyword,
      type: bangumi ? 'media_bangumi' : 'media_ft',
      page: page,
      pageSize: pageSize,
    );
    return VodSeasonSearchPage(
      seasons: [for (final hit in answer.results) ?_seasonOfSearch(hit)],
      hasMore: answer.hasMore,
    );
  }

  /// The user hits of a search (`bili_user`).
  Future<VodUserSearchPage> searchUsers(String keyword, {int page = 1, int pageSize = 20}) async {
    final answer = await _searchType(keyword, type: 'bili_user', page: page, pageSize: pageSize);
    return VodUserSearchPage(
      users: [for (final hit in answer.results) ?_userOf(hit)],
      hasMore: answer.hasMore,
    );
  }

  /// The live-room hits of a search (`live_room`).
  Future<VodLiveRoomSearchPage> searchLiveRooms(String keyword, {int page = 1, int pageSize = 20}) async {
    final answer = await _searchType(keyword, type: 'live_room', page: page, pageSize: pageSize);
    return VodLiveRoomSearchPage(
      rooms: [for (final hit in answer.results) ?_liveRoomOf(hit)],
      hasMore: answer.hasMore,
    );
  }

  /// The generic answer behind the typed searches: the raw hits and whether
  /// another page follows. The window and the guest fingerprint follow the
  /// video search — it is the same endpoint.
  Future<({List<Object?> results, bool hasMore})> _searchType(
    String keyword, {
    required String type,
    required int page,
    required int pageSize,
  }) async {
    final window = pageSize.clamp(1, 50);
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/search/type', {
          'search_type': type,
          'keyword': keyword,
          'page': '$page',
          'page_size': '$window',
        }),
        headers: await _searchHeaders(),
      ),
    );
    final data = _body(response)['data'];
    if (data is! Map) return (results: const <Object?>[], hasMore: false);
    final results = (data['result'] as List<Object?>?) ?? const <Object?>[];
    final pages = (data['numPages'] as num?)?.toInt();
    final total = (data['numResults'] as num?)?.toInt();
    final hasMore = pages != null
        ? page < pages
        : total != null
        ? page * window < total
        : results.isNotEmpty;
    return (results: results, hasMore: hasMore);
  }

  /// One 番剧/影视 hit as a season card: the score and the type's own name.
  static VodSeason? _seasonOfSearch(Object? hit) {
    if (hit is! Map) return null;
    final seasonId = (hit['season_id'] as num?)?.toInt() ?? 0;
    final title = _plain('${hit['title'] ?? ''}');
    if (seasonId == 0 || title.isEmpty) return null;
    final score = hit['media_score'];
    final value = score is Map ? score['score'] : null;
    return VodSeason(
      seasonId: seasonId,
      title: title,
      subtitle: '${hit['season_type_name'] ?? ''}'.trim(),
      coverUrl: _coverOf(hit['cover']),
      rating: value is num ? '$value' : (value is String && value.trim().isNotEmpty ? value.trim() : null),
      evaluate: '${hit['desc'] ?? ''}'.trim(),
    );
  }

  /// One user hit.
  static VodUser? _userOf(Object? hit) {
    if (hit is! Map) return null;
    final mid = (hit['mid'] as num?)?.toInt() ?? int.tryParse('${hit['mid'] ?? ''}') ?? 0;
    final name = _plain('${hit['uname'] ?? ''}');
    if (mid == 0 || name.isEmpty) return null;
    return VodUser(
      mid: mid,
      name: name,
      avatar: _coverOf(hit['upic']),
      sign: '${hit['usign'] ?? ''}'.trim(),
      fans: (hit['fans'] as num?)?.toInt(),
      videoCount: (hit['videos'] as num?)?.toInt(),
    );
  }

  /// One live-room hit.
  static VodLiveRoom? _liveRoomOf(Object? hit) {
    if (hit is! Map) return null;
    final roomId = (hit['roomid'] as num?)?.toInt() ?? 0;
    final title = _plain('${hit['title'] ?? ''}');
    if (roomId == 0 || title.isEmpty) return null;
    final anchor = '${hit['uname'] ?? ''}'.trim();
    return VodLiveRoom(
      roomId: roomId,
      title: title,
      coverUrl: _coverOf(hit['cover'] ?? hit['user_cover']),
      anchor: anchor.isEmpty ? null : anchor,
      avatar: _coverOf(hit['uface']),
      online: (hit['online'] as num?)?.toInt(),
    );
  }

  /// The guest fingerprint pair (`buvid3`, `buvid4`) from the site's own
  /// endpoint; empty when the answer is unusable, so a search still asks
  /// and reports the block if it comes.
  Future<String> _fetchGuestCookies() async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          url: Uri.https('api.bilibili.com', '/x/frontend/finger/spi'),
          headers: {'user-agent': userAgent, 'referer': 'https://www.bilibili.com'},
        ),
      );
      final data = _body(response)['data'];
      if (data is! Map) return '';
      final third = '${data['b_3'] ?? ''}'.trim();
      final fourth = '${data['b_4'] ?? ''}'.trim();
      return [if (third.isNotEmpty) 'buvid3=$third', if (fourth.isNotEmpty) 'buvid4=$fourth'].join('; ');
    } on Object {
      return '';
    }
  }

  /// The audio renditions of [video]'s first part — 音乐模式 plays the sound
  /// and never needs the picture, so the DASH audio ladder is the right
  /// answer here where the video page needed the muxed mp4. Best first: the
  /// answer's own order is not guaranteed, so the ladder sorts by bitrate.
  Future<List<VodAudioStream>> audioStreams(VodVideo video) async {
    final cid = await _firstCid(video);
    final play = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/player/playurl', {
          'bvid': video.bvid ?? video.id,
          'cid': cid,
          'fnval': '16',
          'fourk': '1',
        }),
        headers: _headers,
      ),
    );
    final data = _body(play)['data'];
    final dash = data is Map ? data['dash'] : null;
    if (dash is! Map) throw const VodFailure('the video offered no audio stream');
    final audio = (dash['audio'] as List<Object?>?) ?? const <Object?>[];
    final flac = dash['flac'];
    final flacAudio = flac is Map ? flac['audio'] : null;
    final streams = <VodAudioStream>[
      for (final item in [...audio, ?flacAudio])
        if (item is Map && item['baseUrl'] is String && (item['baseUrl'] as String).isNotEmpty)
          VodAudioStream(
            id: (item['id'] as num?)?.toInt() ?? 0,
            url: item['baseUrl'] as String,
            bandwidth: (item['bandwidth'] as num?)?.toInt(),
            codecs: item['codecs'] is String ? item['codecs'] as String : null,
          ),
    ];
    if (streams.isEmpty) throw const VodFailure('the video offered no audio stream');
    streams.sort((a, b) => (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0));
    return streams;
  }

  /// The first part's cid, through the page list.
  Future<String> _firstCid(VodVideo video) async {
    final pages = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/player/pagelist', {'bvid': video.bvid ?? video.id}),
        headers: _headers,
      ),
    );
    final pageList = _body(pages)['data'];
    final first = pageList is List && pageList.isNotEmpty ? pageList.first : null;
    final cid = first is Map ? '${first['cid'] ?? ''}' : '';
    if (cid.isEmpty) {
      throw const VodFailure('the video names no cid');
    }
    return cid;
  }

  /// The first video a search returns for [keyword], or null.
  Future<VodVideo?> first(String keyword) async {
    final page = await search(keyword, pageSize: 1);
    return page.videos.isEmpty ? null : page.videos.first;
  }

  // ---------------------------------------------------------------------------
  // Account, home, dynamics, comments and the personal lists
  // ---------------------------------------------------------------------------

  /// The viewer's account as the nav endpoint sees it. A guest is a
  /// logged-out record, not a failure: the envelope's `-101` is the normal
  /// guest answer and its data is what tells the app to offer a sign-in.
  Future<VodAccount> account() async {
    final response = await http.send(
      LiveRequest.custom(method: 'GET', url: Uri.https('api.bilibili.com', '/x/web-interface/nav'), headers: _headers),
    );
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final json = _tryDecode(response.text);
    final data = json is Map ? json['data'] : null;
    if (data is! Map) return const VodAccount(isLogin: false);
    final name = '${data['uname'] ?? ''}'.trim();
    final face = '${data['face'] ?? ''}'.trim();
    return VodAccount(
      isLogin: data['isLogin'] == true,
      mid: (data['mid'] as num?)?.toInt(),
      name: name.isEmpty ? null : name,
      avatar: face.isEmpty ? null : _https(face),
    );
  }

  /// The home recommendation feed, page by page — every page is a fresh draw,
  /// which is why it is paged rather than cursored.
  Future<VodRecommendPage> recommend({int page = 1, int pageSize = 30}) async {
    final query = await _signed({'fresh_type': '4', 'ps': '$pageSize', 'fresh_idx': '$page', 'fresh_idx_1h': '$page'});
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/wbi/index/top/feed/rcmd', query),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    final items = data is Map ? (data['item'] as List<Object?>?) ?? const <Object?>[] : const <Object?>[];
    return VodRecommendPage(
      videos: [
        for (final item in items)
          if (item is Map) ?_listVideoOf(item),
      ],
      page: page,
    );
  }

  /// The signed-in viewer's dynamic feed. [offset] is the cursor a previous
  /// page answered with; null asks the first page.
  Future<VodDynamicPage> dynamics({String? offset}) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/polymer/web-dynamic/v1/feed/all', {
          'timezone_offset': '-480',
          'type': 'all',
          'page': '1',
          'offset': ?offset,
        }),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    if (data is! Map) return const VodDynamicPage(items: [], hasMore: false);
    final items = (data['items'] as List<Object?>?) ?? const <Object?>[];
    final cursor = '${data['offset'] ?? ''}'.trim();
    return VodDynamicPage(
      items: [for (final item in items) ?_dynamicOf(item)],
      offset: cursor.isEmpty ? null : cursor,
      hasMore: data['has_more'] == true,
    );
  }

  /// One page of an archive's comments; [sort] 1 is by likes (the hot list),
  /// 2 by time.
  Future<VodCommentPage> comments(int aid, {int page = 1, int pageSize = 20, int sort = 1}) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/v2/reply', {
          'type': '1',
          'oid': '$aid',
          'sort': '$sort',
          'pn': '${page < 1 ? 1 : page}',
          'ps': '${pageSize.clamp(1, 20)}',
          'nohot': '1',
        }),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    if (data is! Map) return const VodCommentPage(comments: [], total: 0, hasMore: false);
    final replies = (data['replies'] as List<Object?>?) ?? const <Object?>[];
    final stats = data['page'];
    final total = stats is Map ? ((stats['count'] as num?)?.toInt() ?? replies.length) : replies.length;
    return VodCommentPage(
      comments: [for (final reply in replies) ?_commentOf(reply)],
      total: total,
      hasMore: page * pageSize < total,
    );
  }

  /// The signed-in viewer's 稍后再看 list.
  Future<List<VodVideo>> watchLater() async {
    final response = await http.send(
      LiveRequest.custom(method: 'GET', url: Uri.https('api.bilibili.com', '/x/v2/history/toview'), headers: _headers),
    );
    final data = _body(response)['data'];
    final list = data is Map ? (data['list'] as List<Object?>?) ?? const <Object?>[] : const <Object?>[];
    return [
      for (final item in list)
        if (item is Map) ?_listVideoOf(item),
    ];
  }

  /// The seasons [mid] follows (追番追剧). [type] 1 is anime, 2 cinema.
  Future<VodSeasonPage> followingSeasons({required int mid, int type = 1, int page = 1, int pageSize = 20}) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/space/bangumi/follow/list', {
          'type': '$type',
          'follow_status': '0',
          'vmid': '$mid',
          'ps': '$pageSize',
          'pn': '$page',
        }),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    if (data is! Map) return const VodSeasonPage(seasons: [], hasMore: false);
    final list = (data['list'] as List<Object?>?) ?? const <Object?>[];
    final total = (data['total'] as num?)?.toInt() ?? list.length;
    return VodSeasonPage(
      seasons: [
        for (final item in list)
          if (item is Map) ?_seasonOf(item),
      ],
      hasMore: page * pageSize < total,
    );
  }

  // ---------------------------------------------------------------------------
  // PGC (影视)
  // ---------------------------------------------------------------------------

  /// One page of a PGC catalogue. [type] is Bilibili's season type: 1 番剧,
  /// 2 电影, 3 纪录片, 4 国创, 5 电视剧, 7 综艺.
  Future<VodSeasonPage> pgcFeed({required int type, int cursor = 0}) async {
    final v3 = type == 1 || type == 4;
    final name = switch (type) {
      1 => 'anime',
      2 => 'movie',
      3 => 'documentary',
      4 => 'guochuang',
      5 => 'tv',
      7 => 'variety',
      _ => 'anime',
    };
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', v3 ? '/pgc/page/web/v3/feed' : '/pgc/page/web/feed', {
          'name': name,
          // The endpoint spells the cursor with an `o`; `cursor` is ignored.
          'coursor': '$cursor',
          if (!v3) 'new_cursor_status': 'true',
        }),
        headers: _headers,
      ),
    );
    final data = _body(response)['data'];
    if (data is! Map) return VodSeasonPage(seasons: const [], cursor: cursor, hasMore: false);
    final items = (data['items'] as List<Object?>?) ?? const <Object?>[];
    final seasons = <VodSeason>[];
    for (final item in items) {
      if (item is! Map) continue;
      seasons.addAll(_seasonOfList(item));
    }
    final next = (data['coursor'] as num?)?.toInt() ?? cursor;
    return VodSeasonPage(seasons: seasons, cursor: next, hasMore: data['has_next'] == true && next != cursor);
  }

  /// A season's page: its blurb, its episodes and whether the viewer follows
  /// it.
  Future<VodSeasonDetail> seasonDetail({required int seasonId}) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/pgc/view/web/season', {'season_id': '$seasonId'}),
        headers: {..._headers, 'referer': 'https://www.bilibili.com'},
      ),
    );
    final data = _body(response)['data'];
    if (data is! Map) throw const VodFailure('the season answer carried no data');
    final episodes = (data['episodes'] as List<Object?>?) ?? const <Object?>[];
    final status = data['user_status'];
    final publish = data['publish'];
    final started = publish is Map ? DateTime.tryParse('${publish['pub_time'] ?? ''}') : null;
    final cover = '${data['cover'] ?? data['square_cover'] ?? ''}'.trim();
    final title = '${data['title'] ?? data['season_title'] ?? ''}'.trim();
    return VodSeasonDetail(
      seasonId: (data['season_id'] as num?)?.toInt() ?? seasonId,
      title: title,
      coverUrl: cover.isEmpty ? null : _https(cover),
      evaluate: '${data['evaluate'] ?? ''}'.trim(),
      episodes: [for (final episode in episodes) ?_episodeOf(episode)],
      publishedAt: started,
      followed: status is Map && ((status['follow'] as num?)?.toInt() ?? 0) > 0,
    );
  }

  /// Resolves a PGC episode's progressive address, the signed endpoint
  /// behind the cinema player. [cid] and [aid] come from the season answer
  /// and narrow the request to the exact episode revision.
  Future<VodPlayInfo> pgcPlay({required int episodeId, int? cid, int? aid, int qn = 80}) async {
    final query = await _signed({
      'ep_id': '$episodeId',
      if (cid != null) 'cid': '$cid',
      if (aid != null) 'avid': '$aid',
      'qn': '$qn',
      'fnval': '1',
      'fnver': '0',
      'fourk': '1',
    });
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/pgc/player/web/playurl', query),
        headers: {..._headers, 'referer': 'https://www.bilibili.com'},
      ),
    );
    final body = _body(response);
    final data = body['result'] ?? body['data'];
    if (data is! Map) throw const VodFailure('the episode returned no play data');
    return _playInfoOf(data, qn: qn);
  }

  /// Signs [params] with the cached WBI key pair and the current time.
  Future<Map<String, String>> _signed(Map<String, String> params) async {
    final keys = await _ensureWbiKeys();
    return BilibiliWbiSign.sign(
      params,
      imgKey: keys.imgKey,
      subKey: keys.subKey,
      wts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// The WBI key pair, read from the nav answer once every six hours.
  ///
  /// A guest is fine here: the nav envelope says `-101` but still carries
  /// `data.wbi_img`, which is all the signer needs.
  Future<({String imgKey, String subKey})> _ensureWbiKeys() async {
    final cached = _wbiKeys;
    final fetchedAt = _wbiFetchedAt;
    if (cached != null && fetchedAt != null && DateTime.now().difference(fetchedAt) < const Duration(hours: 6)) {
      return cached;
    }
    final response = await http.send(
      LiveRequest.custom(method: 'GET', url: Uri.https('api.bilibili.com', '/x/web-interface/nav'), headers: _headers),
    );
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final keys = BilibiliWbiSign.keysOf(response.text);
    if (keys == null) throw const VodFailure('the nav answer carried no WBI keys');
    _wbiKeys = keys;
    _wbiFetchedAt = DateTime.now();
    return keys;
  }

  /// One dynamic post: the author module, the words, and the archive it
  /// shares when it shares one.
  static VodDynamic? _dynamicOf(Object? item) {
    if (item is! Map) return null;
    final id = '${item['id_str'] ?? item['id'] ?? ''}'.trim();
    final modules = item['modules'];
    final author = modules is Map ? modules['module_author'] : null;
    final name = author is Map ? '${author['name'] ?? ''}'.trim() : '';
    if (id.isEmpty || name.isEmpty) return null;
    final card = modules is Map ? modules['module_dynamic'] : null;
    final desc = card is Map ? card['desc'] : null;
    final major = card is Map ? card['major'] : null;
    final archive = major is Map ? major['archive'] : null;
    final stamp = author is Map ? (author['pub_ts'] as num?)?.toInt() : null;
    final bvid = archive is Map ? '${archive['bvid'] ?? ''}'.trim() : '';
    return VodDynamic(
      id: id,
      author: name,
      avatar: author is Map ? _coverOf(author['face']) : null,
      text: desc is Map ? '${desc['text'] ?? ''}'.trim() : '',
      coverUrl: archive is Map ? _coverOf(archive['cover']) : null,
      publishedAt: stamp == null ? null : DateTime.fromMillisecondsSinceEpoch(stamp * 1000),
      bvid: bvid.isEmpty ? null : bvid,
    );
  }

  /// One reply of the `x/v2/reply` answer.
  static VodComment? _commentOf(Object? reply) {
    if (reply is! Map) return null;
    final id = (reply['rpid'] as num?)?.toInt() ?? int.tryParse('${reply['rpid_str'] ?? ''}') ?? 0;
    if (id == 0) return null;
    final member = reply['member'];
    final content = reply['content'];
    final author = member is Map ? '${member['uname'] ?? ''}'.trim() : '';
    final message = content is Map ? '${content['message'] ?? ''}'.trim() : '';
    if (author.isEmpty || message.isEmpty) return null;
    final stamp = (reply['ctime'] as num?)?.toInt();
    return VodComment(
      id: id,
      author: author,
      avatar: member is Map ? _coverOf(member['avatar']) : null,
      message: message,
      likeCount: (reply['like'] as num?)?.toInt(),
      replyCount: (reply['rcount'] as num?)?.toInt() ?? (reply['count'] as num?)?.toInt(),
      createdAt: stamp == null ? null : DateTime.fromMillisecondsSinceEpoch(stamp * 1000),
    );
  }

  /// One card of the 追番 answer.
  static VodSeason? _seasonOf(Map<Object?, Object?> item) {
    final seasonId = (item['season_id'] as num?)?.toInt();
    final title = '${item['title'] ?? item['season_title'] ?? ''}'.trim();
    if (seasonId == null || title.isEmpty) return null;
    final newEp = item['new_ep'];
    final subtitle = item['subtitle'];
    final episodeId = (item['episode_id'] as num?)?.toInt();
    final score = item['rating'];
    final stat = item['stat'];
    return VodSeason(
      seasonId: seasonId,
      title: title,
      subtitle: switch (newEp) {
        final Map<Object?, Object?> ep => '${ep['index_show'] ?? ''}'.trim(),
        _ => subtitle is String ? subtitle.trim() : '',
      },
      coverUrl: _coverOf(item['cover'] ?? item['square_cover']),
      rating: score is Map && score['score'] != null
          ? '${score['score']}'
          : score is String && score.trim().isNotEmpty
          ? score.trim()
          : null,
      evaluate: '${item['evaluate'] ?? ''}'.trim(),
      playCount: stat is Map
          ? ((stat['views'] as num?)?.toInt() ?? (stat['view'] as num?)?.toInt())
          : (stat as num?)?.toInt(),
      followed: ((item['follow_status'] as num?)?.toInt() ?? 0) > 0,
      episodeId: episodeId == null || episodeId <= 0 ? null : episodeId,
    );
  }

  /// The season cards the PGC feed's [card] carries: a v3 card wraps its
  /// titles in `sub_items`, the older feed puts one title per item.
  static Iterable<VodSeason> _seasonOfList(Map<Object?, Object?> card) sync* {
    final subItems = card['sub_items'];
    if (subItems is List) {
      for (final sub in subItems) {
        if (sub is! Map) continue;
        final season = _seasonOf(sub);
        if (season != null) yield season;
      }
      return;
    }
    final season = _seasonOf(card);
    if (season != null) yield season;
  }

  /// One episode of a season's page.
  static VodEpisode? _episodeOf(Object? value) {
    if (value is! Map) return null;
    final id = (value['id'] as num?)?.toInt() ?? (value['ep_id'] as num?)?.toInt() ?? 0;
    if (id == 0) return null;
    final name = '${value['title'] ?? ''}'.trim();
    final long = '${value['long_title'] ?? ''}'.trim();
    // The season answer's episode duration is milliseconds.
    final millis = (value['duration'] as num?)?.toInt() ?? 0;
    final cid = (value['cid'] as num?)?.toInt() ?? 0;
    final aid = (value['aid'] as num?)?.toInt() ?? 0;
    return VodEpisode(
      id: id,
      title: long.isEmpty ? name : long,
      index: name.isEmpty ? '$id' : name,
      coverUrl: _coverOf(value['cover']),
      duration: millis > 0 ? Duration(milliseconds: millis) : null,
      cid: cid > 0 ? cid : null,
      aid: aid > 0 ? aid : null,
    );
  }

  /// The address of a play answer's data (`x/player/playurl` or the PGC
  /// player): the muxed `durl` when there is one, else the first DASH
  /// rendition marked silent.
  VodPlayInfo _playInfoOf(Map<Object?, Object?> data, {required int qn}) {
    final qualities = _qualitiesOf(data);
    final served = (data['quality'] as num?)?.toInt() ?? qn;
    final label = _qualityLabel(qualities, served);
    final durl = data['durl'];
    final firstPart = durl is List && durl.isNotEmpty ? durl.first : null;
    final address = firstPart is Map ? firstPart['url'] : null;
    if (address is String && address.isNotEmpty) {
      return VodPlayInfo(url: address, headers: _headers, quality: label, qualities: qualities, servedQuality: served);
    }
    final dash = data['dash'];
    if (dash is Map) {
      final videos = (dash['video'] as List<Object?>?) ?? const [];
      final first = videos.isEmpty ? null : videos.first;
      final dashAddress = first is Map ? first['baseUrl'] : null;
      if (dashAddress is String && dashAddress.isNotEmpty) {
        return VodPlayInfo(
          url: dashAddress,
          headers: _headers,
          format: 'm4s',
          quality: label,
          qualities: qualities,
          servedQuality: served,
          silent: true,
        );
      }
    }
    throw const VodFailure('the video offered no address');
  }

  Map<String, Object?> _body(LiveResponse response) {
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final text = response.text;
    final decoded = _tryDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const VodFailure('the source answered something that is not JSON');
    }
    final code = (decoded['code'] as num?)?.toInt() ?? 0;
    if (code != 0) {
      throw VodFailure('${decoded['message'] ?? 'code $code'}');
    }
    return decoded;
  }

  VodVideo? _videoOf(Map<Object?, Object?> hit) {
    final bvid = '${hit['bvid'] ?? ''}';
    final title = _plain('${hit['title'] ?? ''}');
    if (bvid.isEmpty || title.isEmpty) {
      return null;
    }
    final duration = _durationOf('${hit['duration'] ?? ''}');
    final cover = '${hit['pic'] ?? ''}';
    return VodVideo(
      id: bvid,
      bvid: bvid,
      aid: (hit['aid'] as num?)?.toInt(),
      title: title,
      coverUrl: cover.isEmpty ? null : _https(cover),
      uploader: '${hit['author'] ?? ''}'.isEmpty ? null : '${hit['author']}',
      duration: duration,
      playCount: (hit['play'] as num?)?.toInt(),
    );
  }

  /// One entry of the browse feeds (popular, ranking, region, related):
  /// `owner`/`stat` objects and a numeric duration. The region feed names
  /// the cover `cover` and the uploader as an `author` object, where the
  /// other feeds use `pic` and `owner`.
  VodVideo? _listVideoOf(Map<Object?, Object?> item) {
    final bvid = '${item['bvid'] ?? ''}';
    final title = '${item['title'] ?? ''}'.trim();
    if (bvid.isEmpty || title.isEmpty) return null;
    final owner = item['owner'];
    final author = item['author'];
    final stat = item['stat'];
    final duration = item['duration'];
    final uploader = switch ((owner, author)) {
      (final Map<Object?, Object?> owner, _) => '${owner['name'] ?? ''}'.trim(),
      (_, final Map<Object?, Object?> author) => '${author['name'] ?? ''}'.trim(),
      (_, final String author) => author.trim(),
      _ => '',
    };
    final plays = stat is Map ? (stat['view'] as num?)?.toInt() : (item['play'] as num?)?.toInt();
    return VodVideo(
      id: bvid,
      bvid: bvid,
      aid: (item['aid'] as num?)?.toInt(),
      title: title,
      coverUrl: _coverOf(item['pic'] ?? item['cover']),
      uploader: uploader.isEmpty ? null : uploader,
      duration: duration is num ? Duration(seconds: duration.toInt()) : _durationOf('${duration ?? ''}'),
      playCount: plays,
    );
  }

  /// A cover address with a scheme, or null when there is none.
  static String? _coverOf(Object? value) {
    final url = '${value ?? ''}'.trim();
    return url.isEmpty ? null : _https(url);
  }

  /// The `accept_quality`/`accept_description` pair as choices, best first.
  static List<VodQuality> _qualitiesOf(Map<Object?, Object?> data) {
    final qns = data['accept_quality'];
    final labels = data['accept_description'];
    if (qns is! List) return const [];
    return [
      for (var index = 0; index < qns.length; index++)
        if (qns[index] case final num qn when qn > 0)
          VodQuality(
            qn: qn.toInt(),
            label: labels is List && index < labels.length ? '${labels[index]}' : 'qn ${qn.toInt()}',
          ),
    ];
  }

  /// The served quality's label, by its qn.
  static String? _qualityLabel(List<VodQuality> qualities, int served) {
    for (final quality in qualities) {
      if (quality.qn == served) return quality.label;
    }
    return served > 0 ? '$served' : null;
  }

  /// Strips the `<em class="keyword">` markup the search highlights with.
  static String _plain(String title) => title.replaceAll(RegExp('<[^>]*>'), '').trim();

  /// The covers arrive as `//i0.hdslb.com/...` or a plain `http://` address;
  /// a player wants the secure scheme, which the same host serves.
  static String _https(String url) {
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
  }

  /// "12:34" or "1:02:03" as a duration.
  static Duration? _durationOf(String text) {
    final parts = text.split(':');
    if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) {
      return null;
    }
    var seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + int.parse(part);
    }
    return Duration(seconds: seconds);
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on Object {
      return null;
    }
  }
}
