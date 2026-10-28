// Dart port of hongguoTV's ContentRepository (kotlin-tv/core); GPL-3.0-only.
// Two first-party paths: the public website's pages (no signing, the data
// sits in the `_ROUTER_DATA` JSON and the `data-fn-*` script attributes) and
// the app's endpoints (the discovery landpage and search signed in-process;
// the playback model carried by the registered device identity alone).
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_device.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_media_crypto.dart' show HongguoMediaCrypto;
import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart' show HongguoSigner;
import 'package:pure_live/modules/hongguo/official/hongguo_vendor.dart' show HongguoVendor;

/// One playable rendition of an episode.
final class HongguoRendition {
  /// Creates the rendition.
  const HongguoRendition({
    required this.quality,
    required this.codec,
    required this.url,
    this.width,
    this.height,
    this.key,
  });

  /// The quality tier as a number (1080, 720…), 0 when unknown.
  final int quality;

  /// The codec label the model reports (`h264`, `h265`…).
  final String codec;

  /// The CDN URL — the encrypted file's, when a key is present.
  final String url;

  /// The coded width, when the model reports it.
  final int? width;

  /// The coded height, when the model reports it.
  final int? height;

  /// The derived CENC key; null when the rendition is not encrypted.
  final Uint8List? key;
}

/// The website's rank boards, the four the public pages serve.
enum HongguoWebsiteBoard {
  /// The cross-genre board.
  all('hot-drama', 'rank_hot-drama/page'),

  /// Live-action only.
  real('hot-real-drama', 'rank_hot-real-drama/page'),

  /// Comics only.
  comic('hot-comic-drama', 'rank_hot-comic-drama/page'),

  /// AI drama only.
  ai('hot-ai-drama', 'rank_hot-ai-drama/page');

  HongguoWebsiteBoard(this.route, this.loader);

  /// The board's route under `/rank/`.
  final String route;

  /// The router loader key its data sits behind.
  final String loader;
}

/// One discovery page: the shelf's series plus, on the first page, the
/// selector panel and the cursor the next page asks.
final class HongguoDiscoveryPage {
  /// Creates the page.
  const HongguoDiscoveryPage({required this.items, required this.hasMore, this.next, this.groups = const []});

  /// The page's series.
  final List<HongguoSeries> items;

  /// Whether another page follows.
  final bool hasMore;

  /// The cursor the next page asks, when one follows.
  final HongguoDiscoveryCursor? next;

  /// The selector panel, on the first page.
  final List<HongguoFilterRow> groups;
}

/// The discovery feed's continuation: the offset and the session the next
/// page carries.
final class HongguoDiscoveryCursor {
  /// Creates the cursor.
  const HongguoDiscoveryCursor({required this.offset, required this.session, required this.page});

  /// Where the next page starts.
  final int offset;

  /// The feed's session id.
  final String session;

  /// The page this cursor opens (2..100).
  final int page;
}

/// The search feed's continuation.
final class HongguoSearchCursor {
  /// Creates the cursor.
  const HongguoSearchCursor({required this.page, this.searchId = '', this.passback = '', this.offset});

  /// The page this cursor opens.
  final int page;

  /// The tab's search id.
  final String searchId;

  /// The tab's passback token.
  final String passback;

  /// The tab's own next offset, when it reports one.
  final int? offset;
}

/// The selector dimensions' Chinese labels, as the reference ships them.
const Map<String, String> kHongguoDimensionLabels = {
  'genre': '类型',
  'category_dim_theme': '主题',
  'category_dim_role': '设定',
  'category_dim_epoch': '背景',
  'sort': '推荐',
  'gender': '受众',
  'online_time': '时间',
  'creation_status': '状态',
};

const String _kSite = 'https://hongguoduanju.com';
const String _kLandpageHost = 'https://api5-normal-sinfonlineb.fqnovel.com';
const String _kSearchHost = 'https://api5-normal-sinfonlinea.fqnovel.com';
const String _kPlayerUa =
    'com.phoenix.read/71532 (Linux; U; Android 9; SM-N9860; Build/PQ3A.190705.10241111;tt-ok/3.12.13.20)';

