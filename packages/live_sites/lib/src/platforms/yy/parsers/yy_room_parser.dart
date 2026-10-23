import 'dart:convert';

import 'package:live_sites/src/common/normalization/html_entities.dart';
import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_json.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';

/// The listing module of an area page (`pageInfo.pageBar`): what
/// `more/page.action` needs. 3.x stored it as the area's `shortName`.
typedef YyModule = ({int moduleId, String biz, String subBiz});

/// The channel behind a room, apart from its identity: a room asked for by
/// its short number (`www.yy.com/2149`) keeps that number as its identity,
/// while streams and danmaku use the canonical `sid` and `ssid`.
typedef YyChannel = ({String sid, String ssid});

/// What a room page says: the canonical channel, the streamer, the channel
/// title and the area name.
typedef YyRoomPage = ({String sid, String ssid, String uid, String nick, String avatar, String title, String area});

/// One area of the catalog, with the page its listing module is read from.
typedef YyAreaEntry = ({LiveArea area, Uri? page});

/// A parsed room with the channel its streams enter by.
typedef YyLiveRoom = ({LiveRoom room, YyChannel channel});

/// YY's default portraits (`yystatic.com/.../portrait/…`): no avatar.
final RegExp _defaultPortrait = RegExp(r'yystatic\.com/.*portrait', caseSensitive: false);

/// Pure parsing of YY responses (3.x's `YyApi`): the catalog, the listings,
/// the search, the room detail and the room page. Each function takes the
/// response text and status and returns shared models, or throws a
/// [YyFailure]; streams are the play parser's to read.
abstract final class YyRoomParser {
  // Catalog -------------------------------------------------------------------

  /// `yyweb/module/data/header`: the top-level categories (`categoryTabs`).
  static List<({String id, String name})> categoryTabs(String body, {int status = 200}) {
    final root = YyJson.object(YyJson.decoded(body, status: status, what: 'header'));
    final tabs = root?['categoryTabs'];
    if (tabs is! List) {
      throw YyFailure(YyFailureKind.apiChanged, 'header: no categoryTabs (${YyJson.snippet(body)})');
    }
    return [
      for (final raw in tabs)
        if (YyJson.object(raw) case final tab? when YyJson.text(tab['id']).isNotEmpty)
          (id: YyJson.text(tab['id']), name: YyJson.text(tab['title'])),
    ];
  }

  /// Whether an area [page] is a short-video page (`www.yy.com/sv/`, 小视频
  /// under 其他): no live rooms, so the catalog leaves it out.
  static bool isShortVideoPage(Uri? page) {
    final segments = page?.pathSegments.where((segment) => segment.isNotEmpty);
    return segments != null && segments.isNotEmpty && segments.first.toLowerCase() == 'sv';
  }

  /// `category/getCategory.action?parentId=`: the areas of one category in
  /// server order, each with the page its listing module is read from. The
  /// body is JSON served as `text/html`.
  static List<YyAreaEntry> areas(
    String body, {
    required String categoryId,
    required String categoryName,
    int status = 200,
  }) {
    final root = YyJson.object(YyJson.decoded(body, status: status, what: 'getCategory'));
    final data = root?['data'];
    if (data is! List) {
      throw YyFailure(YyFailureKind.apiChanged, 'getCategory: no data (${YyJson.snippet(body)})');
    }
    return [
      for (final raw in data)
        if (YyJson.object(raw) case final item? when YyJson.text(item['id']).isNotEmpty)
          (
            area: LiveArea.normalized(
              platform: yySiteId,
              areaId: YyJson.text(item['id']),
              areaName: YyJson.text(item['title']),
              parentAreaId: categoryId,
              parentAreaName: categoryName,
              iconUrl: YyJson.image(item['cover']),
            ),
            page: YyJson.url(YyJson.https(YyJson.text(item['url']))),
          ),
    ];
  }

