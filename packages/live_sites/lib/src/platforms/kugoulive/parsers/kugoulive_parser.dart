import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Kugou Live APIs.
abstract final class KugouLiveParser {
  /// Room-info host.
  static const String roomHost = 'service2.fanxing.kugou.com';

  /// Stream/API host.
  static const String apiHost = 'fx1.service.kugou.com';

  /// API request headers.
  static const Map<String, String> apiHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://fanxing.kugou.com/',
  };

  /// Media headers for [roomId].
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': apiHeaders['user-agent']!,
    'referer': 'https://fanxing.kugou.com/$roomId',
  };

  /// The `getEnterRoomInfo` URL.
  static Uri roomInfoUrl(String roomId) =>
      Uri.https(roomHost, '/roomcen/room/web/cdn/getEnterRoomInfo', {'roomId': roomId});

  /// The `streamaddr` URL.
  static Uri streamUrl(String roomId, {required int millis}) =>
      Uri.https(apiHost, '/video/pc/live/pull/mutiline/streamaddr', {
        'std_rid': roomId,
        'std_plat': '7',
        'std_kid': '0',
        'streamType': '1-2-4-5-8',
        'ua': 'fx-flash',
        'targetLiveTypes': '1-5-6',
        'version': '1000',
        'supportEncryptMode': '1',
        'appid': '1010',
        '_': '$millis',
      });

  /// Decodes an answer; HTTP failures and non-JSON bodies are API changes.
  static Map<String, Object?> decode(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kugoulive $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('kugoulive $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('kugoulive $what: body is not an object');
    }
    return decoded;
  }

  /// `getEnterRoomInfo` → the room; a room without nick and kugouId is
  /// "not found", `liveType` -1 offline, a `liveSessionId` live.
  static LiveRoom roomInfo(String body, {required String roomId, int status = 200}) {
    final root = decode(body, status: status, what: 'getEnterRoomInfo');
    final data = root['data'];
    final info = data is Map<String, Object?> ? data['normalRoomInfo'] : null;
    if (info is! Map<String, Object?>) {
      throw const SiteApiChangedError('kugoulive getEnterRoomInfo: no normalRoomInfo');
    }
    final nick = info['nickName']?.toString() ?? '';
    final kugouId = info['kugouId']?.toString() ?? '';
    if (nick.isEmpty && (kugouId.isEmpty || kugouId == '0')) {
      throw SiteNotFoundError('kugoulive: no room $roomId');
    }
    final liveType = data is Map<String, Object?> ? (data['liveType'] as num?)?.toInt() : null;
    final session = data is Map<String, Object?> ? data['liveSessionId']?.toString() ?? '' : '';
    final live = liveType != -1 && session.isNotEmpty;
    return LiveRoom(
      platform: SiteIds.kugouLive,
      roomId: roomId,
      nick: nick,
      avatar: image(info['userLogo']),
      cover: image(info['imgPath']),
      status: live ? LiveStatus.live : LiveStatus.offline,
      data: session.isEmpty ? null : session,
    );
  }

  /// `streamaddr` → the play lines grouped by (protocol, rate, codec,
  /// layout), highest rate first; `code` 2 is "login required", `status`
  /// other than 1 is "nothing streaming".
  static List<LivePlayLine> playLines(String body, {required String roomId, int status = 200}) {
    final root = decode(body, status: status, what: 'streamaddr');
    final code = (root['code'] as num?)?.toInt();
    if (code == 2) {
      throw SiteNeedsLoginError('kugoulive streamaddr: login required for $roomId');
    }
    final data = root['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('kugoulive streamaddr: no data');
    }
    final statusField = (data['status'] as num?)?.toInt();
    if (statusField != null && statusField != 1) {
      throw SiteNotFoundError('kugoulive streamaddr: nothing streaming (status $statusField)');
    }
    final headers = mediaHeaders(roomId);
    final lines = <LivePlayLine>[];
    final seenUrls = <String>{};
    final rawLines = data['lines'];
    if (rawLines is List) {
      for (final lineValue in rawLines) {
        if (lineValue is! Map<String, Object?>) {
          continue;
        }
        final sid = lineValue['sid']?.toString();
        final profiles = lineValue['streamProfiles'];
        if (profiles is! List) {
          continue;
        }
        for (final profileValue in profiles) {
          if (profileValue is! Map<String, Object?>) {
            continue;
          }
          final rate = (profileValue['rate'] as num?)?.toInt() ?? 0;
          final codec = (profileValue['codec'] as num?)?.toInt() ?? 0;
          for (final (key, format) in const [('httpsFlv', StreamFormat.flv), ('httpsHls', StreamFormat.hls)]) {
            final urls = profileValue[key];
            if (urls is! List) {
              continue;
            }
            for (final raw in urls) {
              final url = raw?.toString() ?? '';
              if (!(url.startsWith('http://') || url.startsWith('https://')) || !seenUrls.add(url)) {
                continue;
              }
              lines.add(
                LivePlayLine(
                  url: url,
                  headers: headers,
                  format: format,
                  codec: codec == 1 ? 'hevc' : 'avc',
                  lineId: sid == null ? null : 'sid$sid',
                  height: rate == 0 ? null : rate,
                ),
              );
            }
          }
        }
      }
    }
    if (lines.isEmpty) {
      throw SiteNotFoundError('kugoulive streamaddr: no playable URL for $roomId');
    }
    return lines;
  }

  /// Passes a full http(s) image/URL through, else null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    return url;
  }
}