/// The official client the station's feeds ask.
final class HongguoOfficialClient {
  /// Creates the client over [http].
  HongguoOfficialClient({required LiveHttp http})
    : _http = http,
      _signer = HongguoSigner(),
      _session = HongguoDeviceSession(http: http);

  final LiveHttp _http;
  final HongguoSigner _signer;
  final HongguoDeviceSession _session;
  final Map<String, Map<String, String>> _cookies = {};

  // ---- transport ---------------------------------------------------------

  Map<String, String> _cookieHeaderFor(Uri uri) {
    final jar = _cookies[uri.host];
    if (jar == null || jar.isEmpty) return const {};
    return {'Cookie': jar.entries.map((entry) => '${entry.key}=${entry.value}').join('; ')};
  }

  void _storeCookies(Uri uri, List<String> setCookies) {
    if (setCookies.isEmpty) return;
    final jar = _cookies.putIfAbsent(uri.host, () => {});
    for (final header in setCookies) {
      final pair = header.split(';').first.trim();
      final at = pair.indexOf('=');
      if (at <= 0) continue;
      jar[pair.substring(0, at).trim()] = pair.substring(at + 1).trim();
    }
  }

  /// Sends the request; [retry] repeats once on a transient failure (the
  /// platform's CDN soft-blocks a page now and then).
  Future<String> _text(
    Uri uri, {
    Uint8List? body,
    Map<String, String> headers = const {},
    String userAgent = HongguoVendor.videoUa,
    bool retry = false,
  }) async {
    Future<String> fetch() async {
      final response = await _http.send(
        LiveRequest.custom(
          method: body == null ? 'GET' : 'POST',
          url: uri,
          bodyBytes: body,
          contentType: body == null ? null : 'application/json; charset=utf-8',
          headers: {'User-Agent': userAgent, 'Accept-Language': 'zh-CN,zh;q=0.9', ..._cookieHeaderFor(uri), ...headers},
          timeout: const Duration(seconds: 30),
        ),
      );
      _storeCookies(uri, response.setCookies);
      if (!response.isOk) {
        throw HongguoOfficialFailure('HTTP ${response.statusCode}');
      }
      return response.text;
    }

    try {
      return await fetch();
    } on Object {
      if (!retry) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return await fetch();
    }
  }

  // ---- website pages -----------------------------------------------------

