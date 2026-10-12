import 'dart:convert';

import 'package:html/parser.dart' as html;
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
    final code = SiteCounts.integer(header is Map<String, Object?> ? header['code'] : null);
    if (code == 5201) {
      throw SiteNotFoundError('kilakila getRoomInfo: no broadcast $broadcastId');
    }
    if (code == 5966) {
      throw SiteNotFoundError('kilakila getRoomInfo: $broadcastId is a historical replay');
    }
    if (code != null && code != 0 && code != 200) {
      throw SiteApiChangedError('kilakila getRoomInfo: code $code');
    }
    final body = decoded['b'];
    if (body is! Map<String, Object?>) {
      throw const SiteApiChangedError('kilakila getRoomInfo: no b object');
    }
    return body;
  }

  /// The two timelines, by the `type` the endpoint takes: 0 is the hot
  /// timeline (the recommendations), 107 the rising stars.
  static const Map<String, String> timelineNames = {'0': '热门直播', '107': '萌星推荐'};

  /// Rows one timeline page asks for (the site's own pager size).
  static const int timelinePageSize = 10;

  /// How many pages in a row without a new anchor end a browse.
  static const int maxPagesWithoutNew = 3;

  /// The last timeline page read.
  ///
  /// The timelines repeat their anchors page after page — the hot one for
  /// dozens of pages before it says it is the last, the rising stars once
  /// ran past page three hundred — so reading stops here whatever the site
  /// says.
  static const int maxPages = 100;

  /// The catalogue: the site's two constant timelines, so no request is
  /// spent finding them out.
  static List<LiveArea> areas() => [
    for (final (index, entry) in timelineNames.entries.indexed) LiveArea(id: entry.key, name: entry.value, sort: index),
  ];

  /// Whether [areaId] names one of the timelines.
  static bool isTimeline(String areaId) => timelineNames.containsKey(areaId.trim());

  /// The URL of timeline [type]'s page [page] of [pageSize] rows.
  static Uri timelineUrl({required int type, required int page, int pageSize = timelinePageSize}) => Uri.https(
    liveHost,
    '/pcLive/timeline',
    {'tag': '0', 'type': '$type', 'genderType': '0', 'pageNo': '$page', 'pageSize': '$pageSize'},
  );

  /// A `pcLive/timeline` page: the live rows of timeline [type], each
  /// broadcast and each anchor once, and whether the site says another page
  /// follows.
  ///
  /// The answer is wrapped three times — `data.body` for the page, its `h`
  /// for the header and its `b` for the body — and the body must echo the
  /// page asked for. A row of another data kind is skipped (the timelines
  /// carry several), and one that cannot be read costs itself, while a page
  /// with unreadable rows and no usable one is a changed endpoint rather
  /// than an empty timeline. `isLastPage`, a page with no rows and
  /// [maxPages] all end the listing.
  static LivePage<LiveRoom> timeline(String body, {required int page, required int type, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kilakila timeline: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('kilakila timeline: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('kilakila timeline: body is not an object');
    }
    final code = SiteCounts.integer(decoded['code']);
    if (code != null && code != 200) {
      throw SiteApiChangedError('kilakila timeline: code $code ${SiteText.trimmed(decoded['msg'])}'.trim());
    }
    final data = SiteJson.object(SiteJson.path(decoded, ['data', 'body', 'b']));
    final last = data['isLastPage'];
    if (SiteCounts.integer(data['pageNo']) != page ||
        SiteCounts.integer(data['pageSize']) == null ||
        (last != null && last is! bool)) {
      throw SiteApiChangedError('kilakila timeline page $page: echo pageNo ${data['pageNo']}, isLastPage $last');
    }
    final rows = SiteJson.list(data['data']);
    if (rows.length > 1000) {
      throw SiteApiChangedError('kilakila timeline page $page: ${rows.length} rows');
    }
    final broadcasts = <String>{};
    final anchors = <String>{};
    final rooms = <LiveRoom>[];
    var unreadable = 0;
    for (final row in rows) {
      final fields = SiteJson.object(row);
      final kind = SiteCounts.integer(fields['dataType']);
      if (kind != 8 && !(type == 107 && kind == 2)) {
        continue;
      }
      final room = card(SiteJson.object(fields['roomResq']), SiteJson.object(fields['userResp']));
      if (room == null) {
        unreadable++;
        continue;
      }
      if (!broadcasts.add(room.roomId) || !anchors.add(room.nick)) {
        continue;
      }
      rooms.add(room);
    }
    if (rooms.isEmpty && unreadable > 0) {
      throw SiteApiChangedError('kilakila timeline page $page: $unreadable unreadable rows, none usable');
    }
    final hasMore = last != true && rows.isNotEmpty && page < maxPages;
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// One timeline row as a room, or null when its broadcast or broadcaster
  /// cannot be read.
  ///
  /// A row's `roomResq` names the same fields as the room detail, so the
  /// same ones are read: the title, the cover from `backPic` (else the
  /// channel's default background), the listeners now, a positive
  /// `goldPrice` as a paid broadcast, and `actualTime` as the start. A row
  /// whose owner is not the broadcast's own anchor, or that names no title
  /// or broadcaster, is not usable.
  static LiveRoom? card(Map<String, Object?> broadcast, Map<String, Object?> owner) {
    final broadcastId = SiteText.trimmed(broadcast['roomIdStr']);
    final uid = SiteText.trimmed(broadcast['uid']);
    final title = SiteText.title(SiteText.text(broadcast['title']));
    final nick = SiteText.title(SiteText.text(owner['nickname']));
    if (broadcastId.isEmpty || uid.isEmpty || title.isEmpty || nick.isEmpty) {
      return null;
    }
    if (SiteText.trimmed(owner['id']) != uid) {
      return null;
    }
    final price = SiteCounts.integer(broadcast['goldPrice']) ?? 0;
    final startMs = SiteCounts.integer(broadcast['actualTime']);
    return LiveRoom(
      platform: SiteIds.kilakila,
      roomId: broadcastId,
      title: title,
      nick: nick,
      avatar: _picture(owner['headPortraitUrl']),
      cover: _picture(broadcast['backPic']) ?? _picture(broadcast['defaultBackgroundPicUrl']),
      watching: SiteCounts.integer(broadcast['onlineNumber']) ?? SiteCounts.integer(broadcast['watchNumber']),
      status: LiveStatus.live,
      restriction: price > 0 ? LiveRestriction.paid : null,
      startedAt: startMs != null && startMs >= 1000000000000 && startMs < 10000000000000
          ? DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true)
          : null,
    );
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
    final state = SiteCounts.integer(body['status']);
    final price = SiteCounts.integer(body['goldPrice']) ?? 0;
    final startMs = SiteCounts.integer(body['actualTime']);
    final live = state == 4;
    return LiveRoom(
      platform: SiteIds.kilakila,
      roomId: broadcastId,
      title: title,
      nick: nick,
      avatar: _picture(ownerMap['headPortraitUrl']),
      cover: _picture(body['backPic']) ?? _picture(body['defaultBackgroundPicUrl']),
      watching: SiteCounts.integer(body['onlineNumber']) ?? SiteCounts.integer(body['watchNumber']),
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

  /// The longest keyword the search page takes (3.x refused a longer one).
  static const int keywordLimit = 100;

  /// The keyword sent for [keyword]: trimmed and cut to [keywordLimit] UTF-16
  /// code units, never inside a surrogate pair, then trimmed again. Empty when
  /// there is nothing to search for.
  static String searchKeyword(String keyword) {
    var text = keyword.trim();
    if (text.length > keywordLimit) {
      var end = keywordLimit;
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) {
        end--;
      }
      text = text.substring(0, end).trim();
    }
    return text;
  }

  /// The website's user search page of [keyword] ([searchKeyword]; `serach` is
  /// the site's own spelling): `/aboutus/serach/kw/<keyword>`, `/p/<page>`
  /// after page 1.
  static Uri searchUrl(String keyword, int page) => Uri(
    scheme: 'https',
    host: 'live.kilakila.cn',
    pathSegments: [
      'aboutus',
      'serach',
      'kw',
      searchKeyword(keyword),
      if (page > 1) ...['p', '$page'],
    ],
  );

  /// A user search page: the anchors of the `.userList` links `/zhubo/<uid>`,
  /// each once, as rooms named by their `.anchor-name` (also the title) with
  /// the `.anchorHeaderImg` avatar. The page says nothing about broadcasts, so
  /// their state is unknown. An entry whose link is not an anchor page or that
  /// has no name is left out; a page without the list, over 100 entries, or
  /// whose entries are all broken is a changed page.
  static List<LiveRoom> searchPage(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kilakila search: HTTP $status');
    }
    final list = html.parseFragment(body).querySelector('.userList');
    if (list == null || list.children.length > 100) {
      throw const SiteApiChangedError('kilakila search: no user list');
    }
    final rooms = <String, LiveRoom>{};
    var broken = 0;
    for (final anchor in list.children.where((element) => element.localName == 'a')) {
      final match = RegExp(r'^/zhubo/([1-9][0-9]{0,31})$').firstMatch(anchor.attributes['href'] ?? '');
      final nick = anchor.querySelector('.anchor-name')?.text.trim() ?? '';
      if (match == null || nick.isEmpty) {
        broken++;
        continue;
      }
      final uid = match.group(1)!;
      final avatar = anchor.querySelector('.anchorHeaderImg img')?.attributes['src'];
      rooms.putIfAbsent(
        uid,
        () => LiveRoom(platform: SiteIds.kilakila, roomId: uid, nick: nick, title: nick, avatar: _picture(avatar)),
      );
    }
    if (broken > 0 && rooms.isEmpty) {
      throw SiteApiChangedError('kilakila search: $broken broken entries, none usable');
    }
    return rooms.values.toList();
  }

  static String? _picture(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
