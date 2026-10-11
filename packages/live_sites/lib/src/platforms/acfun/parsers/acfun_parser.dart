import 'dart:convert';
import 'dart:math';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the AcFun / Kuaishou-ZT live APIs.
abstract final class AcfunParser {
  /// API request headers shared by the visitor and startPlay calls.
  static const Map<String, String> apiHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'origin': 'https://live.acfun.cn',
    'referer': 'https://live.acfun.cn/',
  };

  /// Validates a JSON body and returns the root object.
  static Map<String, Object?> root(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('acfun $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('acfun $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('acfun $what: body is not an object');
    }
    return decoded;
  }

  /// `visitor/login` → the session (userId, token, deviceId), or an error
  /// on a refused login.
  static ({String userId, String token}) visitor(String body, {int status = 200}) {
    final parsed = root(body, status: status, what: 'visitor/login');
    final result = (parsed['result'] as num?)?.toInt();
    if (result != 0) {
      throw SiteRiskControlError('acfun visitor/login: result $result');
    }
    final userId = parsed['userId']?.toString() ?? '';
    final token = parsed['acfun.api.visitor_st']?.toString() ?? '';
    if (userId.isEmpty || userId == '0' || token.isEmpty) {
      throw const SiteApiChangedError('acfun visitor/login: incomplete session');
    }
    return (userId: userId, token: token);
  }

  /// A random 16-char device id for the visitor session.
  static String deviceId() {
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return [for (var i = 0; i < 16; i++) alphabet[random.nextInt(alphabet.length)]].join();
  }

  /// `live/info?authorId=` → the room; live when it has a `liveId`.
  static LiveRoom roomDetail(String body, {required String authorId, int status = 200}) {
    final parsed = root(body, status: status, what: 'live/info');
    final result = (parsed['result'] as num?)?.toInt();
    if (result != 0) {
      throw SiteApiChangedError('acfun live/info: result $result');
    }
    final user = parsed['user'];
    final userId = user is Map<String, Object?> ? user['id']?.toString() ?? '' : '';
    final name = user is Map<String, Object?> ? user['name']?.toString() ?? '' : '';
    if (user is! Map<String, Object?> || userId.isEmpty || userId == '0' || name.isEmpty) {
      throw SiteNotFoundError('acfun live/info: no author $authorId');
    }
    final live = (parsed['liveId']?.toString() ?? '').isNotEmpty;
    final covers = parsed['coverUrls'];
    final count = (parsed['onlineCount'] as num?)?.toInt();
    final type = parsed['type'];
    final createTime = (parsed['createTime'] as num?)?.toInt();
    return LiveRoom(
      platform: SiteIds.acfun,
      roomId: authorId,
      title: parsed['title']?.toString() ?? '',
      nick: name,
      avatar: authorImage(user['headUrl']),
      cover: covers is List && covers.isNotEmpty ? authorImage(covers.first) : null,
      areaName: type is Map<String, Object?> ? type['name']?.toString() : null,
      watching: count,
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live && createTime != null ? DateTime.fromMillisecondsSinceEpoch(createTime) : null,
    );
  }

  /// `startPlay` → the media URLs of the adaptive manifests, best
  /// representation first. `result` 1 is live; a closed broadcast
  /// (`result` 5) is a "not found" condition; anything else is risk
  /// control.
  static List<LivePlayLine> playLines(String body, {int status = 200}) {
    final parsed = root(body, status: status, what: 'startPlay');
    final result = (parsed['result'] as num?)?.toInt();
    if (result == 5) {
      throw const SiteNotFoundError('acfun startPlay: broadcast ended');
    }
    if (result != 1) {
      throw SiteRiskControlError('acfun startPlay: result $result ${parsed['error_msg'] ?? ''}'.trim());
    }
    final data = parsed['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('acfun startPlay: no data');
    }
    var videoPlayRes = data['videoPlayRes'];
    if (videoPlayRes is String) {
      try {
        videoPlayRes = jsonDecode(videoPlayRes);
      } on FormatException {
        videoPlayRes = null;
      }
    }
    final manifests = videoPlayRes is Map<String, Object?> ? videoPlayRes['liveAdaptiveManifest'] : null;
    if (manifests is! List) {
      throw const SiteApiChangedError('acfun startPlay: no liveAdaptiveManifest');
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    for (final manifest in manifests) {
      final adaptation = manifest is Map<String, Object?> ? manifest['adaptationSet'] : null;
      final representations = adaptation is Map<String, Object?> ? adaptation['representation'] : null;
      if (representations is! List) {
        continue;
      }
      for (final raw in representations) {
        if (raw is! Map<String, Object?>) {
          continue;
        }
        final url = raw['url']?.toString() ?? '';
        if (!url.startsWith('http') || !seen.add(url)) {
          continue;
        }
        lines.add(
          LivePlayLine(
            url: url,
            headers: apiHeaders,
            format: url.contains('.m3u8') ? StreamFormat.hls : StreamFormat.flv,
            codec: raw['name']?.toString(),
            lineId: raw['id']?.toString(),
          ),
        );
      }
    }
    if (lines.isEmpty) {
      throw const SiteNotFoundError('acfun startPlay: nothing playable');
    }
    return lines;
  }

  /// Normalizes a possibly relative image path to an absolute URL.
  static String? authorImage(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