  /// The `_ROUTER_DATA` JSON embedded in a page, braces matched, strings
  /// respected.
  static Map<String, Object?> extractRouter(String html) {
    final marker = html.indexOf('_ROUTER_DATA');
    if (marker < 0) {
      throw const HongguoOfficialFailure('页面没有内容数据');
    }
    final first = html.indexOf('{', marker);
    if (first < 0) {
      throw const HongguoOfficialFailure('页面数据格式错误');
    }
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var i = first; i < html.length; i++) {
      final code = html.codeUnitAt(i);
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5C) {
          escaped = true;
        } else if (code == 0x22) {
          quoted = false;
        }
        continue;
      }
      if (code == 0x22) {
        quoted = true;
      } else if (code == 0x7B || code == 0x5B) {
        depth++;
      } else if (code == 0x7D || code == 0x5D) {
        depth--;
        if (depth == 0) {
          final decoded = jsonDecode(html.substring(first, i + 1));
          if (decoded is Map<String, Object?>) return decoded;
          throw const HongguoOfficialFailure('页面数据格式错误');
        }
      }
    }
    throw const HongguoOfficialFailure('页面数据不完整');
  }

  Map<String, Object?> _routerOf(String html) {
    final root = extractRouter(html);
    final loader = root['loaderData'];
    return loader is Map<String, Object?> ? loader : const {};
  }

  /// One board page from the public website.
  Future<({List<HongguoSeries> items, bool hasMore})> websiteRank(HongguoWebsiteBoard board, {int page = 1}) async {
    final html = await _text(Uri.parse('$_kSite/rank/${board.route}?page=$page'), retry: true);
    final payload = _rankPayload(html, board);
    if (payload['isSuccess'] != true) {
      throw const HongguoOfficialFailure('剧集榜单暂不可用');
    }
    final rows = payload['rankList'];
    if (rows is! List<Object?>) {
      throw const HongguoOfficialFailure('剧集榜单格式已变化');
    }
    final pagination = payload['pagination'];
    final totalPages = pagination is Map<String, Object?> ? (pagination['totalPages'] as num?)?.toInt() ?? 0 : 0;
    if (totalPages < 1) {
      throw const HongguoOfficialFailure('剧集分页信息缺失');
    }
    final items = <HongguoSeries>[];
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final series = _seriesFromRank(row);
      if (series != null) items.add(series);
    }
    return (items: items, hasMore: items.isNotEmpty && page < totalPages && page < 100);
  }

  /// The rank payload behind the page's `data-fn-*` script attributes —
  /// read as data only, never executed.
  static Map<String, Object?> _rankPayload(String html, HongguoWebsiteBoard board) {
    final tagPattern = RegExp(r'<script\b[^>]*>');
    for (final match in tagPattern.allMatches(html)) {
      final tag = match.group(0)!;
      final name = RegExp('data-fn-name="([^"]*)"').firstMatch(tag)?.group(1);
      if (name != 'r' && name != 'mergeLoaderData') continue;
      final argsRaw = RegExp('data-fn-args="([^"]*)"').firstMatch(tag)?.group(1);
      if (argsRaw == null) continue;
      final args = jsonDecode(_unescapeAttribute(argsRaw));
      if (args is! List<Object?> || args.isEmpty || args[0] != board.loader) continue;
      Object? raw;
      if (name == 'r' && args.length > 2 && args[1] == 'content') {
        raw = args[2];
      } else if (name == 'mergeLoaderData' && args.length > 1 && args[1] is List<Object?>) {
        for (final entry in args[1]! as List<Object?>) {
          if (entry is Map<String, Object?> &&
              entry['key'] == 'content' &&
              entry['routerDataFnName'] == 'p' &&
              entry['routerDataFnArgs'] is List<Object?>) {
            final fnArgs = entry['routerDataFnArgs']! as List<Object?>;
            if (fnArgs.isNotEmpty) raw = fnArgs[0];
          }
        }
      }
      if (raw is Map<String, Object?>) return raw;
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, Object?>) return decoded;
      }
    }
    throw const HongguoOfficialFailure('剧集榜单暂不可用');
  }

  static String _unescapeAttribute(String value) => value
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  /// One series' detail and its episode vid list, from the public page.
  Future<HongguoSeriesDetail> detail(String seriesId) async {
    final html = await _text(Uri.parse('$_kSite/detail?series_id=$seriesId'));
    final detailPage = _routerOf(html)['detail_page'];
    final raw = detailPage is Map<String, Object?> ? detailPage['seriesDetail'] : null;
    if (raw is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('剧集详情暂不可用');
    }
    final vidList = raw['vid_list'];
    if (vidList is! List<Object?> || vidList.isEmpty) {
      throw const HongguoOfficialFailure('分集暂不可用');
    }
    final vids = [for (final vid in vidList) vid.toString()];
    if (vids.any((vid) => !RegExp(r'^[0-9]{1,30}$').hasMatch(vid))) {
      throw const HongguoOfficialFailure('分集数据异常');
    }
    final meta = HongguoSeriesMeta(
      seriesId: seriesId,
      title: _str(raw, 'series_name'),
      intro: _str(raw, 'series_intro'),
      episodeCount: vids.length,
      statusText: _str(raw, 'episode_right_text'),
      cover: _cleanUrl(_str(raw, 'series_cover')),
      categories: _tagNames(raw),
    );
    return HongguoSeriesDetail(
      meta: meta,
      episodes: [for (var i = 0; i < vids.length; i++) HongguoEpisode(index: i + 1, vid: vids[i])],
    );
  }

  /// The website's cross-category search page.
  Future<({List<HongguoSeries> items, bool hasMore})> websiteSearch(String keyword, {int page = 1}) async {
    final raw = await _text(
      Uri.parse('$_kSite/api/search/result?query=${Uri.encodeQueryComponent(keyword)}&page=$page'),
      userAgent: HongguoVendor.appUa,
      retry: true,
    );
    final section = jsonDecode(raw);
    if (section is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('搜索响应格式已变化');
    }
    final pageNum = section['pageNum'];
    if (pageNum is num && pageNum.toInt() != page) {
      throw const HongguoOfficialFailure('搜索页码不匹配');
    }
    final rows = section['searchList'];
    if (rows is! List<Object?>) {
      throw const HongguoOfficialFailure('搜索数据结构已变化');
    }
    final items = <HongguoSeries>[];
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final series = _seriesFromCard(row);
      if (series != null) items.add(series);
    }
    final totalPages = (section['totalPages'] as num?)?.toInt() ?? 0;
    final more = section['hasMore'] == true || (totalPages > 0 && page < totalPages);
    return (items: items, hasMore: items.isNotEmpty && page < 100 && more);
  }

  // ---- signed app endpoints ----------------------------------------------

  /// The discovery landpage: one shelf under a selection, paged by cursor.
  Future<HongguoDiscoveryPage> discovery({
    Map<String, String> selection = const {},
    HongguoDiscoveryCursor? cursor,
  }) async {
    final values = {
      ...HongguoVendor.device,
      'version_code': '73532',
      'manifest_version_code': '73532',
      'update_version_code': '73532',
      'pv_player': '73532',
      'version_name': '7.3.5.32',
    };
    final selected = <String, Object?>{};
    for (final type in kHongguoDimensionLabels.keys) {
      final chosen = selection[type];
      selected[type] = chosen == null ? <Object?>[] : <Object?>[chosen];
    }
    final scene = selection['genre'] == 'comic_series' || selection['genre'] == 'ai_series'
        ? selection['genre']!
        : 'default';
    final body = utf8.encode(
      jsonEncode({
        'offset': cursor?.offset ?? 0,
        'limit': 24,
        'need_selector_panel': cursor == null,
        'select_items': selected,
        'session_id': cursor?.session ?? '',
        'req_type': cursor == null ? 'default' : 'only_content',
        'client_req_type': 3,
        'filter_ids': '',
        'req_scene': scene,
      }),
    );
    final signed = _signer.sign(
      '$_kLandpageHost/reading/distribution/category/landpage/v/',
      values,
      body: Uint8List.fromList(body),
    );
    final raw = await _text(Uri.parse(signed.url), body: signed.body, headers: signed.headers, retry: true);
    final root = jsonDecode(raw);
    if (root is! Map<String, Object?> || (root['code'] is num ? (root['code']! as num).toInt() : -1) != 0) {
      throw const HongguoOfficialFailure('分类服务暂不可用');
    }
    final data = root['data'];
    if (data is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('分类数据缺失');
    }
    final rows = data['video_data'];
    if (rows is! List<Object?>) {
      throw const HongguoOfficialFailure('分类剧集列表缺失');
    }
    final items = <HongguoSeries>[];
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final id = _str(row, 'series_id');
      final title = _str(row, 'title');
      if (!RegExp(r'^[0-9]{1,30}$').hasMatch(id) || title.isEmpty) continue;
      items.add(
        HongguoSeries(
          seriesId: id,
          title: title,
          episodeCount: (row['episode_cnt'] as num?)?.toInt() ?? 0,
          cover: _cleanUrl(_str(row, 'cover')),
          intro: _str(row, 'video_desc'),
          category: _schemaTags(row['category_schema']),
        ),
      );
    }
    if (rows.isNotEmpty && items.isEmpty) {
      throw const HongguoOfficialFailure('分类剧集格式异常');
    }
    var groups = const <HongguoFilterRow>[];
    final selectorRows = data['selector_rows'];
    if (cursor == null && selectorRows is List<Object?>) {
      final parsed = <HongguoFilterRow>[];
      for (final row in selectorRows) {
        if (row is! Map<String, Object?>) continue;
        final type = _str(row, 'type');
        final label = kHongguoDimensionLabels[type];
        if (label == null) continue;
        final options = <HongguoFilterOption>[];
        final rawItems = row['items'];
        if (rawItems is List<Object?>) {
          for (final item in rawItems) {
            if (item is! Map<String, Object?>) continue;
            final id = _str(item, 'selector_item_id');
            final name = _str(item, 'show_name');
            if (RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) && name.isNotEmpty && name.length <= 40) {
              options.add(HongguoFilterOption(id: id, name: name));
            }
          }
        }
        parsed.add(HongguoFilterRow(type: type, rowName: label, items: options));
      }
      groups = parsed;
      if (groups.every((group) => group.type != 'genre')) {
        throw const HongguoOfficialFailure('分类筛选条件缺失');
      }
    }
    final page = cursor?.page ?? 1;
    final more = data['has_more'] == true && page < 100;
    HongguoDiscoveryCursor? next;
    if (more) {
      final offset = (data['next_offset'] as num?)?.toInt() ?? -1;
      final session = _str(data, 'session_id').isNotEmpty ? _str(data, 'session_id') : cursor?.session ?? '';
      if (offset <= (cursor?.offset ?? 0) || session.isEmpty) {
        throw const HongguoOfficialFailure('分类续页信息异常');
      }
      next = HongguoDiscoveryCursor(offset: offset, session: session, page: page + 1);
    }
    return HongguoDiscoveryPage(items: items, hasMore: more, next: next, groups: groups);
  }

  /// The app's own search: richer than the website's, but the tab's cursor
  /// must be carried between pages.
  Future<({List<HongguoSeries> items, bool hasMore, HongguoSearchCursor? next})> appSearch(
    String keyword, {
    HongguoSearchCursor? cursor,
  }) async {
    final page = cursor?.page ?? 1;
    final values = {
      ...HongguoVendor.device,
      'version_code': '72232',
      'manifest_version_code': '72232',
      'update_version_code': '72232',
      'pv_player': '72232',
      'version_name': '7.2.2.32',
      'query': keyword,
      'count': '20',
      'offset': '${(page - 1) * 20}',
      'tab_type': '11',
      'bookshelf_search_plan': '4',
      'use_correct': 'true',
      'user_is_login': '0',
    };
    final searchId = cursor?.searchId ?? '';
    final passback = cursor?.passback ?? '';
    if (searchId.isNotEmpty) values['search_id'] = searchId;
    if (passback.isNotEmpty) values['passback'] = passback;
    final offsetOverride = cursor?.offset;
    if (offsetOverride != null && offsetOverride >= 0) values['offset'] = '$offsetOverride';
    final signed = _signer.sign('$_kSearchHost/reading/bookapi/search/tab/v', values);
    final raw = await _text(Uri.parse(signed.url), headers: signed.headers, userAgent: HongguoVendor.appUa);
    final data = jsonDecode(raw);
    if (data is! Map<String, Object?> || (data['code'] is num ? (data['code']! as num).toInt() : -1) != 0) {
      throw const HongguoOfficialFailure('搜索接口暂不可用');
    }
    final tabsValue =
        data['search_tabs'] ??
        (data['data'] is Map<String, Object?> ? (data['data']! as Map<String, Object?>)['search_tabs'] : null);
    final tabs = tabsValue is List<Object?> ? tabsValue : null;
    if (tabs == null) {
      throw const HongguoOfficialFailure('搜索格式异常');
    }
    Map<String, Object?>? tab;
    for (final row in tabs) {
      if (row is Map<String, Object?> && (row['tab_type'] as num?)?.toInt() == 11) tab = row;
    }
    if (tab == null) {
      throw const HongguoOfficialFailure('短剧搜索暂不可用');
    }
    final items = <HongguoSeries>[];
    final cells = tab['data'];
    if (cells is List<Object?>) {
      for (final cell in cells) {
        if (cell is! Map<String, Object?>) continue;
        final videoRows = cell['video_data'];
        final video = videoRows is List<Object?> && videoRows.isNotEmpty && videoRows[0] is Map<String, Object?>
            ? videoRows[0]! as Map<String, Object?>
            : null;
        if (video == null) continue;
        final id = _str(video, 'series_id').isNotEmpty
            ? _str(video, 'series_id')
            : _str(cell, 'book_id').isNotEmpty
            ? _str(cell, 'book_id')
            : _str(cell, 'search_result_id');
        final highlight = cell['search_high_light'];
        final title = highlight is Map<String, Object?> && highlight['title'] is Map<String, Object?>
            ? _str(highlight['title']! as Map<String, Object?>, 'text')
            : '';
        final count = (video['episode_cnt'] as num?)?.toInt() ?? 0;
        if (!RegExp(r'^[0-9]{1,30}$').hasMatch(id)) continue;
        items.add(
          HongguoSeries(
            seriesId: id,
            title: title.isNotEmpty ? _stripTags(title) : _str(video, 'title'),
            episodeCount: count,
            cover: _cleanUrl(_str(video, 'cover').isNotEmpty ? _str(video, 'cover') : _str(video, 'cover_url')),
            intro: _str(video, 'video_desc'),
            hot: _str(video, 'rec_text'),
            category: _str(video, 'sub_title'),
          ),
        );
      }
    }
    final hasMore = tab['has_more'] == true && page < 100;
    final nextOffset = (tab['next_offset'] as num?)?.toInt();
    final next = hasMore
        ? HongguoSearchCursor(
            page: page + 1,
            searchId: _str(tab, 'search_id'),
            passback: _str(tab, 'passback'),
            offset: nextOffset,
          )
        : null;
    return (items: items, hasMore: hasMore, next: next);
  }

  // ---- playback ----------------------------------------------------------

  /// Forgets the playback identity, so the next ladder asks registers a
  /// fresh anonymous device.
  Future<void> resetDevice() => _session.reset();

  /// Every playable rendition of one episode, best tier last. The model
  /// endpoint needs no signature — the registered device identity is the
  /// ticket.
  Future<List<HongguoRendition>> playbackLadder(String vid) async {
    if (!RegExp(r'^[0-9]{1,30}$').hasMatch(vid)) {
      throw const HongguoOfficialFailure('分集编号异常');
    }
    final identity = await _session.profile();
    final body = utf8.encode(
      '{"biz_param":{"detail_page_version":0,"device_level":3,"disable_digg_stat":false,'
      '"need_all_video_definition":true,"need_mp4_align":false,"use_os_player":false,'
      '"use_server_dns":false,"video_platform":1024},"mixed_video_id_map":{"1004":["$vid"]}}',
    );
    final query = HongguoSigner.encodeValues({
      ...identity.values,
      '_rticket': '${DateTime.now().millisecondsSinceEpoch}',
    });
    final url = '$_kLandpageHost/novel/player/multi_video_model/v1/?$query';
    final headers = <String, String>{
      'User-Agent': _kPlayerUa,
      'Accept': 'application/json; charset=utf-8,application/x-protobuf',
      if (identity.cookie.isNotEmpty) 'Cookie': identity.cookie,
    };
    var raw = await _text(Uri.parse(url), body: Uint8List.fromList(body), headers: headers, retry: true);
    if (raw.trim().isEmpty) {
      // An empty answer is transient; a fresh ticket only, no new identity.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final retryQuery = HongguoSigner.encodeValues({
        ...identity.values,
        '_rticket': '${DateTime.now().millisecondsSinceEpoch}',
      });
      raw = await _text(
        Uri.parse('$_kLandpageHost/novel/player/multi_video_model/v1/?$retryQuery'),
        body: Uint8List.fromList(body),
        headers: headers,
      );
    }
    final data = jsonDecode(raw);
    if (data is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('播放信息为空');
    }
    final code = (data['Code'] as num?)?.toInt() ?? (data['code'] as num?)?.toInt() ?? 0;
    if (code != 0) {
      throw HongguoOfficialFailure('播放接口暂不可用（错误码 $code）');
    }
    final map = data['data'];
    if (map is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('播放信息为空');
    }
    Map<String, Object?>? entry;
    final named = map[vid];
    if (named is Map<String, Object?>) {
      entry = named;
    } else {
      for (final value in map.values) {
        if (value is Map<String, Object?>) {
          entry = value;
          break;
        }
      }
    }
    if (entry == null) {
      throw const HongguoOfficialFailure('播放信息为空');
    }
    final rawModel = entry['video_model'];
    final model = rawModel is Map<String, Object?>
        ? rawModel
        : rawModel is String && rawModel.isNotEmpty
        ? jsonDecode(rawModel)
        : null;
    if (model is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('播放模型为空');
    }
    final inline = <HongguoRendition>[];
    final videoList = model['video_list'];
    if (videoList is List<Object?>) {
      for (final row in videoList) {
        if (row is! Map<String, Object?>) continue;
        final meta = row['video_meta'];
        final encryption = row['encrypt_info'];
        if (meta is! Map<String, Object?> || encryption is! Map<String, Object?>) continue;
        final codec = _str(meta, 'codec_type').toLowerCase();
        final url = _cleanUrl(_str(row, 'main_url'));
        if (codec.isEmpty || codec == 'bytevc2' || codec == 'bvc2' || !url.startsWith('http')) continue;
        final width = (meta['vwidth'] as num?)?.toInt() ?? (meta['width'] as num?)?.toInt();
        final height = (meta['vheight'] as num?)?.toInt() ?? (meta['height'] as num?)?.toInt();
        final spade = _str(encryption, 'spade_a');
        Uint8List? key;
        if (spade.isNotEmpty) {
          try {
            key = HongguoMediaCrypto.deriveKey(spade);
          } on Object {
            continue;
          }
        }
        final encrypted = encryption['encrypt'];
        if (key == null && encrypted != false && encrypted != 0 && encrypted != '0' && encrypted != 'false') {
          continue;
        }
        inline.add(
          HongguoRendition(
            quality: _qualityNumber(_str(meta, 'definition')),
            codec: codec,
            width: width == null || width <= 0 ? null : width,
            height: height == null || height <= 0 ? null : height,
            url: url,
            key: key,
          ),
        );
      }
    }
    if (inline.isNotEmpty) return inline..sort((a, b) => a.quality.compareTo(b.quality));
    // The legacy fallback: an envelope URL decrypted with the key seed.
    final rawFallback = model['fallback_api'];
    final fallback = rawFallback is Map<String, Object?>
        ? _str(rawFallback, 'fallback_api')
        : rawFallback is List<Object?> && rawFallback.isNotEmpty && rawFallback[0] is String
        ? rawFallback[0]! as String
        : rawFallback is String
        ? rawFallback
        : '';
    if (!fallback.startsWith('https://')) {
      throw const HongguoOfficialFailure('播放地址格式异常');
    }
    final infoRaw = await _text(Uri.parse(fallback));
    final infoJson = jsonDecode(infoRaw);
    final info = infoJson is Map<String, Object?> && infoJson['video_info'] is Map<String, Object?>
        ? (infoJson['video_info']! as Map<String, Object?>)['data']
        : null;
    if (info is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('没有播放资源');
    }
    final videoMap = info['video_list'];
    if (videoMap is! Map<String, Object?>) {
      throw const HongguoOfficialFailure('没有可用清晰度');
    }
    final seedRaw = _str(info, 'key_seed');
    final renditions = <HongguoRendition>[];
    for (final entry in videoMap.entries) {
      final row = entry.value;
      if (row is! Map<String, Object?>) continue;
      final codec = _str(row, 'codec_type').toLowerCase();
      if (codec == 'bytevc2' || codec == 'bvc2') continue;
      var url = _cleanUrl(_str(row, 'main_url'));
      try {
        if (seedRaw.isNotEmpty) {
          url = HongguoMediaCrypto.decryptUrl(url, Uint8List.fromList(_hexBytes(seedRaw)));
        }
      } on Object {
        continue;
      }
      if (!url.startsWith('http')) continue;
      final qualityText = _str(row, 'quality_desc').isNotEmpty
          ? _str(row, 'quality_desc')
          : _str(row, 'height').isNotEmpty
          ? _str(row, 'height')
          : entry.key;
      final spade = _str(row, 'spade_a');
      renditions.add(
        HongguoRendition(
          quality: _qualityNumber(qualityText),
          codec: codec,
          width: (row['vwidth'] as num?)?.toInt(),
          height: (row['vheight'] as num?)?.toInt(),
          url: url,
          key: spade.isEmpty ? null : HongguoMediaCrypto.deriveKey(spade),
        ),
      );
    }
    if (renditions.isEmpty) {
      throw const HongguoOfficialFailure('没有可播放的清晰度');
    }
    return renditions..sort((a, b) => a.quality.compareTo(b.quality));
  }
}

