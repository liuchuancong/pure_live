import 'dart:math';

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
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_json.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';

const _site = 'huya';
const _web = 'https://www.huya.com';

final RegExp _number = RegExp(r'^\d{1,19}$');
final RegExp _alias = RegExp(r'^[A-Za-z0-9_-]+$');

/// huya.com path segments that are pages, not room aliases.
const Set<String> _reserved = {
  'g',
  'l',
  'e',
  'myfollow',
  'download',
  'play',
  'search',
  'live',
  'v',
  'cache',
  'api',
  'all',
  'global',
  'profile',
};

/// The four fixed top-level categories, in platform order (their `bussType`
/// ids and display names).
const List<({String id, String name})> huyaTopCategories = [
  (id: '1', name: '网游'),
  (id: '2', name: '单机'),
  (id: '8', name: '娱乐'),
  (id: '3', name: '手游'),
];

/// A `profileRoom` answer: the room as the user asked for it, the ids streams
/// and danmaku need, and, for a live room, its qualities and (with a `stream`)
/// its pre-signing lines. Replay recording playback is deferred, so a replay
/// carries no lines or qualities.
typedef HuyaProfile = ({
  LiveRoom room,
  int presenterUid,
  int topSid,
  int subSid,
  bool hasStream,
  List<HuyaLine> lines,
  List<LivePlayQuality> qualities,
});

/// Pure parsing of the huya catalog/search/room responses. Each function
/// takes the response text and HTTP status and returns shared models, or
/// throws a [HuyaFailure]. Signing lives in [HuyaPlayParser].
abstract final class HuyaRoomParser {
  /// Whether [address] is a bare numeric room id.
  static bool isNumericId(String address) => _number.hasMatch(address.trim());

  /// Whether [address] can name a room at all (digits, letters, `_`, `-`).
  static bool isRoomKey(String address) => _alias.hasMatch(address.trim());

  /// The numeric room id in a huya room URL's first path segment, or null.
  static String? roomIdAt(Uri target) {
    final host = target.host.toLowerCase();
    if (host != 'huya.com' && !host.endsWith('.huya.com')) return null;
    final first = target.pathSegments.where((segment) => segment.isNotEmpty).firstOrNull;
    return first != null && _number.hasMatch(first) ? first : null;
  }

  /// The alias (non-numeric room key) a huya room URL names, or null when the
  /// first segment is a page, a number or absent.
  static String? aliasAt(Uri target) {
    final host = target.host.toLowerCase();
    if (host != 'huya.com' && !host.endsWith('.huya.com')) return null;
    final first = target.pathSegments.where((segment) => segment.isNotEmpty).firstOrNull;
    if (first == null || !_alias.hasMatch(first) || _reserved.contains(first.toLowerCase())) return null;
    return _number.hasMatch(first) ? null : first;
  }

  /// The numeric room a room page names: `var TT_ROOM_DATA = {...}`'s
  /// `profileRoom`, else the first `"profileRoom"` in the page; null without
  /// one.
  static String? roomIdFromPage(String html) {
    final data = RegExp(r'var\s+TT_ROOM_DATA\s*=\s*(\{.*?\})\s*;', dotAll: true).firstMatch(html);
    if (data != null) {
      try {
        final id = _roomId(jsonObject(jsonObject(decodeJson(data.group(1)!))?['profileRoom']));
        if (id != null) return id;
      } on FormatException {
        // Fall through to the loose match.
      }
    }
    return _roomId(RegExp(r'"profileRoom"\s*:\s*"?(\d+)"?').firstMatch(html)?.group(1));
  }

  // Catalog -------------------------------------------------------------------

