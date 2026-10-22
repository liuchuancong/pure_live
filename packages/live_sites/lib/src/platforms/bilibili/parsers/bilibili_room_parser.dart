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
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_json.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name rules that govern the public
// surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Pure parsing of Bilibili responses (catalog, search, rooms, the gift table
/// and the anonymous session). Each function takes the response text and
/// status and returns shared models or throws a [BilibiliFailure]; stream
/// assembly is in `bilibili_play_parser.dart`, the danmaku wire format in
/// `danmaku/bilibili_danmaku_codec.dart`.
abstract final class BilibiliRoomParser {
  /// The codes that mean "no such room"; the same answer for a room the
  /// platform hid is reported as not-found rather than as an API change.
  static const Set<int> notFoundCodes = {-404, 19002000, 60004};

  /// The `{code, message, data}` envelope. HTTP 412 and code `-412` are
  /// throttling, HTTP 5xx is the network, `-352` is WBI risk control, `-101`
  /// needs a login and a code in [notFoundCodes] (or [extraNotFound]) is
  /// not-found; any other non-zero code, a non-2xx status or a body that is
  /// not an object is api-changed.
  static Map<String, dynamic> checked(
    String body, {
    required String what,
    int status = 200,
    Set<int> extraNotFound = const {},
  }) {
    if (status == 412) throw BilibiliFailure(BilibiliFailureKind.rateLimited, '$what: HTTP 412');
    if (status >= 500) throw BilibiliFailure(BilibiliFailureKind.network, '$what: HTTP $status');
    final ok = status >= 200 && status < 300;
    final decoded = decodeJson(body);
    if (decoded is! Map<String, dynamic>) {
      throw BilibiliFailure(
        BilibiliFailureKind.apiChanged,
        '$what: ${ok ? 'not a JSON object' : 'HTTP $status'} (${jsonSnippet(body)})',
      );
    }
    final code = jsonInt(decoded['code']);
    if (code == 0 && ok) return decoded;
    final message = jsonString(decoded['message']) ?? jsonString(decoded['msg']) ?? '';
    final detail = '$what: code $code $message'.trim();
    final notFound = extraNotFound.isEmpty ? notFoundCodes : {...notFoundCodes, ...extraNotFound};
    throw switch (code) {
      -352 => BilibiliFailure(BilibiliFailureKind.riskControl, detail),
      -412 => BilibiliFailure(BilibiliFailureKind.rateLimited, detail),
      -101 => BilibiliFailure(BilibiliFailureKind.needsLogin, detail),
      final int value when notFound.contains(value) => BilibiliFailure(BilibiliFailureKind.notFound, detail),
      _ => BilibiliFailure(BilibiliFailureKind.apiChanged, ok ? detail : 'HTTP $status, $detail'),
    };
  }

  // Catalog -------------------------------------------------------------------

