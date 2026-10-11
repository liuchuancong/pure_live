import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the YY web APIs and room pages.
abstract final class YyParser {
  /// Validates a JSON envelope (`code == 0` / `res == 0`) and returns it.
  static Map<String, Object?> checked(String body, {int status = 200, String what = 'response'}) {
    if (status == 404) {
      throw const SiteNotFoundError('yy response: HTTP 404');
    }
    if (status >= 500) {
      throw SiteApiChangedError('yy $what: HTTP $status');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('yy $what: HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('yy $what: body is not JSON');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('yy $what: body is not an object');
    }
    final code = (root['code'] as num?)?.toInt() ?? (root['res'] as num?)?.toInt() ?? 0;
    if (code != 0) {
      throw SiteApiChangedError('yy $what: code $code ${root['message']?.toString() ?? ''}'.trim());
    }
    return root;
  }

  /// `api/liveInfoDetail/<sid>/<sid>/0` → the live room, or null when the
  /// channel is not streaming (`data` absent).
  static LiveRoom? liveDetail(String body, {required String requestedId, int status = 200}) {
    final root = checked(body, status: status, what: 'liveInfoDetail');
    final data = root['data'];
    if (data == null) {
      return null;
    }
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('yy liveInfoDetail: data is not an object');
    }
    final sid = channel(data['sid']) ?? requestedId;
    final ssid = channel(data['ssid']) ?? sid;
    return LiveRoom(
      platform: SiteIds.yy,
      roomId: requestedId,
      title: data['desc']?.toString() ?? '',
      nick: data['name']?.toString() ?? '',
      avatar: image(data['avatar']),
      cover: image(data['thumb2']) ?? image(data['thumb']),
      areaName: data['biz']?.toString(),
      watching: int.tryParse(data['users']?.toString() ?? ''),
      status: LiveStatus.live,
      data: {'sid': sid, 'ssid': ssid},
    );
  }

