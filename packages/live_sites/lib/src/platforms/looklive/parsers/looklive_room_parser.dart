import 'dart:convert';

import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_json.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// Pure parsing of LOOK Live (NetEase) answers (3.x's `LookLiveApi`): the
/// recommendation lists, the room answer, the chat servers, and the rooms,
/// qualities and lines the models carry. Each function takes the answer and
/// its status and returns the parsed values or throws a [LookliveFailure].
abstract final class LookliveRoomParser {
  // Catalog -------------------------------------------------------------------

  /// The one category LOOK 直播 with the video and voice areas, the first
  /// [pageSize] of them.
  static List<LiveArea> areas({int pageSize = 2}) =>
      [LookliveEndpoints.videoArea, LookliveEndpoints.audioArea].take(pageSize).toList();

  /// The list of [area]: null for none (the merged recommendations); the
  /// video or voice area; anything else is a caller error.
  static LookLiveKind? kindOf(LiveArea? area) {
    if (area == null) return null;
    if (area.platform == lookliveSiteId) {
      final kind = LookliveEndpoints.kindOfAreaId(area.areaId);
      if (kind != null) return kind;
    }
    throw LookliveFailure(LookliveFailureKind.invalidArgument, 'area "${area.identityKey}" is not a LOOK Live area');
  }

  /// Whether [room] matches the lower-case [query] of the search filter: in
  /// its number, or its name or title (case ignored).
  static bool matches(LookLiveRoom room, String query) =>
      room.roomId.contains(query) ||
      room.nick.toLowerCase().contains(query) ||
      room.title.toLowerCase().contains(query);

  // Lists ---------------------------------------------------------------------

