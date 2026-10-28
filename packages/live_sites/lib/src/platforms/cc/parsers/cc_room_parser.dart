import 'dart:convert';

import 'package:live_sites/src/common/normalization/html_entities.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

const _site = 'cc';

/// What a live channel's streams are made of, apart from the room's identity
/// (3.x kept them in `data` and `link`): the channel's tier list and the
/// redirect playlist its signatures are appended to. Rooms without a live
/// channel (offline, refreshed without one, list cards) have none.
///
/// It rides on an entered room as its `RoomRuntime.streamHandle`, and is the
/// fallback when the `video_play_url` answer fails but the room carries its
/// tier list.
final class CcRoomData {
  /// Creates the data.
  const CcRoomData({this.streams, this.playlist});

  /// The channel's `quickplay`, else its `stream_list`: tier → CDN → URL or
  /// signature.
  final Map<String, dynamic>? streams;

  /// The channel's `m3u8`: `cgi.v.cc.163.com/redirect/video/{ccid}.m3u8`.
  final String? playlist;
}

/// One entered room of a live channel: the room as the user asked for it, and
/// the stream data its tier list and playlist.
typedef CcChannelRoom = ({LiveRoom room, CcRoomData data});

/// Pure parsing of NetEase CC responses (3.x's `CCSite` and `CCCatalog`):
/// the catalog, the lists, the search, the room answers and the play answers.
///
/// Each function takes the response text and status and returns v2 models or
/// throws a [CcFailure]. Answers are checked strictly — an envelope whose
/// code or echo does not match is api-changed, never a short list — except
/// that one broken row of a list only drops that row.
abstract final class CcRoomParser {
  // Catalog -------------------------------------------------------------------

  /// `wapcc/gamecategory?catetype=0`: the top-level categories (`cate_list`)
  /// in the server's order, without 全部 (`cate_type` 0). `code` other than 0
  /// is api-changed; a row without a positive `cate_type` or a name is
  /// skipped.
  static List<({String id, String name})> categoryTypes(String body, {int status = 200}) {
    final info = _categoryInfo(body, status: status);
    final seen = <String>{};
    return [
      for (final raw in CcJson.list(info['cate_list']))
        if (CcJson.objectOrNull(raw) case final row?)
          if ((CcJson.integer(row['cate_type']), decodeHtmlEntities(CcJson.text(row['name'])).trim())
              case (final type?, final name) when type > 0 && name.isNotEmpty && seen.add('$type'))
            (id: '$type', name: name),
    ];
  }

  /// `wapcc/gamecategory?catetype={id}`: the areas (`game_list`) of the
  /// category [id] named [name], in the server's order. The area id is the
  /// `gametype` the area rooms are listed by; the picture is `cover`. A row
  /// without a game type or a name is skipped, a repeated game type listed
  /// once.
  static List<LiveArea> categoryAreas(String body, {required String id, required String name, int status = 200}) {
    final info = _categoryInfo(body, status: status);
    final seen = <String>{};
    return [
      for (final raw in CcJson.list(info['game_list']))
        if (CcJson.objectOrNull(raw) case final row?)
          if ((CcJson.string(row['gametype']) ?? '', decodeHtmlEntities(CcJson.text(row['name'])).trim())
              case (final gametype, final areaName)
              when CcEndpoints.isAreaId(gametype) && areaName.isNotEmpty && seen.add(gametype))
            LiveArea.normalized(
              platform: _site,
              areaId: gametype,
              areaName: areaName,
              parentAreaId: id,
              parentAreaName: name,
              iconUrl: CcJson.image(row['cover']).isEmpty ? null : CcJson.image(row['cover']),
            ),
    ];
  }

  /// `data.category_info` of a `gamecategory` answer.
  static Map<String, dynamic> _categoryInfo(String body, {required int status}) {
    final root = CcJson.objectOrNull(CcJson.decode(body, what: 'gamecategory', status: status));
    if (root == null || CcJson.integer(root['code']) != 0) {
      throw CcFailure(CcFailureKind.apiChanged, 'gamecategory: code ${root?['code']}');
    }
    final info = CcJson.objectOrNull(CcJson.objectOrNull(root['data'])?['category_info']);
    if (info == null) throw const CcFailure(CcFailureKind.apiChanged, 'gamecategory: no category_info');
    return info;
  }

