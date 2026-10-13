import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_json.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_play_parser.dart';

const _site = 'douyin';

/// One room answer (enter, reflow or room page): the room as the adapter
/// builds it, this broadcast's room_id (danmaku, deep links), the stream
/// description (`room.stream_url`, live only), the visitor id a room page
/// names, and whether the queried broadcast has ended.
typedef DouyinRoomParse = ({
  LiveRoom room,
  String? roomId,
  Map<String, dynamic>? streamUrl,
  String? userUniqueId,
  bool sessionEnded,
});

/// A page row of a React Server Component payload: whether it is a text row
/// and its decoded value.
typedef _Row = ({bool text, String value});

/// Pure parsing of Douyin responses (catalog, search, rooms and their
/// fallbacks). Each function takes the response text, status and headers and
/// returns shared models or throws a [DouyinFailure]; stream assembly is in
/// [DouyinPlayParser].
abstract final class DouyinRoomParser {
  /// Whether [id] is a broadcast room_id rather than a web_rid: rooms of more
  /// than 16 digits are per-broadcast ids, shorter ones the room's lasting
  /// identity.
  static bool isBroadcastId(String id) => RegExp(r'^\d{17,}$').hasMatch(id.trim());

  /// Whether [address] can be a room address at all (digits, 1–32).
  static bool isRoomKey(String address) => RegExp(r'^\d{1,32}$').hasMatch(address.trim());

  // Status --------------------------------------------------------------------

