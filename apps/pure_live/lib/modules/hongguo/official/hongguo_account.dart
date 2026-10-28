// Dart port of hongguoTV's CloudAccount (kotlin-tv/core), endpoint shapes
// from charlie901208/HGTV; GPL-3.0-only. The signed, cookie-carrying
// account surface: profile, cloud history, video-shelf favorites with
// add/remove, reservations, and progress upload.
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show gzip;
import 'dart:typed_data' show Uint8List;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_signer.dart' show HongguoSigner;
import 'package:pure_live/modules/hongguo/official/hongguo_vendor.dart' show HongguoVendor;

const String _kAccountHost = 'https://api5-normal-sinfonlinea.fqnovel.com';

/// A confirmed login: the cookie header and the device the session was
/// opened on — account endpoints sign with exactly this device.
final class HongguoCredentials {
  /// Creates the credentials.
  const HongguoCredentials({required this.cookie, this.deviceId = '', this.installId = '', this.device = const {}});

  /// The whole `Cookie` header value.
  final String cookie;

  /// The device the session was opened on.
  final String deviceId;

  /// Its install id.
  final String installId;

  /// Extra device fields to overlay on the vendor fingerprint.
  final Map<String, String> device;

  /// Serializes for storage.
  String toJson() => jsonEncode({'cookie': cookie, 'deviceId': deviceId, 'installId': installId, 'device': device});

  /// Reads back what [toJson] wrote; null when malformed.
  static HongguoCredentials? fromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final cookie = decoded['cookie'];
      if (cookie is! String || cookie.isEmpty) return null;
      final device = <String, String>{};
      final rawDevice = decoded['device'];
      if (rawDevice is Map<String, Object?>) {
        for (final entry in rawDevice.entries) {
          if (entry.value is String) device[entry.key] = entry.value! as String;
        }
      }
      return HongguoCredentials(
        cookie: cookie,
        deviceId: decoded['deviceId'] is String ? decoded['deviceId']! as String : '',
        installId: decoded['installId'] is String ? decoded['installId']! as String : '',
        device: device,
      );
    } on Object {
      return null;
    }
  }
}

/// The signed-in viewer.
final class HongguoProfile {
  /// Creates the profile.
  const HongguoProfile({required this.id, required this.nickname});

  /// The platform's user id.
  final String id;

  /// The user's nickname.
  final String nickname;
}