  /// The listing module in an area page's `pageInfo`: `moduleId`, `biz` and
  /// `subBiz`, or null when the page has none of them. Server-rendered areas
  /// answer `moduleId: 0` and `biz: 'null'` ([hasListing] is false).
  static YyModule? pageInfo(String html) {
    final source = RegExp(r'pageInfo\s*=\s*(\{[\s\S]*?\})\s*;').firstMatch(html)?.group(1);
    if (source == null) return null;
    final moduleId = int.tryParse(RegExp(r'''moduleId\s*:\s*['"]?(-?\d+)''').firstMatch(source)?.group(1) ?? '');
    final biz = RegExp(r'''biz\s*:\s*['"]([^'"]+)''').firstMatch(source)?.group(1)?.trim() ?? '';
    final subBiz = RegExp(r'''subBiz\s*:\s*['"]([^'"]+)''').firstMatch(source)?.group(1)?.trim() ?? '';
    if (moduleId == null || biz.isEmpty || subBiz.isEmpty) return null;
    return (moduleId: moduleId, biz: biz, subBiz: subBiz);
  }

  /// [module] as 3.x stored it in `LiveArea.shortName`:
  /// `{"moduleId":313,"biz":"dance","subBiz":"idx"}`.
  static String shortName(YyModule module) =>
      jsonEncode({'moduleId': module.moduleId, 'biz': module.biz, 'subBiz': module.subBiz});

  /// The module a stored `shortName` holds (3.x's areas and follows), or
  /// null when it holds none.
  static YyModule? moduleOf(String shortName) {
    final Object? decoded;
    try {
      decoded = jsonDecode(shortName);
    } on FormatException {
      return null;
    }
    final map = YyJson.object(decoded);
    final moduleId = YyJson.integer(map?['moduleId']);
    final biz = YyJson.text(map?['biz']);
    final subBiz = YyJson.text(map?['subBiz']);
    if (moduleId == null || biz.isEmpty || subBiz.isEmpty) return null;
    return (moduleId: moduleId, biz: biz, subBiz: subBiz);
  }

  /// Whether [module] lists rooms. The server-rendered areas (英雄联盟,
  /// 综合, 手机直播) have `moduleId: 0, biz: 'null'`; their listing is
  /// always empty and their rooms render in the page itself.
  static bool hasListing(YyModule module) => module.moduleId != 0 && module.biz != 'null' && module.subBiz != 'null';

  // Listings ------------------------------------------------------------------

  /// `more/page.action`: live rooms of an area (label [area]) or of the
  /// recommendations (labels from [areaNames] by `biz`, else empty: 3.x
  /// showed the raw `biz`, `other` for every recommendation). `data: null`
  /// (an area without listing) is empty. A card without a channel number is
  /// left out.
  static List<YyLiveRoom> roomList(
    String body, {
    String? area,
    Map<String, String> areaNames = const {},
    int status = 200,
  }) {
    final root = YyJson.checked(body, status: status, what: 'page.action');
    final data = root['data'];
    if (data != null && data is! Map) {
      throw const YyFailure(YyFailureKind.apiChanged, 'page.action: data is not an object');
    }
    final list = YyJson.object(data)?['data'];
    if (list != null && list is! List) {
      throw const YyFailure(YyFailureKind.apiChanged, 'page.action: data.data is not a list');
    }
    return [
      for (final raw in YyJson.list(list))
        if (YyJson.object(raw) case final item?)
          ?_liveCard(
            item,
            area: area ?? YyEndpoints.areaOf(item['biz'], areaNames),
            title: item['desc'],
            nick: item['name'],
            avatar: _avatar(YyJson.image(item['avatar'])),
          ),
    ];
  }

