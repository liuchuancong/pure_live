import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Inke web and app live APIs.
abstract final class InkeParser {
  /// Web API base.
  static const String webApi = 'https://webapi.busi.inke.cn/web';

  /// App API base.
  static const String appApi = 'https://service.inke.cn/api/live';

  /// Home page, for links.
  static const String origin = 'https://www.inke.cn';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://www.inke.cn/',
  };

  /// The `live_share_pc?uid=` URL.
  static Uri shareUrl(String uid) => Uri.https('webapi.busi.inke.cn', '/web/live_share_pc', {'uid': uid});

  /// The `now_publish?id=` URL.
  static Uri publishUrl(String uid) => Uri.https('service.inke.cn', '/api/live/now_publish', {'id': uid});

  /// A uuid: digits.
  static bool isUid(String value) => RegExp(r'^\d{1,20}$').hasMatch(value.trim());

  /// Decodes a body and returns its `data` object; null when the answer
  /// says the anchor has no broadcast ("当前用户无直播").
  static Map<String, Object?>? data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('inke $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('inke $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('inke $what: body is not an object');
    }
    final data = decoded['data'];
    if (data is String && data.contains('无直播')) {
      return null;
    }
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('inke $what: no data object');
    }
    return data;
  }

  /// `live_share_pc` → the room; null when the anchor is not broadcasting.
  static LiveRoom? room(String body, {required String uid, int status = 200}) {
    final info = data(body, status: status, what: 'live_share_pc');
    if (info == null) {
      return LiveRoom(platform: SiteIds.inke, roomId: uid, status: LiveStatus.offline);
    }
    final liveUid = info['live_uid']?.toString() ?? '';
    final liveStatus = info['status'];
    if (liveUid != uid || !(liveStatus == 1 || liveStatus == '1' || liveStatus == true)) {
      throw SiteApiChangedError('inke live_share_pc: not the live room of $uid');
    }
    final liveId = info['liveid']?.toString() ?? '';
    final owner = info['media_info'];
    final ownerMap = owner is Map<String, Object?> ? owner : const <String, Object?>{};
    final nick = ownerMap['nick']?.toString() ?? '';
    if (liveId.isEmpty || nick.isEmpty) {
      throw const SiteApiChangedError('inke live_share_pc: incomplete live broadcast');
    }
    final name = info['live_name']?.toString() ?? '';
    return LiveRoom(
      platform: SiteIds.inke,
      roomId: uid,
      title: name.isEmpty ? nick : name,
      nick: nick,
      avatar: image(ownerMap['portrait']),
      cover: image(info['portrait']),
      status: LiveStatus.live,
      data: {'liveId': liveId},
    );
  }

  /// `now_publish` → the broadcast's play lines and live facts; null when
  /// the anchor is not live. `stream_addr` is the Wangsu H.264 pull URL,
  /// `stream_multi_addr` the Zego original.
  static ({List<LivePlayLine> lines, String? cover, int? watching, DateTime? startedAt})? broadcast(
    String body, {
    required String uid,
    int status = 200,
  }) {
    final data = InkeParser.data(body, status: status, what: 'now_publish');
    if (data == null) {
      return null;
    }
    final live = data['live'];
    if (live is! Map<String, Object?>) {
      return null;
    }
    if (live['creator']?.toString() != uid) {
      throw SiteApiChangedError('inke now_publish: a broadcast of ${live['creator']} for $uid');
    }
    if ((live['status'] as num?)?.toInt() != 1) {
      return null;
    }
    final lines = <LivePlayLine>[];
    final pull = live['stream_addr']?.toString() ?? '';
    if (pull.startsWith('http')) {
      lines.add(LivePlayLine(url: pull, headers: headers, format: StreamFormat.flv, lineId: 'flv'));
    }
    final origin = live['stream_multi_addr']?.toString() ?? '';
    if (origin.startsWith('http')) {
      lines.add(LivePlayLine(url: origin, headers: headers, format: StreamFormat.flv, lineId: 'original'));
    }
    final numbers = live['numbers'];
    final online = numbers is Map<String, Object?> ? (numbers['real'] as num?)?.toInt() : null;
    final startedSeconds = (live['start_time'] as num?)?.toInt();
    return (
      lines: lines,
      cover: image(live['cover']),
      watching: online ?? (live['online_users'] as num?)?.toInt(),
      startedAt: startedSeconds == null || startedSeconds < 946684800
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedSeconds * 1000, isUtc: true),
    );
  }

  /// Passes a full URL through, else null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