  /// A recommendation page of [kind]: the `type` "1" entries with live data;
  /// a card of the other kind is skipped (the voice list injects video
  /// cards), as is an entry without `liveData`. Each room once, where it
  /// first appeared, with the last card's data.
  ///
  /// An entry that cannot be read (not an object, a `liveType` other than 1
  /// or 2, a card failing the field checks) is skipped, unless nothing on
  /// the page can be read: then the page is api-changed, as are more than
  /// [LookliveEndpoints.maxEntries] entries and a `hasMore` that is not a
  /// boolean. A bad stream address costs only that stream of the card.
  ///
  /// A list past its end answers `itemList: null` with `hasMore: false`
  /// (S04-video-p2); that is an empty last page.
  static LookLivePage directory(String body, {required LookLiveKind kind, int status = 200}) {
    final what = kind == LookLiveKind.audio ? 'voice list' : 'video list';
    final data = LookliveJson.data(body, status: status, what: what);
    final rows = data['itemList'];
    final hasMore = data['hasMore'];
    if (rows == null && hasMore == false) return LookLivePage.empty;
    if (rows is! List || rows.length > LookliveEndpoints.maxEntries || hasMore is! bool) {
      throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        '$what: itemList ${rows is List ? 'of ${rows.length}' : 'is ${LookliveJson.kindOf(rows)}'}, '
        'hasMore ${LookliveJson.kindOf(hasMore)}',
      );
    }
    final rooms = <String, LookLiveRoom>{};
    var unreadable = 0;
    for (final row in rows) {
      final LookLiveRoom? room;
      try {
        room = _entry(row, kind: kind, what: what);
      } on LookliveFailure {
        unreadable++;
        continue;
      }
      if (room != null) rooms[room.roomId] = room;
    }
    if (unreadable > 0 && rooms.isEmpty) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: $unreadable unreadable entries, no room');
    }
    return LookLivePage(rooms: rooms.values, hasMore: hasMore);
  }

  /// The card of a list entry, or null for another kind of entry or card;
  /// api-changed when it cannot be read.
  static LookLiveRoom? _entry(Object? row, {required LookLiveKind kind, required String what}) {
    final item = LookliveJson.object(row, '$what entry');
    if ('${item['type']}' != '1' || item['liveData'] == null) return null;
    final live = LookliveJson.object(item['liveData'], '$what liveData');
    return kindOfLiveType(live['liveType'], what) == kind ? _card(live, kind: kind, what: what) : null;
  }

  /// A list card: number `userInfo.liveRoomNo` (a room number, 2 to 18
  /// digits), account `userInfo.userId`, session `liveId` (all required
  /// ids), title `liveTitle`, name `userInfo.nickname`, avatar, cover, heat
  /// `popularity`, viewers `onlineNumber` (null when missing, else a
  /// non-negative integer), stream type `type` (the lists carry no
  /// `liveStreamType`) and the streams of `liveUrl`; live.
  static LookLiveRoom _card(Map<String, dynamic> live, {required LookLiveKind kind, required String what}) {
    final user = LookliveJson.object(live['userInfo'], '$what userInfo');
    final roomId = LookliveJson.id(user['liveRoomNo'], '$what liveRoomNo');
    if (!LookliveEndpoints.isRoomNumber(roomId)) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: room number $roomId is not 2 to 18 digits');
    }
    final urls = live['liveUrl'];
    return LookLiveRoom(
      roomId: roomId,
      userId: LookliveJson.id(user['userId'], 'userId of $roomId'),
      sessionId: LookliveJson.id(live['liveId'], 'liveId of $roomId'),
      title: LookliveJson.text(live['liveTitle']),
      nick: LookliveJson.text(user['nickname']),
      avatar: LookliveJson.picture(user['avatarUrl']),
      cover: LookliveJson.picture(live['liveCoverUrl']),
      kind: kind,
      streamType: LookliveJson.integer(live['liveStreamType'] ?? live['type']),
      state: LookLiveState.live,
      popularity: LookliveJson.count(live['popularity'], 'popularity of $roomId'),
      currentViewers: LookliveJson.count(live['onlineNumber'], 'onlineNumber of $roomId'),
      hasAddress: hasAddress(urls),
      mediaChecked: true,
      variants: variants(urls),
    );
  }

  // Room ----------------------------------------------------------------------

  /// `room/get/v3` for [roomId]: the anchor must answer for this number
  /// (else api-changed); state from `liveStatus` (1 live; 0, -1 and -2
  /// offline; -10 and -4 banned; anything else unknown); kind from
  /// `roomInfo.liveType` (1 or 2, else api-changed); account, session
  /// (required ids), title, name, avatar, cover, stream type, whether it
  /// carries addresses, the ticket (`feeInfo`) and, when live, the start
  /// (`roomInfo.startTime`). The streams are read only with [withMedia] and
  /// when live (a refresh never looks at them); a bad address costs only
  /// its stream. No audience: the answer has none.
  static LookLiveRoom room(String body, {required String roomId, bool withMedia = true, int status = 200}) {
    const what = 'room/get/v3';
    final data = LookliveJson.data(body, status: status, what: what, room: true);
    final anchor = LookliveJson.object(data['anchor'], '$what anchor');
    final answered = LookliveJson.id(anchor['liveRoomNo'], '$what anchor.liveRoomNo');
    if (answered != roomId) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: asked $roomId, got $answered');
    }
    final info = LookliveJson.object(data['roomInfo'], '$what roomInfo');
    final kind = kindOfLiveType(info['liveType'], what);
    final state = switch (LookliveJson.integer(data['liveStatus'])) {
      1 => LookLiveState.live,
      0 || -1 || -2 => LookLiveState.offline,
      -10 || -4 => LookLiveState.banned,
      _ => LookLiveState.unknown,
    };
    final live = state == LookLiveState.live;
    final urls = info['liveUrl'];
    return LookLiveRoom(
      roomId: roomId,
      userId: LookliveJson.id(anchor['userId'], 'userId of $roomId'),
      sessionId: LookliveJson.id(info['id'], 'roomInfo.id of $roomId'),
      title: LookliveJson.text(info['title']),
      nick: LookliveJson.text(anchor['nickName']),
      avatar: LookliveJson.picture(anchor['avatarUrl']),
      cover: LookliveJson.picture(info['liveCoverUrl']),
      kind: kind,
      streamType: LookliveJson.integer(info['liveStreamType']),
      state: state,
      startedAt: live ? LookliveJson.startedAt(info['startTime']) : null,
      hasAddress: hasAddress(urls),
      mediaChecked: withMedia && live,
      paid: LookliveJson.paid(data['feeInfo']),
      chatroomId: LookliveJson.optionalId(info['roomId']),
      anonymousMode: data['anonymousMode'] == true,
      variants: withMedia && live ? variants(urls) : const [],
    );
  }

  /// The `liveType` of an entry or answer: 1 video, 2 voice, anything else
  /// api-changed.
  static LookLiveKind kindOfLiveType(Object? liveType, String what) => switch (LookliveJson.integer(liveType)) {
    1 => LookLiveKind.video,
    2 => LookLiveKind.audio,
    _ => throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: liveType ${LookliveJson.kindOf(liveType)}'),
  };

  // Streams -------------------------------------------------------------------

  /// The streams of `liveUrl`: the HLS playlist, then the FLV stream, each
  /// when present and accepted by [LookliveEndpoints.mediaUri]. A bad
  /// address, or a `liveUrl` that is not an object, costs only its streams.
  static List<LookLiveVariant> variants(Object? value) {
    if (value is! Map<String, dynamic>) return const [];
    return [
      for (final (id, key, format) in const [
        (LookliveEndpoints.hlsId, 'hlsPullUrl', LiveStreamKind.hls),
        (LookliveEndpoints.flvId, 'httpPullUrl', LiveStreamKind.flv),
      ])
        if (LookliveJson.text(value[key]) case final raw when raw.isNotEmpty)
          if (_mediaUriOrNull(raw, format) case final uri?) LookLiveVariant(id: id, format: format, uri: uri),
    ];
  }

  static Uri? _mediaUriOrNull(String raw, LiveStreamKind format) {
    try {
      return LookliveEndpoints.mediaUri(raw, format: format);
    } on LookliveFailure {
      return null;
    }
  }

  /// Whether `liveUrl` carries an HLS or FLV address, valid or not.
  static bool hasAddress(Object? value) =>
      value is Map &&
      (LookliveJson.text(value['hlsPullUrl']).isNotEmpty || LookliveJson.text(value['httpPullUrl']).isNotEmpty);

  // Chat servers --------------------------------------------------------------

  /// The chat servers of a [LookliveEndpoints.chatAddressPath] answer:
  /// `data.address`, in the answer's order. No `address` list, or none
  /// usable, is api-changed. The envelope is the other answers' (a `code`
  /// 404 "无资源", for a room that is not live, is not-found).
  static List<String> chatAddresses(String body, {int status = 200}) {
    const what = 'chat/address';
    final data = LookliveJson.data(body, status: status, what: what);
    final raw = data['address'];
    if (raw is! List) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: address is ${LookliveJson.kindOf(raw)}');
    }
    final addresses = LookliveEndpoints.chatAddressList(raw);
    if (addresses.isEmpty) {
      throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        '$what: no usable address in ${LookliveEndpoints.snippet(jsonEncode(raw))}',
      );
    }
    return addresses;
  }

  // Rooms ---------------------------------------------------------------------

  /// The room of [room]: the number, account, title and name; the avatar,
  /// else the cover; the area by kind; current viewers and heat, each kept
  /// apart, with the figure a list card leads with; the state (live,
  /// offline, banned or unknown); the start and the restriction; the notice
  /// lines (banned, app-only, ticket, chat); the room page as the web link.
  /// A number that is not 2 to 18 digits is api-changed.
  static LiveRoom liveRoom(LookLiveRoom room) {
    if (!LookliveEndpoints.isRoomNumber(room.roomId)) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, 'room number ${room.roomId} is not 2 to 18 digits');
    }
    final online = room.currentViewers;
    final heat = room.popularity;
    final restriction = _restriction(room);
    final liveStatus = switch (room.state) {
      LookLiveState.live => LiveStatus.live,
      LookLiveState.offline => LiveStatus.offline,
      LookLiveState.banned => LiveStatus.banned,
      LookLiveState.unknown => LiveStatus.unknown,
    };
    final notice = [
      if (room.state == LookLiveState.banned) LookliveEndpoints.bannedNotice,
      if (restriction == LiveRestriction.appOnly) LookliveEndpoints.appOnlyNotice,
      if (restriction == LiveRestriction.paid) LookliveEndpoints.paidNotice,
      LookliveEndpoints.chatNotice,
    ].join('\n');
    return LiveRoom.normalized(
      platform: lookliveSiteId,
      roomId: room.roomId,
      content: RoomContent.of(title: room.title, coverUrl: room.cover, notice: notice),
      anchor: LiveAnchor.normalized(
        platform: lookliveSiteId,
        anchorId: room.userId,
        name: room.nick,
        avatarUrl: room.avatar.isEmpty ? room.cover : room.avatar,
        liveStatus: liveStatus,
      ),
      audience: RoomAudience.of(
        popularity: heat,
        onlineViewers: online,
        primaryMetric: online != null
            ? LiveAudienceMetricType.onlineViewers
            : heat != null
            ? LiveAudienceMetricType.popularity
            : LiveAudienceMetricType.unknown,
      ),
      broadcast: RoomBroadcast.of(liveStatus: liveStatus, startedAt: room.startedAt, restriction: restriction),
      links: RoomLinks.of(webUrl: LookliveEndpoints.roomUrl(room.roomId)),
      area: room.kind == LookLiveKind.audio ? LookliveEndpoints.audioArea : LookliveEndpoints.videoArea,
    );
  }

  /// The room's restriction for our model: null keeps "the source said
  /// nothing" (an unknown state, or a playable list card that does not tell
  /// tickets).
  static LiveRestriction? _restriction(LookLiveRoom room) => switch (room.block) {
    null => null,
    LookLiveBlock.none => LiveRestriction.none,
    LookLiveBlock.appOnly => LiveRestriction.appOnly,
    LookLiveBlock.paid => LiveRestriction.paid,
    LookLiveBlock.unplayable => LiveRestriction.unplayable,
  };

  // Qualities and lines -------------------------------------------------------

  /// The qualities of a playable [room]: one per stream, HLS first (the
  /// platform's order as `platformOrder`, best first).
  static List<LivePlayQuality> qualities(LookLiveRoom room) {
    final total = room.variants.length;
    return [
      for (final (index, variant) in room.variants.indexed)
        LivePlayQuality.of(
          label: variant.format == LiveStreamKind.hls ? LookliveEndpoints.hlsLabel : LookliveEndpoints.flvLabel,
          qualityId: variant.id,
          platformOrder: total - index,
        ),
    ];
  }

  /// The line of quality [qualityId] of a playable [room]: its stream, the
  /// host as line label, and the web's media headers. No lease: the
  /// addresses carry no signature or expiry. No codec: the answer does not
  /// say it (voice rooms have no video). A quality the room lacks is
  /// stream-unavailable; one that is not LOOK's is a caller error.
  static LivePlayLine line(LookLiveRoom room, String qualityId) {
    if (qualityId != LookliveEndpoints.hlsId && qualityId != LookliveEndpoints.flvId) {
      throw LookliveFailure(LookliveFailureKind.invalidArgument, 'quality "$qualityId" is not a LOOK Live quality');
    }
    for (final variant in room.variants) {
      if (variant.id == qualityId) {
        return LivePlayLine.of(
          url: '${variant.uri}',
          format: variant.format == LiveStreamKind.hls ? LiveStreamFormat.hls : LiveStreamFormat.flv,
          formatSource: LivePlayFormatSource.declared,
          headers: LookliveEndpoints.mediaHeaders(room.roomId),
          lineLabel: variant.uri.host,
        );
      }
    }
    throw LookliveFailure(LookliveFailureKind.streamUnavailable, '${room.roomId} has no $qualityId');
  }
}
