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
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Which list a room belongs to: `liveType` 1 is video, 2 is voice.
enum LookliveKind {
  /// `liveType` 1.
  video,

  /// `liveType` 2.
  audio,
}

/// A room's state in the room answer. List cards are always live.
///
/// The values follow LOOK's web client, whose `LIVE_STATUS_TYPE` is
/// `{NOLIVE: 0, LIVING: 1, FORBID: -10}`: the room page shows
/// "- 直播间已关闭 -" for -1, 0 and -2, and for -4 hides the stream behind
/// "该直播间已涉嫌违规…整改期间直播内容将被屏蔽".
enum LookliveState {
  /// `liveStatus` 1.
  live,

  /// `liveStatus` 0, -1 or -2.
  offline,

  /// `liveStatus` -10 (`FORBID`: the room may not broadcast) or -4 (blocked
  /// while it corrects a violation).
  banned,

  /// Any other `liveStatus`, or none.
  unknown,
}

/// One stream of a room: the HLS playlist (`hlsPullUrl`) or the FLV stream
/// (`httpPullUrl`) on NetEase's CDN, made https.
final class LookliveVariant {
  /// Creates a stream.
  const LookliveVariant({required this.id, required this.format, required this.uri});

  /// The quality id: `hls:source` or `flv:source`.
  final String id;

  /// HLS or FLV.
  final LiveStreamFormat format;

  /// The address.
  final Uri uri;
}

/// A LOOK room: a list card, or the room answer (`room/get/v3`), completed
/// from what was seen before ([LookliveRoom.enrich]).
///
/// It is also the stream handle of a room entry: the room's identity, the
/// streamer's account and the broadcast's session, and the streams read at
/// that moment (never stored).
final class LookliveRoom {
  /// Creates a room.
  const LookliveRoom({
    required this.roomId,
    required this.userId,
    required this.sessionId,
    required this.kind,
    required this.state,
    this.title = '',
    this.nick = '',
    this.avatar = '',
    this.cover = '',
    this.streamType,
    this.popularity,
    this.currentViewers,
    this.startedAt,
    this.hasAddress = false,
    this.mediaChecked = false,
    this.paid,
    this.chatroomId = '',
    this.anonymousMode = false,
    this.variants = const [],
  });

  /// The room number (`liveRoomNo`): the room's identity.
  final String roomId;

  /// The streamer's account (`userId`).
  final String userId;

  /// The broadcast (`liveId` of a card, `roomInfo.id` of the room answer).
  final String sessionId;

  /// The title; '' when unknown.
  final String title;

  /// The streamer's name; '' when unknown.
  final String nick;

  /// The streamer's avatar, https; '' when unknown.
  final String avatar;

  /// The cover, https; '' when unknown.
  final String cover;

  /// Video or voice.
  final LookliveKind kind;

  /// The stream type: `liveStreamType` of the room answer, `type` of a list
  /// card's `liveData`. 1 normal, 6 audio, 12 mobile game, 19 music festival
  /// and 50 multi-person; 50 is a room type the website has no media for.
  final int? streamType;

  /// The state.
  final LookliveState state;

  /// The list's heat (`popularity`); null when unknown.
  final int? popularity;

  /// The list's current viewers (`onlineNumber`); null when unknown.
  final int? currentViewers;

  /// When the broadcast started (`roomInfo.startTime`, epoch milliseconds),
  /// for a live room answer; null otherwise (the lists do not say).
  final DateTime? startedAt;

  /// Whether the answer or card carries a stream address (`hlsPullUrl` or
  /// `httpPullUrl` text, valid or not), read at every depth: a refresh tells
  /// an app-only room from one with streams without reading them.
  final bool hasAddress;

  /// Whether [variants] were read from this answer's addresses: a list card,
  /// or a live room answer at room entry.
  final bool mediaChecked;

  /// Whether the broadcast needs a ticket: the room answer's `feeInfo.fee`
  /// without a `sessionKey`. Null for a list card (the lists do not say).
  final bool? paid;

  /// The room's Yunxin chatroom (`roomInfo.roomId`); '' for a list card or an
  /// answer without one.
  final String chatroomId;

  /// Whether the room answer says the room hides its viewers' names
  /// (`anonymousMode`); false for a list card.
  final bool anonymousMode;

