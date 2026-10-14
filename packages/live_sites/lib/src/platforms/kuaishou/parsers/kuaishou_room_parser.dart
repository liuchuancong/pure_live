import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_json.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_play_parser.dart';

const _site = 'kuaishou';

/// A room page's answer: the room as the adapter shows it, the raw
/// `playUrls` (a card's descriptor list or the page's `{h264, hevc}` object)
/// and this broadcast's `liveStreamId` (the comment feed's key); null when the
/// room is offline. The stream handle and the danmaku arguments the site
/// builds from these ride in [LiveRoom.runtime].
typedef KuaishouRoomParse = ({LiveRoom room, Object? playUrls, String? liveStreamId});

/// Pure parsing of Kuaishou responses (catalog, search and the room page).
/// Each function takes the response text and status and returns shared models
/// or throws a [KuaishouFailure]; stream assembly is in [KuaishouPlayParser].
abstract final class KuaishouRoomParser {
  /// `live_api/category/data`: the areas of category [categoryId] on one page,
  /// in server order without repeats; picture `poster`, else `iconUrl`. The
  /// server ignores `size` (50 a page); the next page exists while `hasMore`.
  static ({List<LiveArea> areas, bool hasMore}) areas(
    String body, {
    required String categoryId,
    required String categoryName,
    int status = 200,
  }) {
    final data = _apiData(body, status: status, what: 'category/data');
    final list = data['list'];
    if (list is! List) throw KuaishouFailure(_apiChanged, 'category/data: no list (${jsonSnippet(body)})');
    final seen = <String>{};
    final areas = <LiveArea>[];
    for (final raw in list) {
      final item = jsonObject(raw);
      final id = jsonString(item?['id']);
      if (item == null || id == null || !seen.add(id)) continue;
      final poster = imageUrl(item['poster']);
      areas.add(
        LiveArea.normalized(
          platform: _site,
          areaId: id,
          areaName: text(item['name']),
          parentAreaId: categoryId,
          parentAreaName: categoryName,
          iconUrl: poster.isEmpty ? imageUrl(item['iconUrl']) : poster,
        ),
      );
    }
    return (areas: areas, hasMore: areas.isNotEmpty && truthy(data['hasMore']));
  }

  /// `live_api/gameboard/list` and `non-gameboard/list`: live rooms of one
  /// area page, and the paging the server reports (`hasMore`, and the
  /// non-gameboard `cursor` the next page must send). A card without an author
  /// id is skipped.
  static ({List<LiveRoom> rooms, bool hasMore, String? cursor}) areaRooms(String body, {int status = 200}) {
    final data = _apiData(body, status: status, what: 'area rooms');
    final list = data['list'];
    if (list is! List) throw KuaishouFailure(_apiChanged, 'area rooms: no list (${jsonSnippet(body)})');
    final rooms = [for (final item in list) ?_card(item, recommend: false)];
    return (rooms: rooms, hasMore: rooms.isNotEmpty && truthy(data['hasMore']), cursor: jsonString(data['cursor']));
  }

  /// `live_api/home/list`: every group's `gameLiveInfo[].liveInfo[]` in server
  /// order, one card per streamer. Cover and title come from the card
  /// (`poster`, `caption`); the bio stays the introduction.
  static List<LiveRoom> recommendRooms(String body, {int status = 200}) {
    final data = _apiData(body, status: status, what: 'home/list');
    final groups = data['list'];
    if (groups is! List) throw KuaishouFailure(_apiChanged, 'home/list: no list (${jsonSnippet(body)})');
    final seen = <String>{};
    return [
      for (final group in groups)
        for (final label in jsonList(fields(group)['gameLiveInfo']))
          for (final item in jsonList(fields(label)['liveInfo']))
            if (_card(item, recommend: true) case final room? when seen.add(room.roomId)) room,
    ];
  }