  /// A live card of a list or of the room search: the channel is the
  /// identity, the audience is popularity, the room is live. The search's
  /// `liveOn` 0 keeps the room but marks it offline.
  static YyLiveRoom? _liveCard(
    Map<String, dynamic> item, {
    required String area,
    required Object? title,
    required Object? nick,
    required String avatar,
    bool live = true,
  }) {
    final sid = YyJson.channel(item['sid']);
    if (sid == null) return null;
    final ssid = YyJson.channel(item['ssid']) ?? sid;
    final users = parseAudienceNumberOrNull(YyJson.text(item['users']));
    final state = live ? LiveStatus.live : LiveStatus.offline;
    return (
      room: LiveRoom.normalized(
        platform: yySiteId,
        roomId: sid,
        content: RoomContent.of(
          title: YyJson.title(title),
          coverUrl: YyJson.image(item['thumb2']).isEmpty ? YyJson.image(item['thumb']) : YyJson.image(item['thumb2']),
        ),
        anchor: LiveAnchor.normalized(
          platform: yySiteId,
          anchorId: YyJson.text(item['uid']),
          name: YyJson.name(nick),
          avatarUrl: avatar,
          liveStatus: state,
        ),
        area: LiveArea.normalized(platform: yySiteId, areaName: area),
        audience: RoomAudience.of(popularity: users, primaryMetric: LiveAudienceMetricType.popularity),
        broadcast: RoomBroadcast.of(liveStatus: state, startedAt: live ? YyJson.startedAt(item['startTime']) : null),
        links: RoomLinks.of(webUrl: YyEndpoints.roomUrl(sid)),
      ),
      channel: (sid: sid, ssid: ssid),
    );
  }

  // Search --------------------------------------------------------------------

  /// `apiSearch/doSearch.json?t=120`: rooms matching the keyword. Live is
  /// `liveOn` 1 (every result seen so far); the title is `channelName`
  /// without the default title's `正在直播`. Results carry no start time.
  static List<YyLiveRoom> searchRooms(String body, {int status = 200}) => [
    for (final item in _docs(body, status: status, tab: '120'))
      ?_liveCard(
        item,
        area: YyJson.text(item['category']),
        title: item['channelName'],
        nick: item['name'],
        avatar: _avatar(YyJson.image(item['headurl'])),
        live: YyJson.isLive(item['liveOn']),
      ),
  ];

  /// `apiSearch/doSearch.json?t=1`: streamers, live or not. `liveOn` is the
  /// streamer's own state: it agreed with `liveInfoDetail` of the channel in
  /// 59 of 60 checks (2026-09-29). The exception is a shared channel (a
  /// guild's) live with another performer: the streamer is offline while the
  /// channel is not. Neither `t=120` (it misses live streamers whose room
  /// does not match the keyword) nor hiding the state would be more
  /// accurate, so it is kept.
  static List<LiveAnchor> searchAnchors(String body, {int status = 200}) => [
    for (final item in _docs(body, status: status, tab: '1'))
      if (YyJson.channel(item['sid']) ?? YyJson.channel(item['ssid']) case final sid?)
        LiveAnchor.normalized(
          platform: yySiteId,
          anchorId: sid,
          name: YyJson.name(item['name'] ?? item['stageName']),
          avatarUrl: _avatar(YyJson.image(item['headurl'])),
          liveStatus: YyJson.isLive(item['liveOn']) ? LiveStatus.live : LiveStatus.offline,
        ),
  ];

  static List<Map<String, dynamic>> _docs(String body, {required int status, required String tab}) {
    final root = YyJson.object(YyJson.decoded(body, status: status, what: 'doSearch'));
    if (root == null) {
      throw YyFailure(YyFailureKind.apiChanged, 'doSearch: not a JSON object (${YyJson.snippet(body)})');
    }
    if (root['success'] == false || (YyJson.integer(root['status']) ?? 0) != 0) {
      throw YyFailure(
        YyFailureKind.apiChanged,
        'doSearch: status ${root['status']} ${YyJson.text(root['message'])}'.trim(),
      );
    }
    final result = YyJson.object(YyJson.object(root['data'])?['searchResult']);
    if (result == null) {
      throw YyFailure(YyFailureKind.apiChanged, 'doSearch: no searchResult (${YyJson.snippet(body)})');
    }
    return [
      for (final raw in YyJson.list(YyJson.object(YyJson.object(result['response'])?[tab])?['docs']))
        ?YyJson.object(raw),
    ];
  }