/// The official client's failure, safe to show as sent.
final class HongguoOfficialFailure implements Exception {
  /// Creates the failure.
  const HongguoOfficialFailure(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}

// ---- small parsing helpers ---------------------------------------------

String _str(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num) return value.toInt() == value ? value.toInt().toString() : value.toString();
  return value.toString();
}

String _cleanUrl(String value) => value
    .replaceAll(r'\/', '/')
    .replaceAll(r'\u002F', '/')
    .replaceAll(r'\u002f', '/')
    .replaceAll(r'\u0026', '&')
    .replaceAll('&amp;', '&');

String _stripTags(String value) => value.replaceAll(RegExp('<[^>]+>'), '');

List<String> _tagNames(Map<String, Object?> json) {
  final tags = json['tags'] ?? json['category_list'];
  if (tags is! List<Object?>) return const [];
  return [
    for (final tag in tags.take(5))
      if (tag is Map<String, Object?>) _str(tag, 'name') else if (tag is String && tag.trim().isNotEmpty) tag.trim(),
  ];
}

String _schemaTags(Object? schema) {
  if (schema is! String || schema.isEmpty) return '';
  try {
    final decoded = jsonDecode(schema);
    if (decoded is! List<Object?>) return '';
    final names = [
      for (final entry in decoded.take(8))
        if (entry is Map<String, Object?>) _str(entry, 'name'),
    ].where((name) => name.isNotEmpty).toList();
    return names.join(' / ');
  } on Object {
    return '';
  }
}

