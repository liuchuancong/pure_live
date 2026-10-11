import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the PandaLive APIs.
abstract final class PandaLiveParser {
  /// API host.
  static const String apiHost = 'api.pandalive.co.kr';

  /// Web origin.
  static const String origin = 'https://www.pandalive.co.kr';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
  };

  /// The room page URL of [userId].
  static String roomUrl(String userId) => '$origin/play/$userId';

  /// The `member/bj` form of [userId].
  static Map<String, String> memberForm(String userId) => {'userId': userId, 'info': 'media'};

  /// The `live/play` form of [userId].
  static Map<String, String> playForm(String userId) => {
    'action': 'watch',
    'userId': userId,
    'password': '',
    'shareLinkType': '',
  };

  /// Validates the `{result, data}` envelope; HTTP 400 is "not found"
  /// ("유저 정보가 없습니다").
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status == 400) {
      throw SiteNotFoundError('pandalive $what: HTTP 400');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('pandalive $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('pandalive $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('pandalive $what: body is not an object');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('pandalive $what: no data object');
    }
    return data;
  }

  /// `member/bj` → the broadcaster facts. The `bjInfo.id` must echo
  /// [userId].
  static ({String userId, int index, String nick, String? avatar, bool live, String? title, Map<String, Object?> media})
  member(String body, {required String userId, int status = 200}) {
    final data = PandaLiveParser.data(body, status: status, what: 'member/bj');
    final info = data['bjInfo'];
    if (info is! Map<String, Object?>) {
      throw const SiteApiChangedError('pandalive member/bj: no bjInfo');
    }
    final id = info['id']?.toString() ?? '';
    if (id.toLowerCase() != userId.toLowerCase()) {
      throw SiteApiChangedError('pandalive member/bj: bjInfo of $id for $userId');
    }
    final index = (info['idx'] as num?)?.toInt();
    if (index == null || index <= 0) {
      throw const SiteApiChangedError('pandalive member/bj: no idx');
    }
    final media = data['media'];
    final mediaMap = media is Map<String, Object?> ? media : const <String, Object?>{};
    final live = mediaMap['isLive'] == true || mediaMap['isLive'] == 1;
    return (
      userId: userId,
      index: index,
      nick: (info['nickName'] ?? info['name'])?.toString() ?? '',
      avatar: _image(info['profileImage'] ?? info['imgPath']),
      live: live,
      title: (mediaMap['title'] ?? info['title'])?.toString(),
      media: mediaMap,
    );
  }

  /// `live/play` → the master playlist URLs (`hls3`, `hls2`, `hls` in
  /// order), the first usable per list.
  static List<String> masters(String body, {int status = 200}) {
    final data = PandaLiveParser.data(body, status: status, what: 'live/play');
    if (data['result'] != true && data['result'] != 1) {
      throw const SiteNotFoundError('pandalive live/play: refused');
    }
    final playlist = data['PlayList'];
    if (playlist is! Map<String, Object?>) {
      throw const SiteApiChangedError('pandalive live/play: no PlayList');
    }
    final masters = <String>[];
    for (final key in const ['hls3', 'hls2', 'hls']) {
      final list = playlist[key];
      if (list is! List) {
        continue;
      }
      for (final entry in list) {
        final url = entry is Map<String, Object?> ? entry['url']?.toString() : entry?.toString();
        if (url != null && url.startsWith('http') && url.contains('.m3u8')) {
          masters.add(url);
          break;
        }
      }
    }
    return masters;
  }

  /// The room snapshot from the member facts and, when live, the title.
  static LiveRoom room(
    ({String userId, int index, String nick, String? avatar, bool live, String? title, Map<String, Object?> media})
    member,
  ) => LiveRoom(
    platform: SiteIds.pandalive,
    roomId: member.userId,
    title: member.title ?? member.nick,
    nick: member.nick,
    avatar: member.avatar,
    cover: member.avatar,
    status: member.live ? LiveStatus.live : LiveStatus.offline,
  );

  /// The play lines of the masters: HLS tiers with their referer.
  static List<LivePlayLine> playLines(List<String> masters, String userId) => [
    for (final (index, url) in masters.indexed)
      LivePlayLine(
        url: url,
        headers: {'user-agent': headers['user-agent']!, 'referer': roomUrl(userId)},
        format: StreamFormat.hls,
        codec: 'avc',
        lineId: 'HLS-$index',
      ),
  ];

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
