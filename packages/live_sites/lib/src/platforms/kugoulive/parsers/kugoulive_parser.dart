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

  /// The area id of the site's recommendations (推荐).
  static const String recommendAreaId = '8000';

  /// The last directory page the site serves (3.x).
  static const int maxPage = 10000;

  /// The area id [area] asks for: [recommendAreaId] for null (the
  /// recommendations), else the area's own id. An area of another kind, or
  /// with an id that is not a short number, is a caller error refused before
  /// any request.
  static String areaId(LiveArea? area) {
    if (area == null) {
      return recommendAreaId;
    }
    final id = SiteText.trimmed(area.id);
    if (SiteText.trimmed(area.parentId) != areaType || !_areaId.hasMatch(id)) {
      throw ArgumentError.value(area, 'area', 'not a Kugou Live area');
    }
    return id;
  }

  static final RegExp _areaId = RegExp(r'^[0-9]{1,8}$');

  static final RegExp _roomId = RegExp(r'^[1-9][0-9]{2,10}$');

  /// The room list of [areaId] at [page]: the recommendations are
  /// `index/list`, another area `index/list_v4` with its `cid`, and the
  /// answers differ in nothing else.
  static Uri directoryUrl(int page, String areaId) {
    final recommend = areaId == recommendAreaId;
    return Uri.https(
      apiHost,
      recommend ? '/mfanxing-home/h5/cdn/room/index/list' : '/mfanxing-home/h5/cdn/room/index/list_v4',
      {
        'pid': '0',
        'kugouId': '0',
        'doubleLiveFirst': '1',
        'sysVersion': '0',
        'platform': '7',
        'device': 'PureLive-Web',
        'channel': '0',
        'version': '99999',
        'longitude': '0',
        'latitude': '0',
        'appid': '1010',
        'liveTypeFilter': '0',
        'isNew': '0',
        'entranceType': '0',
        'uiMode': '0',
        'page': '$page',
        if (!recommend) 'cid': areaId,
      },
    );
  }

  /// A room list page: the cards of `list` (`star` rows unwrapping their own
  /// `data`), a room once, and whether the site has another page. The
  /// answer's `times` dates the cards' `livetime`.
  static LivePage<LiveRoom> directoryPage(String body, {required int page, int status = 200}) {
    final root = decode(body, status: status, what: 'room list');
    if (SiteCounts.integer(root['code']) != 0) {
      throw SiteApiChangedError('kugoulive room list: code ${root['code']}');
    }
    final data = SiteJson.object(root['data']);
    if (data.isEmpty) {
      throw const SiteApiChangedError('kugoulive room list: no data');
    }
    final at = answeredAt(root);
    final seen = <String>{};
    final items = <LiveRoom>[];
    for (final entry in SiteJson.list(data['list'])) {
      final wrapper = SiteJson.object(entry);
      final raw = SiteText.trimmed(wrapper['uiType']) == 'star' ? SiteJson.object(wrapper['data']) : wrapper;
      final room = card(raw, answeredAt: at);
      if (room != null && seen.add(room.roomId)) {
        items.add(room);
      }
    }
    final more = data['hasNextPage'];
    final hasMore = more == true || SiteCounts.integer(more) == 1;
    return LivePage(items: items, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// A card as a room, or null for a row without a room number.
  ///
  /// The title is `label`, else `topicContent`, `performContent` or the nick;
  /// the avatar `userLogo` (a present `logo` only when it is absent), the
  /// cover `imgPath` (else `imagePath`). `viewerNum`/`getViewerNum` are the
  /// viewers and `hot` the popularity — the site publishes one or the other —
  /// and a live card's start is its `livetime`, the broadcast's age in
  /// seconds when the answer was written.
  static LiveRoom? card(Map<String, Object?> raw, {DateTime? answeredAt}) {
    final id = SiteText.trimmed(raw['roomId']);
    if (!_roomId.hasMatch(id)) {
      return null;
    }
    final nick = SiteText.title(SiteText.text(raw['nickName']));
    final state = _state(raw['liveStatus'] ?? raw['status'] ?? raw['liveType']);
    final live = state == LiveStatus.live;
    final viewers = SiteCounts.integer(raw['viewerNum'] ?? raw['getViewerNum']);
    return LiveRoom(
      platform: SiteIds.kugouLive,
      roomId: id,
      title: _firstText([raw['label'], raw['topicContent'], raw['performContent'], nick]),
      nick: nick,
      avatar: image(raw['userLogo'] ?? raw['logo']),
      cover: image(raw['imgPath'] ?? raw['imagePath']),
      status: state,
      watching: viewers ?? SiteCounts.integer(raw['hot']),
      onlineViewers: viewers,
      startedAt: live ? listStart(raw['livetime'], answeredAt) : null,
    );
  }

  /// A card's state (`liveStatus`, else `status`, else `liveType`): a
  /// positive value is live (1 a camera, 6 a phone or game broadcast), 0 or
  /// -1 offline, anything else unknown.
  static LiveStatus _state(Object? value) => switch (SiteCounts.integer(value)) {
    final int state when state > 0 => LiveStatus.live,
    0 || -1 => LiveStatus.offline,
    _ => LiveStatus.unknown,
  };

  /// When the platform wrote an answer: its root `times` (milliseconds,
  /// seconds when implausibly small), and only a plausible moment — in
  /// 2000–2099 — else null.
  static DateTime? answeredAt(Map<String, Object?> root) {
    final value = SiteCounts.integer(root['times']);
    if (value == null || value <= 0) {
      return null;
    }
    final time = DateTime.fromMillisecondsSinceEpoch(value >= 100000000000 ? value : value * 1000, isUtc: true);
    return _plausible(time, null);
  }

  /// A list card's start: `livetime` is the broadcast's age in seconds at the
  /// moment the answer was written, so it began that moment minus the age.
  static DateTime? listStart(Object? liveSeconds, DateTime? answeredAt) {
    final seconds = SiteCounts.integer(liveSeconds);
    if (answeredAt == null || seconds == null || seconds < 0) {
      return null;
    }
    return _plausible(answeredAt.subtract(Duration(seconds: seconds)), answeredAt);
  }

  static final DateTime _earliest = DateTime.utc(2000);
  static final DateTime _latest = DateTime.utc(2100);

  /// How far a start may lie after the answer's own time (servers' clocks).
  static const Duration _skew = Duration(minutes: 5);

  /// [time] when it lies in 2000–2099 and (when known) not after
  /// [answeredAt], give or take [_skew]; else null.
  static DateTime? _plausible(DateTime time, DateTime? answeredAt) =>
      time.isBefore(_earliest) || !time.isBefore(_latest) || (answeredAt != null && time.isAfter(answeredAt.add(_skew)))
      ? null
      : time;

  /// The first of [values] whose text is neither empty nor the literal
  /// `null` the site writes into fields it does not use.
  static String _firstText(List<Object?> values) {
    for (final value in values) {
      final text = SiteText.title(SiteText.text(value));
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return '';
  }

  /// The areas the site's own home page links.
  ///
  /// There is no catalogue endpoint: the page carries the areas as
  /// `/pcindex/category/<id>` links with a `title`, in the order the site
  /// shows them, and that is what is read here. The per-user routes are left
  /// out — they are "my rooms" rather than subjects — and when the page
  /// carries no such link at all the known list [fallbackAreas] is used,
  /// because a page redesign must not leave the picker empty.
  static List<LiveArea> areas(String html, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('kugoulive home page: HTTP $status');
    }
    final seen = <String>{};
    final found = <({String id, String name})>[
      for (final match in _areaLink.allMatches(html))
        if (SiteText.title(SiteText.text(match.group(2))) case final name
            when !_personalRoutes.contains(match.group(1)) && name.isNotEmpty && seen.add(match.group(1)!))
          (id: match.group(1)!, name: name),
    ];
    return [for (final area in found.isEmpty ? fallbackAreas : found) _area(area.id, area.name)];
  }

  /// The category a stored area belongs to (the site has one).
  static LiveArea _area(String id, String name) => LiveArea(id: id, name: name, parentId: areaType);

  /// The areas the site is known to have, used when its page links none.
  static const List<({String id, String name})> fallbackAreas = [
    (id: '8000', name: '推荐'),
    (id: '100001', name: '一起玩'),
    (id: '100002', name: '音乐'),
    (id: '31050', name: '高清'),
    (id: '7024', name: '舞蹈'),
    (id: '1009', name: '颜值'),
    (id: '1001', name: '新秀'),
    (id: '3007', name: '酷次元'),
    (id: '7041', name: '搞笑'),
    (id: '31', name: '国风'),
    (id: '6201', name: '游戏女神'),
    (id: '6007', name: '王者荣耀'),
  ];

  /// The area links of the home page.
  static final RegExp _areaLink = RegExp(
    r'''href=["\'](?:https://fanxing\.kugou\.com)?/pcindex/category/(\d{1,8})[^"\']*["\'][^>]*title=["\']([^"\']+)["\']''',
    caseSensitive: false,
  );

  /// Routes of the site's own pages that are not subjects.
  static const Set<String> _personalRoutes = {'3001', '3009', '3014', '3015'};

  /// The one category name the site's areas belong to.
  static const String areaType = 'official';
}