  /// `bussLive?bussType=`: the areas of one top-level category in server
  /// order. `gid` may be written `2165.0`; the area id is `"2165"`. The icon
  /// is `https://huyaimg.msstatic.com/cdnimage/game/<gid>-MS.jpg`.
  static List<LiveArea> areas(
    String body, {
    required String categoryId,
    required String categoryName,
    int status = 200,
  }) {
    final root = envelope(body, status: status, what: 'bussLive');
    final result = <LiveArea>[];
    for (final raw in jsonList(root['data'])) {
      final item = jsonObject(raw);
      if (item == null) continue;
      final gid = _positive(item['gid']);
      if (gid == null) continue;
      result.add(
        LiveArea.normalized(
          platform: _site,
          areaId: '$gid',
          areaName: _text(item['gameFullName']),
          parentAreaId: categoryId,
          parentAreaName: categoryName,
          iconUrl: 'https://huyaimg.msstatic.com/cdnimage/game/$gid-MS.jpg',
        ),
      );
    }
    return result;
  }

  /// `getLiveListByPage` (recommendations without `gameId`, an area with it):
  /// every listed room is live; the audience is popularity. More pages follow
  /// until `totalPage` or an empty `datas`. `isRoomPay` marks a paid card.
  static ({List<LiveRoom> rooms, bool hasMore}) roomList(String body, {required int page, int status = 200}) {
    final root = envelope(body, status: status, what: 'getLiveListByPage');
    final data = jsonObject(root['data']);
    final raw = data?['datas'];
    if (raw is! List) {
      throw HuyaFailure(HuyaFailureKind.apiChanged, 'getLiveListByPage: no datas (${jsonSnippet(body)})');
    }
    final rooms = <LiveRoom>[];
    for (final item in raw) {
      final room = jsonObject(item);
      final id = room == null ? null : _roomId(room['profileRoom']);
      if (room == null || id == null) continue;
      rooms.add(
        LiveRoom.normalized(
          platform: _site,
          roomId: id,
          content: RoomContent(
            title: _title(room['introduction'], room['roomName']),
            coverUrl: _thumbnail(room['screenshot']),
          ),
          anchor: LiveAnchor.normalized(
            platform: _site,
            name: _text(room['nick']),
            avatarUrl: normalizeImageUrl(room['avatar180']),
          ),
          area: LiveArea.normalized(platform: _site, areaName: _text(room['gameFullName'])),
          audience: RoomAudience(
            popularity: jsonInt(room['totalCount']),
            primaryMetric: LiveAudienceMetricType.popularity,
          ),
          broadcast: RoomBroadcast(liveStatus: LiveStatus.live, restriction: _flagRestriction(room['isRoomPay'])),
          links: RoomLinks(webUrl: '$_web/$id'),
        ),
      );
    }
    final totalPage = jsonInt(data?['totalPage']) ?? 0;
    return (rooms: rooms, hasMore: raw.isNotEmpty && (totalPage <= 0 || page < totalPage));
  }

  // Search --------------------------------------------------------------------

