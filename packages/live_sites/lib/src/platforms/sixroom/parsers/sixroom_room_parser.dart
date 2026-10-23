import 'dart:convert';

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
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_endpoints.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_html.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_json.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A room's state.
enum SixroomState {
  /// A list card; an inroom answer with a live id and a stream name, or a
  /// private or black-screen room with a live id; a search card with the
  /// page's live mark.
  live,

  /// An inroom answer without them; a search card without the live mark
  /// that links the broadcaster's profile.
  offline,

  /// A search card that says neither.
  unknown,
}

/// The one FLV stream of a live room: the platform's `wlive.6rooms.com` FLV
/// address, and what the answer's `streamInfo` says about it.
final class SixroomStream {
  /// Creates the stream.
  const SixroomStream({required this.url, this.resolution = '', this.bitrate, this.codec});

  /// The FLV URL; not signed, no expiry.
  final Uri url;

  /// `streamInfo.resolution` (`1024x768`), or ''.
  final String resolution;

  /// `streamInfo.videoBitrate` (else `bitrate`) in kbps, when given.
  final int? bitrate;

  /// The video codec of `streamInfo.videoCodec` (`avc`, `hevc`), when known.
  final LiveStreamCodec? codec;
}

/// One room: a list card (homepage, mobile list, web subarea), a search
/// card, or a room read from the inroom answer.
final class SixroomRoom {
  /// Creates the room.
  const SixroomRoom({
    required this.roomId,
    required this.userId,
    required this.state,
    this.nick = '',
    this.title = '',
    this.liveId = '',
    this.avatar = '',
    this.cover = '',
    this.category = '',
    this.popularity,
    this.followers,
    this.startedAt,
    this.restriction,
    this.restrictionNote = '',
    this.stream,
    this.mediaError,
  });

  /// The room number (`rid`): the room's identity.
  final String roomId;

  /// The broadcaster's user id (`uid`, inroom `ruid`).
  final String userId;

  /// The broadcast id (`liveid`); '' when not live or not given.
  final String liveId;

  /// The broadcaster's name; '' when the answer has none (a follow keeps
  /// what it stored).
  final String nick;

  /// The title, else the broadcaster's signature, else the name; ''.
  final String title;

  /// The broadcaster's avatar (a card's `picuser`, the search card's image,
  /// inroom `headPicUrl`, `picuser` or `uoption.picuser`); '' when not
  /// given, never the cover. Mobile list cards have none.
  final String avatar;

  /// The poster; ''.
  final String cover;

  /// The area (`anchor_area`, else `rtypename`); ''.
  final String category;

  /// A card's `count`, platform popularity; null when not given.
  final int? popularity;

  /// Inroom `fans_num`; null when not given.
  final int? followers;

  /// When the broadcast began (a card's `realstarttime`, inroom
  /// `liveinfo.starttime`), UTC; null when not given or not live.
  final DateTime? startedAt;

  /// The restriction the inroom answer states: `private` (`isPriveRoom`),
  /// `unplayable` (a black screen, `blackScreenInfo.msg`) or `none`; null
  /// for cards and answers that say nothing about it.
  final LiveRestriction? restriction;

  /// The black screen's message; ''.
  final String restrictionNote;

  /// The state.
  final SixroomState state;

  /// The live room's stream, read on room entry; null otherwise, and for
  /// restricted rooms.
  final SixroomStream? stream;

  /// Why a live room read with its media has no [stream]: a stream name
  /// that does not match the broadcaster and broadcast.
  final SixroomFailure? mediaError;

  /// Whether this room and [known] can be the same broadcast: either state
  /// is unknown, or both are offline, or both are live with no differing
  /// broadcast ids.
  bool _sameBroadcast(SixroomRoom known) => switch ((state, known.state)) {
    (SixroomState.unknown, _) || (_, SixroomState.unknown) => true,
    (SixroomState.live, SixroomState.live) => liveId.isEmpty || known.liveId.isEmpty || liveId == known.liveId,
    (final current, final earlier) => current == earlier,
  };