  /// `room/v1/Area/getList`: every leaf area of every category, in platform
  /// order, each carrying its category as parent. The area id is
  /// `parent_area_id,area_id` — the pair `getRoomList` needs (see
  /// [splitAreaId]). Area pictures get the `@100w.png` size hint.
  static List<LiveArea> areas(String body, {int status = 200}) {
    final data = checked(body, what: 'Area/getList', status: status)['data'];
    if (data is! List) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'Area/getList: data is not a list (${jsonSnippet(body)})');
    }
    return [
      for (final raw in data)
        if (jsonObject(raw) case final category? when jsonString(category['id']) != null)
          for (final rawArea in jsonList(category['list']))
            if (jsonObject(rawArea) case final area? when jsonString(area['id']) != null)
              LiveArea.normalized(
                platform: bilibiliSiteId,
                areaId: '${jsonString(area['parent_id']) ?? jsonString(category['id'])!},${jsonString(area['id'])!}',
                areaName: decodeHtmlEntities(jsonString(area['name']) ?? ''),
                parentAreaId: jsonString(area['parent_id']) ?? jsonString(category['id'])!,
                parentAreaName: decodeHtmlEntities(
                  jsonString(area['parent_name']) ?? jsonString(category['name']) ?? '',
                ),
                iconUrl: sizedImage(area['pic'], '@100w.png'),
              ),
    ];
  }

  /// The `(parent_area_id, area_id)` pair of an area id: `parent,area`, or the
  /// id alone for a caller that knows only the leaf (the unsigned list then
  /// sends an empty parent and the signed fallback names the leaf twice).
  static ({String parentAreaId, String areaId}) splitAreaId(String areaId) {
    final value = areaId.trim();
    final comma = value.lastIndexOf(',');
    if (comma <= 0 || comma == value.length - 1) return (parentAreaId: '', areaId: value);
    return (parentAreaId: value.substring(0, comma), areaId: value.substring(comma + 1));
  }

  /// A room list answer: `area/getRoomList` (list in `data`), `second/getList`
  /// (its signed fallback), `getListByAreaID` (ranked recommendations) and
  /// `getMoreRecList` (the feed fallback, list in `data.recommend_room_list`).
  /// Every listed room is live; the page is re-sorted by audience with
  /// identity ties, because neither list is reliably ordered. The page ends
  /// when `has_more` says so, else when it comes back empty.
  static ({List<LiveRoom> rooms, bool hasMore}) roomList(String body, {int status = 200}) {
    final data = checked(body, what: 'room list', status: status)['data'];
    final raw = data is Map<String, dynamic> ? (data['list'] ?? data['recommend_room_list']) : data;
    if (raw is! List) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'room list: no list (${jsonSnippet(body)})');
    }
    final rooms = [
      for (final item in raw)
        if (jsonObject(item) case final room?) ?_listRoom(room),
    ];
    final flag = data is Map<String, dynamic> ? data['has_more'] : null;
    final more = switch (flag) {
      final bool value => value,
      _ => jsonInt(flag) == null ? raw.isNotEmpty : jsonInt(flag) != 0,
    };
    return (rooms: _byAudience(rooms), hasMore: raw.isNotEmpty && more);
  }

  static LiveRoom? _listRoom(Map<String, dynamic> item) {
    final id = _roomId(item['roomid'] ?? item['room_id']);
    if (id == null) return null;
    final online = jsonCount(item['online']);
    final live = _status(item['live_status']) ?? LiveStatus.live;
    return LiveRoom.normalized(
      platform: bilibiliSiteId,
      roomId: id,
      content: RoomContent(
        title: decodeHtmlEntities(jsonString(item['title']) ?? ''),
        coverUrl: sizedImage(item['cover'] ?? item['user_cover'], '@400w.jpg'),
      ),
      anchor: LiveAnchor.normalized(
        platform: bilibiliSiteId,
        name: decodeHtmlEntities(jsonString(item['uname']) ?? ''),
        avatarUrl: sizedImage(item['face'], '@400w.jpg'),
        liveStatus: live,
      ),
      area: LiveArea.normalized(
        platform: bilibiliSiteId,
        areaName:
            jsonString(item['area_v2_name']) ?? jsonString(item['area_name']) ?? jsonString(item['areaName']) ?? '',
      ),
      audience: _audience(
        online: online,
        total: _watched(item['watched_show'], state: live),
      ),
      broadcast: RoomBroadcast(liveStatus: live),
      links: RoomLinks(webUrl: '${BilibiliEndpoints.origin}/$id'),
    );
  }

  // Search --------------------------------------------------------------------

  /// `search/type?search_type=live`: `live_room` entries are rooms, `live_user`
  /// entries are streamers whose name matched — the only place an offline or
  /// carousel streamer appears. Those become room cards after the rooms, on
  /// page 1 only (every page repeats them), and only when their room is not
  /// listed yet. `live_status` is read as in [roomDetail]; a live entry's
  /// `live_time` (Beijing time) is its start. `<em class="keyword">` highlights
  /// are stripped, entities decoded.
  static List<LiveRoom> searchRooms(String body, {required int page, int status = 200}) {
    final result = jsonObject(checked(body, what: 'search', status: status)['data'])?['result'];
    final rooms = <LiveRoom>[
      for (final item in jsonList(jsonObject(result)?['live_room']))
        if (jsonObject(item) case final room?) ?_searchRoom(room),
    ];
    if (page <= 1) {
      final listed = {for (final room in rooms) room.roomId};
      for (final item in jsonList(jsonObject(result)?['live_user'])) {
        final user = jsonObject(item) == null ? null : _searchUser(jsonObject(item)!);
        if (user != null && listed.add(user.roomId)) rooms.add(user);
      }
    }
    return rooms;
  }

  static LiveRoom? _searchRoom(Map<String, dynamic> item) {
    final id = _roomId(item['roomid']);
    if (id == null) return null;
    final state = _status(item['live_status']) ?? LiveStatus.offline;
    final live = state == LiveStatus.live;
    final online = jsonCount(item['online']);
    return LiveRoom.normalized(
      platform: bilibiliSiteId,
      roomId: id,
      content: RoomContent(title: _highlighted(item['title']), coverUrl: sizedImage(item['user_cover'], '@400w.jpg')),
      anchor: LiveAnchor.normalized(
        platform: bilibiliSiteId,
        anchorId: jsonString(item['uid']) ?? '',
        name: _highlighted(item['uname']),
        avatarUrl: sizedImage(item['uface'], '@400w.jpg'),
        followerCount: jsonCount(item['attentions']),
        liveStatus: state,
      ),
      area: LiveArea.normalized(platform: bilibiliSiteId, areaName: _highlighted(item['cate_name'])),
      audience: _audience(
        online: online,
        total: _watched(item['watched_show'], state: state),
      ),
      broadcast: RoomBroadcast(liveStatus: state, startedAt: live ? _beijingTime(item['live_time']) : null),
      links: RoomLinks(webUrl: '${BilibiliEndpoints.origin}/$id'),
    );
  }

  static LiveRoom? _searchUser(Map<String, dynamic> item) {
    final id = _roomId(item['roomid']);
    if (id == null) return null;
    final state = _status(item['live_status']) ?? LiveStatus.offline;
    return LiveRoom.normalized(
      platform: bilibiliSiteId,
      roomId: id,
      anchor: LiveAnchor.normalized(
        platform: bilibiliSiteId,
        anchorId: jsonString(item['mid']) ?? '',
        name: _highlighted(item['uname']),
        avatarUrl: sizedImage(item['uface'], '@400w.jpg'),
        followerCount: jsonCount(item['fans_num']) ?? jsonCount(item['attentions']),
        liveStatus: state,
      ),
      area: LiveArea.normalized(platform: bilibiliSiteId, areaName: _highlighted(item['cate_name'])),
      broadcast: RoomBroadcast(
        liveStatus: state,
        startedAt: state == LiveStatus.live ? _beijingTime(item['live_time']) : null,
      ),
      links: RoomLinks(webUrl: '${BilibiliEndpoints.origin}/$id'),
    );
  }

  /// `search/type?search_type=live_user`: streamers whose name matched, live
  /// or not (`is_live` says which).
  static List<LiveAnchor> searchAnchors(String body, {int status = 200}) {
    final root = checked(body, what: 'search live_user', status: status);
    return [
      for (final item in jsonList(jsonObject(root['data'])?['result']))
        if (jsonObject(item) case final user? when _roomId(user['roomid']) != null)
          LiveAnchor.normalized(
            platform: bilibiliSiteId,
            anchorId: jsonString(user['mid']) ?? _roomId(user['roomid'])!,
            name: _highlighted(user['uname']),
            avatarUrl: sizedImage(user['uface'], '@400w.jpg'),
            followerCount: jsonCount(user['fans_num']) ?? jsonCount(user['attentions']),
            liveStatus: user['is_live'] == true || jsonInt(user['is_live']) == 1 ? LiveStatus.live : LiveStatus.offline,
          ),
    ];
  }

  // Rooms ---------------------------------------------------------------------

  /// `getInfoByRoom` (WBI signed): the room as the user asked for it
  /// ([requestedId], which may be a short id — a follow's identity must not
  /// change when the platform's canonical id is different) and the canonical
  /// long id every stream and danmaku request uses.
  ///
  /// `live_status` 1 (number or string) is live, 2 is the carousel (old videos
  /// looping while the streamer is off) and anything else is offline. A live
  /// room's `live_start_time` (Unix seconds) is its start; `special_type` gives
  /// the restriction; `description` arrives as HTML and becomes plain text.
  static ({LiveRoom room, String longId}) roomDetail(String body, {required String requestedId, int status = 200}) {
    final data = jsonObject(checked(body, what: 'getInfoByRoom', status: status, extraNotFound: const {-404})['data']);
    final room = jsonObject(data?['room_info']);
    final anchor = jsonObject(data?['anchor_info']);
    if (data == null || room == null || anchor == null) {
      throw BilibiliFailure(
        BilibiliFailureKind.apiChanged,
        'getInfoByRoom: room_info or anchor_info missing (${jsonSnippet(body)})',
      );
    }
    final longId = _roomId(room['room_id']);
    if (longId == null) {
      throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'getInfoByRoom: room_info.room_id missing');
    }
    final state = _status(room['live_status']) ?? LiveStatus.offline;
    final live = state == LiveStatus.live;
    final base = jsonObject(anchor['base_info']);
    final online = jsonCount(room['online']);
    final notice = jsonString(jsonObject(data['news_info'])?['content']);
    final id = requestedId.trim();
    return (
      longId: longId,
      room: LiveRoom.normalized(
        platform: bilibiliSiteId,
        roomId: id,
        content: RoomContent(
          title: decodeHtmlEntities(jsonString(room['title']) ?? ''),
          coverUrl: sizedImage(room['cover']),
          introduction: _richText(room['description']) ?? '',
          notice: notice == null ? '' : decodeHtmlEntities(notice),
        ),
        anchor: LiveAnchor.normalized(
          platform: bilibiliSiteId,
          anchorId: jsonString(base?['uid']) ?? '',
          name: decodeHtmlEntities(jsonString(base?['uname']) ?? ''),
          avatarUrl: sizedImage(base?['face'], '@100w.jpg'),
          liveStatus: state,
        ),
        area: LiveArea.normalized(
          platform: bilibiliSiteId,
          areaId: jsonString(room['area_id']) ?? '',
          areaName: jsonString(room['area_name']) ?? '',
        ),
        audience: _audience(
          online: online,
          total: _watched(data['watched_show'], state: state),
        ),
        broadcast: RoomBroadcast(
          liveStatus: state,
          startedAt: live ? _unixTime(room['live_start_time']) : null,
          restriction: _restriction(room['special_type'], live: live),
        ),
        links: RoomLinks(webUrl: '${BilibiliEndpoints.origin}/$id'),
      ),
    );
  }

  /// `room/v1/Room/get_info`: whether the room is live (a carousel is not).
  static bool liveStatus(String body, {int status = 200}) {
    final data = jsonObject(checked(body, what: 'Room/get_info', status: status)['data']);
    return jsonInt(data?['live_status']) == 1;
  }

  /// `SuperChat/getMessageList`: super chats with their display window; an
  /// entry without either bound is left out.
  static List<LiveSuperChatMessage> superChats(String body, {int status = 200}) {
    final root = checked(body, what: 'SuperChat/getMessageList', status: status);
    return [
      for (final item in jsonList(jsonObject(root['data'])?['list']))
        if (jsonObject(item) case final chat?)
          if ((_unixTime(chat['start_time']), _unixTime(chat['end_time'])) case (final start?, final end?))
            LiveSuperChatMessage(
              messageId: jsonString(chat['id']) ?? '',
              userName: decodeHtmlEntities(jsonString(jsonObject(chat['user_info'])?['uname']) ?? ''),
              faceUrl: sizedImage(jsonObject(chat['user_info'])?['face'], '@200w.jpg'),
              text: jsonString(chat['message']) ?? '',
              price: SuperChatPrice(amount: jsonInt(chat['price']), currency: 'CNY'),
              startTime: start,
              endTime: end,
              display: SuperChatDisplay(
                backgroundColor: jsonString(chat['background_color']) ?? '',
                backgroundBottomColor: jsonString(chat['background_bottom_color']) ?? '',
              ),
            ),
    ];
  }

  // Gifts ---------------------------------------------------------------------

  /// `giftPanel/giftConfig`: `data.list[]` by id (an entry without an id or a
  /// name is left out) and `data.guard_resources[]` by level.
  static BilibiliGiftCatalog giftCatalog(String body, {int status = 200}) {
    final data = jsonObject(checked(body, status: status, what: 'giftPanel/giftConfig')['data']);
    if (data == null) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'giftPanel/giftConfig: no data (${jsonSnippet(body)})');
    }
    final gifts = <String, BilibiliGiftInfo>{};
    for (final raw in jsonList(data['list'])) {
      final gift = jsonObject(raw);
      final id = jsonString(gift?['id']) ?? '';
      final name = jsonString(gift?['name'])?.trim() ?? '';
      if (gift == null || id.isEmpty || id == '0' || name.isEmpty) continue;
      final price = jsonInt(gift['price']) ?? 0;
      gifts[id] = BilibiliGiftInfo(
        id: id,
        name: name,
        price: price > 0 ? price : 0,
        silver: gift['coin_type'] == 'silver',
        icon: BilibiliEndpoints.giftIcon(gift['img_basic']),
      );
    }
    final guards = <int, ({String name, Uri? icon})>{
      for (final raw in jsonList(data['guard_resources']))
        if (jsonObject(raw) case final guard? when (jsonInt(guard['level']) ?? 0) > 0)
          jsonInt(guard['level'])!: (
            name: jsonString(guard['name'])?.trim() ?? '',
            icon: BilibiliEndpoints.giftIcon(guard['img']),
          ),
    };
    return BilibiliGiftCatalog(gifts: gifts, guards: guards);
  }

  // Session -------------------------------------------------------------------

  /// `x/frontend/finger/spi`: the guest `buvid3` (`b_3`) and `buvid4` (`b_4`).
  static ({String buvid3, String buvid4}) buvid(String body, {int status = 200}) {
    final data = jsonObject(checked(body, status: status, what: 'finger/spi')['data']);
    final buvid3 = jsonString(data?['b_3']);
    if (buvid3 == null) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'finger/spi: no b_3 (${jsonSnippet(body)})');
    }
    return (buvid3: buvid3, buvid4: jsonString(data?['b_4']) ?? '');
  }

  /// The cookie of API and media requests: the guest buvid pair, or the login
  /// cookie with the pair appended when it carries no `buvid3` of its own.
  static String cookie({required String buvid3, required String buvid4, String loginCookie = ''}) {
    final stored = loginCookie.trim();
    if (stored.isEmpty) return 'buvid3=$buvid3;buvid4=$buvid4;';
    if (RegExp(r'(?:^|;)\s*buvid3=').hasMatch(stored)) return stored;
    return '${stored.endsWith(';') ? stored : '$stored;'}buvid3=$buvid3;buvid4=$buvid4;';
  }

  /// `getDanmuInfo` (WBI signed, long id): the token and the endpoints, the
  /// general gateway first, then `host_list` with `wss_port` (443 omitted),
  /// without duplicates. An answer without a token is api-changed.
  static ({String token, List<Uri> servers}) danmakuInfo(String body, {int status = 200}) {
    final data = jsonObject(checked(body, status: status, what: 'getDanmuInfo')['data']);
    final token = jsonString(data?['token']);
    if (token == null) {
      throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'getDanmuInfo: empty token (${jsonSnippet(body)})');
    }
    final servers = <String>[BilibiliEndpoints.danmakuGateway];
    for (final item in jsonList(data?['host_list'])) {
      final host = jsonString(jsonObject(item)?['host']);
      if (host == null) continue;
      final port = jsonInt(jsonObject(item)?['wss_port']) ?? 443;
      final endpoint = 'wss://$host${port == 443 ? '' : ':$port'}/sub';
      if (!servers.contains(endpoint)) servers.add(endpoint);
    }
    return (token: token, servers: [for (final server in servers) Uri.parse(server)]);
  }

  /// The danmaku uid: 0 without a cookie; else the `DedeUserID` of that same
  /// cookie (a separately stored uid can belong to an older login while the
  /// cookie already changed); else the verified [storedUid]; else 0.
  static int danmakuUid({required String cookie, required int storedUid}) {
    if (cookie.trim().isEmpty) return 0;
    final match = RegExp(r'(?:^|;)\s*DedeUserID=(\d+)(?:;|$)', caseSensitive: false).firstMatch(cookie);
    final uid = int.tryParse(match?.group(1) ?? '');
    if (uid != null && uid > 0) return uid;
    return storedUid > 0 ? storedUid : 0;
  }

  // Helpers -------------------------------------------------------------------

  /// Rooms sorted by audience, highest first, then by identity, so equal
  /// values never shuffle on a refresh.
  static List<LiveRoom> _byAudience(List<LiveRoom> rooms) => rooms.toList()
    ..sort((left, right) {
      final byAudience = _key(right).compareTo(_key(left));
      return byAudience != 0 ? byAudience : left.roomId.compareTo(right.roomId);
    });

  static int _key(LiveRoom room) =>
      room.audience.popularity ?? room.audience.onlineViewers ?? room.audience.totalViewers ?? 0;

  static RoomAudience _audience({required int? online, required int? total}) => RoomAudience(
    popularity: online,
    totalViewers: total,
    primaryMetric: switch ((online, total)) {
      (_, null) => LiveAudienceMetricType.popularity,
      (null, _) => LiveAudienceMetricType.totalViewers,
      _ => LiveAudienceMetricType.popularity,
    },
  );

  /// `room_id` as a positive decimal id, null for anything else.
  static String? roomIdOf(Object? value) => _roomId(value);

  static String? _roomId(Object? value) {
    final id = jsonInt(value);
    return id != null && id > 0 ? '$id' : null;
  }

  /// The `watched_show` "N人看过" cumulative figure only when the room switched
  /// it on (`switch` true) and the state actually has one: with `switch` false
  /// the platform repeats the popularity there, and a list's carousel or
  /// offline entry has no live figure.
  static int? _watched(Object? value, {required LiveStatus state}) {
    final show = jsonObject(value);
    if (show == null || show['switch'] != true || state != LiveStatus.live) return null;
    return jsonCount(show['num']);
  }

  static final RegExp _emTag = RegExp(r'</?em\b[^>]*>', caseSensitive: false);

  /// Search text without the `<em class="keyword">` highlight, entities
  /// decoded.
  static String _highlighted(Object? value) => decodeHtmlEntities((jsonString(value) ?? '').replaceAll(_emTag, ''));

  /// HTML in `description` (`<p>…</p>`) as plain text: block ends and `<br>`
  /// become line breaks, other tags are dropped, entities decoded.
  static String? _richText(Object? value) {
    final text = jsonString(value);
    if (text == null) return null;
    final lines = decodeHtmlEntities(
      text
          .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false), '\n')
          .replaceAll(RegExp('<[^>]*>'), ''),
    ).split('\n').map((line) => line.trim());
    final plain = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return plain.isEmpty ? null : plain;
  }

  /// `live_status` (number or string): 1 live, 2 the carousel, 3 and anything
  /// else offline; a missing field is null, which the caller reads as offline.
  static LiveStatus? _status(Object? value) => switch (jsonInt(value)) {
    1 => LiveStatus.live,
    2 => LiveStatus.carousel,
    null => null,
    _ => LiveStatus.offline,
  };

  /// A positive Unix time in seconds as UTC; 0 (not live) is none.
  static DateTime? _unixTime(Object? value) => switch (jsonInt(value)) {
    final int seconds when seconds > 0 => DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    _ => null,
  };

  static final RegExp _localTime = RegExp(r'^(\d{4})-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');

  /// Search's `live_time`, `yyyy-MM-dd HH:mm:ss` in Beijing time (UTC+8), as
  /// UTC; the `0000-00-00 00:00:00` of an offline streamer is none.
  static DateTime? _beijingTime(Object? value) {
    final match = _localTime.firstMatch(jsonString(value)?.trim() ?? '');
    if (match == null || int.parse(match.group(1)!) < 2000) return null;
    return DateTime.tryParse('${match.group(0)!.replaceFirst(' ', 'T')}+08:00')?.toUtc();
  }

  /// `room_info.special_type`: 1 is a paid room (a ticket), 0 an ordinary
  /// room, 2 the New Year gala room. A paid room that is live is
  /// [LiveRestriction.paid]; otherwise there is no restriction. Without the
  /// field the response says nothing (null).
  static LiveRestriction? _restriction(Object? specialType, {required bool live}) => switch (jsonInt(specialType)) {
    null => null,
    1 when live => LiveRestriction.paid,
    _ => LiveRestriction.none,
  };
}