  /// 3.x's official rooms and events (`official:{ccid}`), kept beside the
  /// mobile catalog: the `/{ccid}/` entries of the Dashen live
  /// configuration's "直播入口列表" ([configBody]), named and pictured by the
  /// game registry ([gamesBody]). Its live-area entries (`/n/ds_category/…`)
  /// are left to the mobile catalog. A hidden configuration or group lists
  /// none; an entry that is hidden, unknown to the registry, repeated or
  /// leads anywhere else is skipped. An answer without the configuration is
  /// api-changed.
  static List<LiveArea> officialAreas(
    String gamesBody,
    String configBody, {
    int gamesStatus = 200,
    int configStatus = 200,
  }) {
    final games = _catalogEnvelope(gamesBody, status: gamesStatus, what: 'game registry');
    final config = _catalogEnvelope(configBody, status: configStatus, what: 'live configuration');
    final registry = <String, ({String name, String icon})>{};
    for (final raw in CcJson.list(games['result'])) {
      if (CcJson.objectOrNull(raw) case final row?) {
        if ((CcJson.boundedText(row['appKey'], 64), CcJson.boundedText(row['name'], 200)) case (
          final key?,
          final name?,
        )) {
          registry.putIfAbsent(key, () => (name: name, icon: CcJson.httpsImage(row['icon'])));
        }
      }
    }
    final root = CcJson.objectOrNull(config['result']);
    if (root == null || root['id'] != CcEndpoints.catalogConfigurationId) {
      throw CcFailure(CcFailureKind.apiChanged, 'live configuration: id ${root?['id']}');
    }
    if (_hidden(root)) return const [];
    final groups = [
      for (final raw in CcJson.list(root['itemList']))
        if (CcJson.objectOrNull(raw) case final group? when group['name'] == '直播入口列表') group,
    ];
    if (groups.length != 1) {
      throw CcFailure(CcFailureKind.apiChanged, 'live configuration: ${groups.length} live entry groups');
    }
    if (_hidden(groups.single)) return const [];
    final identities = <String>{};
    return [
      for (final raw in CcJson.list(groups.single['itemList']))
        if (CcJson.objectOrNull(raw) case final entry? when !_hidden(entry))
          if ((registry[CcJson.boundedText(entry['name'], 64)], _officialRoom(entry['content']))
              case (final game?, final ccid?) when identities.add(ccid))
            LiveArea.normalized(
              platform: _site,
              areaId: 'official:$ccid',
              areaName: game.name,
              parentAreaId: 'official',
              parentAreaName: CcEndpoints.officialLabel,
              iconUrl: game.icon.isEmpty ? null : game.icon,
            ),
    ];
  }

  /// The ccid of an official entry's `https://cc.163.com/{ccid}/` link, or
  /// null for any other link.
  static String? _officialRoom(Object? content) {
    final url = Uri.tryParse(CcJson.boundedText(content, 2048) ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'cc.163.com' ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.hasFragment) {
      return null;
    }
    return RegExp(r'^/([1-9][0-9]{0,15})/$').firstMatch(url.path)?.group(1);
  }

  /// Whether a Dashen configuration item is hidden; a `hidden` that is not a
  /// bool hides it too.
  static bool _hidden(Map<String, dynamic> value) {
    final hidden = value['hidden'];
    return hidden == true || (hidden != null && hidden is! bool);
  }

  static Map<String, dynamic> _catalogEnvelope(String body, {required int status, required String what}) {
    final envelope = CcJson.objectOrNull(CcJson.decode(body, what: what, status: status));
    if (envelope == null || envelope['code'] != 200) {
      throw CcFailure(CcFailureKind.apiChanged, '$what: code ${envelope?['code']}');
    }
    return envelope;
  }

  // Lists ---------------------------------------------------------------------

  /// `api/category/{gametype}/`: the area's `lives`. The answer must echo
  /// [gametype] and hold a `lives` list of at most 1000 rows; otherwise the
  /// page is api-changed, never a short one. A row without a valid `cuteid`
  /// is skipped. `videos` are recordings, not rooms. `status` 1 is live (a
  /// "【重播】" rebroadcast a replay), 0 offline, anything else unknown.
  static List<LiveRoom> categoryRooms(String body, {required String gametype, int status = 200}) {
    final root = CcJson.objectOrNull(CcJson.decode(body, what: 'category $gametype', status: status));
    if (root == null || root['gametype']?.toString() != gametype || root['lives'] is! List) {
      throw CcFailure(CcFailureKind.apiChanged, 'category $gametype: unexpected answer (${CcJson.snippet(body)})');
    }
    final rows = root['lives'] as List;
    if (rows.length > 1000) throw CcFailure(CcFailureKind.apiChanged, 'category $gametype: ${rows.length} rows');
    return [
      for (final row in rows)
        if (CcJson.objectOrNull(row) case final item? when CcJson.cuteid(item['cuteid']) != null)
          _listRoom(
            item,
            area: _firstText(item['game_name'], item['gamename']),
            liveStatus: _onAirStatus(_status(item['status']), item['title']),
          ),
    ];
  }

