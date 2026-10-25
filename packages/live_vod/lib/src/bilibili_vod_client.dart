import 'dart:convert' show jsonDecode;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse;

/// One video a platform's search returned.
final class VodVideo {
  /// A video hit.
  const new({
    required this.id,
    required this.title,
    this.coverUrl,
    this.uploader,
    this.duration,
    this.playCount,
    this.bvid,
    this.aid,
  });

  /// The source's own id (the bvid on Bilibili).
  final String id;

  /// The video's title, with the search's highlight markup stripped.
  final String title;

  /// The cover address; null when the source gave none.
  final String? coverUrl;

  /// The uploader's name.
  final String? uploader;

  /// The length.
  final Duration? duration;

  /// How many times it was played.
  final int? playCount;

  /// The bvid, for a source that separates ids.
  final String? bvid;

  /// The numeric aid, for a source that separates ids.
  final int? aid;
}

/// One quality a play answer offers.
final class VodQuality {
  /// A quality choice.
  const new({required this.qn, required this.label});

  /// The source's numeric quality id (Bilibili's `qn`).
  final int qn;

  /// The source's own name for it ("1080P 高清").
  final String label;
}

/// One part of a multi-part archive ("P1", "P2").
final class VodPart {
  /// A part.
  const new({required this.cid, required this.page, required this.title, this.duration});

  /// The part's cid, which play addresses are requested for.
  final int cid;

  /// Its 1-based position.
  final int page;

  /// Its own title.
  final String title;

  /// Its length, when the source gave one.
  final Duration? duration;
}

/// A playable address and what it expects.
final class VodPlayInfo {
  /// A play address.
  const new({
    required this.url,
    this.headers = const {},
    this.expiresAt,
    this.format = 'mp4',
    this.quality,
    this.qualities = const [],
    this.servedQuality,
    this.silent = false,
  });

  /// The address handed to the player.
  final String url;

  /// Headers a CDN requires (a referer, a user agent).
  final Map<String, String> headers;

  /// When the address stops working; null keeps it indefinitely.
  final DateTime? expiresAt;

  /// The container, as the player wants it named (`mp4`, `m4s`, `hls`).
  final String format;

  /// The source's own label for the quality, when it named one.
  final String? quality;

  /// The qualities the source will serve for this part, best first.
  final List<VodQuality> qualities;

  /// The qn the source actually served.
  final int? servedQuality;

  /// Whether the answer carries picture only — a DASH fallback without the
  /// audio track (the player says so instead of pretending it has sound).
  final bool silent;
}

/// A feed page: the videos it carried and whether another page follows.
final class VodVideoPage {
  /// A page of a browse feed.
  const new({required this.videos, this.hasMore = false});

  /// The videos, in the source's order.
  final List<VodVideo> videos;

  /// Whether the source says another page follows.
  final bool hasMore;
}

/// One archive's full detail: the `view` answer's metadata and its parts.
final class VodDetail {
  /// A detail record.
  const new({
    required this.bvid,
    required this.aid,
    required this.title,
    this.coverUrl,
    this.description = '',
    this.uploader,
    this.uploaderMid,
    this.uploaderAvatar,
    this.playCount,
    this.danmakuCount,
    this.likeCount,
    this.coinCount,
    this.favoriteCount,
    this.duration,
    this.parts = const [],
    this.publishedAt,
  });

  /// The archive's bvid.
  final String bvid;

  /// The archive's numeric aid.
  final int aid;

  /// The title.
  final String title;

  /// The cover.
  final String? coverUrl;

  /// The uploader's description, plain text.
  final String description;

  /// The uploader's name.
  final String? uploader;

  /// The uploader's numeric id.
  final int? uploaderMid;

  /// The uploader's avatar.
  final String? uploaderAvatar;

  /// How many times the archive was played.
  final int? playCount;

  /// How many danmaku it holds.
  final int? danmakuCount;

  /// How many likes it received.
  final int? likeCount;

  /// How many coins it received.
  final int? coinCount;

  /// How many favourites it received.
  final int? favoriteCount;

  /// The whole archive's length, when the source gave one.
  final Duration? duration;

  /// The parts, in order.
  final List<VodPart> parts;

  /// When it was published.
  final DateTime? publishedAt;
}

/// The failure a VOD source reports.
final class VodFailure implements Exception {
  /// A failure with the source's [message].
  const new(this.message, {this.statusCode});

  /// What the source said.
  final String message;

  /// The HTTP status, when the failure came with one.
  final int? statusCode;

  @override
  String toString() => 'VodFailure($message)';
}

/// The result of a search: the hits and whether another page exists.
final class VodSearchPage {
  /// A page of hits.
  const new({required this.videos, this.hasMore = false});

  /// The hits, in the source's order.
  final List<VodVideo> videos;

  /// Whether the source says another page follows.
  final bool hasMore;
}

/// The Bilibili video source: search, the page list that names the first
/// part's cid, and the progressive play address.
///
/// The client speaks only [LiveHttp] and JSON, so the transport (proxies,
/// retries, cookies) stays the app's business. The address it resolves is the
/// progressive mp4 (`fnval=1`): it carries its audio with the picture, which
/// is what a single-surface player needs — the DASH streams would need the
/// audio and the video muxed separately, and that seam does not exist yet.
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

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  /// The headers every Bilibili web endpoint wants.
  Map<String, String> get _headers => {
    'user-agent': userAgent,
    'referer': 'https://www.bilibili.com',
    if (cookie.isNotEmpty) 'cookie': cookie,
  };

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
    final qualities = _qualitiesOf(data);
    final served = (data['quality'] as num?)?.toInt() ?? qn;
    final label = _qualityLabel(qualities, served);
    final durl = data['durl'];
    final firstPart = durl is List && durl.isNotEmpty ? durl.first : null;
    final address = firstPart is Map ? firstPart['url'] : null;
    if (address is String && address.isNotEmpty) {
      return VodPlayInfo(url: address, headers: _headers, quality: label, qualities: qualities, servedQuality: served);
    }
    // A login-gated video (1080p and above) answers only DASH streams.
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

  /// Resolves the audio-only address of [video]'s first part — 音乐模式 plays
  /// the sound and never needs the picture, so the DASH audio stream is the
  /// right answer here where the video page needed the muxed mp4.
  Future<VodPlayInfo> audio(VodVideo video) async {
    final address = await _firstCid(video);
    final play = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/player/playurl', {
          'bvid': video.bvid ?? video.id,
          'cid': address,
          'fnval': '16',
          'fourk': '1',
        }),
        headers: _headers,
      ),
    );
    final data = _body(play)['data'];
    final dash = data is Map ? data['dash'] : null;
    final audios = dash is Map ? (dash['audio'] as List<Object?>?) ?? const <Object?>[] : const <Object?>[];
    final first = audios.isEmpty ? null : audios.first;
    final url = first is Map ? first['baseUrl'] : null;
    if (url is! String || url.isEmpty) {
      throw const VodFailure('the video offered no audio stream');
    }
    return VodPlayInfo(url: url, headers: _headers, format: 'm4s', quality: 'audio');
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
