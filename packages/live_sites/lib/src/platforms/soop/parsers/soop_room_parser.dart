import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/soop/api/soop_endpoints.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_codec.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_json.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Korea Standard Time, the zone of every `broad_start` (no daylight
/// saving).
const Duration _kst = Duration(hours: 9);

/// One `VIEWPRESET` entry: the request name of a quality and what the
/// platform says about it.
@immutable
final class SoopPreset {
  /// Creates a preset.
  const SoopPreset({required this.name, this.bps = 0, this.codec});

  /// Request name (`sd`, `hd`, `hd4k`, `original`, `auto`).
  final String name;

  /// Bitrate in kbps; 0 when not given.
  final int bps;

  /// `avc` or `hevc` from `vcodec`, when known.
  final String? codec;
}

/// The broadcast behind a room, apart from its identity (the streamer id):
/// what the stream requests need. 3.x kept it in `data` as a map (and the
/// broadcast number also in `userId`).
@immutable
final class SoopRoomData {
  /// Creates the data.
  SoopRoomData({
    required this.bno,
    required this.rmd,
    required this.cdn,
    required List<SoopPreset> presets,
    this.password = false,
  }) : presets = List.unmodifiable(presets);

  /// Broadcast number (`BNO`), new with every broadcast.
  final String bno;

  /// Base URL of the stream manager (`RMD`) that assigns playlists.
  final String rmd;

  /// CDN code (`CDN`), also the line label.
  final String cdn;

  /// `VIEWPRESET` in platform order, `auto` included.
  final List<SoopPreset> presets;

  /// `BPWD` is `Y`: the broadcast asks for a password.
  final bool password;

  /// The codec of preset [name], when known.
  String? codecOf(String name) => presets.where((preset) => preset.name == name).firstOrNull?.codec;
}

/// The broadcast a station names (`broad`).
@immutable
final class SoopStationBroadcast {
  /// Creates the broadcast.
  const SoopStationBroadcast({
    required this.bno,
    this.title = '',
    this.viewers,
    this.startedAt,
    this.restriction = LiveRestriction.none,
  });

  /// `broad_no`.
  final String bno;

  /// `broad_title`, entities decoded.
  final String title;

  /// `current_sum_viewer`: viewers now, PC and mobile.
  final int? viewers;

  /// `station.broad_start` (Korean time) in UTC.
  final DateTime? startedAt;

  /// From `is_password`, `subscription_only` and `broad_grade`.
  final LiveRestriction restriction;
}

/// A streamer's station (`chapi.sooplive.co.kr/api/<id>/station`), read at
/// room entry: the profile the player API lacks and, while one is on, the
/// broadcast.
@immutable
final class SoopStation {
  /// Creates the station.
  const SoopStation({this.nick = '', this.avatar = '', this.introduction = '', this.broadcast});

  /// `station.user_nick`, entities decoded.
  final String nick;

  /// `profile_image`: the profile picture the streamer set.
  final String avatar;

  /// `station.station_title`, the station's tagline.
  final String introduction;

  /// `broad` while broadcasting; null when not.
  final SoopStationBroadcast? broadcast;
}

/// What one player API answer produced: the room, the broadcast data of a
/// live one (the stream requests need it), and — when asked for — the chat
/// arguments of its `CHANNEL`.
typedef SoopDetail = ({LiveRoom room, SoopRoomData? data, SoopDanmakuArgs? danmaku});

/// Pure parsing of SOOP (formerly AfreecaTV) responses (3.x's `SoopSite`,
/// with the archived v4 parser's fixes), into the v2 rooms, areas and play
/// lines. Each function takes the response text and status and returns the
/// models or throws a [SoopFailure].
abstract final class SoopRoomParser {
  // Catalog -------------------------------------------------------------------

  /// `api.php?m=categoryList`: one page of areas, all under the one
  /// category, in platform order (most viewers first). The next page exists
  /// while `is_more` is true; without the flag, while the page is full
  /// (3.x's rule).
  static ({List<LiveArea> areas, bool hasMore}) categoryPage(String body, {int status = 200}) {
    const what = 'categoryList';
    final data = SoopJson.data(body, status: status, what: what);
    final list = SoopJson.listField(data['list'], what, body);
    final areas = [
      for (final raw in list)
        if (SoopJson.object(raw) case final item? when SoopJson.string(item['category_no']) != null)
          LiveArea.normalized(
            platform: soopSiteId,
            areaId: SoopJson.string(item['category_no'])!,
            areaName: SoopJson.display(item['category_name']),
            parentAreaId: SoopEndpoints.category.id,
            parentAreaName: SoopEndpoints.category.name,
            iconUrl: SoopJson.image(item['cate_img']),
          ),
    ];
    final flag = data['is_more'];
    final more = flag == null ? list.length >= SoopEndpoints.categoryPageSize : SoopJson.truthy(flag);
    return (areas: areas, hasMore: areas.isNotEmpty && more);
  }

  /// `api.php?m=categoryContentsList`: live rooms of the area named
  /// [areaName] (the area of every card, as in 3.x). Cards carry their
  /// start time and restriction, like every list (see [restrictionOf]).
  static List<LiveRoom> areaRooms(String body, {required String areaName, int status = 200}) {
    const what = 'categoryContentsList';
    final data = SoopJson.data(body, status: status, what: what);
    return [
      for (final raw in SoopJson.listField(data['list'], what, body))
        if (SoopJson.object(raw) case final item?)
          ?card(item, cover: item['thumbnail'], avatar: SoopJson.image(item['user_profile_img']), area: areaName),
    ];
  }

  /// `main_broad_list_api.php`: live rooms by viewers, 60 a page; the list
  /// ends with an empty page.
  static List<LiveRoom> recommendRooms(String body, {int status = 200}) {
    const what = 'main_broad_list';
    final root = SoopJson.root(body, status: status, what: what);
    return [
      for (final raw in SoopJson.listField(root['broad'], what, body))
        if (SoopJson.object(raw) case final item?)
          ?card(item, cover: item['broad_thumb'], area: item['category_name']?.toString()),
    ];
  }

  // Search --------------------------------------------------------------------

  /// `api.php?m=liveSearch`: live rooms matching the keyword (`REAL_BROAD`).
  /// The results end with an empty page: `HAS_MORE_LIST` stays true and
  /// `TOTAL_CNT` non-zero on empty pages. The area is `broad_cate_name`;
  /// 3.x read `standard_broad_cate_name`, which the answers no longer
  /// carry, and is still read when that is missing.
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    const what = 'liveSearch';
    final root = SoopJson.root(body, status: status, what: what);
    final result = root['RESULT'];
    if (result != null && SoopJson.integer(result) != 1) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: RESULT $result (${SoopJson.snippet(body)})');
    }
    return [
      for (final raw in SoopJson.listField(root['REAL_BROAD'], what, body))
        if (SoopJson.object(raw) case final item?)
          ?card(
            item,
            cover: item['broad_img'],
            area: SoopJson.display(SoopJson.string(item['broad_cate_name']) ?? item['standard_broad_cate_name']),
          ),
    ];
  }

  // Audience ------------------------------------------------------------------

  /// Concurrent viewers of a list entry or `CHANNEL` (3.x's
  /// `parseOnlineViewers`). `total_view_cnt` and `view_cnt` already count
  /// PC and mobile; the PC-only counts are read only when no total said
  /// anything. Order: the first positive of `total_view_cnt`, `view_cnt`,
  /// `VIEW_CNT`; else the positive sum of `pc_view_cnt` + `mobile_view_cnt`,
  /// then of `current_view_cnt` + `m_current_view_cnt`; else `0` when any of
  /// them said zero; else empty.
  static String onlineViewers(Map<String, dynamic> item) {
    String? zero;
    for (final key in const ['total_view_cnt', 'view_cnt', 'VIEW_CNT']) {
      final text = SoopJson.text(item[key]).trim();
      if (text.isEmpty || text == 'null' || !RegExp('[0-9]').hasMatch(text)) continue;
      final value = int.tryParse(text.replaceAll(',', '').replaceAll('，', ''));
      if (value == null) continue;
      if (value > 0) return '$value';
      if (value == 0) zero ??= '0';
    }
    for (final (left, right) in const [
      ('pc_view_cnt', 'mobile_view_cnt'),
      ('current_view_cnt', 'm_current_view_cnt'),
    ]) {
      final a = int.tryParse(SoopJson.text(item[left]).trim().replaceAll(',', ''));
      final b = int.tryParse(SoopJson.text(item[right]).trim().replaceAll(',', ''));
      if (a == null && b == null) continue;
      final total = (a ?? 0) + (b ?? 0);
      if (total > 0) return '$total';
      zero ??= '0';
    }
    return zero ?? '';
  }

  // Rooms ---------------------------------------------------------------------

  /// `player_live_api.php` (`type=live` or `aid`): `CHANNEL` and its
  /// `RESULT`: 1 broadcasting, 0 not broadcasting (or no such streamer: the
  /// answers are the same), -2 blocked, and for a broadcast this client may
  /// not open: -6 age-restricted (login required), -8 age-restricted with a
  /// password, -14 subscribers only. Anything else is api-changed.
  static ({int result, Map<String, dynamic> channel}) channel(String body, {int status = 200}) {
    const what = 'player_live_api';
    final root = SoopJson.root(body, status: status, what: what);
    final channel = SoopJson.object(root['CHANNEL']);
    if (channel == null) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: no CHANNEL (${SoopJson.snippet(body)})');
    }
    final result = SoopJson.integer(channel['RESULT']);
    if (result == null) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: no CHANNEL.RESULT (${SoopJson.snippet(body)})');
    }
    return (result: result, channel: channel);
  }

  /// `player_live_api.php` `type=live`: the room as the user asked for it
  /// (`requestedId`; a follow keeps its identity), the same at every depth.
  ///
  /// - `RESULT` 1: live when `VIEWPRESET` is present, else offline (3.x's
  ///   rule); a live broadcast goes into the `data` of the answer, and with
  ///   [withDanmaku] its `danmaku` carries the chat's arguments. Its
  ///   restriction comes from `BPWD`, `P_MIN_TIER` and `GRADE`
  ///   ([LiveRestriction.none] when none applies).
  /// - 0: offline (an unknown streamer too, which only room entry tells
  ///   apart, with the station); -2: banned.
  /// - -6, -8, -14: live and restricted (adult, password, subscribers
  ///   only): the answer names the title and the elapsed time (not for -14)
  ///   but no stream.
  /// - anything else api-changed.
  ///
  /// Titles and names have their HTML entities decoded. The cover is the
  /// live thumbnail with 3.x's cache buster [now]; `BTIME` (seconds on air)
  /// before [now] is the start time. The answer has no audience figure, so
  /// the audience stays empty (the station adds it at room entry).
  static SoopDetail roomDetail(
    String body, {
    required String requestedId,
    required DateTime now,
    bool withDanmaku = false,
    int status = 200,
  }) {
    const what = 'player_live_api';
    final answer = channel(body, status: status);
    final fields = answer.channel;
    final id = requestedId.trim();
    switch (answer.result) {
      case 1:
        break;
      case 0:
        return (room: _bare(id, LiveStatus.offline), data: null, danmaku: null);
      case -2:
        return (room: _bare(id, LiveStatus.banned), data: null, danmaku: null);
      case -6 || -8 || -14:
        return (
          room: LiveRoom.normalized(
            platform: soopSiteId,
            roomId: id,
            content: RoomContent(title: SoopJson.display(fields['TITLE'])),
            anchor: LiveAnchor.normalized(platform: soopSiteId, anchorId: id, liveStatus: LiveStatus.live),
            broadcast: RoomBroadcast(
              liveStatus: LiveStatus.live,
              startedAt: startedBefore(fields['BTIME'], now),
              restriction: switch (answer.result) {
                -6 => LiveRestriction.adult,
                -8 => LiveRestriction.password,
                _ => LiveRestriction.subscribersOnly,
              },
            ),
            links: RoomLinks(webUrl: SoopEndpoints.roomPageUrl(id)),
          ),
          data: null,
          danmaku: null,
        );
      default:
        throw SoopFailure(SoopFailureKind.apiChanged, '$what: RESULT ${answer.result}');
    }
    final bno = SoopJson.string(fields['BNO']) ?? '';
    final bj = SoopJson.string(fields['BJID']) ?? id;
    final tags = fields['CATEGORY_TAGS'];
    final live = fields['VIEWPRESET'] != null;
    final viewersText = onlineViewers(fields);
    final viewers = int.tryParse(viewersText);
    final room = LiveRoom.normalized(
      platform: soopSiteId,
      roomId: id,
      content: RoomContent(title: SoopJson.display(fields['TITLE']), coverUrl: cover(bno, now)),
      anchor: LiveAnchor.normalized(
        platform: soopSiteId,
        anchorId: id,
        name: SoopJson.display(fields['BJNICK']),
        avatarUrl: SoopEndpoints.logo(bj),
        liveStatus: live ? LiveStatus.live : LiveStatus.offline,
      ),
      area: tags is List && tags.isNotEmpty
          ? LiveArea.normalized(platform: soopSiteId, areaName: SoopJson.text(tags.first))
          : null,
      audience: RoomAudience(
        onlineViewers: viewers,
        primaryMetric: viewers == null ? null : LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast(
        liveStatus: live ? LiveStatus.live : LiveStatus.offline,
        startedAt: live ? startedBefore(fields['BTIME'], now) : null,
        restriction: live
            ? restrictionOf(password: fields['BPWD'], subscribers: fields['P_MIN_TIER'], grade: fields['GRADE'])
            : null,
      ),
      links: RoomLinks(webUrl: SoopEndpoints.roomPageUrl(id)),
    );
    return (
      room: room,
      data: live
          ? SoopRoomData(
              bno: bno,
              rmd: SoopJson.text(fields['RMD']).trim(),
              cdn: SoopJson.text(fields['CDN']).trim(),
              presets: presets(fields['VIEWPRESET']),
              password: SoopJson.truthy(fields['BPWD']),
            )
          : null,
      danmaku: withDanmaku ? danmakuArgs(fields, roomId: id) : null,
    );
  }

  /// The room of a streamer the player API named offline ([liveStatus] also
  /// banned): nothing but its identity and its page.
  static LiveRoom _bare(String id, LiveStatus liveStatus) => LiveRoom.normalized(
    platform: soopSiteId,
    roomId: id,
    anchor: LiveAnchor.normalized(platform: soopSiteId, anchorId: id, liveStatus: liveStatus),
    broadcast: RoomBroadcast(liveStatus: liveStatus),
    links: RoomLinks(webUrl: SoopEndpoints.roomPageUrl(id)),
  );

  /// `chapi.sooplive.co.kr/api/<id>/station`. An unknown streamer is
  /// not-found (HTTP 515, `code` 9000); other failures as every answer's.
  static SoopStation station(String body, {int status = 200}) {
    const what = 'station';
    final decoded = SoopJson.tryDecode(body);
    if (decoded case {'code': final Object code} when SoopJson.integer(code) == 9000) {
      throw SoopFailure(SoopFailureKind.notFound, '$what: no such streamer (${SoopJson.snippet(body)})');
    }
    final root = SoopJson.root(body, status: status, what: what);
    final station = SoopJson.object(root['station']);
    if (station == null) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: no station object (${SoopJson.snippet(body)})');
    }
    final broad = SoopJson.object(root['broad']);
    return SoopStation(
      nick: SoopJson.display(station['user_nick']).trim(),
      avatar: SoopJson.image(root['profile_image']),
      introduction: SoopJson.display(station['station_title']).trim(),
      broadcast: broad == null
          ? null
          : SoopStationBroadcast(
              bno: SoopJson.string(broad['broad_no']) ?? '',
              title: SoopJson.display(broad['broad_title']),
              viewers: SoopJson.count(broad['current_sum_viewer']),
              startedAt: koreanTime(station['broad_start']),
              restriction:
                  restrictionOf(
                    password: broad['is_password'],
                    subscribers: broad['subscription_only'],
                    grade: broad['broad_grade'],
                  ) ??
                  LiveRestriction.none,
            ),
    );
  }

  /// Room entry: [room] (the player API's answer) completed with the
  /// streamer's [station] and the [data] the answer carried. The station's
  /// profile picture, name when the answer has none, and tagline as the
  /// introduction; while live, its broadcast's viewers, and title, cover,
  /// start time and restriction where the answer lacks them (a restricted
  /// answer has no profile).
  ///
  /// A room the player API calls offline while the station names a
  /// broadcast is live: the platform shows it on air but gives this client
  /// no stream, so its restriction is the broadcast's, else
  /// [LiveRestriction.unplayable]. [now] is the cover's cache buster.
  static LiveRoom withStation(LiveRoom room, SoopRoomData? data, SoopStation station, {required DateTime now}) {
    final broadcast = station.broadcast;
    final anchor = room.anchor;
    var merged = room.copyWith(
      content: station.introduction.isEmpty ? room.content : room.content.copyWith(introduction: station.introduction),
    );
    if (anchor == null) {
      if (station.nick.isNotEmpty || station.avatar.isNotEmpty) {
        merged = merged.copyWith(
          anchor: LiveAnchor.normalized(
            platform: soopSiteId,
            anchorId: room.roomId,
            name: station.nick,
            avatarUrl: station.avatar.isEmpty ? null : station.avatar,
          ),
        );
      }
    } else {
      var mergedAnchor = anchor;
      if (anchor.name.isEmpty && station.nick.isNotEmpty) mergedAnchor = mergedAnchor.copyWith(name: station.nick);
      if (station.avatar.isNotEmpty) mergedAnchor = mergedAnchor.copyWith(avatarUrl: station.avatar);
      merged = merged.copyWith(anchor: mergedAnchor);
    }
    final stationBroadcast = broadcast;
    if (stationBroadcast == null || merged.broadcast.effectiveLiveStatus == LiveStatus.banned) return merged;
    final live = merged.broadcast.isLiveNow;
    // A broadcast that ended between the two answers is not this one.
    if (live && data != null && data.bno.isNotEmpty && data.bno != stationBroadcast.bno) return merged;
    if (!live && merged.broadcast.effectiveLiveStatus != LiveStatus.offline) return merged;
    var content = merged.content;
    if (content.title.trim().isEmpty && stationBroadcast.title.isNotEmpty) {
      content = content.copyWith(title: stationBroadcast.title);
    }
    if (content.coverUrl.isEmpty) content = content.copyWith(coverUrl: cover(stationBroadcast.bno, now));
    return merged.copyWith(
      content: content,
      audience: stationBroadcast.viewers == null
          ? merged.audience
          : merged.audience.copyWith(
              onlineViewers: stationBroadcast.viewers,
              primaryMetric: LiveAudienceMetricType.onlineViewers,
            ),
      broadcast: merged.broadcast.copyWith(
        liveStatus: LiveStatus.live,
        startedAt: merged.broadcast.startedAt ?? stationBroadcast.startedAt,
        restriction: live
            ? stricter(merged.broadcast.restriction, stationBroadcast.restriction)
            : (stationBroadcast.restriction == LiveRestriction.none
                  ? LiveRestriction.unplayable
                  : stationBroadcast.restriction),
      ),
    );
  }

  /// Why [room] (the player API's answer when a stream was asked for) has
  /// no stream: an age-restricted broadcast needs a login (needs-login); a
  /// password, subscribers-only or otherwise unplayable one, or a room off
  /// the air, is stream-unavailable naming the reason.
  static SoopFailure noStream(LiveRoom room) => switch (room.broadcast.restriction) {
    LiveRestriction.adult => SoopFailure(
      SoopFailureKind.needsLogin,
      'player_live_api: ${room.roomId} is age-restricted',
    ),
    LiveRestriction.password => SoopFailure(
      SoopFailureKind.streamUnavailable,
      'player_live_api: ${room.roomId} is password-protected',
    ),
    LiveRestriction.subscribersOnly => SoopFailure(
      SoopFailureKind.streamUnavailable,
      'player_live_api: ${room.roomId} is for subscribers only',
    ),
    _ => SoopFailure(
      SoopFailureKind.streamUnavailable,
      'player_live_api: ${room.roomId} is ${room.broadcast.effectiveLiveStatus.name}',
    ),
  };

  /// The restriction a broadcast's flags state, or null when none of them
  /// is given: a password (`BPWD`, `is_password`: `Y`, `1`, `true`) before
  /// subscribers only (`P_MIN_TIER`, `subscription_only` above 0) before
  /// adult (grade 19); [LiveRestriction.none] when the flags say none. The
  /// order puts first what a login alone does not lift.
  static LiveRestriction? restrictionOf({Object? password, Object? subscribers, Object? grade}) {
    if (password == null && subscribers == null && grade == null) return null;
    if (SoopJson.truthy(password)) return LiveRestriction.password;
    if ((SoopJson.integer(subscribers) ?? 0) > 0) return LiveRestriction.subscribersOnly;
    if (SoopJson.integer(grade) == 19) return LiveRestriction.adult;
    return LiveRestriction.none;
  }

  /// The stronger of two restrictions in [restrictionOf]'s order; null only
  /// when both are.
  static LiveRestriction? stricter(LiveRestriction? a, LiveRestriction? b) {
    const order = [
      LiveRestriction.password,
      LiveRestriction.subscribersOnly,
      LiveRestriction.adult,
      LiveRestriction.unplayable,
    ];
    for (final kind in order) {
      if (a == kind || b == kind) return kind;
    }
    return a ?? b;
  }

  /// A `broad_start` (`2026-09-22 19:59:31`, lists add `.0`) in UTC: SOOP
  /// writes Korean time (UTC+9; `BTIME` of the same broadcast and every
  /// list's latest start before its recording agree). Null when missing,
  /// malformed or not after 1970.
  static DateTime? koreanTime(Object? value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?$')
        .firstMatch(SoopJson.string(value) ?? '');
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final local = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
    if (local.month != parts[1] || local.day != parts[2] || local.hour != parts[3]) return null;
    final utc = local.subtract(_kst);
    return utc.millisecondsSinceEpoch > 0 ? utc : null;
  }

  /// The start of a broadcast on air for `BTIME` [seconds] at [now], to the
  /// second; null for a missing, zero or negative time.
  static DateTime? startedBefore(Object? seconds, DateTime now) {
    final elapsed = SoopJson.integer(seconds);
    if (elapsed == null || elapsed <= 0) return null;
    final start = now.toUtc().millisecondsSinceEpoch ~/ 1000 - elapsed;
    return start > 0 ? DateTime.fromMillisecondsSinceEpoch(start * 1000, isUtc: true) : null;
  }

  /// The live thumbnail of broadcast [bno] with 3.x's cache buster.
  static String cover(String bno, DateTime now) =>
      bno.isEmpty ? '' : 'https://liveimg.sooplive.co.kr/m/$bno?_t=${now.millisecondsSinceEpoch}';

  /// `VIEWPRESET` entries with a name, in platform order.
  static List<SoopPreset> presets(Object? value) => [
    for (final raw in value is List ? value.cast<Object?>() : const <Object?>[])
      if (SoopJson.object(raw) case final item? when SoopJson.text(item['name']).trim().isNotEmpty)
        SoopPreset(
          name: SoopJson.text(item['name']).trim(),
          bps: int.tryParse(SoopJson.text(item['bps']).trim()) ?? 0,
          codec: switch (SoopJson.text(item['vcodec']).trim().toLowerCase()) {
            'h264' || 'avc' => 'avc',
            'h265' || 'hevc' => 'hevc',
            _ => null,
          },
        ),
  ];

  /// The danmaku arguments of a `CHANNEL` for streamer [roomId] (3.x's
  /// `buildDanmakuWebSocketUrl`): the chat host is `CHDOMAIN`, else
  /// `chat-<CHIP as hex>.sooplive.com`, and the TLS port is `CHPT + 1`.
  /// Null without `CHATNO`, a host or a plain port below 65535 (3.x
  /// connected nothing then).
  static SoopDanmakuArgs? danmakuArgs(Map<String, dynamic> channel, {required String roomId}) {
    final id = roomId.trim();
    final chatNo = SoopJson.text(channel['CHATNO']).trim();
    final host = SoopJson.string(channel['CHDOMAIN']) ?? _chatHost(SoopJson.text(channel['CHIP']).trim());
    final port = SoopJson.integer(channel['CHPT']);
    if (id.isEmpty || chatNo.isEmpty || host == null || port == null || port <= 0 || port >= 65535) return null;
    return SoopDanmakuArgs(
      url: Uri(scheme: 'wss', host: host, port: port + 1, pathSegments: ['Websocket', id]),
      plainUrl: Uri(scheme: 'ws', host: host, port: port, pathSegments: ['Websocket', id]),
      chatNo: chatNo,
      headers: {...SoopEndpoints.apiHeaders(), 'origin': 'https://${SoopEndpoints.playHost}'},
    );
  }

  /// `chat-<IPv4 as eight hex digits>.sooplive.com`, or null: the domain of
  /// every chat host the API names (`CHDOMAIN`, e.g. `chat-6E0A4C4E` for
  /// `CHIP` 110.10.76.78), as the archived v4 built it.
  static String? _chatHost(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null || part < 0 || part > 255)) return null;
    return 'chat-${parts.map((part) => part!.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}.sooplive.com';
  }

  // Streams -------------------------------------------------------------------

  /// Qualities of [presets] (3.x's `getPlayQualites`): `auto` and nameless
  /// entries left out, one per name (case ignored, the first wins), the
  /// request name as id, named by [qualityName], best first by
  /// [qualitySort].
  static List<LivePlayQuality> qualities(List<SoopPreset> presets) {
    final seen = <String>{};
    final options = <(SoopPreset, LivePlayQuality)>[];
    for (final preset in presets) {
      final key = preset.name.toLowerCase();
      if (key == 'auto' || !seen.add(key)) continue;
      options.add((preset, LivePlayQuality(label: qualityName(preset), qualityId: preset.name)));
    }
    final ordered = options.indexed.toList()
      ..sort((a, b) {
        final bySort = qualitySort(b.$2.$1.name, b.$2.$1.bps).compareTo(qualitySort(a.$2.$1.name, a.$2.$1.bps));
        return bySort != 0 ? bySort : a.$1.compareTo(b.$1);
      });
    return [for (final (index, (_, quality)) in ordered) quality.copyWith(platformOrder: index)];
  }

  /// The name of [preset] (3.x's `LiveQualityLabel` names: 原画, 高清, 标清,
  /// …). The transcodes 3.x showed under their request names are named on
  /// the same scale: `hd4k` (720p) 超清, and `hd8k` (the 1080p transcode of
  /// a 1440p source) 蓝光. Ids stay the request names, so no stored choice
  /// needs migrating.
  static String qualityName(SoopPreset preset) => switch (_token(preset.name)) {
    'hd8k' => '蓝光',
    'hd4k' => '超清',
    _ => _qualityLabel(preset),
  };

  static String _qualityLabel(SoopPreset preset) {
    final raw = preset.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(r'[\u3400-\u9fff]').hasMatch(raw)) return raw;
    final token = _token(raw);
    final mapped = _soopLabel(token) ?? _genericLabel(token);
    if (mapped != null) return mapped;
    if (raw.isNotEmpty) return raw;
    if (preset.bps > 0) return _bitrateLabel(preset.bps);
    return '清晰度 ${preset.name}';
  }

  static String? _soopLabel(String token) => switch (token) {
    'original' || 'origin' || 'source' => '原画',
    'master' || 'uhd' => '蓝光',
    'fullhd' || 'fhd' => '超清',
    'hd' => '高清',
    'sd' || 'normal' => '标清',
    'low' || 'ld' => '流畅',
    'auto' => '自动',
    _ => null,
  };

  static String? _genericLabel(String token) => switch (token) {
    'origion' => '原画',
    'blue' || 'bluray' || 'blueray' => '蓝光',
    'super' || 'superhd' => '超清',
    'high' => '高清',
    'standard' || 'medium' => '标清',
    'smooth' || 'fluent' => '流畅',
    'default' => '默认',
    _ => null,
  };

  static String _bitrateLabel(int bitsPerSecond) {
    if (bitsPerSecond >= 1000000) {
      final mbps = bitsPerSecond / 1000000;
      return '${mbps.toStringAsFixed(mbps == mbps.roundToDouble() ? 0 : 1)} Mbps';
    }
    return '${(bitsPerSecond / 1000).round()} Kbps';
  }

  /// The order of a preset (3.x's `_qualitySort`): the name's tier first,
  /// the bitrate within it, so a source without a bitrate never falls below
  /// a transcode. Tiers: `original` > `master` > `fullhd`, `hd8k` (1080p) >
  /// `hd4k` (720p) > `hd` (540p) > `sd` > `low`; other names rank by bitrate
  /// alone, below every tier. The other tiers' values are 3.x's.
  static int qualitySort(String name, int bps) {
    final tier = switch (_token(name)) {
      'original' || 'origin' || 'source' => 600000000,
      'master' || 'uhd' => 500000000,
      'fullhd' || 'fhd' || 'hd8k' => 400000000,
      'hd4k' => 350000000,
      'hd' => 300000000,
      'sd' || 'normal' => 200000000,
      'low' || 'ld' => 100000000,
      _ => 0,
    };
    return tier == 0 ? bps : tier + bps.clamp(0, 49999999);
  }

  static String _token(String name) => name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '');

  /// The `return_type` of the stream assignment for CDN code [cdn].
  static String returnType(String cdn) {
    if (cdn.contains('gs_cdn')) return 'gs_cdn_pc_web';
    if (cdn.contains('lg_cdn')) return 'lg_cdn_pc_web';
    return cdn;
  }

  /// `<RMD>/broad_stream_assign.html` for preset [quality] of broadcast
  /// [bno] (RMD's own path kept, a trailing `/` dropped).
  static Uri assignUrl({required String rmd, required String cdn, required String bno, required String quality}) {
    final base = Uri.tryParse('${rmd.replaceAll(RegExp(r'/$'), '')}/broad_stream_assign.html');
    if (base == null || !(base.isScheme('http') || base.isScheme('https')) || base.host.isEmpty) {
      throw SoopFailure(SoopFailureKind.apiChanged, 'player_live_api: RMD "$rmd" is not a URL');
    }
    return base.replace(queryParameters: {'return_type': returnType(cdn), 'broad_key': '$bno-common-$quality-hls'});
  }

  /// `broad_stream_assign.html`: the playlist URL (`view_url`). A `result`
  /// other than 1 is stream-unavailable; 1 without a URL api-changed.
  static String assignedPlaylist(String body, {int status = 200}) {
    const what = 'broad_stream_assign';
    final root = SoopJson.root(body, status: status, what: what);
    final result = SoopJson.integer(root['result']);
    if (result != 1) {
      throw SoopFailure(SoopFailureKind.streamUnavailable, '$what: result ${root['result']}');
    }
    final url = SoopJson.url(root['view_url']);
    if (url == null) {
      throw SoopFailure(SoopFailureKind.apiChanged, '$what: no view_url (${SoopJson.snippet(body)})');
    }
    return SoopJson.string(root['view_url'])!;
  }

  /// `player_live_api.php` `type=aid`: the stream key. -6 is needs-login
  /// (age-restricted); any other answer without a key stream-unavailable
  /// (3.x got an empty key and no URL), noting a [password] broadcast
  /// (asked without its password the key is refused with `RESULT` 0).
  static String aid(String body, {int status = 200, bool password = false}) {
    const what = 'aid';
    final answer = channel(body, status: status);
    if (answer.result == -6) {
      throw const SoopFailure(SoopFailureKind.needsLogin, 'aid: RESULT -6 (age-restricted broadcast)');
    }
    final aid = SoopJson.string(answer.channel['AID']);
    if (answer.result != 1 || aid == null) {
      throw SoopFailure(
        SoopFailureKind.streamUnavailable,
        '$what: RESULT ${answer.result}${password ? ', password-protected' : ''}',
      );
    }
    return aid;
  }

  /// The line of [playlist] with stream key [aid] (3.x's
  /// `'$view_url?aid=$aid'`) for streamer [roomId]: the media headers, HLS,
  /// [codec], the CDN code as line label and no lease (a playlist with its
  /// key keeps working; recovery asks again). The platform does not say
  /// which quality it applied; the requested one is assumed, as 3.x did.
  static LivePlayLine resolution({
    required String playlist,
    required String aid,
    required String roomId,
    required String cdn,
    String? codec,
  }) {
    final url = '$playlist${playlist.contains('?') ? '&' : '?'}aid=$aid';
    final uri = Uri.parse(url);
    return LivePlayLine(
      url: url,
      format: uri.path.toLowerCase().endsWith('.flv') ? LiveStreamFormat.flv : LiveStreamFormat.hls,
      formatSource: LivePlayFormatSource.inferred,
      headers: SoopEndpoints.mediaHeaders(roomId),
      codec: switch (codec) {
        'avc' => LiveStreamCodec.avc,
        'hevc' => LiveStreamCodec.hevc,
        _ => null,
      },
      lineLabel: cdn.isEmpty ? uri.host : cdn,
    );
  }

  // Lists ---------------------------------------------------------------------

  /// A list card: live, the audience from [onlineViewers], the avatar
  /// [avatar] or the one built from the id. Null without `user_id`.
  ///
  /// Title and name have their entities decoded; `broad_start` is the start
  /// time; `is_password`, `subscription_only` and the grade (`broad_grade`,
  /// or `grade` in area lists) the restriction, the card staying live
  /// (restricted broadcasts are listed as 3.x listed them).
  static LiveRoom? card(Map<String, dynamic> item, {required Object? cover, String avatar = '', String? area}) {
    final id = SoopJson.string(item['user_id']);
    if (id == null) return null;
    final viewers = int.tryParse(onlineViewers(item));
    final areaName = area == null || area.isEmpty ? null : area;
    return LiveRoom.normalized(
      platform: soopSiteId,
      roomId: id,
      content: RoomContent(title: SoopJson.display(item['broad_title']), coverUrl: SoopJson.image(cover)),
      anchor: LiveAnchor.normalized(
        platform: soopSiteId,
        anchorId: id,
        name: SoopJson.display(item['user_nick']),
        avatarUrl: avatar.isEmpty ? SoopEndpoints.avatar(id) : avatar,
        liveStatus: LiveStatus.live,
      ),
      area: areaName == null ? null : LiveArea.normalized(platform: soopSiteId, areaName: areaName),
      audience: RoomAudience(
        onlineViewers: viewers,
        primaryMetric: viewers == null ? null : LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast(
        liveStatus: LiveStatus.live,
        startedAt: koreanTime(item['broad_start']),
        restriction: restrictionOf(
          password: item['is_password'],
          subscribers: item['subscription_only'],
          grade: item['broad_grade'] ?? item['grade'],
        ),
      ),
      links: RoomLinks(webUrl: SoopEndpoints.roomPageUrl(id)),
    );
  }
}