  /// `getSearchContent&v=4`: live rooms (`response.3.docs`). The room id is
  /// the streamer entry's (`response.1.docs`) with the same `uid` and `yyid`,
  /// else the room entry's. A later page repeats every earlier result, so the
  /// first [start] docs are skipped when there are more than [rows], and a
  /// seen id is not repeated. Docs carry neither a start time nor a
  /// restriction.
  static List<LiveSearchResult> searchRooms(String body, {required int start, required int rows, int status = 200}) {
    final response = jsonObject(json(body, status: status, what: 'getSearchContent')['response']);
    if (response == null) {
      throw HuyaFailure(HuyaFailureKind.apiChanged, 'getSearchContent: no response (${jsonSnippet(body)})');
    }
    final docs = jsonList(jsonObject(response['3'])?['docs']);
    final streamers = jsonList(jsonObject(response['1'])?['docs']);

    String? roomIdOf(Map<String, dynamic> doc) {
      final uid = jsonString(doc['uid']);
      final yyid = jsonString(doc['yyid']);
      if (uid != null && yyid != null) {
        for (final raw in streamers) {
          final streamer = jsonObject(raw);
          if (streamer != null && jsonString(streamer['uid']) == uid && jsonString(streamer['yyid']) == yyid) {
            if (_roomId(streamer['room_id']) case final id?) return id;
          }
        }
      }
      return _roomId(doc['room_id']);
    }

    final skipped = docs.length > rows ? min(max(start, 0), docs.length) : 0;
    final seen = <String>{};
    final results = <LiveSearchResult>[];
    for (final (index, raw) in docs.indexed) {
      final doc = jsonObject(raw);
      final id = doc == null ? null : roomIdOf(doc);
      if (doc == null || id == null || !seen.add(id) || index < skipped) continue;
      results.add(
        LiveSearchResult.room(
          LiveRoom.normalized(
            platform: _site,
            roomId: id,
            content: RoomContent(
              title: _title(doc['game_introduction'], doc['game_roomName']),
              coverUrl: _thumbnail(doc['game_screenshot']),
            ),
            anchor: LiveAnchor.normalized(
              platform: _site,
              anchorId: jsonString(doc['uid']) ?? '',
              name: _text(doc['game_nick']),
              avatarUrl: normalizeImageUrl(doc['game_imgUrl']),
              liveStatus: LiveStatus.live,
            ),
            area: LiveArea.normalized(platform: _site, areaName: _text(doc['gameName'])),
            audience: RoomAudience(
              popularity: jsonInt(doc['game_total_count']),
              primaryMetric: LiveAudienceMetricType.popularity,
            ),
            broadcast: const RoomBroadcast(liveStatus: LiveStatus.live),
            links: RoomLinks(webUrl: '$_web/$id'),
          ),
        ),
      );
    }
    return results;
  }

  /// `getSearchContent&v=1`: streamers (`response.1.docs`), live or not.
  static List<LiveSearchResult> searchAnchors(String body, {int status = 200}) {
    final response = jsonObject(json(body, status: status, what: 'getSearchContent')['response']);
    if (response == null) {
      throw HuyaFailure(HuyaFailureKind.apiChanged, 'getSearchContent: no response (${jsonSnippet(body)})');
    }
    final results = <LiveSearchResult>[];
    for (final raw in jsonList(jsonObject(response['1'])?['docs'])) {
      final doc = jsonObject(raw);
      final id = doc == null ? null : _roomId(doc['room_id']);
      if (doc == null || id == null) continue;
      results.add(
        LiveSearchResult.anchor(
          LiveAnchor.normalized(
            platform: _site,
            anchorId: id,
            name: _text(doc['game_nick']),
            avatarUrl: normalizeImageUrl(doc['game_avatarUrl180']),
            liveStatus: doc['gameLiveOn'] == true || jsonInt(doc['gameLiveOn']) == 1
                ? LiveStatus.live
                : LiveStatus.offline,
          ),
        ),
      );
    }
    return results;
  }

  // Room detail ---------------------------------------------------------------

