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
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_json.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// How much of a room the detail chain reads when the anchor has no live
/// channel (the reference's `_Depth`).
enum CcDetailDepth {
  /// Room entry: the room page, which also tells an unknown id.
  entry,

  /// Follow refresh: the existence check (9-7).
  refresh,

  /// Recording and status checks: nothing more.
  status,
}

/// Pure parsing of NetEase CC responses (3.x's `CCSite`, with the room page
/// as the archived v4 parser's fallback): the room lists, the search, the
/// `activitylives` → `live/channel` chain and the existence probe.
///
/// Each function takes the response text and status and returns the shared
/// room models or throws a [CcFailure].
abstract final class CcRoomParser {
  // Lists ---------------------------------------------------------------------

  /// `api/category/{gametype}/`: the area's `lives`. The answer must echo
  /// [gametype] and hold a `lives` list of at most 1000 rows; otherwise the
  /// page is api-changed, never a short one. A row without a valid `cuteid`
  /// is skipped (3.x failed the page; the unified "容错" rule). `videos`
  /// are recordings, not rooms. `status` 1 is live (a "【重播】" rebroadcast
  /// a replay, 9-3), 0 offline, anything else unknown.
  static List<LiveRoom> areaRooms(String body, {required String gametype, int status = 200}) {
    final root = CcJson.object(CcJson.decode(body, status: status, what: 'category $gametype'));
    if (root == null || root['gametype']?.toString() != gametype || root['lives'] is! List) {
      throw CcFailure(CcFailureKind.apiChanged, 'category $gametype: unexpected answer (${CcJson.snippet(body)})');
    }
    final rows = root['lives'] as List;
    if (rows.length > 1000) throw CcFailure(CcFailureKind.apiChanged, 'category $gametype: ${rows.length} rows');
    return [
      for (final row in rows)
        if (CcJson.object(row) case final item? when CcJson.cuteid(item['cuteid']) != null)
          _listRoom(
            item,
            area: CcJson.text(item['game_name']).isEmpty
                ? CcJson.text(item['gamename'])
                : CcJson.text(item['game_name']),
            status: _status(item['status']),
          ),
    ];
  }

  /// `api/category/live/`: every live room, by the site's heat order. The
  /// endpoint lists live rooms only, so every card is on air (3.x), a
  /// "【重播】" rebroadcast as a replay (9-3). The area is `gamename`, the
  /// only area field these rows carry (3.x read `game_name` and showed
  /// none; 9-2). Rows without a valid `cuteid` are skipped (3.x wrote the
  /// room id "null").
  static List<LiveRoom> recommendRooms(String body, {int status = 200}) {
    final root = CcJson.object(CcJson.decode(body, status: status, what: 'category/live'));
    final lives = root?['lives'];
    if (lives is! List) {
      throw CcFailure(CcFailureKind.apiChanged, 'category/live: no lives list (${CcJson.snippet(body)})');
    }
    return [
      for (final row in lives)
        if (CcJson.object(row) case final item? when CcJson.cuteid(item['cuteid']) != null)
          _listRoom(
            item,
            area: CcJson.text(item['gamename']).isEmpty
                ? CcJson.text(item['game_name'])
                : CcJson.text(item['gamename']),
            status: LiveStatus.live,
          ),
    ];
  }