  /// This room with the fields its answer lacks taken from [known], an
  /// earlier card or room of the same room: the user id, name, title,
  /// avatar, cover and area when empty, the followers when not given, the
  /// state when unknown. What belongs to one broadcast (the broadcast id,
  /// popularity, start time and restriction) is taken only from the same
  /// live broadcast. The media stay this room's.
  SixroomRoom enrich(SixroomRoom known) {
    final same = _sameBroadcast(known);
    final live = state != SixroomState.offline && known.state == SixroomState.live && same;
    return SixroomRoom(
      roomId: roomId,
      userId: userId.isEmpty ? known.userId : userId,
      liveId: liveId.isEmpty && live ? known.liveId : liveId,
      nick: nick.isEmpty ? known.nick : nick,
      title: title.isEmpty ? known.title : title,
      avatar: avatar.isEmpty ? known.avatar : avatar,
      cover: cover.isEmpty ? known.cover : cover,
      category: category.isEmpty ? known.category : category,
      popularity: popularity ?? (live ? known.popularity : null),
      followers: followers ?? known.followers,
      startedAt: startedAt ?? (live ? known.startedAt : null),
      restriction: restriction ?? (same ? known.restriction : null),
      restrictionNote: restriction == null && same ? known.restrictionNote : restrictionNote,
      state: state == SixroomState.unknown ? known.state : state,
      stream: stream,
      mediaError: mediaError,
    );
  }
}

/// What a room detail carries besides the model's fields: the broadcaster,
/// the state, the restriction and, on room entry, the stream.
final class SixroomRoomData {
  /// Creates the data.
  const SixroomRoomData({
    required this.roomId,
    required this.userId,
    required this.state,
    this.liveId = '',
    this.restriction,
    this.restrictionNote = '',
    this.stream,
    this.mediaError,
  });

  /// The room number.
  final String roomId;

  /// The broadcaster's user id (inroom `ruid`).
  final String userId;

  /// The broadcast id; '' when not live.
  final String liveId;

  /// The state.
  final SixroomState state;

  /// The restriction the answer states (see [SixroomRoom.restriction]).
  final LiveRestriction? restriction;

  /// The black screen's message; ''.
  final String restrictionNote;

  /// The FLV stream, read on room entry; null for restricted rooms.
  final SixroomStream? stream;

  /// Why the live room has no stream, when its stream name is unusable.
  final SixroomFailure? mediaError;

  /// Why this room cannot be played, or null: offline or unknown is
  /// stream-unavailable; so is a live private or black-screen room, with
  /// the reason; a live one with an unusable stream name says so; a live
  /// one read without its stream is stream-unavailable until the room is
  /// entered.
  SixroomFailure? get streamError => switch (state) {
    SixroomState.offline => SixroomFailure(SixroomFailureKind.streamUnavailable, '$roomId is offline'),
    SixroomState.unknown => SixroomFailure(SixroomFailureKind.streamUnavailable, '$roomId: state unknown'),
    SixroomState.live when restriction == LiveRestriction.private => SixroomFailure(
      SixroomFailureKind.streamUnavailable,
      '$roomId is a private room',
    ),
    SixroomState.live when restriction == LiveRestriction.unplayable => SixroomFailure(
      SixroomFailureKind.streamUnavailable,
      '$roomId has a black screen${restrictionNote.isEmpty ? '' : ': $restrictionNote'}',
    ),
    SixroomState.live when mediaError != null => mediaError,
    SixroomState.live when stream == null => SixroomFailure(
      SixroomFailureKind.streamUnavailable,
      '$roomId: read without its stream; enter the room',
    ),
    SixroomState.live => null,
  };
}

/// One page of a mobile list: its cards, and whether the list goes on.
typedef SixroomListPage = ({List<SixroomRoom> rooms, bool hasMore});

