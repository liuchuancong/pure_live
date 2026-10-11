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

  /// The id of the public-directory area (3.x's `public`).
  static const String publicAreaId = 'public';

  /// The name of the public-directory area (3.x's zh.json
  /// `pandalive_public_directory`).
  static const String directoryAreaName = '公开直播';

  /// The id of the new-broadcaster area: the platform's list of the
  /// broadcasters it marks as new (`onlyNewBj=Y`).
  static const String newBroadcasterAreaId = 'newbj';

  /// The name of the new-broadcaster area.
  static const String newBroadcasterAreaName = '新人主播';

  /// Rows of a directory page (3.x's `directory` size).
  static const int pageSize = 30;

  /// The highest directory page 3.x would ask (1–1000).
  static const int maxPage = 1000;

  /// The most rows a paged answer may carry (3.x's guard).
  static const int maxRows = 64;

  /// The Referer of a directory POST (the website's own directory page).
  static const String directoryReferer = '$origin/live';

  /// The names of the category codes the cards carry.
  static const Map<String, String> areaNames = {
    'ind': '个人直播',
    'talk': '聊天',
    'music': '音乐',
    'game': '游戏',
    'sports': '体育',
    'etc': '其他',
  };

  /// The name of category code [code]: the table's name, else the code as
  /// sent; empty for none.
  static String areaNameOf(Object? code) {
    final text = SiteText.trimmed(code);
    return areaNames[text.toLowerCase()] ?? text;
  }

  /// The catalogue: this site's two areas, both *constant* — the public
  /// directory and the new broadcasters, no request at all (3.x's
  /// `categories`).
  static List<LiveArea> areas() => const [
    LiveArea(id: publicAreaId, name: directoryAreaName),
    LiveArea(id: newBroadcasterAreaId, name: newBroadcasterAreaName, sort: 1),
  ];

  /// The `live/index` form of directory page [page] of [areaId]:
  /// [pageSize] rows by popularity; the new broadcasters add
  /// `onlyNewBj=Y`.
  static Map<String, String> directoryForm(int page, {String areaId = publicAreaId}) => {
    'offset': '${(page - 1) * pageSize}',
    'limit': '$pageSize',
    'orderBy': 'hot',
    if (areaId == newBroadcasterAreaId) 'onlyNewBj': 'Y',
  };

  /// Checks [area] as the caller error it is: null (the public directory)
  /// or one of the two areas; anything else is refused before any request.
  static String checkArea(LiveArea? area) {
    if (area == null) return publicAreaId;
    if (area.id != publicAreaId && area.id != newBroadcasterAreaId) {
      throw ArgumentError.value(area, 'area', 'not a PandaTV directory');
    }
    return area.id;
  }

  /// Checks a page number (1–[maxPage]) as 3.x did before any request.
  static void checkPage(int page) {
    if (page < 1 || page > maxPage) throw RangeError.range(page, 1, maxPage, 'page');
  }

  /// A page of `live/index` asked at [page] of [size]: the directory and
  /// the LIVE search answer with the same envelope.
  ///
  /// This endpoint's answer is *flat* — `list`, `page` and `result` sit at
  /// the top level, unlike `member/bj`'s `{result, data}` — so it is decoded
  /// here rather than through [data]. `page.offset`, `limit` and `page` must
  /// be what was asked and `total` must be a count: a paged answer that does
  /// not echo the request is a changed endpoint, not an empty page. A row
  /// that cannot be a live card is skipped instead of failing the page.
  static LivePage<LiveRoom> livePage(String body, {required int page, int size = pageSize, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('pandalive live/index: HTTP $status');
    }
    final root = SiteJson.decode(body, what: 'pandalive live/index');
    if (SiteCounts.flag(root['result']) != true) {
      throw SiteApiChangedError('pandalive live/index: result ${root['result']}');
    }
    final paging = SiteJson.object(root['page']);
    final offset = (page - 1) * size;
    if (SiteCounts.integer(paging['offset']) != offset ||
        SiteCounts.integer(paging['limit']) != size ||
        SiteCounts.integer(paging['page']) != page) {
      throw SiteApiChangedError('pandalive live/index: page $paging for offset $offset, limit $size');
    }
    final total = SiteCounts.integer(paging['total']);
    if (total == null) {
      throw SiteApiChangedError('pandalive live/index: page.total ${paging['total']}');
    }
    final rows = SiteJson.list(root['list']);
    if (rows.length > maxRows) {
      throw SiteApiChangedError('pandalive live/index: list of ${rows.length} rows');
    }
    final seen = <String>{};
    final items = <LiveRoom>[];
    for (final row in rows) {
      final card = liveCard(SiteJson.object(row));
      if (card != null && seen.add(card.roomId.toLowerCase())) items.add(card);
    }
    final hasMore = offset + rows.length < total;
    return LivePage(items: items, hasMore: hasMore, nextPage: hasMore ? page + 1 : null, totalCount: total);
  }

  /// A live card of a directory row: the broadcast title (else the nick),
  /// the broadcaster's nick and avatar, the snapshot as cover, the
  /// category's name as area, concurrent viewers and the start. Null for a
  /// row without a broadcaster id or that is not on air.
  ///
  /// The site's adult/password/fans-only flags have no counterpart in the
  /// unified restriction enum, so a card carries the state only; a refusal
  /// is the play path's to report.
  static LiveRoom? liveCard(Map<String, Object?> row) {
    final id = normalizeUserId(row['userId']);
    if (id == null || SiteCounts.flag(row['isLive']) != true) return null;
    final nick = SiteText.title(SiteText.text(row['userNick']));
    final title = SiteText.title(SiteText.text(row['title']));
    return LiveRoom(
      platform: SiteIds.pandalive,
      roomId: id,
      title: title.isEmpty ? nick : title,
      nick: nick,
      avatar: _image(row['userImg']),
      cover: _image(row['thumbUrl'] ?? row['ivsThumbnail']),
      areaName: areaNameOf(row['category']),
      status: isRerun(row) ? LiveStatus.replay : LiveStatus.live,
      watching: SiteCounts.integer(row['user']),
      startedAt: koreanTime(row['startTime']),
    );
  }

  /// Whether an on-air broadcast is a recording played again (`onAirType`
  /// or `liveType` `rec`; its title starts with `[녹]`, 녹화): a replay,
  /// as Twitch's reruns. It plays like a live broadcast.
  static bool isRerun(Map<String, Object?> media) =>
      SiteText.trimmed(media['onAirType']) == 'rec' || SiteText.trimmed(media['liveType']) == 'rec';

  /// A `startTime` as a moment in time: the site sends a Korean wall clock
  /// (`yyyy-MM-dd HH:mm:ss`), which is UTC+9 — parsing it as local time
  /// would shift every start by the viewer's offset.
  static DateTime? koreanTime(Object? value) {
    final match = _koreanTime.firstMatch(SiteText.trimmed(value));
    if (match == null) return null;
    final parts = [for (var group = 1; group <= 6; group++) int.parse(match.group(group)!)];
    return DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]).subtract(const Duration(hours: 9));
  }

  /// [value] as a broadcaster id: trimmed, letters, digits and `_`, with an
  /// optional social-login suffix (`@ka`); null for anything else.
  static String? normalizeUserId(Object? value) {
    if (value is! String) return null;
    final id = value.trim();
    return _userId.hasMatch(id) ? id : null;
  }

  static final RegExp _koreanTime = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$');

  static final RegExp _userId = RegExp(r'^[A-Za-z0-9_]{1,64}(?:@[A-Za-z0-9_]{2,16})?$');

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
