import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Baidu Live room command (searchbox 371).
abstract final class BaiduLiveParser {
  /// API request headers.
  static const Map<String, String> apiHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://live.baidu.com/',
  };

  /// The `cmd 371` query for [roomId].
  static Map<String, String> roomQuery(String roomId, {required String deviceId}) => {
    'cmd': '371',
    'action': 'star',
    'service': 'bdbox',
    'osname': 'pc',
    'data': jsonEncode({
      'data': {'room_id': roomId, 'device_id': deviceId, 'source_type': 0},
      'replay_slice': 0,
      'nid': '',
    }),
  };

  /// A room id: 6–20 digits, not starting with zero.
  static final RegExp _roomId = RegExp(r'^[1-9]\d{5,19}$');

  /// A share page's code segment.
  static final RegExp _shareCode = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// [raw] trimmed as a room id (6–20 digits, not starting with zero), or
  /// null.
  static String? normalizeRoomId(String raw) {
    final value = raw.trim();
    return _roomId.hasMatch(value) ? value : null;
  }

  /// A room id or a room link (3.x's `BaiduLiveLink.parseRoomId`), or null
  /// for anything else.
  static String? parseRoomId(String raw) => normalizeRoomId(raw) ?? roomIdFromUrl(raw);

  /// The room of a Baidu Live room link, or null: https or http on
  /// `live.baidu.com` with the scheme's default port, no user info or
  /// fragment, and either `/m/room/<id>` or a `room_id=<id>` on the PC player
  /// or a share page.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    final defaultPort = switch (scheme) {
      'https' => 443,
      'http' => 80,
      _ => null,
    };
    if (defaultPort == null ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'live.baidu.com' ||
        (uri.hasPort && uri.port != defaultPort) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    try {
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
      if (segments.length == 3 && segments[0] == 'm' && segments[1] == 'room' && _roomId.hasMatch(segments[2])) {
        return segments[2];
      }
      final roomId = uri.queryParameters['room_id']?.trim();
      if (roomId == null || !_roomId.hasMatch(roomId)) {
        return null;
      }
      if ('/${segments.join('/')}' == '/m/media/pclive/pchome/live.html') {
        return roomId;
      }
      if (segments.length == 6 &&
          segments.take(5).join('/') == 'm/media/multipage/liveshow/index' &&
          _shareCode.hasMatch(segments.last)) {
        return roomId;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  /// The `data.371` command of a searchbox answer; "not found" when the
  /// command is missing or its error codes say so.
  static Map<String, Object?> commandOf(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('baidulive searchbox: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('baidulive searchbox: body is not JSON');
    }
    final data = decoded is Map<String, Object?> ? decoded['data'] : null;
    final raw = data is Map<String, Object?> ? data['371'] : null;
    if (raw is! Map<String, Object?>) {
      throw const SiteNotFoundError('baidulive: no room command');
    }
    final error = SiteCounts.integer(raw['error_code']);
    if (error == 1 || error == 4) {
      throw SiteNotFoundError('baidulive: error_code $error');
    }
    if (error != 0 && error != null) {
      throw SiteApiChangedError('baidulive searchbox: error_code $error');
    }
    return raw;
  }

  /// The room state from the command.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    final cmd = commandOf(body, status: status);
    final host = cmd['host'];
    final video = cmd['video'];
    if (host is! Map<String, Object?> && video is! Map<String, Object?>) {
      throw const SiteNotFoundError('baidulive: no host or video');
    }
    final hostMap = host is Map<String, Object?> ? host : const <String, Object?>{};
    final videoMap = video is Map<String, Object?> ? video : const <String, Object?>{};
    final stateCode = SiteCounts.integer(cmd['status']);
    final live = stateCode == 0;
    final replay = stateCode == 3;
    final nick = hostMap['nick_name']?.toString() ?? hostMap['name']?.toString() ?? '';
    final cover = videoMap['cover'];
    final coverMap = cover is Map<String, Object?> ? cover : const <String, Object?>{};
    return LiveRoom(
      platform: SiteIds.baiduLive,
      roomId: roomId,
      title: videoMap['title']?.toString() ?? nick,
      nick: nick,
      avatar: _image(
        hostMap['image'] is Map<String, Object?> ? (hostMap['image']! as Map<String, Object?>)['image_33'] : null,
      ),
      cover: _image(coverMap['cover_100'] ?? coverMap['vertical_cover']),
      areaName: cmd['category']?.toString(),
      watching: SiteCounts.integer(cmd['online_users']),
      status: replay
          ? LiveStatus.replay
          : live
          ? LiveStatus.live
          : LiveStatus.offline,
    );
  }

  /// The playable URLs of the room command's video (url_clarity_list and
  /// url_list), de-duplicated.
  static List<LivePlayLine> playLines(String body, {required String roomId, int status = 200}) {
    final cmd = commandOf(body, status: status);
    final video = cmd['video'];
    if (video is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    void add(Object? raw, String protocol, String? codec, int? height) {
      final url = raw?.toString() ?? '';
      if (!(url.startsWith('http://') || url.startsWith('https://')) || !seen.add(url)) {
        return;
      }
      lines.add(
        LivePlayLine(
          url: url,
          headers: apiHeaders,
          format: protocol == 'hls' ? StreamFormat.hls : StreamFormat.flv,
          codec: codec,
          lineId: height == null ? null : 'h$height',
          height: height,
        ),
      );
    }

    final clarity = video['url_clarity_list'];
    if (clarity is List) {
      for (final item in clarity) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final height = SiteCounts.integer(item['resolution']);
        final urls = item['urls'];
        if (urls is! Map<String, Object?>) {
          continue;
        }
        add(urls['avc_flv'], 'flv', 'avc', height);
        add(urls['hls'], 'hls', 'avc', height);
        add(urls['hevc_flv'], 'flv', 'hevc', height);
      }
    }
    final list = video['url_list'];
    if (list is List) {
      for (final item in list) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final height = SiteCounts.integer(item['resolution']);
        final pairs = item['urls'];
        if (pairs is! List) {
          continue;
        }
        for (final pair in pairs) {
          if (pair is! Map<String, Object?>) {
            continue;
          }
          add(pair['flv'], 'flv', 'avc', height);
          add(pair['hls'], 'hls', 'avc', height);
        }
      }
    }
    return lines;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