  /// `live_api/search/author`: streamers, live or not. `result` 2 is
  /// rate-limited and 10 risk control (both handled in [_apiData]); a `result`
  /// 1 with no list is the no-result answer.
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    final data = _apiData(body, status: status, what: 'search/author');
    final list = data['list'];
    if (list is! List) {
      if (jsonInt(data['result']) == 1) return const [];
      throw KuaishouFailure(_apiChanged, 'search/author: no list (${jsonSnippet(body)})');
    }
    return [
      for (final raw in list)
        if (jsonObject(raw) case final author? when jsonString(author['id']) != null) _searchRoom(author),
    ];
  }

  /// The room page `/u/{id}`: the room as the user asked for it
  /// ([requestedId]; a follow keeps its identity). `isLiving` (true, 1 or
  /// "true") alone decides live or offline; `errorType` 22 is not-found, any
  /// other `errorType` risk control.
  ///
  /// The page has no broadcast title and no room audience, so both stay empty
  /// until a card or the comment feed brings one; the streamer's bio is the
  /// introduction and the notice. [url] is the page's final URL (a
  /// verification redirect is risk control), [userCookie] marks a page read
  /// with the user's cookie (its suspect when refused).
  static KuaishouRoomParse roomDetail(
    String body, {
    required String requestedId,
    int status = 200,
    bool userCookie = false,
    Uri? url,
  }) {
    final state = _pageState(body, status: status, userCookie: userCookie, url: url);
    final room = _playItem(state, userCookie: userCookie);
    final author = fields(room['author']);
    final stream = fields(room['liveStream']);
    final game = fields(room['gameInfo']);
    final description = text(author['description']);
    final liveStreamId = jsonString(stream['id']);
    final id = requestedId.trim();
    final living = truthy(room['isLiving']);
    final playUrls = stream['playUrls'];
    return (
      room: LiveRoom.normalized(
        platform: _site,
        roomId: id,
        content: RoomContent(coverUrl: _cover(stream['poster']), introduction: description, notice: description),
        anchor: LiveAnchor.normalized(
          platform: _site,
          anchorId: id,
          name: text(author['name']),
          avatarUrl: imageUrl(author['avatar']),
          followerCount: parseAudienceNumberOrNull(jsonString(fields(author['counts'])['fan'])),
        ),
        area: LiveArea.normalized(platform: _site, areaName: text(game['name'])),
        audience: const RoomAudience(primaryMetric: LiveAudienceMetricType.onlineViewers),
        broadcast: RoomBroadcast(
          liveStatus: living ? LiveStatus.live : LiveStatus.offline,
          restriction: living
              ? KuaishouPlayParser.qualities(playUrls).isEmpty
                    ? LiveRestriction.unplayable
                    : LiveRestriction.none
              : null,
        ),
        links: RoomLinks(webUrl: KuaishouEndpoints.roomPageUrl(id)),
      ),
      playUrls: playUrls,
      liveStreamId: liveStreamId,
    );
  }

  /// The `window.__INITIAL_STATE__` object of a room page, cut by JSON
  /// structure: a `;` inside a string does not end it, and only a bare
  /// `undefined` becomes null. A page without the state is a verification page
  /// (risk control, the user's cookie suspect when [userCookie]) or an unknown
  /// page (api-changed).
  static Map<String, dynamic> initialState(String html, {bool userCookie = false}) {
    final marker = _stateMarker.firstMatch(html);
    if (marker == null) {
      if (_challenge.hasMatch(html)) {
        throw const KuaishouFailure(KuaishouFailureKind.riskControl, 'room page is a verification page');
      }
      throw const KuaishouFailure(_apiChanged, 'room page: no __INITIAL_STATE__');
    }
    final literal = _objectLiteral(html, marker.end);
    if (literal == null) {
      throw const KuaishouFailure(_apiChanged, 'room page: __INITIAL_STATE__ is not a complete object');
    }
    final state = decodeJson(literal);
    if (state is Map<String, dynamic>) return state;
    throw const KuaishouFailure(_apiChanged, 'room page: __INITIAL_STATE__ is not a JSON object');
  }

  /// The `name=value` pairs of a room page's `set-cookie` header (the session
  /// the bare visit keeps for 30 minutes: `did`, `clientid`, `client_key`,
  /// `kpn`, `kuaishou.live.bfb1s`). The transport joins repeated headers with
  /// `, `, so each field is read out of the one string; unknown names are left
  /// out.
  static Map<String, String> sessionCookies(Map<String, String> headers) {
    final raw = _header(headers, 'set-cookie') ?? '';
    String? field(String name) => RegExp(
      r'(?:^|[;,]\s*)'
      '${RegExp.escape(name)}=([^;,]+)',
    ).firstMatch(raw)?.group(1)?.trim();
    return {
      for (final name in _sessionNames)
        if (field(name) case final value? when value.isNotEmpty) name: value,
    };
  }

  /// The `misc2` device report of a new session's [did] (the fixed webLogger
  /// 3.9.49 values the client imitates).
  static Map<String, Object> devicePayload(String did, {required int timestamp, required int incrementId}) {
    const session = '1eb20f88-51ac-4ecf-8dc3-ace5aefcae4f';
    return {
      'common': {
        'identity_package': {'device_id': did, 'global_id': ''},
        'app_package': {'language': 'zh-CN', 'platform': 10, 'container': 'WEB', 'product_name': 'KS_GAME_LIVE_PC'},
        'device_package': {
          'os_version': 'NT 6.1',
          'model': 'Windows',
          'ua':
              'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/86.0.4240.198 Safari/537.36',
        },
        'need_encrypt': 'false',
        'network_package': {'type': 3},
        'h5_extra_attr':
            '{"sdk_name":"webLogger","sdk_version":"3.9.49","sdk_bundle":"log.common.js","app_version_name":"",'
            '"host_product":"","resolution":"1600x900","screen_with":1600,"screen_height":900,'
            '"device_pixel_ratio":1,"domain":"https://live.kuaishou.com"}',
        'global_attr': '{}',
      },
      'logs': [
        {
          'client_timestamp': timestamp,
          'client_increment_id': incrementId,
          'session_id': session,
          'time_zone': 'GMT+08:00',
          'event_package': {
            'task_event': {
              'type': 1,
              'status': 0,
              'operation_type': 1,
              'operation_direction': 0,
              'session_id': session,
              'url_package': {
                'page': 'GAME_DETAL_PAGE',
                'identity': '5316c78e-f0b6-4be2-a076-c8f9d11ebc0a',
                'page_type': 2,
                'params': '{"game_id":1001,"game_name":"王者荣耀"}',
              },
              'element_package': <String, Object>{},
            },
          },
        },
      ],
    };
  }

  // Helpers -------------------------------------------------------------------

  static const KuaishouFailureKind _apiChanged = KuaishouFailureKind.apiChanged;
  static final RegExp _stateMarker = RegExp(r'window\.__INITIAL_STATE__\s*=\s*');
  static final RegExp _challenge = RegExp('captcha|验证码|安全验证|人机验证|滑块', caseSensitive: false);
  static const Set<String> _sessionNames = {'did', 'clientid', 'client_key', 'kpn', 'kuaishou.live.bfb1s'};

  /// Image extensions the site recognises on covers.
  static const Set<String> _imageExtensions = {
    'svgz', 'pjp', 'png', 'ico', 'avif', 'tiff', 'tif', 'jfif', 'svg', 'xbm', 'pjpeg', 'webp', 'jpg', 'jpeg', //
    'bmp', 'gif',
  };

  /// A list card of the area lists and recommendations. Every card is live (the
  /// lists hold live rooms; the card's own `living` is false even for them).
  /// `LiveRoom.broadcast.startedAt` is the card's `statrtTime` (the platform's
  /// spelling; `startTime` is accepted too), in epoch milliseconds; a card with
  /// a playable stream has no restriction, one without leaves it unknown.
  static LiveRoom? _card(Object? value, {required bool recommend}) {
    final item = jsonObject(value);
    if (item == null) return null;
    final author = fields(item['author']);
    final id = jsonString(author['id']);
    if (id == null) return null;
    final watching = text(item['watchingCount']);
    final caption = text(item['caption']);
    final bio = jsonString(author['description']);
    final flatBio = bio?.replaceAll('\n', ' ');
    return LiveRoom.normalized(
      platform: _site,
      roomId: id,
      content: RoomContent(
        title: recommend && caption.isEmpty ? flatBio ?? '' : caption,
        coverUrl: _cover(item['poster']),
        introduction: recommend ? flatBio ?? '' : null,
        notice: recommend ? bio : null,
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: id,
        name: text(author['name']),
        avatarUrl: imageUrl(author['avatar']),
      ),
      area: LiveArea.normalized(platform: _site, areaName: text(fields(item['gameInfo'])['name'])),
      audience: RoomAudience(
        onlineViewers: parseAudienceNumberOrNull(watching),
        primaryMetric: LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast(
        liveStatus: LiveStatus.live,
        startedAt: _epochMilliseconds(item['statrtTime']) ?? _epochMilliseconds(item['startTime']),
        restriction: KuaishouPlayParser.qualities(item['playUrls']).isEmpty ? null : LiveRestriction.none,
      ),
      links: RoomLinks(webUrl: KuaishouEndpoints.roomPageUrl(id)),
    );
  }

  static LiveRoom _searchRoom(Map<String, dynamic> author) {
    final id = jsonString(author['id'])!;
    final name = text(author['name']);
    final avatar = imageUrl(author['avatar']);
    final counts = fields(author['counts']);
    final banned = fields(author['bannedStatus'])['banned'] == true;
    final living = truthy(author['living']);
    final status = banned
        ? LiveStatus.banned
        : living
        ? LiveStatus.live
        : LiveStatus.offline;
    return LiveRoom.normalized(
      platform: _site,
      roomId: id,
      content: RoomContent(title: name, coverUrl: avatar, introduction: jsonString(author['description'])),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: id,
        name: name,
        avatarUrl: avatar,
        followerCount: parseAudienceNumberOrNull(jsonString(counts['fan'])),
        liveStatus: status,
      ),
      broadcast: RoomBroadcast(liveStatus: status),
      links: RoomLinks(webUrl: KuaishouEndpoints.roomPageUrl(id)),
    );
  }

  /// A cover as the site wrote it: made absolute, and `.jpg` appended when the
  /// path names no image type (the screenshot URLs have no extension). A URL
  /// with a query is kept as is. Empty when there is none.
  static String _cover(Object? value) {
    final url = imageUrl(value);
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.hasQuery || uri.hasFragment) return url;
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    return dot >= 0 && _imageExtensions.contains(name.substring(dot + 1).toLowerCase()) ? url : '$url.jpg';
  }

  /// A time in epoch milliseconds; null for 0, negatives, values that are not
  /// milliseconds (before 2001 or after 2286, such as a time in seconds) and
  /// anything that is not an integer.
  static DateTime? _epochMilliseconds(Object? value) => switch (jsonInt(value)) {
    final int milliseconds when milliseconds >= 1000000000000 && milliseconds < 10000000000000 =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    _ => null,
  };

  /// `liveroom.playList[0]` of a room page, with the `errorType` mapping
  /// applied (22 not-found, anything else risk control).
  static Map<String, dynamic> _playItem(Map<String, dynamic> state, {required bool userCookie}) {
    final list = jsonObject(state['liveroom'])?['playList'];
    final room = list is List && list.isNotEmpty ? jsonObject(list.first) : null;
    if (room == null) throw const KuaishouFailure(_apiChanged, 'room page: liveroom.playList[0] missing');
    final error = room['errorType'];
    if (error != null) {
      final map = jsonObject(error);
      final type = jsonInt(map?['type'] ?? error);
      final title = jsonString(map?['title']) ?? '';
      final detail = 'errorType $type $title'.trim();
      if (type == 22) throw KuaishouFailure(KuaishouFailureKind.notFound, detail);
      throw KuaishouFailure(KuaishouFailureKind.riskControl, detail);
    }
    return room;
  }

  /// The page's `__INITIAL_STATE__`, with the status and the redirect checked.
  static Map<String, dynamic> _pageState(String body, {required int status, required bool userCookie, Uri? url}) {
    _checkStatus(status, 'room page', userCookie: userCookie);
    if (url != null && '${url.host}${url.path}'.toLowerCase().contains('captcha')) {
      throw KuaishouFailure(KuaishouFailureKind.riskControl, 'room page redirected to ${url.host}${url.path}');
    }
    return initialState(body, userCookie: userCookie);
  }

  /// The JavaScript object literal starting at [start], as JSON text: a bare
  /// `undefined` outside strings becomes null.
  static String? _objectLiteral(String text, int start) {
    final backslash = String.fromCharCode(0x5C);
    var index = start;
    while (index < text.length && text.codeUnitAt(index) <= 0x20) {
      index++;
    }
    if (index >= text.length || text[index] != '{') return null;
    final out = StringBuffer();
    var depth = 0;
    var inString = false;
    for (; index < text.length; index++) {
      final char = text[index];
      if (inString) {
        out.write(char);
        if (char == backslash && index + 1 < text.length) {
          out.write(text[++index]);
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{' || char == '[') {
        depth++;
      } else if (char == '}' || char == ']') {
        depth--;
        if (depth == 0) return (out..write(char)).toString();
      } else if (text.startsWith('undefined', index) &&
          !_identifierAt(text, index - 1) &&
          !_identifierAt(text, index + 'undefined'.length)) {
        out.write('null');
        index += 'undefined'.length - 1;
        continue;
      }
      out.write(char);
    }
    return null;
  }

  static bool _identifierAt(String text, int index) {
    if (index < 0 || index >= text.length) return false;
    final unit = text.codeUnitAt(index);
    return (unit >= 0x30 && unit <= 0x39) ||
        (unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A) ||
        unit == 0x24 ||
        unit == 0x5F;
  }
}

/// `data` of a `live_api` answer. List answers carry no `result`; a `result`
/// other than 1 is 2 rate-limited, 10 risk control (the guest gate) or
/// api-changed.
Map<String, dynamic> _apiData(String body, {required int status, required String what}) {
  _checkStatus(status, what);
  final decoded = decodeJson(body);
  final data = jsonObject(jsonObject(decoded)?['data']);
  if (data == null) {
    throw KuaishouFailure(KuaishouFailureKind.apiChanged, '$what: no data object (${jsonSnippet(body)})');
  }
  final result = jsonInt(data['result']);
  if (result != null && result != 1) {
    final detail = '$what: result $result ${jsonString(data['error_msg']) ?? ''}'.trim();
    throw switch (result) {
      2 => KuaishouFailure(KuaishouFailureKind.rateLimited, detail),
      10 => KuaishouFailure(KuaishouFailureKind.riskControl, detail),
      _ => KuaishouFailure(KuaishouFailureKind.apiChanged, detail),
    };
  }
  return data;
}

/// HTTP 429 → rate-limited; 5xx → network; 401 and 403 → risk control; any
/// other non-2xx → api-changed.
void _checkStatus(int status, String what, {bool userCookie = false}) {
  if (status >= 200 && status < 300) return;
  if (status == 429) throw KuaishouFailure(KuaishouFailureKind.rateLimited, '$what: HTTP 429');
  if (status >= 500) throw KuaishouFailure(KuaishouFailureKind.network, '$what: HTTP $status');
  if (status == 401 || status == 403) throw KuaishouFailure(KuaishouFailureKind.riskControl, '$what: HTTP $status');
  throw KuaishouFailure(KuaishouFailureKind.apiChanged, '$what: HTTP $status');
}

/// The header value of [name] in [headers], looked up case-insensitively (the
/// transport lower-cases them, but a caller-supplied map need not be).
String? _header(Map<String, String> headers, String name) {
  final lower = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == lower && entry.value.isNotEmpty) return entry.value;
  }
  return null;
}