/// The chat arguments of a room: the room number and the broadcaster's user
/// id, which picks the chat servers and is the login's `roomid`. Room entry
/// hands them over, without a request.
final class SixroomDanmakuArgs {
  /// Creates the arguments.
  const SixroomDanmakuArgs({required this.roomId, required this.userId});

  /// The room number.
  final String roomId;

  /// The broadcaster's user id.
  final String userId;

  @override
  String toString() => '$roomId/$userId';
}

/// Pure parsing of 6.cn answers. Each function takes the answer and its
/// status and returns the models or throws a [SixroomFailure]. A list row
/// that cannot be read only drops itself; a page whose identity does not
/// match, or whose rows are all broken, is api-changed.
abstract final class SixroomRoomParser {
  /// The platform's areas: the six fixed ones, without a request.
  static List<LiveArea> areas() => [
    for (final area in SixroomEndpoints.areas)
      LiveArea.normalized(
        platform: sixroomSiteId,
        areaId: area.id,
        areaName: area.name,
        parentAreaId: 'sixroom',
        parentAreaName: SixroomEndpoints.siteName,
      ),
  ];

  /// The area id of [area], or null when it is not one of the six (another
  /// platform, an unknown id). The id is trimmed.
  static String? areaIdOf(LiveArea? area) {
    if (area == null || area.platform != 'sixroom') return null;
    final id = area.areaId.trim();
    return SixroomEndpoints.areaOf(id) == null ? null : id;
  }

  // Directory -----------------------------------------------------------------

  /// The live card of a list row (homepage, mobile list, web subarea), or
  /// null when it has no room number or user id: name (`username`, the
  /// subarea's featured rows `alias`), title (else the signature
  /// `userMood`, else the name), avatar (`picuser`, which the mobile list
  /// lacks), cover (`pospic`, `pic`, `pospic_sp`), area, `count` as
  /// popularity and `realstarttime` as the start.
  static SixroomRoom? _card(Map<String, dynamic> row) {
    final roomId = SixroomJson.string(row['rid']);
    final userId = SixroomJson.string(row['uid']);
    if (SixroomEndpoints.roomIdOf(roomId) != roomId || !SixroomEndpoints.isUserId(userId)) return null;
    final nick = SixroomJson.firstText([row['username'], row['alias']]);
    return SixroomRoom(
      roomId: roomId,
      userId: userId,
      liveId: SixroomJson.string(row['liveid'] ?? row['lid']),
      nick: nick,
      title: SixroomJson.firstText([row['livetitle'], row['userMood'], nick]),
      avatar: SixroomJson.image(row['picuser']),
      cover: SixroomJson.firstImage([row['pospic'], row['pic'], row['pospic_sp']]),
      category: SixroomJson.text(row['anchor_area']),
      popularity: SixroomJson.count(row['count']),
      startedAt: SixroomJson.time(row['realstarttime']),
      state: SixroomState.live,
    );
  }

  /// The cards of [rows], in order, once per room; rows without a room
  /// number or user id are skipped.
  static List<SixroomRoom> _cards(Iterable<Object?> rows) {
    final seen = <String>{};
    final rooms = <SixroomRoom>[];
    for (final value in rows) {
      final row = SixroomJson.map(value);
      final room = row == null ? null : _card(row);
      if (room != null && seen.add(room.roomId)) rooms.add(room);
    }
    return rooms;
  }

  /// The homepage's rooms: the embedded `typeList` (JSON, or JSON text), in
  /// its order, once per room; a row needs a room number and a user id (see
  /// [_card]); all live. No room at all is api-changed.
  static List<SixroomRoom> directory(String body, {int status = 200}) {
    const what = 'homepage';
    SixroomJson.checkBody(body, what, status);
    final root = _embeddedRoot(body);
    var rows = root['typeList'];
    if (rows is String) {
      try {
        rows = jsonDecode(rows);
      } on FormatException {
        throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: typeList is not JSON');
      }
    }
    if (rows is! List) throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: no typeList');
    final rooms = _cards(rows);
    if (rooms.isEmpty) throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: typeList has no room');
    return List.unmodifiable(rooms);
  }