  /// HTTP-level failures before the body is read: a captcha
  /// (`bdturing-verify`), 429, 5xx, 401/403 and an empty 200 (no ttwid, a
  /// rejected signature) are risk control, throttling or the network; any
  /// other non-2xx is api-changed.
  static void checkHttp(String body, int status, Map<String, String> headers, String what) {
    if (_header(headers, 'bdturing-verify') != null || _header(headers, 'x-vc-bdturing-parameters') != null) {
      throw DouyinFailure(DouyinFailureKind.riskControl, '$what: captcha (bdturing-verify)');
    }
    if (status == 429) throw DouyinFailure(DouyinFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw DouyinFailure(DouyinFailureKind.network, '$what: HTTP $status');
    if (status == 401 || status == 403) throw DouyinFailure(DouyinFailureKind.riskControl, '$what: HTTP $status');
    if (status < 200 || status >= 300) throw DouyinFailure(DouyinFailureKind.apiChanged, '$what: HTTP $status');
    if (body.trim().isEmpty) {
      throw DouyinFailure(DouyinFailureKind.riskControl, '$what: empty body (no ttwid, signature or captcha)');
    }
  }

  /// A JSON API answer: [checkHttp], then `status_code`: 4001038 (no such
  /// web_rid) is not-found, 2483 and 20003 (not signed in) need a login, any
  /// other non-zero code is api-changed. A body that is not JSON is a
  /// challenge page: risk control.
  static Map<String, dynamic> checked(
    String body, {
    required String what,
    required int status,
    Map<String, String> headers = const {},
  }) {
    checkHttp(body, status, headers, what);
    final decoded = decodeJson(body);
    if (decoded is! Map<String, dynamic>) {
      throw DouyinFailure(DouyinFailureKind.riskControl, '$what: not JSON (${jsonSnippet(body)})');
    }
    final code = jsonInt(decoded['status_code']);
    if (code == null || code == 0) return decoded;
    final data = jsonObject(decoded['data']);
    final message = jsonFirstText([decoded['status_msg'], data?['prompts'], data?['message']]) ?? '';
    final detail = '$what: status_code $code $message'.trim();
    throw switch (code) {
      4001038 => DouyinFailure(DouyinFailureKind.notFound, detail),
      2483 || 20003 => DouyinFailure(DouyinFailureKind.needsLogin, detail),
      _ => DouyinFailure(DouyinFailureKind.apiChanged, detail),
    };
  }

  /// The anonymous cookie of a home page response: its `ttwid` and
  /// `UIFID_TEMP` pairs, null without a ttwid. The transport joins repeated
  /// `Set-Cookie` headers with `, `, so the fields are read out of the one
  /// string.
  static String? anonymousCookie(Map<String, String> headers) {
    final raw = _header(headers, 'set-cookie') ?? '';
    String? field(String name) => RegExp('(?:^|[;,]\\s*)$name=([^;,]+)').firstMatch(raw)?.group(1)?.trim();
    final ttwid = field('ttwid');
    if (ttwid == null || ttwid.isEmpty) return null;
    final temporary = field('UIFID_TEMP');
    return temporary == null || temporary.isEmpty ? 'ttwid=$ttwid' : 'ttwid=$ttwid; UIFID_TEMP=$temporary';
  }

  // Catalog -------------------------------------------------------------------

  /// The categories of the home page, whose data is the page's React Server
  /// Component payload (`self.__pace_f.push`). Ids are `id_str,type`; every
  /// category lists itself first as its "all" area. The third level (single
  /// games under a sub-category) follows its sub-category and has it as
  /// parent; a game listed under two sub-categories appears once, under the
  /// first.
  static List<LiveArea> areas(String html, {int status = 200, Map<String, String> headers = const {}}) {
    checkHttp(html, status, headers, 'home page');
    final rows = _flightRows(html);
    final raw = _flightObject(rows, 'categoryData')?['categoryData'];
    if (raw is! List) throw const DouyinFailure(DouyinFailureKind.apiChanged, 'home page: categoryData missing');
    final seen = <String>{};
    return [
      for (final item in raw)
        if (_partition(_jsonObject(item)?['partition']) case final top?)
          ..._areas(top, _list(_jsonObject(item)?['sub_partition']), seen),
    ];
  }

  /// [top] itself, then each sub-partition followed by its own (games).
  static List<LiveArea> _areas(({String id, String name}) top, List<Object?> subs, Set<String> seen) {
    LiveArea? area(({String id, String name})? partition, ({String id, String name}) parent) =>
        partition != null && seen.add(partition.id)
        ? LiveArea.normalized(
            platform: _site,
            areaId: partition.id,
            areaName: partition.name,
            parentAreaId: parent.id,
            parentAreaName: parent.name,
          )
        : null;
    return [
      ?area(top, top),
      for (final sub in subs)
        if (_partition(_jsonObject(sub)?['partition']) case final partition?) ...[
          ?area(partition, top),
          for (final game in _list(_jsonObject(sub)!['sub_partition']))
            ?area(_partition(_jsonObject(game)?['partition']), partition),
        ],
    ];
  }

  /// The `partition` and `partition_type` of an area id `id_str,type`;
  /// anything else is not-found.
  static ({String partition, String type}) partition(String areaId) {
    final comma = areaId.lastIndexOf(',');
    if (comma <= 0 || comma == areaId.length - 1) {
      throw DouyinFailure(DouyinFailureKind.notFound, 'area id "$areaId" is not id_str,type');
    }
    return (partition: areaId.substring(0, comma).trim(), type: areaId.substring(comma + 1).trim());
  }

  /// `partition/detail/room/v2` requested at [offset]: every room is live;
  /// the area is `tag_name`, else [areaName] (the unsigned host leaves it
  /// empty). More pages follow while `data.count` is positive and
  /// `data.offset` (the next offset) advances. An empty 200 with a
  /// `bdturing-verify` is a captcha: risk control.
  static ({List<LiveRoom> rooms, bool hasMore}) partitionRooms(
    String body, {
    required int offset,
    String? areaName,
    int status = 200,
    Map<String, String> headers = const {},
  }) {
    final data = jsonObject(checked(body, what: 'partition rooms', status: status, headers: headers)['data']);
    final list = data?['data'];
    if (data == null || list is! List) {
      throw const DouyinFailure(DouyinFailureKind.apiChanged, 'partition rooms: data.data missing');
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final raw in list) {
      final item = jsonObject(raw);
      final room = jsonObject(item?['room']);
      if (item == null || room == null) continue;
      final owner = jsonObject(room['owner']) ?? const <String, dynamic>{};
      final id = jsonFirstId([item['web_rid'], owner['web_rid'], room['id_str']]);
      if (id == null || !seen.add(id)) continue;
      rooms.add(
        _listRoom(
          id,
          room: room,
          title: jsonText(room['title']) ?? '',
          nick: jsonText(owner['nickname']) ?? '',
          cover: jsonFirstImage([room['cover']]),
          avatar: jsonFirstImage([owner['avatar_thumb']]),
          areaName: jsonText(item['tag_name']) ?? areaName ?? '',
          anchorId: jsonFirstId([owner['id_str']]),
          areaId: jsonFirstText([room['category'], jsonFirstText(_list(room['partition_road_map']).map(_tagTitle))]),
        ),
      );
    }
    final count = jsonInt(data['count']);
    final next = jsonInt(data['offset']);
    return (rooms: rooms, hasMore: (count == null || count > 0) && next != null && next > offset);
  }

  /// `webcast/feed/` recommendations, both generations: the envelope list
  /// (room in `data[].data`, possibly a JSON string, or in `room`) and the
  /// older `data.data` room list. Identity is the web_rid, else the room_id;
  /// duplicates are dropped. A room without an area shows [recommendArea].
  static List<LiveRoom> feed(String body, {int status = 200, Map<String, String> headers = const {}}) {
    final root = checked(body, what: 'feed', status: status, headers: headers);
    var list = root['data'];
    if (list is Map) list = list['data'];
    if (list is! List) throw const DouyinFailure(DouyinFailureKind.apiChanged, 'feed: room list missing');
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final raw in list) {
      final envelope = jsonObject(raw);
      if (envelope == null) continue;
      final room = [
        jsonObject(envelope['data']),
        jsonObject(envelope['room']),
        envelope,
      ].firstWhere((candidate) => candidate != null && _looksLikeRoom(candidate), orElse: () => null);
      if (room == null) continue;
      final owner = jsonObject(room['owner']) ?? jsonObject(envelope['owner']) ?? const <String, dynamic>{};
      final id = jsonFirstId([envelope['web_rid'], owner['web_rid'], room['web_rid'], room['id_str'], room['id']]);
      if (id == null || !seen.add(id)) continue;
      rooms.add(
        _listRoom(
          id,
          room: room,
          title: jsonFirstText([room['title'], envelope['title'], owner['nickname']]) ?? '',
          nick: jsonFirstText([owner['nickname'], envelope['nickname']]) ?? '',
          cover: jsonFirstImage([room['cover'], envelope['cover']]),
          avatar: jsonFirstImage([owner['avatar_thumb'], owner['avatar_large'], envelope['avatar_thumb']]),
          areaName: _feedArea(envelope, room) ?? recommendArea,
          anchorId: jsonFirstId([owner['id_str']]),
          areaId: jsonFirstText([room['category'], envelope['category']]),
        ),
      );
    }
    return rooms;
  }

