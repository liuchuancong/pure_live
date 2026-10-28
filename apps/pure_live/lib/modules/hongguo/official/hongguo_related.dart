// Dart port of hongguoTV's RelatedWorks parsing and the reservation write
// (kotlin-tv/core); GPL-3.0-only. The reading-plan endpoint answers a
// series' other seasons; `uncover_subscribe` books one that has not
// premiered yet. Every request rides the account client's own transport.
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show gzip;
import 'dart:typed_data' show Uint8List;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;

import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart' show HongguoAccountFailure, HongguoCredentials;
import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart' show HongguoSigner;
import 'package:pure_live/modules/hongguo/official/hongguo_vendor.dart' show HongguoVendor;

/// One related work: another season of the series, live or waiting.
final class HongguoRelatedWork {
  /// Creates the entry.
  const HongguoRelatedWork({required this.series, required this.season, required this.upcoming});

  /// The work's series.
  final HongguoSeries series;

  /// The season line ("第2季"), when the platform labels one.
  final String season;

  /// Whether it has not premiered yet — the only kind reservable.
  final bool upcoming;
}

/// The related-works reader and the reservation writer, over one shared
/// transport.
final class HongguoRelatedClient {
  /// Creates the client.
  HongguoRelatedClient({required this._http}) : _signer = HongguoSigner();

  final LiveHttp _http;
  final HongguoSigner _signer;

  /// The plan endpoint's hosts, in the reference's failover order.
  static const List<String> _hosts = [
    'api5-normal-sinfonlinec.fqnovel.com',
    'api5-normal-hl.fqnovel.com',
    'api5-normal-lf.fqnovel.com',
  ];

  /// The series' related works — its other seasons, live and waiting. Read
  /// with the anonymous device; no login needed.
  Future<List<HongguoRelatedWork>> related(String seriesId) async {
    if (!RegExp(r'^[0-9]{1,30}$').hasMatch(seriesId)) {
      throw const HongguoAccountFailure('剧集编号无效');
    }
    final values = {
      ...HongguoVendor.device,
      for (final key in const ['version_code', 'manifest_version_code', 'update_version_code', 'pv_player'])
        key: '72232',
      'version_name': '7.2.2.32',
      'scene': '10',
      'from': 'detail_page_more_related',
      'book_id': seriesId,
      'new_search_middle_page': 'false',
      'bookstore_tab_type': '0',
      'query_history_removed': 'false',
      'user_is_login': '0',
      'bookstore_tab': '0',
      'search_middle_page_version': '0',
      'pad_column_detail': '0',
      'hot_word_exchange': 'false',
      'device_level': '3',
      'limit': '0',
      'offset': '0',
      'is_horizontal_screen': 'false',
      'reader_single_col_from_ip_strategy': 'false',
    };
    HongguoAccountFailure? last;
    for (final host in _hosts) {
      try {
        final signed = _signer.sign('https://$host/reading/bookapi/plan/v:version/', values);
        final response = await _http.send(
          LiveRequest.custom(
            method: 'GET',
            url: Uri.parse(signed.url),
            headers: signed.headers,
            timeout: const Duration(seconds: 30),
          ),
        );
        if (!response.isOk) {
          last = HongguoAccountFailure('HTTP ${response.statusCode}');
          continue;
        }
        if (response.text.trim().isEmpty) {
          last = const HongguoAccountFailure('相关作品接口暂无响应');
          continue;
        }
        return _parseRelated(response.text, seriesId);
      } on HongguoAccountFailure catch (error) {
        last = error;
      } on Object {
        last = const HongguoAccountFailure('相关作品暂时无法加载');
      }
    }
    throw last ?? const HongguoAccountFailure('相关作品暂时无法加载');
  }