HongguoSeries? _seriesFromCard(Map<String, Object?> item) {
  final o = item['video_data'] is Map<String, Object?> ? item['video_data']! as Map<String, Object?> : item;
  final id = _str(o, 'series_id');
  var title = _str(o, 'series_name');
  if (title.isEmpty) title = _str(o, 'series_title');
  if (title.isEmpty) title = _str(item, 'name');
  if (!RegExp(r'^[0-9]{1,30}$').hasMatch(id) || title.isEmpty) return null;
  return HongguoSeries(
    seriesId: id,
    title: title,
    episodeCount: (o['episode_cnt'] as num?)?.toInt() ?? 0,
    cover: _cleanUrl(_str(o, 'series_cover')),
    intro: _str(o, 'series_intro'),
    hot: _str(o, 'episode_right_text'),
    category: _tagNames(o).join(' / '),
  );
}

HongguoSeries? _seriesFromRank(Map<String, Object?> row) {
  final id = _str(row, 'seriesId').isNotEmpty ? _str(row, 'seriesId') : _str(row, 'id');
  final title = _str(row, 'title');
  if (!RegExp(r'^[0-9]{1,30}$').hasMatch(id) || title.isEmpty) return null;
  final episodeVids = row['episodeVids'];
  final count = (row['episodeCount'] as num?)?.toInt() ?? (episodeVids is List<Object?> ? episodeVids.length : 0);
  final tags = row['tags'];
  return HongguoSeries(
    seriesId: id,
    title: title,
    episodeCount: count,
    cover: _cleanUrl(_str(row, 'cover')),
    intro: _str(row, 'description'),
    hot: _str(row, 'heatText'),
    score: _str(row, 'scoreText'),
    rank: (row['rank'] as num?)?.toInt(),
    category: tags is List<Object?> ? [for (final tag in tags.take(5)) tag.toString()].join(' / ') : '',
  );
}

int _qualityNumber(String value) {
  final match = RegExp('2160|1440|1080|720|576|540|480|360').firstMatch(value);
  if (match != null) return int.parse(match.group(0)!);
  return const {'1920': 1080, '1280': 720, '1024': 576, '854': 480, '640': 360}[value] ?? int.tryParse(value) ?? 0;
}

List<int> _hexBytes(String value) => [
  for (var i = 0; i + 1 < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16),
];