  /// The streams, HLS first: a list card's, or a live room's at room entry;
  /// empty otherwise. An address that fails the checks is left out.
  final List<LookliveVariant> variants;

  /// The chat of this room: a live room answer with a chatroom; null
  /// otherwise (a list card, a room that is not live).
  LookliveDanmakuArgs? get danmakuArgs => state == LookliveState.live && chatroomId.isNotEmpty
      ? LookliveDanmakuArgs(roomId: roomId, chatroomId: chatroomId, anonymousMode: anonymousMode)
      : null;

  /// Whether this room is watchable in LOOK's app only: stream type 50
  /// without streams and without any address in the answer, so a refresh
  /// tells it too.
  bool get isAppOnly => streamType == 50 && !hasAddress && variants.isEmpty;

  /// What keeps this client from playing a live room: app-only, a ticket
  /// ([paid]), or no usable address (unplayable); none otherwise. Not live:
  /// none, except null for an unknown state; a list card that can be played
  /// says null, as it does not tell tickets.
  LiveRestriction? get restriction => switch (state) {
    LookliveState.unknown => null,
    LookliveState.live when isAppOnly => LiveRestriction.appOnly,
    LookliveState.live when paid ?? false => LiveRestriction.paid,
    LookliveState.live when variants.isEmpty && (mediaChecked || !hasAddress) => LiveRestriction.unplayable,
    LookliveState.live when paid == null => null,
    _ => LiveRestriction.none,
  };

  /// This answer with what it lacks taken from [known], the last card or
  /// answer of the same room: the account, names and images while empty, the
  /// stream type while unknown; the audience of the same broadcast while
  /// this answer is live; and that broadcast's streams while this live
  /// answer has none (unless the stream type is 50). State, kind, start,
  /// addresses, ticket and chat stay this answer's.
  LookliveRoom enrich(LookliveRoom known) {
    final sameSession = sessionId.isNotEmpty && sessionId == known.sessionId;
    final live = state == LookliveState.live;
    final effectiveStreamType = streamType ?? known.streamType;
    final keepKnownVariants =
        variants.isEmpty && sameSession && live && known.state == LookliveState.live && effectiveStreamType != 50;
    return LookliveRoom(
      roomId: roomId,
      userId: userId.isEmpty ? known.userId : userId,
      sessionId: sessionId,
      title: title.isEmpty ? known.title : title,
      nick: nick.isEmpty ? known.nick : nick,
      avatar: avatar.isEmpty ? known.avatar : avatar,
      cover: cover.isEmpty ? known.cover : cover,
      kind: kind,
      streamType: effectiveStreamType,
      state: state,
      popularity: popularity ?? (sameSession && live ? known.popularity : null),
      currentViewers: currentViewers ?? (sameSession && live ? known.currentViewers : null),
      startedAt: startedAt,
      hasAddress: hasAddress,
      mediaChecked: mediaChecked,
      paid: paid,
      chatroomId: chatroomId,
      anonymousMode: anonymousMode,
      variants: keepKnownVariants ? known.variants : variants,
    );
  }

  /// Why this room cannot be played, or null, each reason its own:
  /// not live (offline, banned, unknown), app-only, a ticket, or no streams.
  LookliveFailure? get streamError => switch (state) {
    LookliveState.live when isAppOnly => LookliveFailure(
      LookliveFailureKind.streamUnavailable,
      '$roomId is watchable in the LOOK app only',
    ),
    LookliveState.live when paid ?? false => LookliveFailure(
      LookliveFailureKind.streamUnavailable,
      '$roomId needs a ticket (feeInfo.fee)',
    ),
    LookliveState.live when variants.isEmpty => LookliveFailure(
      LookliveFailureKind.streamUnavailable,
      '$roomId is live without streams',
    ),
    LookliveState.live => null,
    LookliveState.banned => LookliveFailure(LookliveFailureKind.streamUnavailable, '$roomId is banned by LOOK'),
    _ => LookliveFailure(LookliveFailureKind.streamUnavailable, '$roomId is ${state.name}'),
  };
}