  /// The channel number from a value that may be `number_plain` or
  /// prefixed; digits only.
  static String? channel(Object? value) {
    final digits = (value?.toString() ?? '').replaceAll(RegExp('[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  /// The room page of a channel number: `pageInfo = {…}` carrying the
  /// sid/ssid pair (and streamer facts) for channels whose number is not
  /// their sid.
  static ({String sid, String ssid, String? nick, String? title}) roomPage(String html) {
    if (html.contains('yycom_404')) {
      throw const SiteNotFoundError('yy room page is the 404 page');
    }
    final source = RegExp(r'pageInfo\s*=\s*\{[\s\S]*?\};').firstMatch(html)?.group(0);
    if (source == null) {
      throw const SiteApiChangedError('yy room page: no pageInfo');
    }
    String? field(String name) {
      final match = RegExp('\\b$name\\s*:\\s*(?:decodeURIComponent\\()?"([^"]*)"').firstMatch(source);
      if (match == null) {
        return null;
      }
      return match.group(1);
    }

    final sid = channel(field('sid'));
    if (sid == null) {
      throw const SiteApiChangedError('yy room page: no sid');
    }
    return (sid: sid, ssid: channel(field('ssid')) ?? sid, nick: field('nick'), title: field('roomName'));
  }

  /// The offline room snapshot for a channel: identity and state only.
  static LiveRoom offlineRoom(String requestedId, {String? sid, String? ssid}) => LiveRoom(
    platform: SiteIds.yy,
    roomId: requestedId,
    status: LiveStatus.offline,
    data: sid == null ? null : {'sid': sid, 'ssid': ssid ?? sid},
  );

  /// Play lines of a stream-manager answer: every `stream_line_addr`
  /// entry in server order, de-duplicated by URL.
  static List<LivePlayLine> playLines(Map<String, Object?> streams) {
    final avp = streams['avp_info_res'];
    final addresses = avp is Map<String, Object?> ? avp['stream_line_addr'] : null;
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    if (addresses is Map<String, Object?>) {
      for (final value in addresses.values) {
        if (value is! Map<String, Object?>) {
          continue;
        }
        final cdn = value['cdn_info'];
        var url = cdn is Map<String, Object?> ? cdn['url']?.toString() ?? '' : '';
        if (url.startsWith('//')) {
          url = 'https:$url';
        }
        if (!url.startsWith('http') || !seen.add(url)) {
          continue;
        }
        final lineSeq = value['line_seq']?.toString();
        lines.add(LivePlayLine(url: url, format: StreamFormat.flv, lineId: lineSeq == null ? null : 'line-$lineSeq'));
      }
    }
    return lines;
  }

  /// `more/page.action` → one page of rooms.
  ///
  /// The envelope is `data.data` (the endpoint wraps its own payload once).
  /// Each card's label comes from `biz` — the site's module name, not a
  /// human area name — so [areaNames] translates the ones this build knows
  /// and an unknown module leaves the area empty rather than showing `other`
  /// on every card.
  ///
  /// Cards without a numeric `sid` are dropped: the lists mix in
  /// advertisements and banner entries.
  static LivePage<LiveRoom> roomList(
    Map<String, Object?> root, {
    String? area,
    Map<String, String> areaNames = const {},
  }) {
    final data = SiteJson.object(root['data']);
    final rows = SiteJson.objects(data['data']);
    final rooms = <LiveRoom>[
      for (final item in rows)
        if (channel(item['sid']) case final sid?)
          _card(item, sid, area: area ?? areaNames[SiteText.trimmed(item['biz'])] ?? ''),
    ];
    // The endpoint answers about thirty rooms per page and reports no total,
    // so a full page is the only signal there may be more.
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.length >= _pageRows);
  }

  /// The rows one page holds; used only to guess at more pages, which is all
  /// this endpoint allows.
  static const int _pageRows = 30;

  /// The module a page's `pageInfo` blob names, or null when it carries none.
  static ({int moduleId, String biz, String subBiz})? pageInfo(String html) {
    final source = RegExp(r'pageInfo\s*=\s*(\{[\s\S]*?\})\s*;').firstMatch(html)?.group(1);
    if (source == null) {
      return null;
    }
    final moduleId = SiteCounts.integer(RegExp(r'''moduleId\s*:\s*['\"]?(-?\d+)''').firstMatch(source)?.group(1));
    final biz = SiteText.trimmed(RegExp(r'''biz\s*:\s*['\"]([^'\"]+)''').firstMatch(source)?.group(1));
    final subBiz = SiteText.trimmed(RegExp(r'''subBiz\s*:\s*['\"]([^'\"]+)''').firstMatch(source)?.group(1));
    if (moduleId == null || biz.isEmpty || subBiz.isEmpty) {
      return null;
    }
    return (moduleId: moduleId, biz: biz, subBiz: subBiz);
  }

  /// The module a stored area carries (3.x kept it in the area's short name);
  /// null when the text holds no module.
  static ({int moduleId, String biz, String subBiz})? moduleOf(String shortName) {
    Object? decoded;
    try {
      decoded = jsonDecode(shortName);
    } on FormatException {
      return null;
    }
    final map = SiteJson.object(decoded);
    final moduleId = SiteCounts.integer(map['moduleId']);
    final biz = SiteText.trimmed(map['biz']);
    final subBiz = SiteText.trimmed(map['subBiz']);
    if (moduleId == null || biz.isEmpty || subBiz.isEmpty) {
      return null;
    }
    return (moduleId: moduleId, biz: biz, subBiz: subBiz);
  }

  /// Whether a module has a JSON listing at all.
  ///
  /// An area whose module id is 0 (手机直播, 综合, 英雄联盟) renders its rooms
  /// inside its own page and answers no listing request; asking for one used
  /// to be an HTTP 400.
  static bool hasListing(({int moduleId, String biz, String subBiz}) module) =>
      module.moduleId != 0 && module.biz != 'null' && module.subBiz != 'null';

  /// The rooms of an area page whose module has no listing: the cards the
  /// page itself renders.
  ///
  /// Such an area cannot be paged — there is no second page to ask for —
  /// which is why the answer is a single page with no continuation.
  static LivePage<LiveRoom> pageRooms(String html, {required String area}) {
    final source = RegExp(r'initData\s*=\s*(\{[\s\S]*?\});').firstMatch(html)?.group(1);
    if (source == null) {
      return const LivePage<LiveRoom>(items: []);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const SiteApiChangedError('yy area page: initData is not JSON');
    }
    final rooms = <LiveRoom>[
      for (final item in SiteJson.objects(SiteJson.path(decoded, ['data', 'list'])))
        if (channel(item['sid']) case final sid?) _card(item, sid, area: area),
    ];
    return LivePage<LiveRoom>(items: rooms);
  }

  /// One card.
  static LiveRoom _card(Map<String, Object?> item, String sid, {required String area}) {
    final users = SiteCounts.integer(item['users']);
    return LiveRoom(
      platform: SiteIds.yy,
      roomId: sid,
      title: title(item['desc']),
      nick: SiteText.title(SiteText.text(item['name'])),
      avatar: image(item['avatar']),
      cover: image(item['thumb2']) ?? image(item['thumb']),
      areaName: area,
      watching: users,
      status: LiveStatus.live,
      startedAt: startedAt(item['startTime']),
      data: {'sid': sid, 'ssid': channel(item['ssid']) ?? sid},
    );
  }

  /// A room title without YY's default suffix.
  ///
  /// A room whose streamer never set a title is named `<nickname> 正在直播` by
  /// the site, so showing that as the title repeats the streamer's name on
  /// every card. The suffix is stripped only when it is the whole tail —
  /// a streamer may well have typed it themselves.
  static String title(Object? value) {
    final text = SiteText.title(SiteText.text(value));
    return text.endsWith(liveSuffix) ? text.substring(0, text.length - liveSuffix.length).trim() : text;
  }

  /// The suffix YY appends to a room without a title of its own.
  static const String liveSuffix = '正在直播';

  /// When a broadcast started: Unix seconds, or null for the site's 0 and
  /// for values that are plainly milliseconds.
  static DateTime? startedAt(Object? value) {
    final seconds = SiteCounts.integer(value);
    if (seconds == null || seconds <= 0 || seconds > 100000000000) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// The module names this build can translate; an unknown one leaves the
  /// card's area empty.
  static const Map<String, String> bizAreaNames = {
    'sing': '音乐',
    'talk': '脱口秀',
    'dance': '舞蹈',
    'red': '户外',
    'pretty': '颜值',
    'mc': '喊麦',
    'sport': '体育',
    'car': '二次元',
    'game': '王者荣耀',
    'zonghe': '综合',
  };

  /// The headers a directory, area-page or search request needs.
  static const Map<String, String> apiHeaders = SiteHeaders.json;

  /// `doSearch.json?t=120` → the live rooms matching a keyword.
  ///
  /// The payload nests the results three levels deep
  /// (`data.searchResult.response.<tab>.docs`) and reports its own failure in
  /// a `success` flag plus a status code, which is checked before the list is
  /// read — a search that failed and a search that found nothing are
  /// different answers. The tab is `120` for live rooms; the site's own
  /// search page uses the same tab for the same list. `category` is the area
  /// name and `liveOn` the channel's state.
  static LivePage<LiveRoom> searchRooms(Map<String, Object?> root) {
    final docs = _searchDocs(root, tab: '120');
    final rooms = <LiveRoom>[
      for (final item in docs)
        if (channel(item['sid']) case final sid?)
          LiveRoom(
            platform: SiteIds.yy,
            roomId: sid,
            title: title(item['channelName']),
            nick: SiteText.title(SiteText.text(item['name'])),
            avatar: image(item['headurl']),
            cover: image(item['posterurl']),
            areaName: SiteText.trimmed(item['category']),
            watching: SiteCounts.integer(item['users']),
            status: SiteCounts.flag(item['liveOn']) ?? false ? LiveStatus.live : LiveStatus.offline,
            data: {'sid': sid, 'ssid': channel(item['ssid']) ?? sid},
          ),
    ];
    // Sixteen rows a page and no total: a full page is the only hint of more.
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.length >= _searchPageRows);
  }

  /// The rows a search tab answers with.
  static List<Map<String, Object?>> _searchDocs(Map<String, Object?> root, {required String tab}) {
    if (root['success'] == false || (SiteCounts.integer(root['status']) ?? 0) != 0) {
      throw SiteApiChangedError('yy doSearch: status ${root['status']} ${SiteText.trimmed(root['message'])}'.trim());
    }
    final response = SiteJson.path(root, ['data', 'searchResult', 'response']);
    return SiteJson.objects(SiteJson.path(response, [tab, 'docs']));
  }

  /// How many rows one search page holds.
  static const int _searchPageRows = 16;

  /// Passes a non-empty image URL through, else null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