  /// `api/category/live/`: every live room, by the site's heat order. The
  /// endpoint lists live rooms only, so every card is on air, a "【重播】"
  /// rebroadcast a replay. The area is `gamename`, the only area field these
  /// rows carry. Rows without a valid `cuteid` are skipped.
  static List<LiveRoom> recommendRooms(String body, {int status = 200}) {
    final root = CcJson.objectOrNull(CcJson.decode(body, what: 'category/live', status: status));
    final lives = root?['lives'];
    if (lives is! List) {
      throw CcFailure(CcFailureKind.apiChanged, 'category/live: no lives list (${CcJson.snippet(body)})');
    }
    return [
      for (final row in lives)
        if (CcJson.objectOrNull(row) case final item? when CcJson.cuteid(item['cuteid']) != null)
          _listRoom(
            item,
            area: _firstText(item['gamename'], item['game_name']),
            liveStatus: _onAirStatus(LiveStatus.live, item['title']),
          ),
    ];
  }

  /// A room card of the directory lists: heat and concurrent viewers side by
  /// side (3.x's `parseRoomAudience`), the heat leading when there is one.
  /// On air, the start is `startat` and a tier list means no restriction.
  static LiveRoom _listRoom(Map<String, dynamic> item, {required String area, required LiveStatus liveStatus}) {
    final roomId = CcJson.cuteid(item['cuteid'])!;
    final audience = _audience(item);
    return LiveRoom.normalized(
      platform: _site,
      roomId: roomId,
      content: RoomContent.of(title: CcJson.text(item['title']), coverUrl: _image(item['cover'], item['poster'])),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: roomId,
        name: CcJson.text(item['nickname']),
        avatarUrl: CcJson.image(item['purl']),
      ),
      area: area.isEmpty ? null : LiveArea.normalized(platform: _site, areaName: area),
      audience: _audienceOf(popularity: audience.$1, online: audience.$2),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: _startedAt(item, liveStatus),
        restriction: _restriction(item, liveStatus),
      ),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(roomId)),
    );
  }

  // Search --------------------------------------------------------------------

  /// `search/anchor/`: streamers, live or not. `status` 1 is on air (a
  /// "【重播】" rebroadcast a replay), anything else offline. On air, the card
  /// shows the broadcast's cover and heat; otherwise, as in 3.x, the portrait
  /// is the cover and the follower count the audience. Rows without a valid
  /// `cuteid` are skipped.
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    final root = CcJson.objectOrNull(CcJson.decode(body, what: 'search/anchor', status: status));
    final anchors = CcJson.objectOrNull(root?['webcc_anchor']);
    if (anchors == null) {
      throw CcFailure(CcFailureKind.apiChanged, 'search/anchor: no webcc_anchor (${CcJson.snippet(body)})');
    }
    return [
      for (final row in CcJson.list(anchors['result']))
        if (CcJson.objectOrNull(row) case final item? when CcJson.cuteid(item['cuteid']) != null) _searchRoom(item),
    ];
  }

  /// A search card. The heat is `hot_score` alone (search's `visitor` is
  /// something else: offline streamers have it too); an on-air card without
  /// heat falls back to the follower count, and one without a cover to the
  /// portrait.
  static LiveRoom _searchRoom(Map<String, dynamic> item) {
    final roomId = CcJson.cuteid(item['cuteid'])!;
    final portrait = _image(item['portrait'], item['portraiturl']);
    final followers = CcJson.figure(item['follower_num']);
    final liveStatus = _status(item['status']) == LiveStatus.live
        ? _onAirStatus(LiveStatus.live, item['title'])
        : LiveStatus.offline;
    final onAir = liveStatus == LiveStatus.live || liveStatus == LiveStatus.replay;
    final heat = switch (CcJson.integer(item['hot_score'])) {
      final int value when onAir && value > 0 => value,
      _ => null,
    };
    final cover = onAir ? _image(item['cover'], item['poster']) : '';
    return LiveRoom.normalized(
      platform: _site,
      roomId: roomId,
      content: RoomContent.of(title: CcJson.text(item['title']), coverUrl: cover.isEmpty ? portrait : cover),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: roomId,
        name: CcJson.text(item['nickname']),
        avatarUrl: portrait,
        followerCount: followers,
      ),
      area: CcJson.text(item['game_name']).trim().isEmpty
          ? null
          : LiveArea.normalized(platform: _site, areaName: CcJson.text(item['game_name'])),
      audience: _audienceOf(popularity: heat, online: null, followers: followers),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: _startedAt(item, liveStatus),
        restriction: _restriction(item, liveStatus),
      ),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(roomId)),
    );
  }

  // Rooms ---------------------------------------------------------------------

  /// `activitylives/anchor/lives`: the channel [ccid] broadcasts in, or null
  /// when it has none (an offline anchor's entry names no channel). HTTP 400
  /// (a non-numeric id) is not-found; a `code` other than "OK" or no entry
  /// for [ccid] is api-changed.
  static String? liveChannel(String body, {required String ccid, int status = 200}) {
    if (status == 400) throw CcFailure(CcFailureKind.notFound, 'activitylives: HTTP 400 for $ccid');
    final root = CcJson.objectOrNull(CcJson.decode(body, what: 'activitylives', status: status));
    if (CcJson.string(root?['code']) != 'OK') {
      throw CcFailure(CcFailureKind.apiChanged, 'activitylives: code ${root?['code']}');
    }
    final entry = CcJson.objectOrNull(CcJson.objectOrNull(root?['data'])?[ccid]);
    if (entry == null) throw CcFailure(CcFailureKind.apiChanged, 'activitylives: no entry for $ccid');
    return CcJson.string(entry['channel_id']);
  }

  /// `live/channel/?channelids=`: the room broadcasting in the channel, as
  /// 3.x's `_loadRoomDetail` read it, under the id [ccid] the user asked for.
  /// `status` 1 is live, anything else offline; an official "【重播】"
  /// rebroadcast is a replay. The audience is the heat, else the viewers; the
  /// introduction and notice are both the streamer's `personal_label`. On
  /// air, the start is `startat` and a tier list means no restriction. The
  /// tier list and redirect playlist go into [CcRoomData].
  ///
  /// Null when the channel no longer broadcasts (`nolive`, or no rows: the
  /// broadcast ended between the two requests). A row for another anchor is
  /// api-changed.
  static CcChannelRoom? channelRoom(String body, {required String ccid, int status = 200}) {
    final root = CcJson.objectOrNull(CcJson.decode(body, what: 'live/channel', status: status));
    if (root == null) throw const CcFailure(CcFailureKind.apiChanged, 'live/channel: not an object');
    final rows = root['data'];
    if (rows != null && rows is! List) {
      throw const CcFailure(CcFailureKind.apiChanged, 'live/channel: data is not a list');
    }
    final room = CcJson.objectOrNull((rows as List?)?.firstOrNull);
    if (room == null || CcJson.integer(room['nolive']) == 1) return null;
    final id = CcJson.cuteid(room['ccid'] ?? room['cuteid']);
    if (id != ccid) throw CcFailure(CcFailureKind.apiChanged, 'live/channel: answered ccid $id for $ccid');
    final audience = _audience(room);
    final label = CcJson.text(room['personal_label']);
    final followers = CcJson.figure(room['follower_num']);
    final liveStatus = _status(room['status']) == LiveStatus.live
        ? _onAirStatus(LiveStatus.live, room['title'])
        : LiveStatus.offline;
    final data = CcRoomData(
      streams: CcJson.objectOrNull(room['quickplay']) ?? CcJson.objectOrNull(room['stream_list']),
      playlist: CcJson.string(room['m3u8']),
    );
    final built = LiveRoom.normalized(
      platform: _site,
      roomId: ccid,
      content: RoomContent.of(
        title: CcJson.text(room['title']),
        coverUrl: _image(room['cover'], room['poster']),
        introduction: label.isEmpty ? null : label,
        notice: label.isEmpty ? null : label,
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: ccid,
        name: CcJson.text(room['nickname']),
        avatarUrl: CcJson.image(room['purl']),
        followerCount: followers,
      ),
      area: (CcJson.string(room['gamename']) ?? '').trim().isEmpty
          ? null
          : LiveArea.normalized(platform: _site, areaName: CcJson.string(room['gamename'])!),
      audience: _audienceOf(popularity: audience.$1, online: audience.$2, followers: followers),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: _startedAt(room, liveStatus),
        restriction: _restriction(room, liveStatus),
      ),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(ccid)),
    );
    return (room: built, data: data);
  }

  /// A room whose anchor has no live channel, for offline states: only the
  /// identity and the offline state, every other field absent (a merge keeps
  /// the stored ones).
  static LiveRoom offlineRoom(String ccid) => LiveRoom.normalized(
    platform: _site,
    roomId: ccid,
    broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
    links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(ccid)),
  );

  static final RegExp _nextData = RegExp(r'<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>');

  /// The room page of an anchor without a live channel, on room entry
  /// (`cc.163.com/{ccid}/`, whose `__NEXT_DATA__` holds
  /// `props.pageProps.roomInfoInitData`): `code` 404 (`no ccid`) is
  /// not-found; anything else is the anchor's offline room. Without heat or
  /// viewers the audience is the follower count; the introduction and notice
  /// are the `announcement`. Offline, so there is no start time or
  /// restriction.
  static LiveRoom pageRoom(String html, {required String ccid, int status = 200}) {
    CcJson.checkStatus(status, 'room page');
    final script = _nextData.firstMatch(html)?.group(1);
    final data = script == null ? null : CcJson.objectOrNull(_tryDecode(script));
    final info = CcJson.objectOrNull(
      CcJson.objectOrNull(CcJson.objectOrNull(data?['props'])?['pageProps'])?['roomInfoInitData'],
    );
    if (info == null) throw const CcFailure(CcFailureKind.apiChanged, 'room page: no roomInfoInitData');
    if (CcJson.integer(info['code']) == 404) {
      throw CcFailure(CcFailureKind.notFound, 'room page: ${CcJson.string(info['reason']) ?? 'no ccid'} ($ccid)');
    }
    final anchor = CcJson.fields(info['micfirst']);
    final live = CcJson.fields(info['live']);
    final id = CcJson.cuteid(anchor['ccid'] ?? info['ccid'] ?? live['ccid']);
    if (id != ccid) throw CcFailure(CcFailureKind.apiChanged, 'room page: answered ccid $id for $ccid');
    final nick = _firstText(anchor['nickname'], info['nickname']);
    if (nick.isEmpty) throw const CcFailure(CcFailureKind.apiChanged, 'room page: no nickname');
    final announcement = CcJson.text(info['announcement']);
    final followers = CcJson.figure(info['follower_num']) ?? CcJson.figure(live['follower_num']);
    final gamename = CcJson.string(info['gamename']) ?? CcJson.string(live['gamename']);
    return LiveRoom.normalized(
      platform: _site,
      roomId: ccid,
      content: RoomContent.of(
        title: _firstText(info['live_title'], live['title']),
        coverUrl: _firstOf([anchor['purl'], anchor['portraiturl'], info['purl']]),
        introduction: announcement.isEmpty ? null : announcement,
        notice: announcement.isEmpty ? null : announcement,
      ),
      anchor: LiveAnchor.normalized(
        platform: _site,
        anchorId: ccid,
        name: nick,
        avatarUrl: _firstOf([anchor['purl'], anchor['portraiturl'], info['purl']]),
        followerCount: followers,
      ),
      area: (gamename ?? '').trim().isEmpty ? null : LiveArea.normalized(platform: _site, areaName: gamename!),
      audience: _audienceOf(popularity: null, online: null, followers: followers),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
      links: RoomLinks.of(webUrl: CcEndpoints.roomUrl(ccid)),
    );
  }

  // Streams: video_play_url ---------------------------------------------------

  /// `vapi.cc.163.com/video_play_url/{ccid}` → its object. HTTP 410 (`Gone`,
  /// "no live") and 404 are stream-unavailable.
  static Map<String, dynamic> playData(String body, {int status = 200}) {
    if (status == 410 || status == 404) {
      throw CcFailure(CcFailureKind.streamUnavailable, 'video_play_url: HTTP $status');
    }
    final data = CcJson.objectOrNull(CcJson.decode(body, what: 'video_play_url', status: status));
    if (data == null) {
      throw CcFailure(CcFailureKind.apiChanged, 'video_play_url: not an object (${CcJson.snippet(body)})');
    }
    return data;
  }

  /// The site's own names of its tier codes (`vbrname_mapping` in every
  /// recorded answer), for an answer without the mapping.
  static const Map<String, String> _siteNames = {'original': '原画', 'ultra': '超清', 'high': '高清', 'standard': '标清'};

  /// The qualities users pick from: `vbrname_list` in the server's order,
  /// best first (`vbrname_sel` alone when the list is empty), each a
  /// different stream. The id is the tier code (`original`,
  /// `blueray_5M_avc`, `ultra`, `high`, `standard`, …) sent as `vbrname`.
  /// The label is the site's own name (`vbrname_mapping`: 原画, 蓝光5M, 超清,
  /// 高清, 标清), else its usual name for the code; the source `original` is
  /// always 原画. When the answer does not say which tier it played
  /// (`vbrname_sel`), the qualities are marked playback-unconfirmed.
  static List<LivePlayQuality> qualities(Map<String, dynamic> data) {
    final codes = <String>[for (final raw in CcJson.list(data['vbrname_list'])) ?CcJson.string(raw)];
    if (codes.isEmpty) {
      final selected = CcJson.string(data['vbrname_sel']);
      if (selected == null) {
        throw const CcFailure(CcFailureKind.apiChanged, 'video_play_url: no vbrname_list or vbrname_sel');
      }
      codes.add(selected);
    }
    final names = CcJson.fields(data['vbrname_mapping']);
    final unconfirmed = CcJson.string(data['vbrname_sel']) == null;
    final unique = codes.toSet().toList();
    return [
      for (final (index, code) in unique.indexed)
        LivePlayQuality.of(
          label: code == 'original' ? '原画' : CcJson.string(names[code]) ?? _siteNames[code] ?? code,
          qualityId: code,
          platformOrder: unique.length - index,
          isPlaybackUnconfirmed: unconfirmed,
        ),
    ];
  }

  /// The CDN codes of `cdn_list` that the answer's own lines do not cover;
  /// each is asked for once more with `cdn={code}`.
  static List<String> uncoveredCdns(Map<String, dynamic> data) {
    final covered = {for (final line in _answerLines(data)) line.cdn};
    return [
      for (final raw in CcJson.list(data['cdn_list']))
        if (CcJson.string(raw) case final code? when covered.add(code)) code,
    ];
  }

  /// The lines of the play answers for one quality: [answers] first the
  /// answer to the quality request, then the ones for the other CDNs.
  ///
  /// An answer has `videourl` on `cdn_sel` and `bakvideourl` on
  /// `bakcdn_sel`. A CDN answer at another tier is dropped, and each CDN code
  /// (the line label) is kept once: a server answering `cdn=hs` with ali
  /// again gives no invented hs line. Every line carries the media headers
  /// for [roomId] and the lease of its `auth_key`. An answer without any URL
  /// is api-changed.
  static List<LivePlayLine> resolution(
    List<({Map<String, dynamic> data, DateTime issuedAt})> answers, {
    required String roomId,
  }) => resolutionWithApplied(answers, roomId: roomId).lines;

  /// [resolution] with the tier the first answer says it played
  /// (`vbrname_sel`), or null when it does not say.
  static ({List<LivePlayLine> lines, String? appliedQualityId}) resolutionWithApplied(
    List<({Map<String, dynamic> data, DateTime issuedAt})> answers, {
    required String roomId,
  }) {
    if (answers.isEmpty) throw const CcFailure(CcFailureKind.apiChanged, 'video_play_url: no answer');
    final applied = CcJson.string(answers.first.data['vbrname_sel']);
    final headers = CcEndpoints.mediaHeaders(roomId);
    final cdns = <String>{};
    final urls = <String>{};
    final lines = <LivePlayLine>[
      for (final (index, answer) in answers.indexed)
        if (index == 0 || CcJson.string(answer.data['vbrname_sel']) == applied)
          for (final line in _answerLines(answer.data))
            if (cdns.add(line.cdn) && urls.add(line.url.toString()))
              LivePlayLine.of(
                url: line.url.toString(),
                format: _format(line.url),
                formatSource: LivePlayFormatSource.inferred,
                headers: headers,
                lineLabel: line.cdn,
                lease: lease(line.url, answer.issuedAt),
              ),
    ];
    if (lines.isEmpty) throw const CcFailure(CcFailureKind.apiChanged, 'video_play_url: no playable URL');
    return (lines: lines, appliedQualityId: applied);
  }

  /// The tier the answer says it played (`vbrname_sel`) as a quality, named
  /// by the answer's own mapping; null when it does not say.
  static LivePlayQuality? appliedQuality(Map<String, dynamic> data) {
    final selected = CcJson.string(data['vbrname_sel']);
    if (selected == null) return null;
    final names = CcJson.fields(data['vbrname_mapping']);
    return LivePlayQuality.of(
      label: selected == 'original' ? '原画' : CcJson.string(names[selected]) ?? _siteNames[selected] ?? selected,
      qualityId: selected,
    );
  }

  static List<({String cdn, Uri url})> _answerLines(Map<String, dynamic> data) => [
    for (final (urlKey, cdnKey) in const [('videourl', 'cdn_sel'), ('bakvideourl', 'bakcdn_sel')])
      if (CcJson.url(data[urlKey]) case final url?) (cdn: CcJson.string(data[cdnKey]) ?? url.host, url: url),
  ];

  // Streams: the channel's tier list (3.x's fallback) --------------------------

  /// 3.x's qualities of a live channel (`getPlayQualites`): one per tier of
  /// [CcRoomData.streams] (`stream_list`: `original`, `high`, `medium`,
  /// `low`), named by 3.x's table (原画, 高清, 标准, 低清), best first. A
  /// quality's lines are built by [legacyLines]: the redirect playlist with
  /// the tier's CDN signature appended (`hs`, `ks`, `ali`, `fws`, `wy`
  /// first), or the tier's own URLs in a `quickplay` object.
  ///
  /// These are only the fallback when the `video_play_url` answer fails and
  /// the room carries its tier list.
  static List<LivePlayQuality> legacyQualities(CcRoomData data) {
    final tiers = _tiersOf(data);
    if (tiers == null) return const [];
    final found = <({LivePlayQuality quality, int sort})>[];
    for (final MapEntry(key: code, value: tier) in tiers.tiers.entries) {
      final read = _legacyTier(code, CcJson.objectOrNull(tier), live: tiers.live, base: tiers.base);
      if (read != null) found.add((quality: read.quality, sort: read.sort));
    }
    found.sort((a, b) => b.sort.compareTo(a.sort));
    return [for (final tier in found) tier.quality];
  }

  /// The lines of one tier of a channel's tier list: [qualityId] picks the
  /// tier (the best one when null), each URL with the media headers for
  /// [roomId] and its format; no lease (every open asks the redirect again).
  /// A tier the room does not carry is stream-unavailable.
  static List<LivePlayLine> legacyLines(CcRoomData data, String? qualityId, {required String roomId}) {
    final wanted = qualityId?.trim() ?? '';
    final found = <({String code, List<String> urls, int sort})>[];
    final tiers = _tiersOf(data);
    if (tiers != null) {
      for (final MapEntry(key: code, value: tier) in tiers.tiers.entries) {
        final read = _legacyTier(code, CcJson.objectOrNull(tier), live: tiers.live, base: tiers.base);
        if (read != null) found.add((code: code, urls: read.urls, sort: read.sort));
      }
    }
    final chosen = wanted.isEmpty
        ? found.isEmpty
              ? null
              : found.reduce((a, b) => a.sort >= b.sort ? a : b)
        : found.where((tier) => tier.code == wanted).firstOrNull;
    if (chosen == null || chosen.urls.isEmpty) {
      throw CcFailure(CcFailureKind.streamUnavailable, 'quality ${wanted.isEmpty ? 'default' : wanted} has no URL');
    }
    final headers = CcEndpoints.mediaHeaders(roomId);
    return [
      for (final url in chosen.urls)
        LivePlayLine.of(
          url: url,
          format: _format(Uri.parse(url)),
          formatSource: LivePlayFormatSource.inferred,
          headers: headers,
          lineLabel: chosen.code,
        ),
    ];
  }

  /// The tier map a [CcRoomData] carries (`quickplay` answers live,
  /// `stream_list` not) and the redirect playlist its `CDN_FMT` signatures
  /// are appended to; null when it carries none.
  static ({Map<String, dynamic> tiers, bool live, String base})? _tiersOf(CcRoomData data) {
    final raw = data.streams;
    if (raw == null) return null;
    final live = raw['resolution'] == null;
    final tiers = live ? raw : CcJson.objectOrNull(raw['resolution']);
    if (tiers == null) return null;
    return (tiers: tiers, live: live, base: data.playlist?.trim() ?? '');
  }

  /// One tier of a channel's tier list: its quality (3.x's name for the tier
  /// code), its URLs (the signed redirect playlist first by the preferred
  /// CDNs, else the tier's own), and 3.x's sort (the tier's rank, then the
  /// bitrate). Null when the tier has no usable URL.
  static ({LivePlayQuality quality, List<String> urls, int sort})? _legacyTier(
    String code,
    Map<String, dynamic>? tier, {
    required bool live,
    required String base,
  }) {
    if (tier == null) return null;
    final cdns = CcJson.objectOrNull(tier[live ? 'CDN_FMT' : 'cdn']);
    if (cdns == null) return null;
    final preferred = <String>[];
    final others = <String>[];
    for (final MapEntry(key: cdn, value: suffix) in cdns.entries) {
      final url = live && base.isNotEmpty ? _signedPlaylist(base, suffix) : _directUrl(suffix);
      if (Uri.tryParse(url)?.hasScheme != true) continue;
      final target = _preferredCdns.contains(cdn.toLowerCase()) ? preferred : others;
      if (!target.contains(url)) target.add(url);
    }
    final urls = [...preferred, ...others];
    if (urls.isEmpty) return null;
    final kbps = int.tryParse(tier['vbr']?.toString() ?? '') ?? 0;
    return (
      quality: LivePlayQuality.of(
        label: _legacyNames[code] ?? code,
        qualityId: code,
        platformOrder: _legacySort(code, kbps),
      ),
      urls: urls,
      sort: _legacySort(code, kbps),
    );
  }

  /// CDNs whose lines 3.x put first.
  static const List<String> _preferredCdns = ['hs', 'ks', 'ali', 'fws', 'wy'];

  /// 3.x's names for the tier codes.
  static const Map<String, String> _legacyNames = {
    'blueray': '原画',
    'original': '原画',
    'high': '高清',
    'medium': '标准',
    'standard': '标准',
    'low': '低清',
    'ultra': '蓝光',
  };

  /// 3.x's order: the tier's rank (a missing `vbr` must not demote 原画),
  /// then the bitrate; unknown tiers by bitrate alone.
  static int _legacySort(String code, int kbps) {
    final rank = switch (code.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '')) {
      'blueray' || 'original' || 'origin' || 'source' => 6,
      'ultra' => 5,
      'high' || 'hd' => 4,
      'medium' || 'standard' || 'sd' => 3,
      'low' || 'ld' => 2,
      _ => 0,
    };
    return rank == 0 ? kbps : rank * 1000000 + kbps.clamp(0, 999999);
  }

  /// [base] with a `CDN_FMT` value: a protocol-relative or absolute http(s)
  /// URL as it is, a signature appended to the query, nothing for another
  /// scheme (3.x's `_resolveLiveCdnUrl`).
  static String _signedPlaylist(String base, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.startsWith('//')) return 'https:$text';
    final direct = Uri.tryParse(text);
    if (direct != null && direct.hasScheme) {
      return const {'http', 'https'}.contains(direct.scheme.toLowerCase()) ? text : '';
    }
    if (text.isEmpty) return base;
    return '$base${base.contains('?') ? '&' : '?'}${text.replaceFirst(RegExp('^[?&]+'), '')}';
  }

  static String _directUrl(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.startsWith('//') ? 'https:$text' : text;
  }

  // Shared helpers ------------------------------------------------------------

  /// The container by the URL path: `.m3u8` is HLS, `.flv` FLV (every line
  /// seen so far).
  static LiveStreamFormat _format(Uri url) {
    final path = url.path.toLowerCase();
    if (path.endsWith('.m3u8')) return LiveStreamFormat.hls;
    if (path.endsWith('.flv')) return LiveStreamFormat.flv;
    return LiveStreamFormat.other;
  }

  /// The lease of a media URL received at [issuedAt], from the first field
  /// of its `auth_key` (`{Unix seconds}-{rand}-{uid}-{md5}`, 300 seconds
  /// after issue): renewed [CcEndpoints.leaseLead] (at most a quarter of the
  /// lifetime) before. Expiry refuses new connections only; an established
  /// one keeps flowing — an HLS playlist is fetched again and again, so only
  /// it must reconnect. No key, or one already past, is no lease.
  static LivePlayLease? lease(Uri url, DateTime issuedAt, {bool allowExpired = false}) {
    final match = RegExp(r'(?:^|&)auth_key=(\d+)-').firstMatch(url.query);
    final expires = match == null ? null : int.tryParse(match.group(1)!);
    if (expires == null || expires <= 0) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) {
      return allowExpired
          ? LivePlayLease.of(
              refreshAt: expiresAt.subtract(CcEndpoints.leaseLead),
              expiresAt: expiresAt,
              requiresReconnect: _format(url) == LiveStreamFormat.hls,
            )
          : null;
    }
    final quarter = lifetime ~/ 4;
    final lead = quarter < CcEndpoints.leaseLead ? quarter : CcEndpoints.leaseLead;
    return LivePlayLease.of(
      refreshAt: expiresAt.subtract(lead),
      expiresAt: expiresAt,
      requiresReconnect: _format(url) == LiveStreamFormat.hls,
    );
  }

  /// 3.x's `parseRoomAudience`: heat is the first of `webcc_visitor`,
  /// `hot_score`, `visitor`, `total_visitor` (aliases of one value);
  /// concurrent viewers are `vision_visitor`, else `online_num`. Values are
  /// parsed to absolute numbers when they carry a figure at all (an explicit
  /// zero included), else null.
  static (int?, int?) _audience(Map<String, dynamic> room) {
    int? first(List<String> keys) {
      for (final key in keys) {
        final figure = CcJson.figure(room[key]);
        if (figure != null) return figure;
      }
      return null;
    }

    return (
      first(const ['webcc_visitor', 'hot_score', 'visitor', 'total_visitor']),
      first(const ['vision_visitor', 'online_num']),
    );
  }

  /// The audience with the metric a list card leads with: the heat, else the
  /// concurrent viewers, else the follower count, else unknown.
  static RoomAudience _audienceOf({required int? popularity, required int? online, int? followers}) => RoomAudience.of(
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

  static LiveStatus _status(Object? value) => switch (int.tryParse(value?.toString() ?? '')) {
    1 => LiveStatus.live,
    0 => LiveStatus.offline,
    _ => LiveStatus.unknown,
  };

  /// [status], except that a live room titled "【重播】" is an official
  /// rebroadcast of a recorded event: a replay, which plays like a live
  /// stream. The site has no other field for it.
  static LiveStatus _onAirStatus(LiveStatus status, Object? title) =>
      status == LiveStatus.live && CcJson.text(title).trimLeft().startsWith('【重播】') ? LiveStatus.replay : status;

  static bool _onAir(LiveStatus status) => status == LiveStatus.live || status == LiveStatus.replay;

  /// `startat` of a room on air: when this broadcast (or rebroadcast
  /// channel) went on air. Off air it is the last broadcast's, so none.
  static DateTime? _startedAt(Map<String, dynamic> row, LiveStatus status) =>
      _onAir(status) ? CcJson.beijingTime(row['startat']) : null;

  /// No restriction for a room on air whose answer carries its tier list
  /// (`stream_list` or `quickplay`): the site hands the stream to anyone.
  /// Otherwise the answer does not say (null); CC shows no paid, private or
  /// password state on these answers.
  static LiveRestriction? _restriction(Map<String, dynamic> row, LiveStatus status) =>
      _onAir(status) &&
          ((CcJson.objectOrNull(row['stream_list'])?.isNotEmpty ?? false) ||
              CcJson.objectOrNull(row['quickplay']) != null)
      ? LiveRestriction.none
      : null;

  /// [value], else [fallback], as the platform wrote it; empty when neither
  /// is text.
  static String _firstText(Object? value, [Object? fallback]) {
    final text = CcJson.text(value);
    return text.isEmpty ? CcJson.text(fallback) : text;
  }

  /// The first of [values] that normalizes to an image address; empty when
  /// none does.
  static String _firstOf(List<Object?> values) {
    for (final value in values) {
      final image = CcJson.image(value);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  /// [value], else [fallback], made absolute by the shared normalizer; empty
  /// when neither is an image.
  static String _image(Object? value, [Object? fallback]) {
    final image = CcJson.image(value);
    return image.isEmpty ? CcJson.image(fallback) : image;
  }

  /// The decoded JSON of a room page's script, or null.
  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
