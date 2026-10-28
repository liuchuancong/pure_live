// Dart port of hongguoTV's RecommendationFeed (kotlin-tv/core);
// GPL-3.0-only. The official app feed behind 首页 — the bookmall tab in its
// default shape, the landpage's content-only form when a genre is chosen —
// with the session cursor and the seen-filter in memory only.
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;

import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoCredentials;
import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart' show HongguoSigner;

const String _kFeedHost = 'https://api5-normal-sinfonlinea.fqnovel.com';

/// One home feed session: the cursor and the seen-filter live here, in
/// memory only. One instance per genre; a fresh one starts a fresh session.
final class HongguoHomeFeed {
  /// Creates the feed; [_account] personalizes it when signed in.
  HongguoHomeFeed({required this._http, this._account});

  final LiveHttp _http;
  final HongguoCredentials? _account;
  final Set<String> _seen = {};
  String _session = '';
  int _offset = 0;

  /// One more batch of recommendations. [genre] picks the shelf's own feed
  /// (短剧/漫剧); null asks the cross-genre bookmall tab.
  Future<List<HongguoSeries>> page(HongguoGenre? genre) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final params = {
        'aid': '8662',
        'app_name': 'novelread',
        'channel': 'update_64',
        'device_platform': 'android',
        'os': 'android',
        'ssmix': 'a',
        'device_type': '25053RT47C',
        'device_brand': 'Redmi',
        'language': 'zh',
        'os_api': '36',
        'os_version': '16',
        'resolution': '1280*2772',
        'dpi': '520',
        'ac': 'wifi',
        'version_code': '73532',
        'version_name': '7.3.5.32',
        'manifest_version_code': '73532',
        'update_version_code': '73532',
        'tab_type': '16',
        'bottom_tab_type': '7',
        'landing_bottom_tab_type': '7',
        'offset': '$_offset',
        'client_req_type': _offset == 0 ? '1' : '2',
        '_rticket': '${DateTime.now().millisecondsSinceEpoch}',
        if (_session.isNotEmpty) 'session_id': _session,
      };
      final account = _account;
      if (account != null) {
        params.remove('channel');
        for (final entry in account.device.entries) {
          if (const [
            'channel',
            'device_platform',
            'os',
            'ssmix',
            'device_type',
            'device_brand',
            'language',
            'os_api',
            'os_version',
            'resolution',
            'dpi',
            'ac',
          ].contains(entry.key)) {
            params[entry.key] = entry.value;
          }
        }
        if (account.deviceId.isNotEmpty) params['device_id'] = account.deviceId;
        if (account.installId.isNotEmpty) params['iid'] = account.installId;
      }
      final HongguoSignedRequestLike request;
      if (genre == null) {
        request = (
          url: Uri.parse('$_kFeedHost/reading/bookapi/bookmall/tab/v1/').replace(queryParameters: params),
          headers: const <String, String>{},
          body: null,
        );
      } else {
        final selector = {
          'genre': [genre.wire],
          for (final key in [
            'sort',
            'gender',
            'category_dim_theme',
            'category_dim_role',
            'category_dim_epoch',
            'online_time',
            'creation_status',
          ])
            key: <String>[],
        };
        final body = utf8.encode(
          jsonEncode({
            'req_scene': genre == HongguoGenre.comicSeries ? 'comic_series' : 'default',
            'offset': _offset,
            'limit': 24,
            'req_type': 'only_content',
            'need_selector_panel': false,
            'client_req_type': _offset == 0 ? 3 : 2,
            'session_id': _session,
            'filter_ids': _seen.join(','),
            'select_items': selector,
          }),
        );
        final query = {
          for (final entry in params.entries)
            if (!const [
              'tab_type',
              'bottom_tab_type',
              'landing_bottom_tab_type',
              'offset',
              'client_req_type',
              'session_id',
            ].contains(entry.key))
              entry.key: entry.value,
        };
        // The signer carries the same device the query does: the platform
        // reads the identity out of `x-medusa` and rejects the two halves
        // disagreeing.
        final signed = HongguoSigner(device: query).sign(
          '$_kFeedHost/reading/distribution/category/landpage/v/',
          query,
          body: Uint8List.fromList(body),
        );
        request = (url: Uri.parse(signed.url), headers: signed.headers, body: Uint8List.fromList(body));
      }
      final response = await _http.send(
        LiveRequest.custom(
          method: request.body == null ? 'GET' : 'POST',
          url: request.url,
          bodyBytes: request.body,
          contentType: request.body == null ? null : 'application/json; charset=utf-8',
          headers: {
            'User-Agent': 'com.dragon.read/73532 (Linux; U; Android 16; zh_CN; 25053RT47C)',
            'Accept': 'application/json',
            'X-XS-From-Web': '0',
            'Sdk-Version': '2',
            ...request.headers,
            if (account != null && account.cookie.isNotEmpty) 'Cookie': account.cookie,
          },
          timeout: const Duration(seconds: 30),
        ),
      );
      if (!response.isOk) {
        throw HongguoHomeFeedFailure('推荐请求失败（HTTP ${response.statusCode}）');
      }
      final text = response.text;
      if (text.trim().isEmpty) {
        throw const HongguoHomeFeedFailure('推荐接口返回空响应，请稍后重试');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) {
        throw const HongguoHomeFeedFailure('推荐数据格式已变化');
      }
      final code = decoded['code'] is num ? (decoded['code']! as num).toInt() : -1;
      if (code != 0) {
        throw HongguoHomeFeedFailure('推荐暂不可用（错误码 $code），请稍后刷新');
      }
      final data = decoded['data'];
      if (data is! Map<String, Object?>) {
        throw const HongguoHomeFeedFailure('推荐数据格式已变化');
      }
      final parsed = genre == null ? _parseMall(data) : _parseCategory(data);
      _session = parsed.session.isNotEmpty ? parsed.session : _session;
      _offset = genre == null ? _offset + 1 : ((data['next_offset'] as num?)?.toInt() ?? _offset + parsed.items.length);
      _seen.addAll(parsed.allIds);
      while (_seen.length > 540) {
        _seen.remove(_seen.first);
      }
      if (parsed.items.isNotEmpty) return parsed.items;
      // A duplicate-only batch is not a failure; the next call may still
      // answer fresh cards, and three in a row give up below.
    }
    throw const HongguoHomeFeedFailure('暂时没有新的推荐，请稍后换一批');
  }

  ({List<HongguoSeries> items, List<String> allIds, String session}) _parseMall(Map<String, Object?> data) {
    final tabs = data['tab_item'];
    if (tabs is! List<Object?>) {
      throw const HongguoHomeFeedFailure('推荐数据格式已变化');
    }
    Map<String, Object?>? tab;
    for (final row in tabs) {
      if (row is Map<String, Object?> && _str(row, 'tab_type') == '16') tab = row;
    }
    if (tab == null) {
      throw const HongguoHomeFeedFailure('推荐数据格式已变化');
    }
    final session = _str(tab, 'session_id');
    if (session.length > 4096 || RegExp(r'[\r\n\x00]').hasMatch(session)) {
      throw const HongguoHomeFeedFailure('推荐分页标记无效');
    }
    final rows = <Map<String, Object?>>[];
    final cells = tab['cell_data'];
    if (cells is List<Object?>) {
      for (final cell in cells) {
        if (cell is! Map<String, Object?>) continue;
        final cards = cell['cell_data'];
        if (cards is! List<Object?>) continue;
        for (final card in cards) {
          if (card is! Map<String, Object?>) continue;
          final videos = card['video_data'];
          if (videos is! List<Object?>) continue;
          for (final video in videos) {
            if (video is Map<String, Object?>) {
              rows.add(video['video_detail'] is Map<String, Object?> ? video['video_detail']! as Map<String, Object?> : video);
            }
          }
        }
      }
    }
    return _rowsToItems(rows, session);
  }

  ({List<HongguoSeries> items, List<String> allIds, String session}) _parseCategory(Map<String, Object?> data) {
    final rows = data['video_data'];
    if (rows is! List<Object?>) {
      throw const HongguoHomeFeedFailure('分类推荐列表缺失');
    }
    return _rowsToItems([for (final row in rows) if (row is Map<String, Object?>) row], _str(data, 'session_id'));
  }

  ({List<HongguoSeries> items, List<String> allIds, String session}) _rowsToItems(
    List<Map<String, Object?>> rows,
    String session,
  ) {
    final items = <HongguoSeries>[];
    final seen = <String>{};
    for (final row in rows) {
      final id = _str(row, 'series_id').isNotEmpty ? _str(row, 'series_id') : _str(row, 'book_id');
      var title = _str(row, 'series_title');
      if (title.isEmpty) title = _str(row, 'book_name');
      if (title.isEmpty) title = _str(row, 'title');
      if (!RegExp(r'^[0-9]{1,24}$').hasMatch(id) || title.isEmpty || !seen.add(id)) continue;
      var intro = _str(row, 'series_intro');
      if (intro.isEmpty) intro = _str(row, 'video_desc');
      var cover = _str(row, 'series_cover');
      if (cover.isEmpty) cover = _str(row, 'cover');
      items.add(HongguoSeries(
        seriesId: id,
        title: title,
        cover: cover.replaceAll(r'\/', '/'),
        intro: intro,
        episodeCount: (row['episode_cnt'] as num?)?.toInt() ?? 0,
      ));
      if (items.length >= 30) break;
    }
    if (items.isEmpty) {
      throw const HongguoHomeFeedFailure('推荐未返回可播放的剧集，请刷新重试');
    }
    return (items: items, allIds: seen.toList(), session: session);
  }
}

/// The home feed's failure, safe to show as sent.
final class HongguoHomeFeedFailure implements Exception {
  /// Creates the failure.
  const HongguoHomeFeedFailure(this.message);

  /// One line on what went wrong.
  final String message;

  @override
  String toString() => message;
}

String _str(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value.trim();
  if (value is num) return value.toInt() == value ? value.toInt().toString() : value.toString();
  return '';
}

/// The three shapes a feed request takes: URL, headers and optional body.
typedef HongguoSignedRequestLike = ({Uri url, Map<String, String> headers, Uint8List? body});