/// One entry of Bilibili's gift table (`giftPanel/giftConfig`'s `data.list[]`):
/// `id`, `name`, [price] in gold seeds — or silver seeds when [silver], which
/// the gift line counts as free — and the picture [icon] (`img_basic`, https).
@immutable
final class BilibiliGiftInfo {
  /// Creates the entry.
  const BilibiliGiftInfo({required this.id, required this.name, this.price = 0, this.silver = false, this.icon});

  /// The gift's id (`id`).
  final String id;

  /// The gift's name (`name`).
  final String name;

  /// The price of one (`price`), in gold seeds, or silver seeds when [silver];
  /// 0 when missing.
  final int price;

  /// Whether it costs silver seeds (`coin_type` `silver`).
  final bool silver;

  /// The picture (`img_basic`), https.
  final Uri? icon;

  @override
  bool operator ==(Object other) =>
      other is BilibiliGiftInfo &&
      other.id == id &&
      other.name == name &&
      other.price == price &&
      other.silver == silver &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, price, silver, icon);

  @override
  String toString() => 'BilibiliGiftInfo($id $name, $price ${silver ? 'silver' : 'gold'})';
}

/// Bilibili's gift table: `xlive/web-room/v1/giftPanel/giftConfig`, public,
/// anonymous and the same for every room. The danmaku connection reads a
/// gift's picture and price here when its packet has none ([gifts], by id),
/// and the guard pictures ([guards], `guard_resources[]`: level 1 总督, 2 提督,
/// 3 舰长).
final class BilibiliGiftCatalog {
  /// Creates the table.
  const BilibiliGiftCatalog({this.gifts = const {}, this.guards = const {}});

  /// No table (not fetched yet, or the fetch failed).
  static const BilibiliGiftCatalog empty = BilibiliGiftCatalog();

  /// The gifts by id.
  final Map<String, BilibiliGiftInfo> gifts;

  /// The guard levels' names and pictures by `level`.
  final Map<int, ({String name, Uri? icon})> guards;

  /// Whether it holds nothing.
  bool get isEmpty => gifts.isEmpty && guards.isEmpty;

  /// The gift [id], or null.
  BilibiliGiftInfo? operator [](String id) => gifts[id];
}