/// Pure parsing of LOOK Live (NetEase) answers (3.x's `LookLiveApi`): the two
/// recommendation lists, the room answer, the chat servers, and the v2
/// rooms, qualities and lines.
///
/// Answers are checked strictly; a bad stream address costs only its stream,
/// and one unreadable entry of a list only that entry, but a page whose
/// entries are all unreadable is api-changed, as is a list that is not one.
abstract final class LookliveRoomParser {
  /// The platform's two areas (the one category's children), without a
  /// request.
  static List<LiveArea> areas() => [videoArea, audioArea];

  /// The video area.
  static final LiveArea videoArea = LiveArea.normalized(
    platform: lookliveSiteId,
    areaId: LookliveEndpoints.videoAreaId,
    areaName: LookliveEndpoints.videoAreaName,
    parentAreaId: 'looklive',
    parentAreaName: LookliveEndpoints.siteName,
  );

  /// The voice area.
  static final LiveArea audioArea = LiveArea.normalized(
    platform: lookliveSiteId,
    areaId: LookliveEndpoints.audioAreaId,
    areaName: LookliveEndpoints.audioAreaName,
    parentAreaId: 'looklive',
    parentAreaName: LookliveEndpoints.siteName,
  );

  /// The area of [kind].
  static LiveArea areaOf(LookliveKind kind) => kind == LookliveKind.audio ? audioArea : videoArea;

  /// The list [areaId] names: null for the merged recommendations; the video
  /// or voice list. Anything else is a caller error.
  static LookliveKind? kindOfArea(String? areaId) => switch (areaId) {
    null => null,
    LookliveEndpoints.videoAreaId => LookliveKind.video,
    LookliveEndpoints.audioAreaId => LookliveKind.audio,
    _ => throw LookliveFailure(LookliveFailureKind.invalidArgument, 'area "$areaId" is not a LOOK Live area'),
  };

  /// The list path of [kind].
  static String listPath(LookliveKind kind) =>
      kind == LookliveKind.audio ? LookliveEndpoints.audioListPath : LookliveEndpoints.videoListPath;

  // Lists ---------------------------------------------------------------------

  /// A recommendation page of [kind]: the `type` "1" entries with live data;
  /// a card of the other kind is skipped (the voice list injects video
  /// cards), as is an entry without `liveData`. Each room once, where it
  /// first appeared, with the last card's data.
  ///
  /// An entry that cannot be read is skipped, unless nothing on the page can
  /// be read: then the page is api-changed, as are more than
  /// [LookliveEndpoints.maxEntries] entries and a `hasMore` that is not a
  /// boolean. A bad stream address costs only that stream of the card.
  ///
  /// A list past its end answers `itemList: null` with `hasMore: false`;
  /// that is an empty last page.
  static ({List<LookliveRoom> rooms, bool hasMore}) directory(
    String body, {
    required LookliveKind kind,
    int status = 200,
  }) {
    final what = kind == LookliveKind.audio ? 'voice list' : 'video list';
    final data = LookliveJson.data(body, status: status, what: what);
    final rows = data['itemList'];
    final hasMore = data['hasMore'];
    if (rows == null && hasMore == false) return (rooms: const <LookliveRoom>[], hasMore: false);
    if (rows is! List || rows.length > LookliveEndpoints.maxEntries || hasMore is! bool) {
      throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        '$what: itemList ${rows is List ? 'of ${rows.length}' : 'is ${LookliveJson.describe(rows)}'}, '
        'hasMore ${LookliveJson.describe(hasMore)}',
      );
    }
    final rooms = <String, LookliveRoom>{};
    var unreadable = 0;
    for (final row in rows) {
      final LookliveRoom? room;
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
    return (rooms: rooms.values.toList(), hasMore: hasMore);
  }

  /// The card of a list entry, or null for another kind of entry or card;
  /// api-changed when it cannot be read.
  static LookliveRoom? _entry(Object? row, {required LookliveKind kind, required String what}) {
    final item = LookliveJson.object(row, '$what entry');
    if ('${item['type']}' != '1' || item['liveData'] == null) return null;
    final live = LookliveJson.object(item['liveData'], '$what liveData');
    return _kindOf(live['liveType'], what) == kind ? _card(live, kind: kind, what: what) : null;
  }