  /// `profileRoom`: the room as the user asked for it ([requestedId]).
  ///
  /// - HTTP or body `status` 422 (a missing room, or a letter alias) is
  ///   [HuyaFailureKind.notFound]; another non-200 or a `data` that is not an
  ///   object is [HuyaFailureKind.apiChanged].
  /// - `liveStatus` `ON` is live; `REPLAY` a replay; `OFF`/`OFFLINE`/`CLOSED`
  ///   offline; anything else `apiChanged`, never offline.
  /// - A live room's restriction: `isRoomPay`/`isPayRoom` → paid; else
  ///   `isSecret` 1 → password; else none. A replay is `unplayable` (its
  ///   recording is a deferred follow-up). `startedAt` is `liveData.startTime`
  ///   seconds (live only).
  /// - Every count is popularity: `totalCount`, else `userCount`. topSid /
  ///   subSid are the first positive `lChannelId`/`lSubChannelId` of
  ///   `baseSteamInfoList`, else `chTopId`/`subChId`.
  static HuyaProfile profile(String body, {required String requestedId, int status = 200}) {
    final root = json(body, status: status, what: 'profileRoom');
    final code = jsonInt(root['status']);
    final message = jsonString(root['message']) ?? '';
    if (code == 422) throw HuyaFailure(HuyaFailureKind.notFound, 'profileRoom 422 $message'.trim());
    if (code != 200) throw HuyaFailure(HuyaFailureKind.apiChanged, 'profileRoom status $code $message'.trim());
    final data = jsonObject(root['data']);
    if (data == null) {
      throw HuyaFailure(HuyaFailureKind.apiChanged, 'profileRoom: data is not an object (${jsonSnippet(body)})');
    }
    final state = switch (jsonString(data['liveStatus'])?.toUpperCase()) {
      'ON' => LiveStatus.live,
      'REPLAY' => LiveStatus.replay,
      'OFF' || 'OFFLINE' || 'CLOSED' => LiveStatus.offline,
      final other => throw HuyaFailure(HuyaFailureKind.apiChanged, 'profileRoom: liveStatus ${other ?? 'missing'}'),
    };
    final live = jsonObject(data['liveData']) ?? const <String, dynamic>{};
    final info = jsonObject(data['profileInfo']) ?? const <String, dynamic>{};
    final stream = jsonObject(data['stream']);
    final bases = [
      for (final raw in jsonList(stream?['baseSteamInfoList']))
        ?jsonObject(raw),
    ];
    int channel(String key, String fallback) =>
        bases.map((base) => _positive(base[key])).nonNulls.firstOrNull ?? _positive(data[fallback]) ?? 0;
    final presenterUid = jsonInt(info['uid']) ?? jsonInt(live['uid']) ?? 0;
    final popularity = jsonInt(live['totalCount']) ?? jsonInt(live['userCount']);
    final id = requestedId.trim();
    final isLive = state == LiveStatus.live;
    final hasStream = isLive && stream != null;
    final startTime = isLive ? _positive(live['startTime']) : null;
    return (
      room: LiveRoom.normalized(
        platform: _site,
        roomId: id,
        content: RoomContent(
          title: _title(live['introduction'], live['roomName']),
          coverUrl: normalizeImageUrl(live['screenshot']),
          introduction: _text(live['introduction']),
          notice: _text(data['welcomeText']),
        ),
        anchor: LiveAnchor.normalized(
          platform: _site,
          anchorId: presenterUid > 0 ? '$presenterUid' : '',
          name: _text(info['nick']),
          avatarUrl: normalizeImageUrl(info['avatar180']),
          liveStatus: state,
        ),
        area: LiveArea.normalized(
          platform: _site,
          areaId: _positive(live['gamePid']) != null ? '${_positive(live['gamePid'])}' : '',
          areaName: _text(live['gameFullName']),
        ),
        audience: RoomAudience(popularity: popularity, primaryMetric: LiveAudienceMetricType.popularity),
        broadcast: RoomBroadcast(
          liveStatus: state,
          startedAt: startTime == null ? null : DateTime.fromMillisecondsSinceEpoch(startTime * 1000, isUtc: true),
          restriction: switch (state) {
            LiveStatus.live => _liveRestriction(data, live),
            LiveStatus.replay => LiveRestriction.unplayable,
            _ => null,
          },
        ),
        links: RoomLinks(webUrl: '$_web/$id'),
      ),
      presenterUid: presenterUid,
      topSid: channel('lChannelId', 'chTopId'),
      subSid: channel('lSubChannelId', 'subChId'),
      hasStream: hasStream,
      lines: hasStream ? HuyaPlayParser.lines(stream, bases, jsonInt(info['uid'])) : const [],
      qualities: isLive ? HuyaPlayParser.qualities(data) : const [],
    );
  }

  /// The anonymous login's `data.uid`; null when the answer has none.
  static int? anonymousUid(String body, {int status = 200}) {
    if (status != 200) return null;
    final uid = jsonInt(jsonObject(jsonObject(decodeJson(body))?['data'])?['uid']);
    return uid != null && uid > 0 ? uid : null;
  }

