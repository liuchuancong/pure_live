import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the KilaKila (奇秀) live APIs.
abstract final class KilakilaParser {
  /// Live API host.
  static const String liveHost = 'live.kilakila.cn';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://live.kilakila.cn/',
  };

  /// The `getRoomInfo` URL of [broadcastId].
  static Uri roomInfoUrl(String broadcastId) => Uri.https(liveHost, '/LiveRoom/getRoomInfo', {'roomId': broadcastId});

  /// Validates the `{h, b}` envelope and returns `b`. Codes 5201 (no
  /// broadcast) and 5966 (historical replay) map to "not found".
  static Map<String, Object?> body(String raw, {required String broadcastId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kilakila getRoomInfo: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const SiteApiChangedError('kilakila getRoomInfo: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('kilakila getRoomInfo: body is not an object');
    }
    final header = decoded['h'];
    final code = header is Map<String, Object?> ? (header['code'] as num?)?.toInt() : null;
    if (code == 5201) {
      throw SiteNotFoundError('kilakila getRoomInfo: no broadcast $broadcastId');
    }
    if (code == 5966) {
      throw SiteNotFoundError('kilakila getRoomInfo: $broadcastId is a historical replay');
    }
    if (code != null && code != 0) {
      throw SiteApiChangedError('kilakila getRoomInfo: code $code');
    }
    final body = decoded['b'];
    if (body is! Map<String, Object?>) {
      throw const SiteApiChangedError('kilakila getRoomInfo: no b object');
    }
    return body;
  }

  /// `getRoomInfo` → the room. Status 4 is on-air; a positive `goldPrice`
  /// marks a paid broadcast. The play URLs ride in `data`.
  static LiveRoom room(String raw, {required String broadcastId, int status = 200}) {
    final body = KilakilaParser.body(raw, broadcastId: broadcastId, status: status);
    final echoed = body['roomIdStr']?.toString() ?? '';
    if (echoed != broadcastId) {
      throw SiteApiChangedError('kilakila getRoomInfo: asked $broadcastId, got $echoed');
    }
    final owner = body['userInfo'];
    final ownerMap = owner is Map<String, Object?> ? owner : const <String, Object?>{};
    final nick = ownerMap['nickname']?.toString() ?? '';
    final title = body['title']?.toString() ?? '';
    if (nick.isEmpty || title.isEmpty) {
      throw SiteApiChangedError('kilakila getRoomInfo $broadcastId: owner or title missing');
    }
    final state = (body['status'] as num?)?.toInt();
    final price = (body['goldPrice'] as num?)?.toInt() ?? 0;
    final startMs = (body['actualTime'] as num?)?.toInt();
    final live = state == 4;
    return LiveRoom(
      platform: SiteIds.kilakila,
      roomId: broadcastId,
      title: title,
      nick: nick,
      avatar: _picture(ownerMap['headPortraitUrl']),
      cover: _picture(body['backPic']) ?? _picture(body['defaultBackgroundPicUrl']),
      watching: (body['onlineNumber'] as num?)?.toInt(),
      status: live ? LiveStatus.live : LiveStatus.offline,
      restriction: live && price > 0 ? LiveRestriction.paid : null,
      startedAt: live && startMs != null && startMs >= 1000000000000 && startMs < 10000000000000
          ? DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true)
          : null,
      data: live ? body : null,
    );
  }

  /// The play lines of a live room's answer: the FLV and HLS pull URLs.
  static List<LivePlayLine> playLines(Object? data) {
    if (data is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final flv = data['flvPlayUrl']?.toString() ?? '';
    final hls = data['hlsPlayUrl']?.toString() ?? '';
    if (flv.startsWith('http')) {
      lines.add(LivePlayLine(url: flv, headers: headers, format: StreamFormat.flv, lineId: 'flv'));
    }
    if (hls.startsWith('http')) {
      lines.add(LivePlayLine(url: hls, headers: headers, format: StreamFormat.hls, lineId: 'hls'));
    }
    return lines;
  }

  static String? _picture(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