  /// A list card: room number `userInfo.liveRoomNo` (2 to 18 digits),
  /// account `userInfo.userId`, session `liveId` (all required ids), title
  /// `liveTitle`, name `userInfo.nickname`, avatar, cover, heat
  /// `popularity`, viewers `onlineNumber` (null when missing, else a
  /// non-negative integer), stream type `type` and the streams of `liveUrl`;
  /// live.
  static LookliveRoom _card(Map<String, dynamic> live, {required LookliveKind kind, required String what}) {
    final user = LookliveJson.object(live['userInfo'], '$what userInfo');
    final roomId = LookliveJson.id(user['liveRoomNo'], '$what liveRoomNo');
    if (!LookliveEndpoints.isRoomNumber(roomId)) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: room number $roomId is not 2 to 18 digits');
    }
    final urls = live['liveUrl'];
    return LookliveRoom(
      roomId: roomId,
      userId: LookliveJson.id(user['userId'], 'userId of $roomId'),
      sessionId: LookliveJson.id(live['liveId'], 'liveId of $roomId'),
      title: LookliveJson.text(live['liveTitle']),
      nick: LookliveJson.text(user['nickname']),
      avatar: LookliveJson.picture(user['avatarUrl']),
      cover: LookliveJson.picture(live['liveCoverUrl']),
      kind: kind,
      streamType: LookliveJson.integer(live['liveStreamType'] ?? live['type']),
      state: LookliveState.live,
      popularity: LookliveJson.count(live['popularity'], 'popularity of $roomId'),
      currentViewers: LookliveJson.count(live['onlineNumber'], 'onlineNumber of $roomId'),
      hasAddress: _hasAddress(urls),
      mediaChecked: true,
      variants: _variants(urls),
    );
  }

  // Room ----------------------------------------------------------------------

  /// `room/get/v3` for [roomId]: the anchor must answer for this number (else
  /// api-changed); state from `liveStatus` (1 live; 0, -1 and -2 offline; -10
  /// and -4 banned; anything else unknown); kind from `roomInfo.liveType` (1
  /// or 2, else api-changed); account, session (required ids), title, name,
  /// avatar, cover, stream type, whether it carries addresses, the ticket
  /// (`feeInfo`) and, when live, the start (`roomInfo.startTime`). The
  /// streams are read only with [withMedia] and when live; a bad address
  /// costs only its stream. No audience: the answer has none.
  static LookliveRoom room(String body, {required String roomId, bool withMedia = true, int status = 200}) {
    const what = 'room/get/v3';
    final data = LookliveJson.data(body, status: status, what: what, room: true);
    final anchor = LookliveJson.object(data['anchor'], '$what anchor');
    final answered = LookliveJson.id(anchor['liveRoomNo'], '$what anchor.liveRoomNo');
    if (answered != roomId) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: asked $roomId, got $answered');
    }
    final info = LookliveJson.object(data['roomInfo'], '$what roomInfo');
    final kind = _kindOf(info['liveType'], what);
    final state = switch (LookliveJson.integer(data['liveStatus'])) {
      1 => LookliveState.live,
      0 || -1 || -2 => LookliveState.offline,
      -10 || -4 => LookliveState.banned,
      _ => LookliveState.unknown,
    };
    final live = state == LookliveState.live;
    final urls = info['liveUrl'];
    return LookliveRoom(
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
      startedAt: live ? LookliveJson.time(info['startTime']) : null,
      hasAddress: _hasAddress(urls),
      mediaChecked: withMedia && live,
      paid: LookliveJson.paid(data['feeInfo']),
      chatroomId: LookliveJson.optionalId(info['roomId']),
      anonymousMode: data['anonymousMode'] == true,
      variants: withMedia && live ? _variants(urls) : const [],
    );
  }

  // Chat servers --------------------------------------------------------------

  static final RegExp _chatAddress = RegExp(
    r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+:([0-9]{1,5})$',
  );

  /// The chat servers of a `chat/address` answer: `data.address`, each a
  /// `host:port` of NetEase Yunxin's chatroom service, in the answer's
  /// order, lower-cased; entries that are not a host name and a port (1 to
  /// 65535) are left out. The envelope is the other answers': `code` 404
  /// ("无资源", for a room that is not live) is not-found. No `address`
  /// list, or none usable, is api-changed.
  static List<String> chatAddresses(String body, {int status = 200}) {
    const what = 'chat/address';
    final data = LookliveJson.data(body, status: status, what: what);
    final raw = data['address'];
    if (raw is! List) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: address is ${LookliveJson.describe(raw)}');
    }
    final addresses = <String>{
      for (final entry in raw)
        if (LookliveJson.text(entry).toLowerCase() case final address)
          if (_chatAddress.firstMatch(address) case final match?)
            if (int.parse(match.group(4)!) case final port when port >= 1 && port <= 65535) address,
    };
    if (addresses.isEmpty) {
      throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        '$what: no usable address in ${LookliveJson.snippet(LookliveJson.describe(raw))}',
      );
    }
    return addresses.toList();
  }

  // Streams -------------------------------------------------------------------

  static final RegExp _mediaHost = RegExp(r'^[a-z0-9-]+\.live\.126\.net$');
  static final RegExp _hlsPath = RegExp(r'^/live/[a-f0-9]{32}/playlist\.m3u8$');
  static final RegExp _flvPath = RegExp(r'^/live/[a-f0-9]{32}\.flv$');

  /// The streams of `liveUrl`: the HLS playlist, then the FLV stream, each
  /// when present and accepted by [mediaUri]. A bad address, or a `liveUrl`
  /// that is not an object, costs only its streams.
  static List<LookliveVariant> _variants(Object? value) {
    if (value is! Map<String, dynamic>) return const [];
    return [
      for (final (id, key, format) in const [
        (LookliveEndpoints.hlsId, 'hlsPullUrl', LiveStreamFormat.hls),
        (LookliveEndpoints.flvId, 'httpPullUrl', LiveStreamFormat.flv),
      ])
        if (LookliveJson.text(value[key]) case final raw when raw.isNotEmpty)
          if (_mediaUriOrNull(raw, format) case final uri?) LookliveVariant(id: id, format: format, uri: uri),
    ];
  }

  static Uri? _mediaUriOrNull(String raw, LiveStreamFormat format) {
    try {
      return mediaUri(raw, format: format);
    } on LookliveFailure {
      return null;
    }
  }

  /// Whether `liveUrl` carries an HLS or FLV address, valid or not.
  static bool _hasAddress(Object? value) =>
      value is Map &&
      (LookliveJson.text(value['hlsPullUrl']).isNotEmpty || LookliveJson.text(value['httpPullUrl']).isNotEmpty);

  /// A stream address as 3.x accepted it, made https: http(s) on a
  /// `*.live.126.net` host (one label of letters, digits and hyphens), no
  /// user info, port or fragment, a query of at most 2048 characters, and
  /// the path `/live/<32 lower-case hex>/playlist.m3u8` (HLS) or
  /// `/live/<32 lower-case hex>.flv` (FLV). Anything else is api-changed.
  static Uri mediaUri(String raw, {required LiveStreamFormat format}) {
    final source = Uri.tryParse(raw.trim());
    final path = switch (format) {
      LiveStreamFormat.hls => _hlsPath,
      LiveStreamFormat.flv => _flvPath,
      _ => null,
    };
    if (source == null ||
        (!source.isScheme('http') && !source.isScheme('https')) ||
        source.userInfo.isNotEmpty ||
        source.hasPort ||
        source.fragment.isNotEmpty ||
        !_mediaHost.hasMatch(source.host.toLowerCase()) ||
        source.query.length > 2048 ||
        path == null ||
        !path.hasMatch(source.path)) {
      throw LookliveFailure(
        LookliveFailureKind.apiChanged,
        'not a LOOK ${format.name.toUpperCase()} address: ${LookliveJson.snippet(raw)}',
      );
    }
    return source.replace(scheme: 'https');
  }

  /// The qualities of a playable [room]: one per stream, HLS first.
  static List<LivePlayQuality> qualities(LookliveRoom room) => [
    for (final variant in room.variants)
      LivePlayQuality.of(
        label: variant.format == LiveStreamFormat.hls
            ? LookliveEndpoints.hlsQualityLabel
            : LookliveEndpoints.flvQualityLabel,
        qualityId: variant.id,
      ),
  ];

  /// The line of quality [qualityId] of a playable [room]: its stream, the
  /// host as line label, and the media headers. No lease: the addresses
  /// carry no signature or expiry. No codec: the answer does not say it.
  /// A quality the room lacks is stream-unavailable; one that is not LOOK's
  /// is a caller error.
  static LivePlayLine line(LookliveRoom room, String qualityId) {
    if (qualityId != LookliveEndpoints.hlsId && qualityId != LookliveEndpoints.flvId) {
      throw LookliveFailure(LookliveFailureKind.invalidArgument, 'quality "$qualityId" is not a LOOK Live quality');
    }
    for (final variant in room.variants) {
      if (variant.id == qualityId) {
        return LivePlayLine.of(
          url: '${variant.uri}',
          format: variant.format,
          formatSource: LivePlayFormatSource.declared,
          headers: LookliveEndpoints.mediaHeaders(room.roomId),
          lineLabel: variant.uri.host,
        );
      }
    }
    throw LookliveFailure(LookliveFailureKind.streamUnavailable, '${room.roomId} has no $qualityId');
  }

  // Rooms ---------------------------------------------------------------------

  /// The v2 room of [room]: the number, account, title and name; the avatar,
  /// else the cover; the area by kind; current viewers as the audience when
  /// known, else the heat (both kept apart); the state; the start and the
  /// restriction ([LookliveRoom.restriction]); the notice lines (banned,
  /// app-only, ticket, chat); the media headers as the links' address.
  /// [withData] (room entry) keeps [room] as the room's stream handle, and
  /// its chat as the danmaku handle ([LookliveRoom.danmakuArgs]). A number
  /// that is not 2 to 18 digits is api-changed.
  static LiveRoom liveRoom(LookliveRoom room, {bool withData = false}) {
    if (!LookliveEndpoints.isRoomNumber(room.roomId)) {
      throw LookliveFailure(LookliveFailureKind.apiChanged, 'room number ${room.roomId} is not 2 to 18 digits');
    }
    final restriction = room.restriction;
    final liveStatus = switch (room.state) {
      LookliveState.live => LiveStatus.live,
      LookliveState.offline => LiveStatus.offline,
      LookliveState.banned => LiveStatus.banned,
      LookliveState.unknown => LiveStatus.unknown,
    };
    return LiveRoom.normalized(
      platform: lookliveSiteId,
      roomId: room.roomId,
      content: RoomContent.of(title: room.title, coverUrl: room.cover, notice: _notice(room, restriction)),
      anchor: LiveAnchor.normalized(
        platform: lookliveSiteId,
        anchorId: room.userId,
        name: room.nick,
        avatarUrl: room.avatar.isEmpty ? room.cover : room.avatar,
        liveStatus: liveStatus,
      ),
      area: areaOf(room.kind),
      audience: RoomAudience.of(
        onlineViewers: room.currentViewers,
        popularity: room.popularity,
        primaryMetric: room.currentViewers != null
            ? LiveAudienceMetricType.onlineViewers
            : room.popularity != null
            ? LiveAudienceMetricType.popularity
            : LiveAudienceMetricType.unknown,
      ),
      broadcast: RoomBroadcast.of(liveStatus: liveStatus, startedAt: room.startedAt, restriction: restriction),
      links: RoomLinks.of(webUrl: LookliveEndpoints.link(room.roomId)),
      runtime: withData ? RoomRuntime.of(streamHandle: room, danmakuHandle: room.danmakuArgs) : RoomRuntime(),
    );
  }

  /// The notice lines of [room]: banned, app-only, ticket, and the chat's
  /// standing note about the numbers.
  static String _notice(LookliveRoom room, LiveRestriction? restriction) => [
    if (room.state == LookliveState.banned) LookliveEndpoints.bannedNotice,
    if (restriction == LiveRestriction.appOnly) LookliveEndpoints.appOnlyNotice,
    if (restriction == LiveRestriction.paid) LookliveEndpoints.paidNotice,
    LookliveEndpoints.chatNotice,
  ].join('\n');

  static LookliveKind _kindOf(Object? liveType, String what) => switch (LookliveJson.integer(liveType)) {
    1 => LookliveKind.video,
    2 => LookliveKind.audio,
    _ => throw LookliveFailure(LookliveFailureKind.apiChanged, '$what: liveType ${LookliveJson.describe(liveType)}'),
  };
}
