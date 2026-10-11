import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the SOOP (formerly AfreecaTV) APIs.
abstract final class SoopParser {
  /// Live API host.
  static const String liveHost = 'live.sooplive.co.kr';

  /// Station API host.
  static const String stationHost = 'chapi.sooplive.co.kr';

  /// Web play origin.
  static const String origin = 'https://play.sooplive.co.kr';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'origin': origin,
    'referer': '$origin/',
  };

  /// Media headers of streamer [roomId].
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': headers['user-agent']!,
    'origin': origin,
    'referer': roomPageUrl(roomId),
  };

  /// The room page URL.
  static String roomPageUrl(String roomId) => '$origin/${Uri.encodeComponent(roomId.trim())}';

  /// The `player_live_api.php` URL for [roomId].
  static Uri playerUrl(String roomId) => Uri.https(liveHost, '/afreeca/player_live_api.php', {'bjid': roomId});

  /// The player form of [roomId]: `live` for the room, `aid` for a
  /// stream key.
  static Map<String, String> playerForm(
    String roomId, {
    required String type,
    String bno = '',
    String quality = 'HD',
  }) => {
    'bid': roomId,
    'bno': bno,
    'type': type,
    'pwd': '',
    'player_type': 'html5',
    'stream_type': 'common',
    'quality': quality,
    'mode': 'landing',
    'from_api': '0',
    'is_revive': 'false',
  };

  /// Validates the `{CHANNEL: {...}}` answer and returns `(result, fields)`.
  static ({int result, Map<String, Object?> fields}) channel(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('soop player_live_api: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('soop player_live_api: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('soop player_live_api: body is not an object');
    }
    final channel = decoded['CHANNEL'];
    if (channel is! Map<String, Object?>) {
      throw const SiteApiChangedError('soop player_live_api: no CHANNEL');
    }
    return (result: (channel['RESULT'] as num?)?.toInt() ?? 0, fields: channel);
  }

  /// The room snapshot from a `type=live` answer. RESULT 1 is live, 0
  /// offline, -2 banned; -6/-8/-14 are live with the adult, password and
  /// subscribers-only restrictions.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    final (:result, :fields) = channel(body, status: status);
    final id = roomId.trim();
    final title = fields['TITLE']?.toString() ?? '';
    switch (result) {
      case 0:
        return LiveRoom(platform: SiteIds.soop, roomId: id, status: LiveStatus.offline);
      case -2:
        return LiveRoom(platform: SiteIds.soop, roomId: id, status: LiveStatus.banned);
      case -6 || -8 || -14:
        return LiveRoom(
          platform: SiteIds.soop,
          roomId: id,
          title: title,
          status: LiveStatus.live,
          restriction: switch (result) {
            -6 => LiveRestriction.loginRequired,
            -8 => LiveRestriction.loginRequired,
            _ => LiveRestriction.loginRequired,
          },
          startedAt: _startedBefore(fields['BTIME']),
        );
      case 1:
        break;
      default:
        throw SiteApiChangedError('soop player_live_api: RESULT $result');
    }
    final bno = fields['BNO']?.toString() ?? '';
    final bj = fields['BJID']?.toString() ?? id;
    final live = fields['VIEWPRESET'] != null;
    final viewers = _int(fields['VIEWPRESET'] == null ? null : fields['VISITOR_COUNT'] ?? fields['VIEWER_COUNT']);
    return LiveRoom(
      platform: SiteIds.soop,
      roomId: id,
      title: title,
      nick: fields['BJNICK']?.toString() ?? '',
      avatar: bj.length < 2 ? null : 'https://stimg.sooplive.co.kr/LOGO/${bj.substring(0, 2)}/$bj/$bj.jpg',
      cover: bno.isEmpty ? null : _cover(bno, DateTime.now()),
      areaName: _firstTag(fields['CATEGORY_TAGS']),
      watching: viewers,
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live ? _startedBefore(fields['BTIME']) : null,
      data: live
          ? {
              'bno': bno,
              'rmd': fields['RMD']?.toString() ?? '',
              'cdn': fields['CDN']?.toString() ?? '',
              'presets': presets(fields['VIEWPRESET']),
            }
          : null,
    );
  }

  /// The presets of a `VIEWPRESET` list: name and codec.
  static List<({String name, String? codec})> presets(Object? value) {
    if (value is! List) {
      return const [];
    }
    final presets = <({String name, String? codec})>[];
    for (final item in value) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      presets.add((
        name: name,
        codec: switch (item['vcodec']?.toString().trim().toLowerCase()) {
          'h264' || 'avc' => 'avc',
          'h265' || 'hevc' => 'hevc',
          _ => null,
        },
      ));
    }
    return presets;
  }

  /// The `return_type` of the stream assignment for CDN code [cdn].
  static String returnType(String cdn) {
    if (cdn.contains('gs_cdn')) {
      return 'gs_cdn_pc_web';
    }
    if (cdn.contains('lg_cdn')) {
      return 'lg_cdn_pc_web';
    }
    return cdn;
  }

  /// The `<RMD>/broad_stream_assign.html` URL for [quality] of [bno].
  static Uri assignUrl({required String rmd, required String cdn, required String bno, required String quality}) {
    final base = Uri.tryParse('${rmd.replaceAll(RegExp(r'/$'), '')}/broad_stream_assign.html');
    if (base == null || !(base.isScheme('http') || base.isScheme('https')) || base.host.isEmpty) {
      throw SiteApiChangedError('soop player_live_api: RMD "$rmd" is not a URL');
    }
    return base.replace(queryParameters: {'return_type': returnType(cdn), 'broad_key': '$bno-common-$quality-hls'});
  }

  /// `broad_stream_assign.html` → the playlist URL (`view_url`).
  static String assignedPlaylist(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('soop broad_stream_assign: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('soop broad_stream_assign: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('soop broad_stream_assign: body is not an object');
    }
    if ((decoded['result'] as num?)?.toInt() != 1) {
      throw SiteNotFoundError('soop broad_stream_assign: result ${decoded['result']}');
    }
    final url = decoded['view_url']?.toString() ?? '';
    if (!url.startsWith('http')) {
      throw const SiteApiChangedError('soop broad_stream_assign: no view_url');
    }
    return url;
  }

  /// A `type=aid` answer → the stream key. RESULT -6 is age-restricted.
  static String aid(String body, {int status = 200}) {
    final (:result, :fields) = channel(body, status: status);
    if (result == -6) {
      throw const SiteNotFoundError('soop aid: RESULT -6 (age-restricted broadcast)');
    }
    final aid = fields['AID']?.toString() ?? '';
    if (result != 1 || aid.isEmpty) {
      throw SiteNotFoundError('soop aid: RESULT $result');
    }
    return aid;
  }

  /// The play line of [playlist] with stream key [aid]: `?aid=` appended,
  /// HLS, the CDN as line id.
  static LivePlayLine line({
    required String playlist,
    required String aid,
    required String roomId,
    required String cdn,
    String? codec,
  }) => LivePlayLine(
    url: '$playlist?aid=$aid',
    headers: mediaHeaders(roomId),
    format: StreamFormat.hls,
    codec: codec,
    lineId: cdn.isEmpty ? 'hls' : cdn,
  );

  /// The cover of broadcast [bno] (the platform serves it per broadcast).
  static String _cover(String bno, DateTime now) => 'https://liveimg.sooplive.co.kr/m/$bno';

  static String? _firstTag(Object? value) {
    if (value is List) {
      for (final tag in value) {
        final text = tag?.toString() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  /// `BTIME` (Unix seconds) as a time; null unless positive seconds.
  static DateTime? _startedBefore(Object? value) {
    final seconds = _int(value);
    if (seconds == null || seconds <= 0 || seconds > 9999999999) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static int? _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString().trim() ?? '');
}