  /// The area the recommendations show for a room that names none.
  static const String recommendArea = '热门推荐';

  static LiveRoom _listRoom(
    String id, {
    required Map<String, dynamic> room,
    required String title,
    required String nick,
    required String cover,
    required String avatar,
    required String areaName,
    String? anchorId,
    String? areaId,
  }) {
    final online = _online(room);
    final total = _total(room);
    return LiveRoom.normalized(
      platform: _site,
      roomId: id,
      content: RoomContent(title: title, coverUrl: cover),
      anchor: LiveAnchor.normalized(platform: _site, anchorId: anchorId ?? '', name: nick, avatarUrl: avatar),
      area: LiveArea.normalized(platform: _site, areaId: areaId ?? '', areaName: areaName),
      audience: RoomAudience(
        onlineViewers: online,
        totalViewers: total,
        primaryMetric: total != null ? LiveAudienceMetricType.totalViewers : LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: const RoomBroadcast(liveStatus: LiveStatus.live),
      links: RoomLinks(webUrl: '${DouyinEndpoints.origin}/$id'),
    );
  }

  static bool _looksLikeRoom(Map<String, dynamic> value) =>
      value['owner'] is Map || value['title'] != null || value['id_str'] != null || value['stream_url'] is Map;

  /// `tag_name`, else the first title of `partition_road_map` or `tags`.
  static String? _feedArea(Map<String, dynamic> envelope, Map<String, dynamic> room) {
    final direct = jsonFirstText([room['tag_name'], envelope['tag_name']]);
    if (direct != null) return direct;
    for (final source in [room['partition_road_map'], envelope['tags']]) {
      for (final tag in _list(source)) {
        final map = _jsonObject(tag);
        final text = map == null ? null : jsonFirstText([map['title'], map['name'], map['tag_name']]);
        if (text != null) return text;
      }
    }
    return null;
  }

  static ({String id, String name})? _partition(Object? raw) {
    final map = _jsonObject(raw);
    final id = jsonText(map?['id_str']);
    final type = jsonText(map?['type']);
    if (id == null || type == null) return null;
    return (id: '$id,$type', name: jsonText(map?['title']) ?? '');
  }

  static Object? _tagTitle(Object? raw) => _jsonObject(raw)?['title'];

  // Search --------------------------------------------------------------------

  /// Live search (`aweme/v1/web/live/search/`) and general search
  /// (`general/search/stream/`, whose body is hex-length framed JSON
  /// documents). An anonymous request answers 2483: needs a login.
  ///
  /// A room may be nested (`lives.rawdata`, `aweme_info.live_info`, …, JSON
  /// strings included). Identity is `owner.web_rid`, else the room_id;
  /// `status` 2 is live; duplicates are dropped. As in the web client the
  /// card's picture is the streamer's large avatar, then the cover.
  static List<LiveSearchItem> searchRooms(String body, {int status = 200, Map<String, String> headers = const {}}) {
    checkHttp(body, status, headers, 'search');
    final items = <Object?>[];
    for (final chunk in _chunks(body)) {
      final data = checked(chunk, what: 'search', status: 200)['data'];
      if (data is List) items.addAll(data);
    }
    final seen = <String>{};
    return [
      for (final item in items)
        if (_searchRoom(_jsonObject(item) ?? const <String, dynamic>{}) case final result?
            when seen.add(result.room.roomId))
          result,
    ];
  }

  /// `webcast/web/partition/search/`: the partitions whose name matches the
  /// keyword (anonymous), as areas `id_str,type`.
  static List<LiveArea> partitionSearch(String body, {int status = 200, Map<String, String> headers = const {}}) {
    final root = checked(body, what: 'partition search', status: status, headers: headers);
    return [
      for (final item in _list(_jsonObject(root['data'])?['SearchResult']))
        if (_partition(_jsonObject(item)?['partition']) case final area?)
          LiveArea.normalized(platform: _site, areaId: area.id, areaName: area.name),
    ];
  }

  static LiveSearchItem? _searchRoom(Map<String, dynamic> item) {
    Object? at(Object? node, String key) => _jsonObject(node)?[key];
    final raw = [
      at(at(item, 'lives'), 'rawdata'),
      at(at(item, 'lives'), 'raw_data'),
      at(at(item, 'live'), 'rawdata'),
      at(at(item, 'live_info'), 'rawdata'),
      at(at(at(item, 'aweme_info'), 'live_info'), 'rawdata'),
      at(at(item, 'data'), 'rawdata'),
      item['rawdata'],
      item['lives'],
      item['live'],
      item['live_info'],
      at(at(item, 'aweme_info'), 'live_info'),
      item['aweme_info'],
      item['data'],
      item,
    ].map(_jsonObject).firstWhere((candidate) => candidate != null, orElse: () => null);
    if (raw == null) return null;
    final room = _jsonObject(raw['room']) ?? const <String, dynamic>{};
    final owner = _jsonObject(raw['owner']) ?? const <String, dynamic>{};
    final roomOwner = _jsonObject(room['owner']) ?? const <String, dynamic>{};
    final roomId = jsonFirstId([
      raw['id_str'],
      raw['room_id_str'],
      room['id_str'],
      room['id'],
      raw['room_id'],
      raw['roomId'],
    ]);
    if (roomId == null) return null;
    final id = jsonFirstId([owner['web_rid'], raw['web_rid'], roomOwner['web_rid']]) ?? roomId;
    final nickname = jsonFirstText([owner['nickname'], raw['nickname'], roomOwner['nickname'], item['nickname']]) ?? '';
    final roadMap = _list(room['partition_road_map']);
    final live = jsonInt(raw['status']) == 2;
    final online = _online(room) ?? _online(raw);
    final total = _total(room) ?? _total(raw);
    return (
      room: LiveRoom.normalized(
        platform: _site,
        roomId: id,
        content: RoomContent(
          title: jsonFirstText([raw['title'], room['title'], item['title'], item['desc'], nickname]) ?? '',
          coverUrl: jsonFirstImage([owner['avatar_large'], raw['cover'], room['cover'], raw['cover_url']]),
        ),
        anchor: LiveAnchor.normalized(
          platform: _site,
          anchorId: jsonFirstId([owner['id_str'], raw['uid'], raw['id_str']]) ?? '',
          name: nickname,
          avatarUrl: jsonFirstImage([owner['avatar_thumb'], owner['avatar_large']]),
          liveStatus: live ? LiveStatus.live : LiveStatus.offline,
        ),
        area: LiveArea.normalized(
          platform: _site,
          areaId: jsonFirstText([raw['category'], room['category']]) ?? '',
          areaName:
              jsonFirstText([
                raw['video_feed_tag'],
                if (roadMap.isNotEmpty) _jsonObject(roadMap.first)?['title'],
                _jsonObject(raw['partition'])?['title'],
                item['search_keyword'],
              ]) ??
              '',
        ),
        audience: RoomAudience(
          onlineViewers: online,
          totalViewers: total,
          primaryMetric: total != null ? LiveAudienceMetricType.totalViewers : LiveAudienceMetricType.onlineViewers,
        ),
        broadcast: RoomBroadcast(liveStatus: live ? LiveStatus.live : LiveStatus.offline),
        links: RoomLinks(webUrl: '${DouyinEndpoints.origin}/$id'),
      ),
      roomId: roomId,
    );
  }

  // Rooms ---------------------------------------------------------------------

  /// `room/web/enter/` for [webRid] (the identity, as requested): the room is
  /// `data.data[0]`, the streamer `data.user` when the room is offline.
  /// `status` 2 is live and any other status offline; a missing status defers
  /// to `data.room_status` (0 live, 2 ended). 4001038 or an empty list is
  /// not-found; an empty 200 (no ttwid, or a rejected signature) is risk
  /// control.
  static DouyinRoomParse enter(
    String body, {
    required String webRid,
    int status = 200,
    Map<String, String> headers = const {},
  }) {
    final data = jsonObject(checked(body, what: 'enter', status: status, headers: headers)['data']);
    final list = data?['data'];
    if (data == null || list is! List) {
      throw const DouyinFailure(DouyinFailureKind.apiChanged, 'enter: data.data missing');
    }
    if (list.isEmpty) throw DouyinFailure(DouyinFailureKind.notFound, 'enter: no room for $webRid');
    final room = jsonObject(list.first);
    if (room == null) throw const DouyinFailure(DouyinFailureKind.apiChanged, 'enter: data.data[0] is not an object');
    return _parsed(
      webRid: webRid.trim(),
      room: room,
      person: jsonObject(data['user']),
      live: _isLive(room, roomStatus: data['room_status']),
      roadMap: jsonObject(data['partition_road_map']),
    );
  }

  /// `room/reflow/info/` for a broadcast room_id: the identity is
  /// `room.owner.web_rid`; `status` 4 means the queried broadcast ended (the
  /// adapter then re-enters by that web_rid). It is the only room answer that
  /// carries the broadcast's start time.
  static DouyinRoomParse reflow(String body, {int status = 200, Map<String, String> headers = const {}}) {
    final root = checked(body, what: 'reflow', status: status, headers: headers);
    final room = jsonObject(jsonObject(root['data'])?['room']);
    if (room == null) throw const DouyinFailure(DouyinFailureKind.apiChanged, 'reflow: data.room missing');
    final webRid = jsonWebRid(_jsonObject(room['owner'])?['web_rid']);
    if (webRid == null) {
      throw const DouyinFailure(DouyinFailureKind.apiChanged, 'reflow: room.owner.web_rid missing or not numeric');
    }
    return _parsed(webRid: webRid, room: room, live: _isLive(room), sessionEnded: jsonInt(room['status']) == 4);
  }

  /// The web_rid of a reflow answer: digits at `data.room.owner.web_rid`;
  /// null for anything else (a short link's room in the making).
  static String? reflowWebRid(String body) => jsonWebRid(
    _jsonObject(_jsonObject(_jsonObject(_jsonObject(decodeJson(body))?['data'])?['room'])?['owner'])?['web_rid'],
  );

  /// The room page `live.douyin.com/{web_rid}`, the fallback when enter
  /// fails. Its state (`roomStore.roomInfo.room` and `anchor`,
  /// `userStore.odin.user_unique_id`) is in the page's React Server Component
  /// payload; references like `"stream_data": "$13"` are resolved from its
  /// text rows.
  static DouyinRoomParse roomPage(
    String html, {
    required String webRid,
    int status = 200,
    Map<String, String> headers = const {},
  }) {
    checkHttp(html, status, headers, 'room page');
    final rows = _flightRows(html);
    final holder = _flightObject(
      rows,
      'roomStore',
      where: (state) => _jsonObject(_jsonObject(_jsonObject(state['roomStore'])?['roomInfo'])?['room']) != null,
    );
    final state = _jsonObject(_resolve(holder, rows));
    final info = _jsonObject(_jsonObject(state?['roomStore'])?['roomInfo']);
    final room = _jsonObject(info?['room']);
    if (state == null || info == null || room == null) {
      throw const DouyinFailure(DouyinFailureKind.apiChanged, 'room page: roomStore.roomInfo.room missing');
    }
    final visitor = jsonText(_jsonObject(_jsonObject(state['userStore'])?['odin'])?['user_unique_id']);
    return _parsed(
      webRid: webRid.trim(),
      room: room,
      person: _jsonObject(info['anchor']),
      live: _isLive(room),
      userUniqueId: visitor != null && RegExp(r'^\d{19}$').hasMatch(visitor) ? visitor : null,
    );
  }

  /// A detail answer (enter, reflow, room page) as a room. While live:
  ///
  /// - `startedAt` is `start_time`, else `create_time` (Unix seconds; only
  ///   reflow has them, lists write a placeholder 0);
  /// - `restriction` is [LiveRestriction.unplayable] when `stream_url` has no
  ///   video quality for this client, else [LiveRestriction.none];
  /// - the play qualities ride in `streamUrl` for
  ///   [DouyinPlayParser].
  ///
  /// An offline room has none of them. The area is the room's game or its
  /// partition road map.
  static DouyinRoomParse _parsed({
    required String webRid,
    required Map<String, dynamic> room,
    required bool live,
    Map<String, dynamic>? person,
    Map<String, dynamic>? roadMap,
    String? userUniqueId,
    bool sessionEnded = false,
  }) {
    final owner = _jsonObject(room['owner']);
    final anchorFirst = live ? [owner, person] : [person, owner];
    final online = live ? _online(room) : null;
    final total = live ? _total(room) : null;
    final streamUrl = live ? _jsonObject(room['stream_url']) : null;
    final qualities = live ? DouyinPlayParser.qualities(streamUrl) : const <LivePlayQuality>[];
    return (
      room: LiveRoom.normalized(
        platform: _site,
        roomId: webRid,
        content: RoomContent(
          title: jsonText(room['title']) ?? '',
          coverUrl: live ? jsonFirstImage([room['cover']]) : '',
          introduction: jsonText(owner?['signature']),
        ),
        anchor: LiveAnchor.normalized(
          platform: _site,
          anchorId: jsonFirstId([for (final node in anchorFirst) node?['id_str']]) ?? '',
          name: jsonFirstText([for (final node in anchorFirst) node?['nickname']]) ?? '',
          avatarUrl: jsonFirstImage([for (final node in anchorFirst) node?['avatar_thumb']]),
          liveStatus: live ? LiveStatus.live : LiveStatus.offline,
        ),
        area: LiveArea.normalized(platform: _site, areaName: _detailArea(room, roadMap)),
        audience: RoomAudience(
          onlineViewers: online,
          totalViewers: total,
          primaryMetric: total != null ? LiveAudienceMetricType.totalViewers : LiveAudienceMetricType.onlineViewers,
        ),
        broadcast: RoomBroadcast(
          liveStatus: live ? LiveStatus.live : LiveStatus.offline,
          startedAt: live ? epochSeconds(room['start_time']) ?? epochSeconds(room['create_time']) : null,
          restriction: live && qualities.isEmpty ? LiveRestriction.unplayable : LiveRestriction.none,
        ),
        links: RoomLinks(webUrl: '${DouyinEndpoints.origin}/$webRid'),
      ),
      roomId: jsonFirstId([room['id_str'], room['id']]),
      streamUrl: streamUrl,
      userUniqueId: userUniqueId,
      sessionEnded: sessionEnded,
    );
  }

  /// The area a detail answer names: the game (`game_data.game_tag_info.
  /// game_tag_name`), else the most specific title of enter's
  /// `partition_road_map` (sub-partition, then partition). Rooms outside the
  /// game partitions name none (an empty string).
  static String _detailArea(Map<String, dynamic> room, Map<String, dynamic>? roadMap) {
    Object? title(Map<String, dynamic>? node) => _jsonObject(node?['partition'])?['title'];
    return jsonFirstText([
          _jsonObject(_jsonObject(room['game_data'])?['game_tag_info'])?['game_tag_name'],
          title(_jsonObject(roadMap?['sub_partition'])),
          title(roadMap),
        ]) ??
        '';
  }

  /// `status` 2 (number or string) is live and any other status offline; a
  /// missing status defers to enter's `room_status` (0 live, 2 ended).
  /// Without either the room is offline.
  static bool _isLive(Map<String, dynamic> room, {Object? roomStatus}) => switch (jsonInt(room['status'])) {
    final int status => status == 2,
    null => jsonInt(roomStatus) == 0,
  };

  /// `webcast/user/me/`: the signed-in account's nickname. 20003 ("User
  /// doesn't login", also the answer without a cookie) needs a login.
  static String account(String body, {int status = 200, Map<String, String> headers = const {}}) {
    final root = checked(body, what: 'user/me', status: status, headers: headers);
    final name = jsonText(_jsonObject(root['data'])?['nickname']);
    if (name == null) {
      throw DouyinFailure(DouyinFailureKind.apiChanged, 'user/me: data.nickname missing (${jsonSnippet(body)})');
    }
    return name;
  }

  /// The web_rid a room page names, for short links the transport already
  /// followed: the page's room state, else a `web_rid`/`live.douyin.com/…`
  /// reference in its text. Null when the page names none.
  static String? roomIdInPage(String html) {
    try {
      final rows = _flightRows(html);
      final holder = _flightObject(rows, 'roomStore');
      final state = _jsonObject(_resolve(holder, rows));
      final room = _jsonObject(_jsonObject(_jsonObject(state?['roomStore'])?['roomInfo'])?['room']);
      final owner = _jsonObject(room?['owner']);
      final id = jsonWebRid(owner?['web_rid']) ?? jsonWebRid(room?['id_str']);
      if (id != null) return id;
    } on DouyinFailure {
      // A page without the flight payload still names its room in text.
    }
    final match =
        RegExp(r'(?:web_rid|room_id)"?\s*[:=]\s*"?(\d{1,20})').firstMatch(html) ??
        RegExp(r'live\.douyin\.com/(\d{1,20})').firstMatch(html);
    return match == null ? null : jsonWebRid(match.group(1));
  }

  /// A broadcast room_id from a link's path (`…/reflow/{room_id}`).
  static String? broadcastIdInPath(String path) {
    final match = RegExp(r'(?:^|/)reflow/(\d+)(?:/|$)').firstMatch(path);
    return match?.group(1);
  }

  // Audience ------------------------------------------------------------------

  /// The concurrent audience: `user_count`/`user_count_str` first, then the
  /// display value when the room is shown by its online count
  /// (`display_type` 1). An exact integer beats bucketed text.
  static int? onlineViewers(Map<String, dynamic> room) => _online(room);

  static int? _online(Map<String, dynamic> room) {
    final view = _jsonObject(room['room_view_stats']) ?? const <String, dynamic>{};
    final stats = _jsonObject(room['stats']) ?? const <String, dynamic>{};
    return _count(allowZero: true, [
      room['user_count'],
      room['user_count_str'],
      room['online_user_count'],
      room['online_user_for_anchor'],
      if (jsonInt(view['display_type']) == 1) view['display_value'],
      view['user_count'],
      view['online_user_count'],
      view['online_user_for_anchor'],
      stats['user_count'],
      stats['online_user_count'],
      stats['online_user_for_anchor'],
      stats['user_count_str'],
    ]);
  }

  /// The cumulative audience: the room's display value when it is not the
  /// online-count one (`display_type` absent or 3), then the `total_user`
  /// fields; a display type of 1 means the room has no cumulative count.
  static int? totalViewers(Map<String, dynamic> room) => _total(room);

  static int? _total(Map<String, dynamic> room) {
    final view = _jsonObject(room['room_view_stats']) ?? const <String, dynamic>{};
    final stats = _jsonObject(room['stats']) ?? const <String, dynamic>{};
    final type = jsonInt(view['display_type']);
    if (type == 1) return null;
    return _count(allowZero: false, [
      if (type == null || type == 3) view['display_value'],
      view['total_user_str'],
      view['total_user'],
      stats['total_user_str'],
      stats['total_user'],
      room['total_user_str'],
      room['total_user'],
    ]);
  }

  /// The first exact integer among [candidates], else the first text carrying
  /// a figure (`"30.6万"` becomes 306000; the model stores numbers, never the
  /// platform's text); zero only with [allowZero].
  static int? _count(List<Object?> candidates, {required bool allowZero}) {
    for (final candidate in candidates) {
      final value = candidate is bool ? null : jsonInt(candidate);
      if (value != null && (allowZero ? value >= 0 : value > 0)) return value;
    }
    for (final candidate in candidates) {
      final text = candidate is String ? candidate.trim() : '';
      if (text.isEmpty || !RegExp('[0-9]').hasMatch(text)) continue;
      final number = parseAudienceNumberOrNull(text);
      if (number != null && (allowZero || number > 0)) return number;
    }
    return null;
  }

  // Page and chunk reading ----------------------------------------------------

  /// The React Server Component rows of a page by id: `id:<json>` lines and
  /// `id:T<hex byte length>,<text>` text rows, from its `self.__pace_f.push`
  /// chunks.
  static Map<String, _Row> _flightRows(String html) {
    final flight = StringBuffer();
    for (final match in RegExp(r'self\.__pace_f\.push\(\[1,"').allMatches(html)) {
      final start = match.end - 1;
      var index = start + 1;
      while (index < html.length) {
        final unit = html.codeUnitAt(index);
        if (unit == 0x5C) {
          index += 2;
        } else if (unit == 0x22) {
          break;
        } else {
          index++;
        }
      }
      if (index >= html.length) break;
      final chunk = decodeJson(html.substring(start, index + 1));
      if (chunk is! String) throw const DouyinFailure(DouyinFailureKind.apiChanged, 'page: undecodable __pace_f chunk');
      flight.write(chunk);
    }
    final bytes = utf8.encode(flight.toString());
    final rows = <String, _Row>{};
    var position = 0;
    while (position < bytes.length) {
      final colon = bytes.indexOf(0x3A, position);
      if (colon < 0) break;
      final id = latin1.decode(bytes.sublist(position, colon)).trim();
      if (colon + 1 < bytes.length && bytes[colon + 1] == 0x54) {
        final comma = bytes.indexOf(0x2C, colon + 2);
        final size = comma < 0 ? null : int.tryParse(latin1.decode(bytes.sublist(colon + 2, comma)), radix: 16);
        if (size == null) break;
        final end = _min(comma + 1 + size, bytes.length);
        rows[id] = (text: true, value: utf8.decode(bytes.sublist(comma + 1, end), allowMalformed: true));
        position = end;
      } else {
        var end = bytes.indexOf(0x0A, colon + 1);
        if (end < 0) end = bytes.length;
        rows[id] = (text: false, value: utf8.decode(bytes.sublist(colon + 1, end), allowMalformed: true));
        position = end + 1;
      }
    }
    return rows;
  }

  /// The first object in the page's JSON rows that has [key] and satisfies
  /// [where] (pages also carry empty initial stores).
  static Map<String, dynamic>? _flightObject(
    Map<String, _Row> rows,
    String key, {
    bool Function(Map<String, dynamic> object)? where,
  }) {
    for (final row in rows.values) {
      if (row.text || !row.value.contains('"$key"')) continue;
      if (!row.value.startsWith('[') && !row.value.startsWith('{')) continue;
      final decoded = decodeJson(row.value);
      if (decoded == null) continue;
      final found = _findKey(decoded, key, where ?? (_) => true);
      if (found != null) return found;
    }
    return null;
  }

  static Map<String, dynamic>? _findKey(Object? node, String key, bool Function(Map<String, dynamic>) where) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey(key) && where(node)) return node;
      for (final value in node.values) {
        final found = _findKey(value, key, where);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findKey(value, key, where);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Decodes the payload's string encodings: `$$x` is `$x`, `$undefined` is
  /// null and `$<hex id>` is that row (a text row as a string).
  static Object? _resolve(Object? node, Map<String, _Row> rows, [int hops = 0]) {
    if (node is String) {
      if (!node.startsWith(r'$')) return node;
      if (node.startsWith(r'$$')) return node.substring(1);
      if (node == r'$undefined') return null;
      final match = RegExp(r'^\$([0-9a-fA-F]+)$').firstMatch(node);
      final row = match == null ? null : rows[match.group(1)];
      if (row == null || hops > 8) return node;
      if (row.text) return row.value;
      final decoded = decodeJson(row.value);
      return decoded == null ? node : _resolve(decoded, rows, hops + 1);
    }
    if (node is Map<String, dynamic>) return node.map((key, value) => MapEntry(key, _resolve(value, rows, hops)));
    if (node is List) return [for (final value in node) _resolve(value, rows, hops)];
    return node;
  }

  /// The JSON documents of a body; the general search frames them as
  /// `<hex byte length>\r\n<document>\r\n` chunks ending with `0\r\n\r\n`.
  static List<String> _chunks(String body) {
    if (!RegExp(r'^[0-9a-fA-F]+\r?\n').hasMatch(body)) return [body];
    final bytes = utf8.encode(body);
    final documents = <String>[];
    var position = 0;
    while (position < bytes.length) {
      final end = bytes.indexOf(0x0A, position);
      if (end < 0) break;
      final size = int.tryParse(latin1.decode(bytes.sublist(position, end)).trim().split(';').first, radix: 16);
      if (size == null) throw const DouyinFailure(DouyinFailureKind.apiChanged, 'search: bad chunk header');
      if (size == 0) break;
      final start = end + 1;
      if (start + size > bytes.length) {
        throw const DouyinFailure(DouyinFailureKind.apiChanged, 'search: truncated chunk');
      }
      documents.add(utf8.decode(bytes.sublist(start, start + size), allowMalformed: true));
      position = start + size;
      if (position < bytes.length && bytes[position] == 0x0D) position++;
      if (position < bytes.length && bytes[position] == 0x0A) position++;
    }
    if (documents.isEmpty) throw const DouyinFailure(DouyinFailureKind.apiChanged, 'search: no chunk');
    return documents;
  }

  static Map<String, dynamic>? _jsonObject(Object? value) => jsonObject(value);

  static List<Object?> _list(Object? value) => jsonList(value);

  static int _min(int a, int b) => a < b ? a : b;

  static String? _header(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower && entry.value.isNotEmpty) return entry.value;
    }
    return null;
  }
}

/// One search card the room parser recognised: the room and the broadcast
/// room_id behind it (the identity of the result is the room's web_rid).
typedef LiveSearchItem = ({LiveRoom room, String roomId});