  /// The `content` of a 6.cn JSON answer whose `flag` is `001`; another
  /// flag is risk control (with the message), none api-changed.
  static Object? _content(String body, {required int status, required String what}) {
    SixroomJson.checkBody(body, what, status);
    final root = SixroomJson.json(body, what, status);
    final flag = root['flag'];
    if (flag is! String) throw SixroomFailure(SixroomFailureKind.apiChanged, '$what: flag is $flag');
    if (flag != '001') {
      throw SixroomFailure(SixroomFailureKind.riskControl, '$what: flag $flag ${SixroomJson.text(root['content'])}');
    }
    return root['content'];
  }

  /// Page [page] of [size] rooms of the mobile list [type]: the rows of
  /// `content[type]` as live cards (see [_card]; a bad row is skipped), and
  /// whether the list goes on: the page had rows and `roomListCount[type]`
  /// is past it (a full page when it is not given). A type without rooms
  /// answers `content: []`. A list whose rows are all unreadable, or no
  /// list for the type, is api-changed.
  static SixroomListPage list(
    String body, {
    required String type,
    required int page,
    required int size,
    int status = 200,
  }) {
    final what = 'mobile list $type';
    final content = _content(body, status: status, what: what);
    if (content is List && content.isEmpty) return (rooms: const [], hasMore: false);
    final map = SixroomJson.map(content);
    final rows = map?[type];
    if (map == null || rows is! List) {
      throw SixroomFailure(SixroomFailureKind.apiChanged, '$what: no $type list');
    }
    final rooms = _cards(rows);
    if (rooms.isEmpty && rows.isNotEmpty) {
      throw SixroomFailure(SixroomFailureKind.apiChanged, '$what: no readable room');
    }
    final total = SixroomJson.count(SixroomJson.map(map['roomListCount'])?[type]);
    final hasMore = rows.isNotEmpty && (total == null ? rows.length >= size : page * size < total);
    return (rooms: List.unmodifiable(rooms), hasMore: hasMore);
  }

  /// The web's subarea list (星颜 is subarea 10): the featured rows of
  /// `bigLiveList.list`, then `liveList` (an object by user id), as live
  /// cards once per room (see [_card]; a bad row is skipped). Neither list
  /// is api-changed; rows but no readable room too.
  static List<SixroomRoom> subarea(String body, {int status = 200}) {
    const what = 'subarea list';
    final content = SixroomJson.map(_content(body, status: status, what: what));
    final featured = SixroomJson.map(content?['bigLiveList'])?['list'];
    final others = content?['liveList'];
    final rows = [
      if (featured is List) ...featured,
      if (others is Map) ...others.values else if (others is List) ...others,
    ];
    if (featured is! List && others is! Map && others is! List) {
      throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: no bigLiveList or liveList');
    }
    final rooms = _cards(rows);
    if (rooms.isEmpty && rows.isNotEmpty) {
      throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: no readable room');
    }
    return List.unmodifiable(rooms);
  }