/// One cloud watch-history entry, its series metadata resolved.
final class HongguoCloudProgress {
  /// Creates the entry.
  const HongguoCloudProgress({
    required this.series,
    required this.episodeVid,
    required this.episodeIndex,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  /// The series the progress belongs to.
  final HongguoSeries series;

  /// The episode's vid.
  final String episodeVid;

  /// The 0-based episode index.
  final int episodeIndex;

  /// Where playback stood, in milliseconds.
  final int positionMs;

  /// The episode's length, in milliseconds.
  final int durationMs;

  /// When the platform last saw it.
  final int updatedAt;
}

/// One cloud favorite.
final class HongguoCloudFavorite {
  /// Creates the favorite.
  const HongguoCloudFavorite({required this.series, required this.collectedAt});

  /// The favorited series.
  final HongguoSeries series;

  /// When it was collected (milliseconds; 0 unknown).
  final int collectedAt;
}

/// One reservation: already online, or waiting for its premiere.
final class HongguoCloudReservation {
  /// Creates the reservation.
  const HongguoCloudReservation({
    required this.series,
    required this.online,
    required this.publishAt,
    this.publishText = '',
  });

  /// The reserved series; an unpublished one carries a `reservation:` id
  /// that can never be mistaken for a playback id.
  final HongguoSeries series;

  /// Whether it has premiered.
  final bool online;

  /// When it premieres / premiered (milliseconds; 0 unknown).
  final int publishAt;

  /// The platform's own premiere words.
  final String publishText;
}

/// The account client: one shared signer, every call carrying the login's
/// cookie and signing with the session's own device.
final class HongguoAccountClient {
  /// Creates the client.
  HongguoAccountClient({required this._http}) : _signer = HongguoSigner();

  final LiveHttp _http;
  final HongguoSigner _signer;

  Future<Map<String, Object?>> _json(
    HongguoCredentials credentials,
    String path, {
    Map<String, String> params = const {},
    Uint8List? body,
    bool gzipBody = false,
  }) async {
    final device = {
      ...HongguoVendor.device,
      ...credentials.device,
      'device_id': credentials.deviceId,
      'iid': credentials.installId,
      for (final key in const ['version_code', 'manifest_version_code', 'update_version_code', 'pv_player'])
        key: body == null ? '72232' : '73932',
      'version_name': body == null ? '7.2.2.32' : '7.3.9.32',
    };
    final wireBody = gzipBody && body != null ? Uint8List.fromList(gzip.encode(body)) : body;
    final signed = _signer.sign('$_kAccountHost$path', {...device, ...params}, body: wireBody);
    final response = await _http.send(
      LiveRequest.custom(
        method: body == null ? 'GET' : 'POST',
        url: Uri.parse(signed.url),
        bodyBytes: wireBody,
        contentType: body == null ? null : 'application/json; charset=utf-8',
        headers: {...signed.headers, 'Cookie': credentials.cookie, if (gzipBody) 'Content-Encoding': 'gzip'},
        timeout: const Duration(seconds: 30),
      ),
    );
    if (!response.isOk) {
      throw HongguoAccountFailure('HTTP ${response.statusCode}');
    }
    final text = response.text;
    if (text.trim().isEmpty) {
      throw const HongguoAccountFailure('账号接口返回空响应，请稍后重试');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const HongguoAccountFailure('账号接口返回格式异常');
    }
    final code = decoded['code'] is num ? (decoded['code']! as num).toInt() : -1;
    if (code != 0) {
      throw HongguoAccountFailure('账号接口不可用（错误码 $code），请重新登录或稍后重试');
    }
    return decoded;
  }

  /// The signed-in viewer's own profile.
  Future<HongguoProfile> profile(HongguoCredentials credentials) async {
    final root = await _json(credentials, '/reading/user/info/v1/');
    final data = root['data'];
    if (data is! Map<String, Object?>) {
      throw const HongguoAccountFailure('账号资料为空');
    }
    final id = _str(data, 'biz_user_id');
    if (id.isEmpty) {
      throw const HongguoAccountFailure('登录态未通过账号验证，请重新登录');
    }
    final name = _str(data, 'user_name');
    return HongguoProfile(id: id, nickname: name.isEmpty ? '红果用户' : name);
  }

  /// The cloud watch history, its rows resolved to series metadata.
  Future<List<HongguoCloudProgress>> history(HongguoCredentials credentials) async {
    final root = await _json(
      credentials,
      '/reading/bookapi/read_progress/list/v1/',
      params: {'book_types': '2', 'limit': '50'},
    );
    final data = root['video_data'] is List<Object?>
        ? root['video_data']! as List<Object?>
        : root['data'] is Map<String, Object?> && (root['data']! as Map<String, Object?>)['video_data'] is List<Object?>
        ? (root['data']! as Map<String, Object?>)['video_data']! as List<Object?>
        : null;
    if (data == null) {
      throw const HongguoAccountFailure('云端历史数据格式已变化');
    }
    final rows = <({String id, String vid, int index, int position, int duration, int updatedAt, int count})>[];
    for (final row in data) {
      if (row is! Map<String, Object?>) continue;
      final id = _str(row, 'series_id').isNotEmpty ? _str(row, 'series_id') : _str(row, 'book_id');
      final vid = _str(row, 'vid');
      if (!RegExp(r'^[0-9]{1,30}$').hasMatch(id) || !RegExp(r'^[0-9]{1,30}$').hasMatch(vid)) continue;
      var stamp = (row['last_watch_time'] as num?)?.toInt() ?? 0;
      if (stamp >= 1 && stamp <= 9999999999) stamp *= 1000;
      rows.add((
        id: id,
        vid: vid,
        index: (((row['vid_index'] as num?)?.toInt() ?? 1) - 1).clamp(0, 1 << 30),
        position: (row['current_play_time'] as num?)?.toInt() ?? 0,
        duration: (row['current_total_time'] as num?)?.toInt() ?? 0,
        updatedAt: stamp,
        count: (row['episode_count'] as num?)?.toInt() ?? 0,
      ));
    }
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toSet().join(',');
    final detailsRoot = await _json(
      credentials,
      '/reading/bookapi/multi-detail/v1/',
      params: {'book_id': ids, 'book_type': '2'},
    );
    final details = <String, HongguoSeries>{};
    final detailRows = detailsRoot['data'];
    if (detailRows is List<Object?>) {
      for (final row in detailRows) {
        if (row is! Map<String, Object?>) continue;
        final id = _str(row, 'book_id');
        if (id.isEmpty) continue;
        details[id] = HongguoSeries(
          seriesId: id,
          title: _str(row, 'book_name'),
          cover: _str(row, 'thumb_url'),
          intro: _str(row, 'abstract'),
          episodeCount: _episodeCount(row),
        );
      }
    }
    final seen = <String>{};
    final progress = <HongguoCloudProgress>[];
    for (final row in rows) {
      if (!seen.add(row.id)) continue;
      progress.add(
        HongguoCloudProgress(
          series: details[row.id] ?? HongguoSeries(seriesId: row.id, title: '剧集 ${row.id}'),
          episodeVid: row.vid,
          episodeIndex: row.index,
          positionMs: row.position,
          durationMs: row.duration,
          updatedAt: row.updatedAt,
        ),
      );
    }
    progress.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return progress;
  }

  /// The video shelf's favorites.
  Future<List<HongguoCloudFavorite>> favorites(HongguoCredentials credentials) async {
    final root = await _json(credentials, '/reading/bookapi/bookshelf/video/info/v1/');
    final data = root['data'];
    if (data is! Map<String, Object?> || !data.containsKey('video_shelf_info')) {
      throw const HongguoAccountFailure('账户收藏数据格式已变化');
    }
    final rows = data['video_shelf_info'];
    if (rows is! List<Object?>) {
      if (rows != null) {
        throw const HongguoAccountFailure('账户收藏列表格式已变化');
      }
      return const [];
    }
    final result = <HongguoCloudFavorite>[];
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final video = row['video_data'] is Map<String, Object?> ? row['video_data']! as Map<String, Object?> : row;
      var id = _str(video, 'series_id');
      if (id.isEmpty) id = _str(row, 'series_id');
      if (id.isEmpty) id = _str(row, 'book_id');
      final title = _pick3(row, video, row, 'series_title', 'title', 'book_name');
      if (!RegExp(r'^[0-9]{1,30}$').hasMatch(id) || title.isEmpty) continue;
      final count =
          (video['episode_cnt'] as num?)?.toInt() ??
          (video['episode_count'] as num?)?.toInt() ??
          (row['episode_cnt'] as num?)?.toInt() ??
          0;
      final tags = _schemaTags(row['category_schema']);
      var stamp = (row['collect_time'] as num?)?.toInt() ?? 0;
      if (stamp >= 1 && stamp <= 9999999999) stamp *= 1000;
      result.add(
        HongguoCloudFavorite(
          series: HongguoSeries(
            seriesId: id,
            title: title,
            cover: _pick3(row, video, video, 'series_cover_url', 'cover', 'thumb_url'),
            intro: _pick3(row, video, row, 'series_intro', 'video_desc', 'abstract'),
            episodeCount: count,
            category: tags,
          ),
          collectedAt: stamp,
        ),
      );
    }
    if (rows.isNotEmpty && result.isEmpty) {
      throw const HongguoAccountFailure('账户收藏条目格式已变化');
    }
    result.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    final seen = <String>{};
    return [
      for (final favorite in result)
        if (seen.add(favorite.series.seriesId)) favorite,
    ];
  }

  /// Adds or removes [seriesId] on the video shelf. The platform only
  /// acknowledges; callers read the shelf back before reporting success.
  Future<void> setFavorite(HongguoCredentials credentials, String seriesId, {required bool add}) async {
    if (!RegExp(r'^[0-9]{1,30}$').hasMatch(seriesId)) {
      throw const HongguoAccountFailure('剧集编号无效');
    }
    final entry = {
      'book_id': seriesId,
      'book_type': 2,
      'modify_time': DateTime.now().millisecondsSinceEpoch,
      'video_shelf_operate_type': add ? 0 : 1,
      if (!add) 'group_name': '',
    };
    final body = {
      'is_cancelled': false,
      'update_bookshelf_video_list': [entry],
      if (add)
        'shark_extra': {
          'enter_from': 'MainFragmentActivity',
          'previous_page': '',
          'page_list': 'MainFragmentActivity',
          'is_active_behavior': 'true',
          'inactive_type': '0',
        },
    };
    await _json(
      credentials,
      '/reading/bookapi/bookshelf/video/update/v1/',
      body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }

  /// The reservations: [online] picks the premiered shelf, else the waiting
  /// one. Each shelf answers its latest twenty.
  Future<List<HongguoCloudReservation>> reservations(HongguoCredentials credentials, {required bool online}) async {
    final root = await _json(
      credentials,
      '/reading/user/subscribe/list/v0/',
      params: {
        'offset': '0',
        'limit': '20',
        'is_online': '$online',
        'tab_type': '13',
        'subscribe_order_type': '0',
        'swipe_type': '0',
        'need_calendar_schema': 'false',
        'subscribe_offset': '0',
      },
    );
    final data = root['data'];
    if (data is! Map<String, Object?> || !data.containsKey('subscribe_items')) {
      throw const HongguoAccountFailure('预约数据格式已变化，请稍后重试');
    }
    final rows = data['subscribe_items'];
    if (rows is! List<Object?>) {
      if (rows != null) {
        throw const HongguoAccountFailure('预约列表格式已变化，请稍后重试');
      }
      return const [];
    }
    final result = <HongguoCloudReservation>[];
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final video = row['subscribe_data'] is Map<String, Object?>
          ? row['subscribe_data']! as Map<String, Object?>
          : (row['video_data'] is Map<String, Object?> ? row['video_data']! as Map<String, Object?> : row);
      var seriesId = _pick2(video, row, 'series_id');
      if (seriesId.isEmpty) seriesId = _pick2(row, row, 'book_id');
      String id;
      if (RegExp(r'^[0-9]{1,30}$').hasMatch(seriesId)) {
        id = seriesId;
      } else if (!online && identical(video, row) && RegExp(r'^[0-9]{1,30}$').hasMatch(_str(row, 'item_id'))) {
        id = 'reservation:${_str(row, 'item_id')}';
      } else {
        continue;
      }
      final title = _pick4(row, video, video, row, 'series_title', 'title', 'book_name', 'name');
      if (title.isEmpty) continue;
      final rowOnline = row['is_online'];
      if (rowOnline is bool && rowOnline != online) continue;
      var stamp = (row['schedule_publish_time'] as num?)?.toInt() ?? 0;
      if (stamp >= 1 && stamp <= 9999999999) stamp *= 1000;
      final badge = online ? (_episodeBadge(video).isNotEmpty ? _episodeBadge(video) : '已上线') : '待上线';
      result.add(
        HongguoCloudReservation(
          series: HongguoSeries(
            seriesId: id,
            title: title,
            cover: _pick3(row, video, video, 'series_cover_url', 'cover', 'thumb_url'),
            intro: _pick4(video, row, row, video, 'video_desc', 'abstract', 'item_desc', ''),
            hot: badge,
            category: _pick2(video, row, 'category'),
          ),
          online: online,
          publishAt: stamp,
          publishText: _str(row, 'expected_rec_text'),
        ),
      );
    }
    final seen = <String>{};
    return [
      for (final reservation in result)
        if (seen.add(reservation.series.seriesId)) reservation,
    ];
  }

  /// Uploads one watch-progress entry; write-through, best effort.
  Future<void> upload(
    HongguoCredentials credentials, {
    required String seriesId,
    required String episodeVid,
    required int episodeIndex0,
    required int positionMs,
    required int durationMs,
    required int episodeCount,
  }) async {
    if (!RegExp(r'^[0-9]{1,30}$').hasMatch(seriesId) || !RegExp(r'^[0-9]{1,30}$').hasMatch(episodeVid)) {
      return;
    }
    final rate = durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0).toString() : '0';
    final body = {
      'books': [
        {
          'book_id': seriesId,
          'item_id': episodeVid,
          'vid_index': episodeIndex0 + 1,
          'current_play_time': positionMs < 0 ? 0 : positionMs,
          'current_total_time': durationMs < 0 ? 0 : durationMs,
          'episode_count': episodeCount,
          'read_timestamp_ms': DateTime.now().millisecondsSinceEpoch,
          'book_type': 2,
          'progress_rate': rate,
          'player_cumulative_total_duration': positionMs < 0 ? 0 : positionMs,
        },
      ],
      'write_mode': 1,
    };
    await _json(
      credentials,
      '/reading/bookapi/read_progress/upload/v1/',
      body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }
}

/// The account layer's failure, safe to show as sent.
final class HongguoAccountFailure implements Exception {
  /// Creates the failure.
  const HongguoAccountFailure(this.message);

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

String _pick2(Map<String, Object?> a, Map<String, Object?> b, String key) {
  final first = _str(a, key);
  return first.isNotEmpty ? first : _str(b, key);
}

String _pick3(Map<String, Object?> a, Map<String, Object?> b, Map<String, Object?> c, String k1, String k2, String k3) {
  for (final source in [a, b, c]) {
    for (final key in [k1, k2, k3]) {
      final value = _str(source, key);
      if (value.isNotEmpty && _looksLikeText(value)) {
        return _clean(value);
      }
    }
  }
  return '';
}

String _pick4(
  Map<String, Object?> a,
  Map<String, Object?> b,
  Map<String, Object?> c,
  Map<String, Object?> d,
  String k1,
  String k2,
  String k3,
  String k4,
) {
  for (final source in [a, b, c, d]) {
    for (final key in [k1, k2, k3, k4]) {
      final value = _str(source, key);
      if (value.isNotEmpty) return value;
    }
  }
  return '';
}

bool _looksLikeText(String value) => !value.startsWith('http') || value.contains('.');

String _clean(String value) => value.replaceAll(r'\/', '/').replaceAll('&amp;', '&');

int _episodeCount(Map<String, Object?> row) {
  for (final key in ['episode_cnt', 'episode_count', 'drama_chapter_number']) {
    final value = (row[key] as num?)?.toInt() ?? 0;
    if (value > 0) return value;
  }
  return 0;
}

String _episodeBadge(Map<String, Object?> row) {
  final count = _episodeCount(row);
  return count > 0 ? '全 $count 集' : '';
}

String _schemaTags(Object? schema) {
  if (schema is! String || schema.isEmpty) return '';
  try {
    final decoded = jsonDecode(schema);
    if (decoded is! List<Object?>) return '';
    return [
      for (final entry in decoded.take(5))
        if (entry is Map<String, Object?>) _str(entry, 'name'),
    ].where((name) => name.isNotEmpty).join(' / ');
  } on Object {
    return '';
  }
}