  /// Books [work] on the account when it has not premiered. The platform
  /// only acknowledges; the reservations shelf read-back confirms.
  Future<void> reserve(HongguoCredentials credentials, HongguoRelatedWork work) async {
    final raw = work.series.seriesId;
    if (!work.upcoming || !RegExp(r'^[0-9]{1,19}$').hasMatch(raw)) {
      throw const HongguoAccountFailure('只有待上线作品可以预约');
    }
    final device = {
      ...HongguoVendor.device,
      ...credentials.device,
      'device_id': credentials.deviceId,
      'iid': credentials.installId,
      for (final key in const ['version_code', 'manifest_version_code', 'update_version_code', 'pv_player'])
        key: '73932',
      'version_name': '7.3.9.32',
    };
    // The reference sends this write gzipped, and signs the bytes it puts on
    // the wire — not the plaintext behind them.
    final wireBody = Uint8List.fromList(
      gzip.encode(
        utf8.encode(jsonEncode({'item_id': int.parse(raw), 'item_type': 3, 'op_type': 1, 'subscribe_source': 0})),
      ),
    );
    final signed = HongguoSigner(device: device).sign(
      'https://api5-normal-sinfonlinea.fqnovel.com/reading/bookapi/search/uncover_subscribe/v1/',
      device,
      body: wireBody,
    );
    final response = await _http.send(
      LiveRequest.custom(
        method: 'POST',
        url: Uri.parse(signed.url),
        bodyBytes: wireBody,
        contentType: 'application/json; charset=utf-8',
        headers: {...signed.headers, 'Cookie': credentials.cookie, 'Content-Encoding': 'gzip'},
        timeout: const Duration(seconds: 30),
      ),
    );
    if (!response.isOk) {
      throw HongguoAccountFailure('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.text);
    final code = decoded is Map<String, Object?> ? (decoded['code'] as num?)?.toInt() ?? -1 : -1;
    if (code != 0) {
      throw HongguoAccountFailure('预约未成功（错误码 $code），请稍后重试');
    }
  }
}

/// The related/plan endpoints' parse, the reference's cell shape.
List<HongguoRelatedWork> _parseRelated(String raw, String currentId) {
  final root = jsonDecode(raw);
  if (root is! Map<String, Object?> || ((root['code'] as num?)?.toInt() ?? -1) != 0) {
    throw const HongguoAccountFailure('相关作品接口暂不可用');
  }
  final cells = root['data'];
  if (cells is! List<Object?>) {
    throw const HongguoAccountFailure('相关作品数据格式已变化');
  }
  String str(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value.trim();
    if (value is num) return value.toInt().toString();
    return '';
  }

  final result = <HongguoRelatedWork>[];
  for (final cell in cells) {
    if (cell is! Map<String, Object?>) continue;
    final showType = (cell['show_type'] as num?)?.toInt() ?? 0;
    if (showType != 547 && str(cell, 'cell_name') != '相关作品') continue;
    final rows = cell['video_data'];
    if (rows is! List<Object?>) continue;
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final id = str(row, 'series_id');
      final title = str(row, 'title');
      final type = (row['content_type'] as num?)?.toInt() ?? 0;
      if (id == currentId ||
          !RegExp(r'^[0-9]{1,30}$').hasMatch(id) ||
          title.isEmpty ||
          (type != 1004 && type != 1007)) {
        continue;
      }
      final upcoming = type == 1007;
      if (!upcoming && ((row['disable_play'] == true) || ((row['episode_cnt'] as num?)?.toInt() ?? 0) <= 0)) {
        continue;
      }
      final tagInfo = row['tag_info'];
      var season = tagInfo is Map<String, Object?> ? str(tagInfo, 'text') : '';
      if (season.isEmpty) {
        final seasonIndex = (row['season_index'] as num?)?.toInt() ?? 0;
        if (seasonIndex > 0) season = '第$seasonIndex季';
      }
      result.add(
        HongguoRelatedWork(
          series: HongguoSeries(
            seriesId: id,
            title: title,
            cover: str(row, 'cover').replaceAll(r'\/', '/'),
            intro: str(row, 'video_desc'),
            episodeCount: (row['episode_cnt'] as num?)?.toInt() ?? 0,
            hot: upcoming ? '待上线' : '已上线',
          ),
          season: season,
          upcoming: upcoming,
        ),
      );
    }
  }
  final seen = <String>{};
  return [
    for (final work in result)
      if (seen.add(work.series.seriesId)) work,
  ].take(30).toList();
}