  /// The object after `window.__SMARTY_ALL_VARIABLES__ = ` (braces counted
  /// outside double-quoted strings).
  static Map<String, dynamic> _embeddedRoot(String body) {
    const marker = 'window.__SMARTY_ALL_VARIABLES__ = ';
    final at = body.indexOf(marker);
    final start = at < 0 ? -1 : body.indexOf('{', at + marker.length);
    if (start < 0) {
      throw const SixroomFailure(SixroomFailureKind.apiChanged, 'homepage: no __SMARTY_ALL_VARIABLES__');
    }
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var index = start; index < body.length; index++) {
      final code = body.codeUnitAt(index);
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == 0x22) {
          quoted = false;
        }
        continue;
      }
      if (code == 0x22) {
        quoted = true;
      } else if (code == 0x7b) {
        depth++;
      } else if (code == 0x7d && --depth == 0) {
        final Object? decoded;
        try {
          decoded = jsonDecode(body.substring(start, index + 1));
        } on FormatException {
          throw const SixroomFailure(SixroomFailureKind.apiChanged, 'homepage: variables are not JSON');
        }
        return SixroomJson.object(decoded, 'homepage variables');
      }
    }
    throw const SixroomFailure(SixroomFailureKind.apiChanged, 'homepage: __SMARTY_ALL_VARIABLES__ does not end');
  }

  // Search --------------------------------------------------------------------

  /// The search page: one card per `ul.search-user > li[data-uid]`, once
  /// per room: the user id, the room of the `a.user-box` link, the name
  /// (`.alias`) as name and title, the image of `.pic img` (`data-src`,
  /// else `src`) as avatar. The state: live with the page's live mark
  /// (`i.live`), offline without it when the link is the broadcaster's
  /// profile (`/profile/<room>`, which the page gives rooms that are not
  /// live), else unknown. 6.cn's "输入内容过长" page (a keyword over 15
  /// characters) is no result; any other prompt page is risk control,
  /// anything else api-changed.
  static List<SixroomRoom> search(String body, {int status = 200}) {
    const what = 'search page';
    SixroomJson.checkBody(body, what, status);
    final root = SixroomHtml.parse(body);
    final page = root.firstWithClass('page-search-user');
    if (page == null) {
      final remind = root.firstWithClass('remind');
      if (remind == null) throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: no page-search-user');
      final message = remind.firstWithClass('rcontent')?.text ?? '';
      if (message.contains('过长')) return const [];
      throw SixroomFailure(SixroomFailureKind.riskControl, '$what: ${SixroomJson.text(message)}');
    }
    final seen = <String>{};
    final rooms = <SixroomRoom>[];
    final items = root.descendants
        .where(
          (element) =>
              element.name == 'li' &&
              element.attributes.containsKey('data-uid') &&
              element.parent?.name == 'ul' &&
              (element.parent?.hasClass('search-user') ?? false),
        )
        .toList(growable: false);
    for (final item in items) {
      final userId = item.attributes['data-uid']!.trim();
      final href = item.descendants
          .where((element) => element.name == 'a' && element.hasClass('user-box'))
          .firstOrNull
          ?.attributes['href'];
      final Uri link;
      final String? roomId;
      try {
        link = Uri.parse(SixroomEndpoints.origin).resolve(href ?? '');
        roomId = SixroomEndpoints.roomIdOf('$link');
      } on FormatException {
        continue;
      }
      if (roomId == null || !SixroomEndpoints.isUserId(userId) || !seen.add(roomId)) continue;
      final image = _picImage(item);
      final nick = SixroomJson.text(item.firstWithClass('alias')?.text);
      final live = item.descendants.any((element) => element.name == 'i' && element.hasClass('live'));
      // roomIdOf accepted the path, so its segments decode.
      final profile = link.pathSegments.first.toLowerCase() == 'profile';
      rooms.add(
        SixroomRoom(
          roomId: roomId,
          userId: userId,
          nick: nick,
          title: nick,
          avatar: SixroomJson.firstImage([image?.attributes['data-src'], image?.attributes['src']]),
          state: live
              ? SixroomState.live
              : profile
              ? SixroomState.offline
              : SixroomState.unknown,
        ),
      );
    }
    return List.unmodifiable(rooms);
  }

  /// The first `img` of [item] that sits under an element carrying class
  /// `pic` (the card's picture block), or null.
  static SixroomHtml? _picImage(SixroomHtml item) {
    for (final element in item.descendants) {
      if (element.name != 'img') continue;
      var ancestor = element.parent;
      while (ancestor != null && !identical(ancestor, item)) {
        if (ancestor.hasClass('pic')) return element;
        ancestor = ancestor.parent;
      }
    }
    return null;
  }

  // Room ----------------------------------------------------------------------

  /// `rid: '<user id>', roomid: <room number>` in the room page's script.
  /// The room number is quoted on some pages and a bare number on others
  /// (both are accepted).
  static final RegExp _pageIds = RegExp(
    r'''\brid\s*:\s*['"]([1-9]\d{1,12})['"]\s*,\s*roomid\s*:\s*['"]?([1-9]\d{1,11})(?!\d)['"]?''',
  );

  /// The broadcaster's user id on the room page of [roomId] (a room number
  /// or link): the canonical link must be the room; a page without it is
  /// not-found when it is a prompt page or short, else api-changed. The id
  /// is the `rid` next to the room's `roomid`. A [roomId] that is no room
  /// is a caller error.
  static String userIdOf(String body, {required String roomId, int status = 200}) {
    const what = 'room page';
    final id = _requireRoomId(roomId);
    SixroomJson.checkBody(body, what, status);
    final root = SixroomHtml.parse(body);
    final canonical = root.descendants
        .where((element) => element.name == 'link' && element.attributes['rel'] == 'canonical')
        .firstOrNull;
    if (SixroomEndpoints.roomIdOf(canonical?.attributes['href'] ?? '') != id) {
      if (root.firstWithClass('remind') != null || body.length < 4096) {
        throw SixroomFailure(SixroomFailureKind.notFound, '$what of $id: no such room');
      }
      throw SixroomFailure(SixroomFailureKind.apiChanged, '$what of $id: canonical ${canonical?.attributes['href']}');
    }
    for (final match in _pageIds.allMatches(body)) {
      if (match.group(2) == id) return match.group(1)!;
    }
    throw SixroomFailure(SixroomFailureKind.apiChanged, '$what of $id: no rid/roomid');
  }

  /// The inroom answer of room [roomId] and broadcaster [userId]: `flag`
  /// `001`, else 402 is not-found (6.cn's "暂不能进入此房间"), another flag
  /// risk control, none api-changed. The room and broadcaster must be the
  /// ones asked.
  ///
  /// A live id and a stream name are live, else offline. A private room
  /// (`isPriveRoom`) is restriction `private`, a black screen
  /// (`blackScreenInfo.msg`) `unplayable`, otherwise `none` (null when the
  /// answer has neither field); such a room is live with a live id alone. The
  /// title is the broadcast's title, else the broadcaster's signature
  /// (`roominfo.userMood`, then `roomParamInfo.operation.userMood`), else
  /// the name; the avatar `headPicUrl`, `picuser`, else `uoption.picuser`;
  /// a live room's start is `liveinfo.starttime`. With [media], an
  /// unrestricted live room's stream (`v<user id>-<live id>[-many]`, else
  /// [SixroomRoom.mediaError]). A [roomId] (number or link) or [userId]
  /// that is no id is a caller error.
  static SixroomRoom room(
    String body, {
    required String roomId,
    required String userId,
    bool media = true,
    int status = 200,
  }) {
    const what = 'inroom';
    final id = _requireRoomId(roomId);
    if (!SixroomEndpoints.isUserId(userId)) {
      throw ArgumentError.value(userId, 'userId', 'not a Six Rooms user id');
    }
    final uid = userId.trim();
    SixroomJson.checkBody(body, what, status);
    final root = SixroomJson.json(body, what, status);
    final flag = root['flag'];
    if (flag is! String) throw SixroomFailure(SixroomFailureKind.apiChanged, '$what: flag is $flag');
    if (flag != '001') {
      final message = SixroomJson.text(root['content']);
      if (flag == '402') {
        throw SixroomFailure(SixroomFailureKind.notFound, '$what of $uid: $message');
      }
      throw SixroomFailure(SixroomFailureKind.riskControl, '$what of $uid: flag $flag $message');
    }
    final content = SixroomJson.map(root['content']);
    final roomInfo = SixroomJson.map(content?['roominfo']);
    final liveInfo = SixroomJson.map(content?['liveinfo']);
    final params = SixroomJson.map(content?['roomParamInfo']);
    if (content == null || roomInfo == null || liveInfo == null || params == null) {
      throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: no roominfo, liveinfo or roomParamInfo');
    }
    final actualRoomId = SixroomJson.string(roomInfo['rid']);
    final actualUserId = SixroomJson.string(roomInfo['id'] ?? params['uid']);
    if (actualRoomId != id || actualUserId != uid) {
      throw SixroomFailure(SixroomFailureKind.apiChanged, '$what of $id/$uid names $actualRoomId/$actualUserId');
    }
    final liveId = SixroomJson.string(liveInfo['id']);
    final flvTitle = SixroomJson.string(liveInfo['flvtitle']);
    final blackScreen = SixroomJson.text(SixroomJson.map(content['blackScreenInfo'])?['msg']);
    final restriction = SixroomJson.truthy(content['isPriveRoom'])
        ? LiveRestriction.private
        : blackScreen.isNotEmpty
        ? LiveRestriction.unplayable
        : content.containsKey('isPriveRoom') || content.containsKey('blackScreenInfo')
        ? LiveRestriction.none
        : null;
    final restricted = restriction != null && restriction != LiveRestriction.none;
    final state = liveId.isNotEmpty && (flvTitle.isNotEmpty || restricted) ? SixroomState.live : SixroomState.offline;
    final nick = SixroomJson.text(roomInfo['alias']);
    SixroomStream? stream;
    SixroomFailure? mediaError;
    if (media && state == SixroomState.live && !restricted) {
      final url = SixroomEndpoints.mediaUri(userId: actualUserId, liveId: liveId, flvTitle: flvTitle);
      if (url == null) {
        mediaError = SixroomFailure(SixroomFailureKind.apiChanged, '$what of $id: stream name $flvTitle for $liveId');
      } else {
        final info = _streamInfo(liveInfo, flvTitle);
        stream = SixroomStream(
          url: url,
          resolution: SixroomJson.text(info?['resolution']),
          bitrate: SixroomJson.count(info?['videoBitrate'] ?? info?['bitrate']),
          codec: switch (SixroomJson.string(info?['videoCodec']).toLowerCase()) {
            'avc' || 'h264' => LiveStreamCodec.avc,
            'hevc' || 'h265' => LiveStreamCodec.hevc,
            _ => null,
          },
        );
      }
    }
    return SixroomRoom(
      roomId: id,
      userId: actualUserId,
      liveId: liveId,
      nick: nick,
      title: SixroomJson.firstText([
        liveInfo['title'],
        roomInfo['userMood'],
        SixroomJson.map(params['operation'])?['userMood'],
        nick,
      ]),
      avatar: SixroomJson.firstImage([
        roomInfo['headPicUrl'],
        roomInfo['picuser'],
        SixroomJson.map(roomInfo['uoption'])?['picuser'],
      ]),
      cover: SixroomJson.firstImage([liveInfo['spredPic'], liveInfo['pospic'], liveInfo['largepic'], liveInfo['pic']]),
      category: SixroomJson.firstText([roomInfo['anchor_area'], roomInfo['rtypename']]),
      followers: SixroomJson.count(params['fans_num']),
      startedAt: state == SixroomState.live ? SixroomJson.time(liveInfo['starttime']) : null,
      restriction: restriction,
      restrictionNote: restriction == LiveRestriction.unplayable ? blackScreen : '',
      state: state,
      stream: stream,
      mediaError: mediaError,
    );
  }

  /// `streamInfo[flvTitle]` of any lane of `liveinfo.content`.
  static Map<String, dynamic>? _streamInfo(Map<String, dynamic> liveInfo, String flvTitle) {
    final lanes = SixroomJson.map(liveInfo['content']);
    if (lanes == null) return null;
    for (final lane in lanes.values) {
      final info = SixroomJson.map(SixroomJson.map(SixroomJson.map(lane)?['streamInfo'])?[flvTitle]);
      if (info != null) return info;
    }
    return null;
  }

  // Rooms, qualities and lines ------------------------------------------------

  /// The card or room of [room]: the avatar (never the cover), the area,
  /// the name and title as given ('' when the answer has none: a follow
  /// keeps what it stored); the popularity as the audience; followers; the
  /// state; the start and restriction (the start only while live); the
  /// notices; [data] and [danmaku] as given.
  static LiveRoom liveRoom(SixroomRoom room, {SixroomRoomData? data, SixroomDanmakuArgs? danmaku}) {
    final liveStatus = switch (room.state) {
      SixroomState.live => LiveStatus.live,
      SixroomState.offline => LiveStatus.offline,
      SixroomState.unknown => LiveStatus.unknown,
    };
    final restricted = room.restriction != null && room.restriction != LiveRestriction.none;
    return LiveRoom.normalized(
      platform: sixroomSiteId,
      roomId: room.roomId,
      content: RoomContent.of(
        title: room.title,
        coverUrl: room.cover,
        notice: restricted
            ? '${SixroomEndpoints.restrictedNotice}\n${SixroomEndpoints.chatNotice}'
            : SixroomEndpoints.chatNotice,
      ),
      anchor: LiveAnchor.normalized(
        platform: sixroomSiteId,
        anchorId: room.userId,
        name: room.nick,
        avatarUrl: room.avatar.isEmpty ? null : room.avatar,
        followerCount: room.followers,
        liveStatus: liveStatus,
      ),
      audience: RoomAudience.of(
        popularity: room.popularity,
        primaryMetric: room.popularity == null ? LiveAudienceMetricType.unknown : LiveAudienceMetricType.popularity,
      ),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: room.state == SixroomState.live ? room.startedAt : null,
        restriction: room.restriction,
      ),
      links: RoomLinks.of(webUrl: SixroomEndpoints.link(room.roomId)),
      runtime: RoomRuntime.of(streamHandle: data, danmakuHandle: danmaku),
    );
  }

  /// The room data of [room].
  static SixroomRoomData roomData(SixroomRoom room) => SixroomRoomData(
    roomId: room.roomId,
    userId: room.userId,
    liveId: room.liveId,
    state: room.state,
    restriction: room.restriction,
    restrictionNote: room.restrictionNote,
    stream: room.stream,
    mediaError: room.mediaError,
  );

  /// The one quality of [stream]: `FLV 原始线路`, with the resolution and
  /// bitrate when known; ordered by bitrate (1 without).
  static LivePlayQuality quality(SixroomStream stream) {
    final detail = [
      if (stream.resolution.isNotEmpty) stream.resolution,
      if (stream.bitrate != null) '${stream.bitrate} kbps',
    ];
    return LivePlayQuality.of(
      label: detail.isEmpty ? SixroomEndpoints.qualityName : '${SixroomEndpoints.qualityName} · ${detail.join(' · ')}',
      qualityId: SixroomEndpoints.qualityId,
      platformOrder: stream.bitrate ?? 1,
      codec: stream.codec,
    );
  }

  /// The one line of [stream]: FLV, its codec, no headers (the player and
  /// recorder sent none; the CDN answers without them) and no lease (no
  /// expiry in the address).
  static LivePlayLine line(SixroomStream stream) => LivePlayLine.of(
    url: '${stream.url}',
    format: LiveStreamFormat.flv,
    formatSource: LivePlayFormatSource.declared,
    codec: stream.codec,
    lineLabel: SixroomEndpoints.lineLabel,
  );

  /// [raw] as a room number (a number or room link); anything else is a
  /// caller error.
  static String _requireRoomId(String raw) =>
      SixroomEndpoints.roomIdOf(raw) ?? (throw ArgumentError.value(raw, 'roomId', 'not a Six Rooms room'));
}
