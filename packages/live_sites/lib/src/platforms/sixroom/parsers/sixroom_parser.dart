import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the 6.cn (六间房) live APIs.
abstract final class SixRoomParser {
  /// Web origin.
  static const String origin = 'https://v.6.cn';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    'referer': 'https://ios.6.cn/?ver=8.0.3&build=4',
  };

  /// The room page URL of [roomId].
  static Uri roomUrl(String roomId) => Uri.parse('$origin/$roomId');

  /// The inroom POST URL.
  static final Uri inroomUrl = Uri.parse('$origin/coop/mobile/index.php?padapi=coop-mobile-inroom.php');

  /// The inroom form of [userId].
  static Map<String, String> inroomForm(String userId) => {
    'av': '3.1',
    'encpass': '',
    'logiuid': '',
    'project': 'v6iphone',
    'rate': '1',
    'rid': '',
    'ruid': userId,
  };

  /// A room number: 2-12 digits, not starting with 0.
  static bool isRoomId(String value) => RegExp(r'^[1-9]\d{1,11}$').hasMatch(value.trim());

  /// A broadcaster user id: 2-13 digits, not starting with 0.
  static bool isUserId(String value) => RegExp(r'^[1-9]\d{1,12}$').hasMatch(value.trim());

  /// The room id of [raw]: a room number or a `v.6.cn`/`m.6.cn` link.
  static String? roomIdOf(String raw) {
    final value = raw.trim();
    if (isRoomId(value)) {
      return value;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        !(uri.host == 'v.6.cn' || uri.host == 'm.6.cn')) {
      return null;
    }
    for (final segment in uri.pathSegments.reversed) {
      if (isRoomId(segment)) {
        return segment;
      }
    }
    return null;
  }

  static final RegExp _pageIds = RegExp(
    r'''\brid\s*:\s*['"]([1-9]\d{1,12})['"]\s*,\s*roomid\s*:\s*['"]?([1-9]\d{1,11})(?!\d)['"]?''',
  );

  /// The room page → the broadcaster user id of [roomId].
  static String userIdOf(String body, {required String roomId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('sixroom room page: HTTP $status');
    }
    for (final match in _pageIds.allMatches(body)) {
      if (match.group(2) == roomId) {
        return match.group(1)!;
      }
    }
    throw SiteNotFoundError('sixroom room page of $roomId: no rid/roomid');
  }

  /// The inroom answer → the room. `flag` 001 is the payload; 402 is
  /// "not found"; anything else is risk control.
  static LiveRoom room(String body, {required String roomId, required String userId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('sixroom inroom: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('sixroom inroom: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('sixroom inroom: body is not an object');
    }
    final flag = decoded['flag']?.toString() ?? '';
    if (flag != '001') {
      final message = decoded['content']?.toString() ?? '';
      if (flag == '402') {
        throw SiteNotFoundError('sixroom inroom of $userId: $message');
      }
      throw SiteRiskControlError('sixroom inroom of $userId: flag $flag $message'.trim());
    }
    final content = decoded['content'];
    final contentMap = content is Map<String, Object?> ? content : const <String, Object?>{};
    final roomInfo = contentMap['roominfo'];
    final liveInfo = contentMap['liveinfo'];
    final params = contentMap['roomParamInfo'];
    if (roomInfo is! Map<String, Object?> || liveInfo is! Map<String, Object?>) {
      throw const SiteApiChangedError('sixroom inroom: no roominfo or liveinfo');
    }
    final paramsMap = params is Map<String, Object?> ? params : const <String, Object?>{};
    final actualRoomId = roomInfo['rid']?.toString() ?? '';
    final actualUserId = (roomInfo['id'] ?? paramsMap['uid'])?.toString() ?? '';
    if (actualRoomId != roomId || actualUserId != userId.trim()) {
      throw SiteApiChangedError('sixroom inroom of $roomId/$userId names $actualRoomId/$actualUserId');
    }
    final liveId = liveInfo['id']?.toString() ?? '';
    final flvTitle = liveInfo['flvtitle']?.toString() ?? '';
    final live = liveId.isNotEmpty && flvTitle.isNotEmpty;
    final nick = roomInfo['alias']?.toString() ?? '';
    final operation = paramsMap['operation'];
    final operationMood = operation is Map<String, Object?> ? operation['userMood'] : null;
    final title = (liveInfo['title'] ?? roomInfo['userMood'] ?? operationMood ?? nick).toString();
    final startSeconds = (liveInfo['starttime'] as num?)?.toInt();
    return LiveRoom(
      platform: SiteIds.sixroom,
      roomId: roomId,
      title: title,
      nick: nick,
      avatar: _image(roomInfo['headPicUrl'] ?? roomInfo['picuser']),
      cover: _image(liveInfo['spredPic'] ?? liveInfo['largepic'] ?? liveInfo['pic']),
      areaName: (roomInfo['anchor_area'] ?? roomInfo['rtypename'])?.toString(),
      watching: (paramsMap['fans_num'] as num?)?.toInt(),
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
      data: live ? {'userId': actualUserId, 'liveId': liveId, 'flvTitle': flvTitle} : null,
    );
  }

  /// The play lines of a live room whose data carries the flv title: the
  /// `httpflv` address derived from `v<userId>-<liveId>`.
  static List<LivePlayLine> playLines(Object? data) {
    if (data is! Map<String, Object?>) {
      return const [];
    }
    final userId = data['userId']?.toString() ?? '';
    final liveId = data['liveId']?.toString() ?? '';
    final flvTitle = data['flvTitle']?.toString() ?? '';
    if (!isUserId(userId) || !isUserId(liveId)) {
      throw const SiteNotFoundError('sixroom: no stream identity');
    }
    final expected = 'v$userId-$liveId';
    if (!(flvTitle == expected || flvTitle == '$expected-many')) {
      throw SiteApiChangedError('sixroom: stream name $flvTitle for live $liveId');
    }
    return [
      LivePlayLine(
        url: 'https://wlive.6rooms.com/httpflv/$flvTitle.flv',
        headers: headers,
        format: StreamFormat.flv,
        lineId: 'flv',
      ),
    ];
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