  // Envelopes -----------------------------------------------------------------

  /// The decoded JSON object of a response: 403 risk control, 422 not-found,
  /// 429 rate limit, 5xx network, another non-2xx or a body that is not an
  /// object `apiChanged`. Huya reports most of its own errors inside a 200
  /// body.
  static Map<String, dynamic> json(String body, {required int status, required String what}) {
    if (status == 403) throw HuyaFailure(HuyaFailureKind.riskControl, '$what: HTTP 403 (${jsonSnippet(body)})');
    if (status == 422) throw HuyaFailure(HuyaFailureKind.notFound, '$what: HTTP 422 (${jsonSnippet(body)})');
    if (status == 429) throw HuyaFailure(HuyaFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw HuyaFailure(HuyaFailureKind.network, '$what: HTTP $status');
    if (status < 200 || status >= 300) throw HuyaFailure(HuyaFailureKind.apiChanged, '$what: HTTP $status');
    final decoded = decodeJson(body);
    if (decoded is! Map<String, dynamic>) {
      throw HuyaFailure(HuyaFailureKind.apiChanged, '$what: not a JSON object (${jsonSnippet(body)})');
    }
    return decoded;
  }

  /// A `cache.php`/`bussLive` envelope: [json] whose body `status` must be
  /// 200.
  static Map<String, dynamic> envelope(String body, {required int status, required String what}) {
    final root = json(body, status: status, what: what);
    final code = jsonInt(root['status']);
    if (code != 200) {
      final message = jsonString(root['message']) ?? jsonString(root['msg']) ?? '';
      throw HuyaFailure(HuyaFailureKind.apiChanged, '$what: status $code $message'.trim());
    }
    return root;
  }
}

/// A live room's restriction, read as the web player does: a paid room
/// (`isRoomPay` of `data` or `liveData`, the page's `isPayRoom`) is
/// [LiveRestriction.paid]; a secret room (`isSecret` 1 and not paid) is
/// [LiveRestriction.password]; else [LiveRestriction.none]. Null when the
/// answer has none of the flags.
LiveRestriction? _liveRestriction(Map<String, dynamic> data, Map<String, dynamic> live) {
  final paid = [data['isRoomPay'], live['isRoomPay'], data['isPayRoom']].map(jsonFlag).nonNulls;
  final secret = [live['isSecret'], data['isSecret']].map(jsonFlag).nonNulls;
  if (paid.isEmpty && secret.isEmpty) return null;
  if (paid.contains(true)) return LiveRestriction.paid;
  return secret.contains(true) ? LiveRestriction.password : LiveRestriction.none;
}

/// A list card's `isRoomPay` alone: paid, none, or null when the card has no
/// flag.
LiveRestriction? _flagRestriction(Object? value) => switch (jsonFlag(value)) {
  true => LiveRestriction.paid,
  false => LiveRestriction.none,
  null => null,
};

/// A room id: a positive integer (`102411.0` too) as decimal text, or null.
String? _roomId(Object? value) {
  final id = jsonInt(value);
  return id != null && id > 0 ? '$id' : null;
}

int? _positive(Object? value) => switch (jsonInt(value)) {
  final int number when number > 0 => number,
  _ => null,
};

/// Display text with HTML entities decoded; '' for null.
String _text(Object? value) => value == null ? '' : decodeHtmlEntities('$value');

/// The introduction, else the room name.
String _title(Object? introduction, Object? roomName) {
  final intro = _text(introduction);
  return intro.isEmpty ? _text(roomName) : intro;
}

/// A list or search cover: a screenshot without a query gets the thumbnail
/// style; a missing one stays empty.
String _thumbnail(Object? value) {
  final url = normalizeImageUrl(value);
  if (url.isEmpty || url.contains('?')) return url;
  return '$url?x-oss-process=style/w338_h190&';
}