  // Rooms ---------------------------------------------------------------------

  /// `api/liveInfoDetail/<sid>/<sid>/0`: the live room of a channel as the
  /// user asked for it ([requestedId], which may be a short number: the
  /// identity of a follow must not change), or null when the channel is not
  /// broadcasting. Offline, unknown and short numbers all answer `data:
  /// null`; the room page tells them apart ([roomPage]). The area is
  /// [areaNames] by `biz`, else empty (3.x showed the raw `biz`, mostly
  /// `other`). The start is `startTime`.
  static YyLiveRoom? liveDetail(
    String body, {
    required String requestedId,
    Map<String, String> areaNames = const {},
    int status = 200,
  }) {
    final root = YyJson.checked(body, status: status, what: 'liveInfoDetail');
    final data = root['data'];
    if (data == null) return null;
    final item = YyJson.object(data);
    if (item == null) {
      throw YyFailure(YyFailureKind.apiChanged, 'liveInfoDetail: data is not an object (${YyJson.snippet(body)})');
    }
    final id = requestedId.trim();
    final sid = YyJson.channel(item['sid']) ?? id;
    final ssid = YyJson.channel(item['ssid']) ?? sid;
    final users = parseAudienceNumberOrNull(YyJson.text(item['users']));
    final room = LiveRoom.normalized(
      platform: yySiteId,
      roomId: id,
      content: RoomContent.of(
        title: YyJson.title(item['desc']),
        coverUrl: YyJson.image(item['thumb2']).isEmpty ? YyJson.image(item['thumb']) : YyJson.image(item['thumb2']),
      ),
      anchor: LiveAnchor.normalized(
        platform: yySiteId,
        anchorId: YyJson.text(item['uid']),
        name: YyJson.name(item['name']),
        avatarUrl: _avatar(YyJson.image(item['avatar'])),
        liveStatus: LiveStatus.live,
      ),
      area: LiveArea.normalized(platform: yySiteId, areaName: YyEndpoints.areaOf(item['biz'], areaNames)),
      audience: RoomAudience.of(popularity: users, primaryMetric: LiveAudienceMetricType.popularity),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live, startedAt: YyJson.startedAt(item['startTime'])),
      links: RoomLinks.of(webUrl: YyEndpoints.roomUrl(id)),
    );
    return (room: room, channel: (sid: sid, ssid: ssid));
  }

  /// The live rooms an area page renders itself. Areas without a JSON
  /// listing (`moduleId: 0`: 手机直播, 综合, 英雄联盟) show their rooms as
  /// `li[data-sid]` cards in the page; a page without cards (小视频, a
  /// short-video page) is empty. Each card gives the title (`data-title`,
  /// cut by the server), cover, streamer, the audience text (`2.1万`) and
  /// the start (the fourth part of `data-pid`, `startTime`).
  static List<YyLiveRoom> pageRooms(String html, {required String area}) => [
    for (final card in _pageCards(html)) ?_pageCard(card, area: area),
  ];

  /// The `li[data-sid]` cards of an area page, in page order: each card's
  /// source, from its opening tag to its matching `</li>`.
  static List<String> _pageCards(String html) {
    final cards = <String>[];
    final openTag = RegExp(r'<li\b[^>]*\bdata-sid\s*=[^>]*>', caseSensitive: false);
    for (final match in openTag.allMatches(html)) {
      var depth = 1;
      var cursor = match.end;
      while (cursor < html.length && depth > 0) {
        final nextClose = html.indexOf('</li', cursor);
        final nextOpen = _nextListOpen(html, cursor);
        if (nextClose < 0) {
          cursor = html.length;
          break;
        }
        if (nextOpen >= 0 && nextOpen < nextClose) {
          depth += 1;
          cursor = nextOpen + 3;
          continue;
        }
        depth -= 1;
        cursor = nextClose + 4;
      }
      final end = html.indexOf('>', cursor);
      cards.add(html.substring(match.start, end < 0 ? cursor : end + 1));
    }
    return cards;
  }

  /// The next `<li` that starts a tag (a `<link` must not count).
  static int _nextListOpen(String html, int from) {
    var at = html.indexOf('<li', from);
    while (at >= 0) {
      if (at + 3 >= html.length) return -1;
      final after = html.codeUnitAt(at + 3);
      // A tag name is followed by whitespace, a slash or `>`.
      if (after == 0x3E || after == 0x2F || after == 0x20 || after == 0x09 || after == 0x0A || after == 0x0D) {
        return at;
      }
      at = html.indexOf('<li', at + 3);
    }
    return -1;
  }

  static YyLiveRoom? _pageCard(String card, {required String area}) {
    final attributes = _attributes(_firstTag(card) ?? '');
    final sid = YyJson.channel(attributes['data-sid']);
    if (sid == null) return null;
    (String, String)? part(String name) => _classElement(card, name);
    String picture((String, String)? part) {
      final source = part?.$1 ?? '';
      return YyJson.image(
        RegExp(
              r'''<img\b[^>]*\bdata-original\s*=\s*["']([^"']*)["']''',
              caseSensitive: false,
            ).firstMatch(source)?.group(1) ??
            '',
      );
    }

    final title = _attribute(_firstTag(part('box')?.$1 ?? '') ?? '', 'data-title');
    final pid = (attributes['data-pid'] ?? '').split('_');
    final room = LiveRoom.normalized(
      platform: yySiteId,
      roomId: sid,
      content: RoomContent.of(
        title: YyJson.title(title.isEmpty ? part('title')?.$2 : title),
        coverUrl: picture(part('cover')),
      ),
      anchor: LiveAnchor.normalized(
        platform: yySiteId,
        anchorId: YyJson.channel(attributes['data-uid']) ?? '',
        name: YyJson.name(part('intro')?.$2),
        avatarUrl: _avatar(picture(part('avt'))),
        liveStatus: LiveStatus.live,
      ),
      area: LiveArea.normalized(platform: yySiteId, areaName: area),
      audience: RoomAudience.of(
        popularity: parseAudienceNumberOrNull(part('usr')?.$2),
        primaryMetric: LiveAudienceMetricType.popularity,
      ),
      broadcast: RoomBroadcast.of(
        liveStatus: LiveStatus.live,
        startedAt: YyJson.startedAt(pid.length > 3 ? pid[3] : null),
      ),
      links: RoomLinks.of(webUrl: YyEndpoints.roomUrl(sid)),
    );
    return (room: room, channel: (sid: sid, ssid: YyJson.channel(attributes['data-ssid']) ?? sid));
  }

  /// The room page `www.yy.com/<sid or short number>`: the canonical channel
  /// (`pageInfo.sid`, `ssid`), the streamer (`nick`, `logo`), the channel
  /// title (`roomName`) and the area name (`owInfo.stringBiz`). The 404 page
  /// (it loads `yycom_404`, with status 200) is not-found.
  static YyRoomPage roomPage(String html, {int status = 200}) {
    YyJson.checkPage(status, 'room page');
    if (status == 404 || html.contains('yycom_404')) {
      throw const YyFailure(YyFailureKind.notFound, 'room page is the 404 page');
    }
    final source = RegExp(r'pageInfo\s*=\s*\{[\s\S]*?\};').firstMatch(html)?.group(0);
    if (source == null) {
      throw YyFailure(YyFailureKind.apiChanged, 'room page: no pageInfo (${YyJson.snippet(html)})');
    }
    String? field(String name) {
      final match = RegExp(r'\b' + name + r'\s*:\s*(?:decodeURIComponent\()?"([^"]*)"').firstMatch(source);
      if (match == null) return null;
      final value = match.group(1)!;
      return YyJson.text(match.group(0)!.contains('decodeURIComponent') ? YyJson.percentDecode(value) : value);
    }

    final sid = YyJson.channel(field('sid'));
    if (sid == null) {
      throw YyFailure(YyFailureKind.apiChanged, 'room page: no sid (${YyJson.snippet(html)})');
    }
    return (
      sid: sid,
      ssid: YyJson.channel(field('ssid')) ?? sid,
      uid: field('uid') ?? '',
      nick: YyJson.name(field('nick')),
      avatar: _avatar(YyJson.image(field('logo'))),
      title: field('roomName') ?? '',
      area: field('stringBiz') ?? '',
    );
  }

  /// The room of a channel that is not broadcasting. Without its [page]
  /// (a refresh of a room whose page was read before) it is 3.x's room: the
  /// id and the state. With the page (room entry, the first refresh) it also
  /// names the streamer, the channel title and area; never a cover, an
  /// audience or a start.
  static LiveRoom offlineRoom({required String requestedId, YyRoomPage? page}) {
    final id = requestedId.trim();
    if (page == null) {
      return LiveRoom.normalized(
        platform: yySiteId,
        roomId: id,
        broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
      );
    }
    return LiveRoom.normalized(
      platform: yySiteId,
      roomId: id,
      content: RoomContent.of(title: page.title),
      anchor: LiveAnchor.normalized(
        platform: yySiteId,
        anchorId: page.uid,
        name: page.nick,
        avatarUrl: page.avatar,
        liveStatus: LiveStatus.offline,
      ),
      area: LiveArea.normalized(platform: yySiteId, areaName: page.area),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
      links: RoomLinks.of(webUrl: YyEndpoints.roomUrl(id)),
    );
  }

  // HTML helpers --------------------------------------------------------------

  /// The first tag of [card] (`<li …>`), or null when there is none.
  static String? _firstTag(String card) {
    final end = card.indexOf('>');
    return end < 0 ? null : card.substring(0, end + 1);
  }

  static final RegExp _attributePattern = RegExp(
    r'''([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''',
  );

  /// The attributes of one tag, lower-cased names, references decoded.
  static Map<String, String> _attributes(String tag) {
    final attributes = <String, String>{};
    for (final match in _attributePattern.allMatches(tag)) {
      final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes.putIfAbsent(match.group(1)!.toLowerCase(), () => decodeHtmlEntities(value));
    }
    return attributes;
  }

  /// The value of [name] in one tag, or ''.
  static String _attribute(String tag, String name) => _attributes(tag)[name.toLowerCase()] ?? '';

  /// The first element of [source] whose `class` names [name]:
  /// `(the element with its tags, its text)`, or null. The element ends at
  /// the first closing tag of its own name; the card's elements hold no
  /// nesting of their kind.
  static (String, String)? _classElement(String source, String name) {
    final pattern = RegExp(
      r'''<([A-Za-z][A-Za-z0-9]*)\b[^>]*\bclass\s*=\s*["\']?[^>"\s]*\b''' + name + r'''\b[^>]*>''',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(source);
    if (match == null) return null;
    final tag = match.group(1)!.toLowerCase();
    final close = source.indexOf('</$tag', match.end);
    if (close < 0) return null;
    final end = source.indexOf('>', close);
    return (
      source.substring(match.start, end < 0 ? source.length : end + 1),
      _textOf(source.substring(match.end, close)),
    );
  }

  /// The text of [html]: tags removed, references decoded.
  static String _textOf(String html) => decodeHtmlEntities(html.replaceAll(RegExp('<[^>]*>'), ''));

  /// An avatar, empty for YY's default portraits.
  static String _avatar(String url) => _defaultPortrait.hasMatch(url) ? '' : url;
}