  /// A room card of the directory lists: heat and concurrent viewers side by
  /// side (3.x's `parseRoomAudience`), the heat shown when there is one. On
  /// air, the start is `startat` and a tier list means no restriction.
  static LiveRoom _listRoom(Map<String, dynamic> item, {required String area, required LiveStatus status}) {
    final liveStatus = _onAirStatus(status, item['title']);
    final (:popularity, :online) = _audience(item);
    final id = CcJson.cuteid(item['cuteid'])!;
    return LiveRoom.normalized(
      platform: ccSiteId,
      roomId: id,
      content: RoomContent.of(title: CcJson.text(item['title']), coverUrl: CcJson.image(item['cover'], item['poster'])),
      anchor: LiveAnchor.normalized(
        platform: ccSiteId,
        anchorId: id,
        name: CcJson.text(item['nickname']),
        avatarUrl: _avatarOrEmpty(CcJson.image(item['purl'])),
        liveStatus: liveStatus,
      ),
      audience: _audienceOf(popularity: popularity, online: online),
      area: LiveArea.normalized(platform: ccSiteId, areaName: area),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: _startedAt(item, liveStatus),
        restriction: _restriction(item, liveStatus),
      ),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(id)),
    );
  }

  // Search --------------------------------------------------------------------

  /// `search/anchor/`: streamers, live or not. `status` 1 is on air (a
  /// "【重播】" rebroadcast a replay, 9-3), anything else offline. On air,
  /// the card shows the broadcast's cover and heat (9-5); otherwise, as in
  /// 3.x, the portrait is the cover and the follower count the audience.
  /// Rows without a valid `cuteid` are skipped.
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    final root = CcJson.object(CcJson.decode(body, status: status, what: 'search/anchor'));
    final anchors = CcJson.object(root?['webcc_anchor']);
    if (anchors == null) {
      throw CcFailure(CcFailureKind.apiChanged, 'search/anchor: no webcc_anchor (${CcJson.snippet(body)})');
    }
    return [
      for (final row in CcJson.list(anchors['result']))
        if (CcJson.object(row) case final item? when CcJson.cuteid(item['cuteid']) != null) _searchRoom(item),
    ];
  }

  /// A search card. The heat is `hot_score` alone (search's `visitor` is
  /// something else: offline streamers have it too); an on-air card without
  /// heat falls back to the follower count, and one without a cover to the
  /// portrait.
  static LiveRoom _searchRoom(Map<String, dynamic> item) {
    final portrait = CcJson.image(item['portrait']).isEmpty
        ? CcJson.image(item['portraiturl'])
        : CcJson.image(item['portrait']);
    final followers = CcJson.digitCount(item['follower_num']);
    final liveStatus = CcJson.integer(item['status']) == 1
        ? _onAirStatus(LiveStatus.live, item['title'])
        : LiveStatus.offline;
    final onAir = liveStatus == LiveStatus.live || liveStatus == LiveStatus.replay;
    final heat = switch (CcJson.integer(item['hot_score'])) {
      final int value when onAir && value > 0 => value,
      _ => null,
    };
    final cover = CcJson.image(item['cover'], item['poster']);
    final id = CcJson.cuteid(item['cuteid'])!;
    return LiveRoom.normalized(
      platform: ccSiteId,
      roomId: id,
      content: RoomContent.of(
        title: CcJson.text(item['title']),
        coverUrl: onAir && cover.isNotEmpty ? cover : portrait,
      ),
      anchor: LiveAnchor.normalized(
        platform: ccSiteId,
        anchorId: id,
        name: CcJson.text(item['nickname']),
        avatarUrl: _avatarOrEmpty(portrait),
        followerCount: followers,
        liveStatus: liveStatus,
      ),
      audience: RoomAudience.of(
        popularity: heat,
        primaryMetric: heat != null
            ? LiveAudienceMetricType.popularity
            : followers != null
            ? LiveAudienceMetricType.followers
            : LiveAudienceMetricType.unknown,
      ),
      area: LiveArea.normalized(platform: ccSiteId, areaName: CcJson.text(item['game_name'])),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: _startedAt(item, liveStatus),
        restriction: _restriction(item, liveStatus),
      ),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(id)),
    );
  }

  /// The streamers of [searchRooms] (3.x did the same): one anchor per room
  /// hit, live only when the room is.
  static List<LiveAnchor> searchAnchors(List<LiveRoom> rooms) => [
    for (final room in rooms)
      LiveAnchor.normalized(
        platform: ccSiteId,
        anchorId: room.roomId,
        name: room.anchor?.name ?? '',
        avatarUrl: _avatarOrEmpty(room.anchor?.avatarUrl ?? ''),
        liveStatus: room.broadcast.isLiveNow ? LiveStatus.live : LiveStatus.offline,
      ),
  ];

  // Rooms ---------------------------------------------------------------------

  /// `activitylives/anchor/lives`: the channel [ccid] broadcasts in, or null
  /// when it has none (an offline or unknown anchor: both answer only
  /// `is_black`). HTTP 400 (a non-numeric id) is not-found; a `code` other
  /// than "OK" or no entry for [ccid] is api-changed.
  static String? liveChannel(String body, {required String ccid, int status = 200}) {
    if (status == 400) throw CcFailure(CcFailureKind.notFound, 'activitylives: HTTP 400 for $ccid');
    final root = CcJson.object(CcJson.decode(body, status: status, what: 'activitylives'));
    if (CcJson.string(root?['code']) != 'OK') {
      throw CcFailure(CcFailureKind.apiChanged, 'activitylives: code ${root?['code']}');
    }
    final entry = CcJson.object(CcJson.object(root?['data'])?[ccid]);
    if (entry == null) throw CcFailure(CcFailureKind.apiChanged, 'activitylives: no entry for $ccid');
    return CcJson.string(entry['channel_id']);
  }

  /// `live/channel/?channelids=`: the room broadcasting in the channel, as
  /// 3.x's `_loadRoomDetail` read it, under the id [ccid] the user asked
  /// for. `status` 1 is live, anything else offline; an official "【重播】"
  /// rebroadcast is a replay (9-3; 3.x showed it live). The audience is the
  /// heat, else the viewers; the introduction and notice are both the
  /// streamer's `personal_label`. The tier list and redirect playlist go
  /// into the room's runtime handle ([CcRoomData]).
  ///
  /// Null when the channel no longer broadcasts (`nolive`, or no rows: the
  /// broadcast ended between the two requests). A row for another anchor is
  /// api-changed.
  static LiveRoom? channelRoom(String body, {required String ccid, int status = 200}) {
    final root = CcJson.object(CcJson.decode(body, status: status, what: 'live/channel'));
    if (root == null) {
      throw CcFailure(CcFailureKind.apiChanged, 'live/channel: not an object (${CcJson.snippet(body)})');
    }
    final rows = root['data'];
    if (rows != null && rows is! List) {
      throw const CcFailure(CcFailureKind.apiChanged, 'live/channel: data is not a list');
    }
    final room = CcJson.object((rows as List?)?.firstOrNull);
    if (room == null || CcJson.integer(room['nolive']) == 1) return null;
    final id = CcJson.cuteid(room['ccid'] ?? room['cuteid']);
    if (id != ccid) throw CcFailure(CcFailureKind.apiChanged, 'live/channel: answered ccid $id for $ccid');
    final (:popularity, :online) = _audience(room);
    final followers = CcJson.digitCount(room['follower_num']);
    final label = CcJson.text(room['personal_label']);
    final statusValue = _status(room['status']);
    final liveStatus = statusValue == LiveStatus.live ? _onAirStatus(LiveStatus.live, room['title']) : statusValue;
    return LiveRoom.normalized(
      platform: ccSiteId,
      roomId: ccid,
      content: RoomContent.of(
        title: CcJson.text(room['title']),
        coverUrl: CcJson.image(room['cover'], room['poster']),
        introduction: label.isEmpty ? null : label,
        notice: label.isEmpty ? null : label,
      ),
      anchor: LiveAnchor.normalized(
        platform: ccSiteId,
        anchorId: CcJson.text(room['uid']).isEmpty ? ccid : CcJson.text(room['uid']),
        name: CcJson.text(room['nickname']),
        avatarUrl: _avatarOrEmpty(CcJson.image(room['purl'])),
        followerCount: followers,
        liveStatus: liveStatus,
      ),
      audience: _audienceOf(popularity: popularity, online: online, followers: followers),
      area: LiveArea.normalized(platform: ccSiteId, areaName: CcJson.string(room['gamename']) ?? ''),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: _startedAt(room, liveStatus),
        restriction: _restriction(room, liveStatus),
      ),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(ccid)),
      runtime: RoomRuntime.of(
        streamHandle: CcRoomData(
          streams: CcJson.object(room['quickplay']) ?? CcJson.object(room['stream_list']),
          playlist: CcJson.string(room['m3u8']),
        ),
      ),
    );
  }

  /// A room whose anchor has no live channel, for follow refreshes and
  /// recordings: only the identity and the offline state, every other field
  /// "not in this response" (a merge keeps the stored ones).
  /// `activitylives` answers an unknown id the same way; room entry asks the
  /// room page ([pageRoom]) and follow refreshes [anchorExists] to tell them
  /// apart.
  static LiveRoom offlineRoom(String ccid) => LiveRoom.normalized(
    platform: ccSiteId,
    roomId: ccid,
    broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
    links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(ccid)),
  );

  static final RegExp _nextData = RegExp(r'<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>');

  /// The room page of an anchor without a live channel, on room entry
  /// (`cc.163.com/{ccid}/…`, whose `__NEXT_DATA__` holds
  /// `props.pageProps.roomInfoInitData`): `code` 404 (`no ccid`) is
  /// not-found; anything else is the anchor's offline room. 3.x failed here
  /// and showed the room as unknown. Fields as in [channelRoom]: the
  /// audience is the follower count; the introduction and notice are the
  /// `announcement`. Offline, so there is no start time or restriction.
  static LiveRoom pageRoom(String html, {required String ccid, int status = 200}) {
    CcJson.checkStatus(status, 'room page');
    final script = _nextData.firstMatch(html)?.group(1);
    final data = script == null ? null : CcJson.object(CcJson.tryDecode(script));
    final info = CcJson.object(CcJson.object(CcJson.object(data?['props'])?['pageProps'])?['roomInfoInitData']);
    if (info == null) throw const CcFailure(CcFailureKind.apiChanged, 'room page: no roomInfoInitData');
    if (CcJson.integer(info['code']) == 404) {
      throw CcFailure(CcFailureKind.notFound, 'room page: ${CcJson.string(info['reason']) ?? 'no ccid'} ($ccid)');
    }
    final anchor = CcJson.fields(info['micfirst']);
    final live = CcJson.fields(info['live']);
    final id = CcJson.cuteid(anchor['ccid'] ?? info['ccid'] ?? live['ccid']);
    if (id != ccid) throw CcFailure(CcFailureKind.apiChanged, 'room page: answered ccid $id for $ccid');
    final nick = CcJson.text(anchor['nickname']).isEmpty
        ? CcJson.text(info['nickname'])
        : CcJson.text(anchor['nickname']);
    if (nick.isEmpty) throw const CcFailure(CcFailureKind.apiChanged, 'room page: no nickname');
    final announcement = CcJson.text(info['announcement']);
    final followers = CcJson.digitCount(info['follower_num']) ?? CcJson.digitCount(live['follower_num']);
    final portrait = CcJson.image(anchor['purl'], anchor['portraiturl']);
    final avatar = portrait.isEmpty ? CcJson.image(info['purl']) : portrait;
    return LiveRoom.normalized(
      platform: ccSiteId,
      roomId: ccid,
      content: RoomContent.of(
        title: CcJson.text(info['live_title']).isEmpty ? CcJson.text(live['title']) : CcJson.text(info['live_title']),
        introduction: announcement.isEmpty ? null : announcement,
        notice: announcement.isEmpty ? null : announcement,
      ),
      anchor: LiveAnchor.normalized(
        platform: ccSiteId,
        anchorId: CcJson.text(info['uid']).isEmpty ? ccid : CcJson.text(info['uid']),
        name: nick,
        avatarUrl: _avatarOrEmpty(avatar),
        followerCount: followers,
        liveStatus: LiveStatus.offline,
      ),
      audience: RoomAudience.of(
        popularity: followers,
        primaryMetric: followers != null ? LiveAudienceMetricType.followers : LiveAudienceMetricType.unknown,
      ),
      area: LiveArea.normalized(
        platform: ccSiteId,
        areaName: CcJson.string(info['gamename']) ?? CcJson.string(live['gamename']) ?? '',
      ),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(ccid)),
    );
  }

  /// `wapcc/recommendbyccid?ccid=`: whether the id asked for is a CC
  /// account (9-7). The mobile site asks it for rooms to recommend beside
  /// an anchor's; an unknown id is `code` 4 ("没有对应的ccid") instead, for
  /// the same ids whose room page says `no ccid`. `code` 0 is an account;
  /// any other answer is api-changed.
  static bool anchorExists(String body, {int status = 200}) {
    final root = CcJson.object(CcJson.decode(body, status: status, what: 'recommendbyccid'));
    return switch (CcJson.integer(root?['code'])) {
      0 => true,
      4 => false,
      final code => throw CcFailure(CcFailureKind.apiChanged, 'recommendbyccid: code $code'),
    };
  }

  // Helpers -------------------------------------------------------------------

  /// 3.x's `parseRoomAudience`: heat is the first of `webcc_visitor`,
  /// `hot_score`, `visitor`, `total_visitor` (aliases of one value);
  /// concurrent viewers are `vision_visitor`, else `online_num`. Values are
  /// read when they hold a digit.
  static ({int? popularity, int? online}) _audience(Map<String, dynamic> room) {
    int? first(List<String> keys) {
      for (final key in keys) {
        if (CcJson.digitCount(room[key]) case final value?) return value;
      }
      return null;
    }

    return (
      popularity: first(const ['webcc_visitor', 'hot_score', 'visitor', 'total_visitor']),
      online: first(const ['vision_visitor', 'online_num']),
    );
  }

  /// The audience figures and the metric a list card leads with.
  static RoomAudience _audienceOf({int? popularity, int? online, int? followers}) => RoomAudience.of(
    popularity: popularity,
    onlineViewers: online,
    primaryMetric: popularity != null
        ? LiveAudienceMetricType.popularity
        : online != null
        ? LiveAudienceMetricType.onlineViewers
        : followers != null
        ? LiveAudienceMetricType.followers
        : LiveAudienceMetricType.unknown,
  );

  /// An avatar that is only an image; null so a missing picture stays
  /// missing on the anchor.
  static String? _avatarOrEmpty(String value) => value.isEmpty ? null : value;

  static LiveStatus _status(Object? value) => switch (CcJson.integer(value)) {
    1 => LiveStatus.live,
    0 => LiveStatus.offline,
    _ => LiveStatus.unknown,
  };

  /// [status], except that a live room titled "【重播】" is an official
  /// rebroadcast of a recorded event: a replay, which plays like a live
  /// stream (9-3). The site has no other field for it.
  static LiveStatus _onAirStatus(LiveStatus status, Object? title) =>
      status == LiveStatus.live && CcJson.text(title).trimLeft().startsWith('【重播】') ? LiveStatus.replay : status;

  /// `startat` of a room on air: when this broadcast (or rebroadcast
  /// channel) went on air. Off air it is the last broadcast's, so none.
  static DateTime? _startedAt(Map<String, dynamic> row, LiveStatus status) =>
      status == LiveStatus.live || status == LiveStatus.replay ? CcJson.beijingTime(row['startat']) : null;

  /// No restriction for a room on air whose answer carries its tier list
  /// (`stream_list` or `quickplay`): the site hands the stream to anyone.
  /// Otherwise the answer does not say (null); CC shows no paid, private or
  /// password state on these answers.
  static LiveRestriction? _restriction(Map<String, dynamic> row, LiveStatus status) {
    final onAir = status == LiveStatus.live || status == LiveStatus.replay;
    final streams = CcJson.object(row['stream_list']);
    return onAir && ((streams?.isNotEmpty ?? false) || CcJson.object(row['quickplay']) != null)
        ? LiveRestriction.none
        : null;
  }
}
