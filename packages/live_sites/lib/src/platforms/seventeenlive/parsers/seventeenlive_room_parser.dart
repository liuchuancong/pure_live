import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_json.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_play_parser.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

const _site = '17live';

/// A stream object as the parsers read it: what a section grid's `stream`, a
/// search row and the `lives/<id>` answer all have in common.
final class SeventeenLiveStream {
  /// Creates the stream object.
  const SeventeenLiveStream({
    required this.roomId,
    required this.userId,
    required this.nick,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.bio,
    required this.followers,
    required this.online,
    required this.total,
    required this.audioOnly,
    required this.status,
    this.startedAt,
    this.restriction,
  });

  /// `liveStreamID`: the room, kept as the caller asked for it.
  final String roomId;

  /// `userID`: the broadcaster's UUID, which names the pull streams.
  final String userId;

  /// `userInfo.displayName`, else `userInfo.openID`, else empty.
  final String nick;

  /// `caption`, or [nick] when the live names none.
  final String title;

  /// `userInfo.picture`; empty unless it is one of the platform's images.
  final String avatar;

  /// `coverPhoto`, else `thumbnail`; empty unless one is an image.
  final String cover;

  /// `userInfo.bio`, trimmed.
  final String bio;

  /// `userInfo.followerCount`, when the answer has one.
  final int? followers;

  /// `liveViewerCount` while live (the viewers now).
  final int? online;

  /// `viewerCount` while live (this broadcast's viewers).
  final int? total;

  /// `audioOnly == 1`: an audio broadcast, which the website marks as such.
  final bool audioOnly;

  /// `status`: 2 live, 0 offline, anything else unknown (never a guess of
  /// offline).
  final LiveStatus status;

  /// `beginTime` while live; null for an offline room, whose value is the last
  /// broadcast's.
  final DateTime? startedAt;

  /// The lock of a live from its `premiumContent`; null when it cannot be read.
  final LiveRestriction? restriction;
}

/// What a room entry keeps for playback (the reference kept its stream snapshot
/// in the room's `data`, lines included): the qualities with the lines behind
/// each of them, or why there is nothing to play. It rides in the room's
/// transient stream handle.
final class SeventeenLiveRoomData {
  /// Creates the data; [unavailable] is required when [qualities] is empty.
  SeventeenLiveRoomData({
    required this.roomId,
    required this.userId,
    this.qualities = const [],
    this.lines = const {},
    this.unavailable,
  }) : assert(qualities.isNotEmpty || unavailable != null, 'an empty playback needs its reason');

  /// The room the playback belongs to (`liveStreamID`).
  final String roomId;

  /// The broadcaster's UUID (`userID`), which names the pull streams.
  final String userId;

  /// Best first: 原画, enhanced, HD, H.264
  /// ([SeventeenLivePlayParser.playQualities] applies "优先 H.264" to this list).
  final List<LivePlayQuality> qualities;

  /// The lines of each quality id, in the answer's provider order.
  final Map<String, List<LivePlayLine>> lines;

  /// Why there is nothing to play: offline, a state the platform did not name,
  /// a locked (restricted) live, or a live without a readable pull URL.
  final SeventeenLiveFailure? unavailable;

  @override
  String toString() => 'SeventeenLiveRoomData($roomId, ${qualities.length} qualities)';
}

/// What the chat connection needs for a room: the room id, which is also the
/// name of its Ably chat channel (the website subscribes to
/// `subscribeChatRoom(roomID)`). The token is anonymous and asked by the chat
/// itself, so a room entry hands the channel over without a request — the
/// channel is the broadcaster's and does not change between broadcasts.
@immutable
final class SeventeenLiveDanmakuArgs {
  /// Creates the arguments.
  const SeventeenLiveDanmakuArgs({required this.roomId});

  /// `liveStreamID`, the Ably channel name.
  final String roomId;

  @override
  bool operator ==(Object other) => other is SeventeenLiveDanmakuArgs && other.roomId == roomId;

  @override
  int get hashCode => roomId.hashCode;

  @override
  String toString() => 'SeventeenLiveDanmakuArgs($roomId)';
}

/// One page of the recommendation sections: live cards, and the opaque cursor of
/// the next page.
final class SeventeenLiveSectionsPage {
  /// Creates the page.
  const SeventeenLiveSectionsPage({required this.rooms, this.nextCursor});

  /// Live cards, one per room.
  final List<LiveRoom> rooms;

  /// The cursor of the next page; null on the last.
  final String? nextCursor;

  /// Whether another page exists: a cursor.
  bool get hasMore => nextCursor != null;
}

/// A stream object the rules refused — a list row loses itself over one, a room
/// answer fails as api-changed.
final class _Refused implements Exception {
  const _Refused(this.reason);

  final String reason;
}

/// Pure parsing of 17LIVE answers: the sections directory, the search, the room
/// and the link rules. Each function takes the answer text and its status and
/// returns shared models or throws a [SeventeenLiveFailure]; streams are
/// assembled in `seventeenlive_play_parser.dart`.
abstract final class SeventeenLiveRoomParser {
  static final RegExp _roomId = RegExp(r'^[1-9][0-9]{0,11}$');
  static final RegExp _control = RegExp(r'[\x00-\x1f]');
  static final RegExp _locale = RegExp(r'^[a-z]{2}(?:-[a-z]{2,4})?$', caseSensitive: false);
  static final RegExp _scheme = RegExp('^[a-z][a-z0-9+.-]*://', caseSensitive: false);

  /// [raw] trimmed when it is a room id (1 to 12 digits, no leading zero); else
  /// null.
  static String? normalizeRoomId(String raw) {
    final roomId = raw.trim();
    return _roomId.hasMatch(roomId) ? roomId : null;
  }

  /// The web page of [roomId]: the room's `link` and the `Referer` of its
  /// requests.
  static String roomUrl(String roomId) => SeventeenLiveEndpoints.roomUrl(roomId);

  /// Checks a directory cursor as the platform takes it: non-empty, at most
  /// [SeventeenLiveEndpoints.maxCursorLength] characters and no control
  /// character; anything else is a caller error, refused before any request.
  static void checkCursor(String? cursor) {
    if (cursor == null) return;
    if (cursor.isEmpty || cursor.length > SeventeenLiveEndpoints.maxCursorLength || cursor.contains(_control)) {
      throw SeventeenLiveFailure(SeventeenLiveFailureKind.invalidArgument, '$cursor is not a 17LIVE directory cursor');
    }
  }

  /// `beginTime` (Unix seconds; the room answer and search rows have it, section
  /// rows do not) as a UTC time; null when missing, not an integer, or outside
  /// 2000–2100 (an offline room's value is the last broadcast's).
  static DateTime? startTime(Object? value) {
    final seconds = value is int ? value : null;
    if (seconds == null || seconds < 946684800 || seconds > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// A live's restriction from its `premiumContent`, by the website's own rule
  /// (`isLocked`: a `premiumType` other than 0 that `paymentInfo.paid` does not
  /// unlock — the anonymous viewer never paid): type 1 (a premium live) is
  /// [LiveRestriction.paid], 2 (the broadcaster's army members)
  /// [LiveRestriction.subscribersOnly], any other (3, and later ones)
  /// [LiveRestriction.unplayable]. No `premiumContent` or type 0 is
  /// [LiveRestriction.none]; one that is not an object cannot be read (null).
  static LiveRestriction? restrictionOf(Object? premium) {
    if (premium == null) return LiveRestriction.none;
    final content = optionalObject(premium);
    if (content == null) return null;
    final type = integer(content['premiumType']) ?? 0;
    if (type == 0 || optionalObject(content['paymentInfo'])?['paid'] == true) return LiveRestriction.none;
    return switch (type) {
      1 => LiveRestriction.paid,
      2 => LiveRestriction.subscribersOnly,
      _ => LiveRestriction.unplayable,
    };
  }

  /// Why a live with [restriction] is not played: the website locks it for this
  /// (anonymous) viewer even when the answer carries pull URLs (it did on
  /// 2026-09-28, sample S04-live-army), so its lines are never read.
  static SeventeenLiveFailure lockedLive(String roomId, LiveRestriction restriction) => SeventeenLiveFailure(
    SeventeenLiveFailureKind.streamUnavailable,
    switch (restriction) {
      LiveRestriction.paid => '$roomId: a premium live, for viewers who paid',
      LiveRestriction.subscribersOnly => "$roomId: a live for the broadcaster's army members only",
      _ => '$roomId: a locked live (${restriction.name})',
    },
  );

  /// A stream object by the platform's rules. Its identity is always checked:
  /// `liveStreamID` is [requested], the owner's `userInfo.roomID` (required with
  /// [ownerRequired]) names the same room, and `userInfo.userID` is the
  /// broadcaster's. With [strict] (a list row, which the reference dropped over
  /// any of these) a field that is not what the platform writes refuses the
  /// object too; without it (a room answer) the field is left empty instead.
  static SeventeenLiveStream _stream(
    Map<String, dynamic> data, {
    required String requested,
    required bool ownerRequired,
    required bool strict,
  }) {
    Never refuse(String reason) => throw _Refused(reason);
    String readText(Object? value) => isBadText(value) ? (strict ? refuse('text $value') : '') : text(value);
    int? readCount(Object? value) => isBadCount(value) ? (strict ? refuse('count $value') : null) : count(value);
    final roomId = positiveId(data['liveStreamID']) ?? refuse('liveStreamID ${data['liveStreamID']}');
    final user = optionalObject(data['userInfo']) ?? refuse('no userInfo');
    final rawOwner = user['roomID'];
    final owner = rawOwner == null ? null : positiveId(rawOwner) ?? refuse('roomID $rawOwner');
    if (roomId != requested || (ownerRequired && owner != requested) || (owner != null && owner != requested)) {
      refuse('room $roomId (owner $owner) for $requested');
    }
    final userId = requiredText(data['userID']) ?? refuse('userID ${data['userID']}');
    if (requiredText(user['userID']) != userId) refuse('userInfo.userID ${user['userID']} for $userId');
    var nick = '';
    for (final value in [user['displayName'], user['openID']]) {
      nick = readText(value);
      if (nick.isNotEmpty) break;
    }
    if (nick.isEmpty && strict) refuse('no displayName or openID');
    final title = readText(data['caption']);
    final status = switch (integer(data['status'])) {
      2 => LiveStatus.live,
      0 => LiveStatus.offline,
      _ => LiveStatus.unknown,
    };
    final live = status == LiveStatus.live;
    return SeventeenLiveStream(
      roomId: roomId,
      userId: userId,
      nick: nick,
      title: title.isEmpty ? nick : title,
      avatar: image(user['picture']),
      cover: image(data['coverPhoto'] ?? data['thumbnail']),
      bio: readText(user['bio']),
      followers: readCount(user['followerCount']),
      online: live ? readCount(data['liveViewerCount']) : null,
      total: live ? readCount(data['viewerCount']) : null,
      audioOnly: integer(data['audioOnly']) == 1,
      status: status,
      // Neither is ever a reason to drop the row (the unified rule on
      // restrictions): one that cannot be read is left out.
      startedAt: live ? startTime(data['beginTime']) : null,
      restriction: live ? restrictionOf(data['premiumContent']) : null,
    );
  }

  /// A list row (a section grid's `stream`, a search result) as the platform
  /// keeps it: a live object that passes its rules, else null. A row that is not
  /// live at all is dropped too — the lists show current broadcasts.
  static SeventeenLiveStream? _liveRow(Object? value, {required bool ownerRequired}) {
    final data = optionalObject(value);
    if (data == null) return null;
    final roomId = positiveId(data['liveStreamID']);
    if (roomId == null) return null;
    try {
      final stream = _stream(data, requested: roomId, ownerRequired: ownerRequired, strict: true);
      return stream.status == LiveStatus.live ? stream : null;
    } on _Refused {
      return null;
    }
  }

  /// The card of [stream]: the age notice on every room, the audio area, the
  /// viewers now and of this broadcast while live, and — while live — the start
  /// time and the restriction (a locked live stays live, marked and unplayed).
  static LiveRoom card(SeventeenLiveStream stream) => LiveRoom.normalized(
    platform: _site,
    roomId: stream.roomId,
    content: RoomContent(
      title: stream.title,
      coverUrl: stream.cover,
      introduction: stream.bio.isEmpty ? null : stream.bio,
      notice: SeventeenLiveEndpoints.ageNotice,
    ),
    anchor: LiveAnchor.normalized(
      platform: _site,
      anchorId: stream.userId,
      name: stream.nick,
      avatarUrl: stream.avatar.isEmpty ? null : stream.avatar,
      followerCount: stream.followers,
      introduction: stream.bio.isEmpty ? null : stream.bio,
      liveStatus: stream.status,
    ),
    area: LiveArea.normalized(
      platform: _site,
      areaName: stream.audioOnly ? SeventeenLiveEndpoints.audioRoom : '',
    ),
    audience: RoomAudience(
      onlineViewers: stream.online,
      totalViewers: stream.total,
      primaryMetric: LiveAudienceMetricType.onlineViewers,
    ),
    broadcast: RoomBroadcast(
      liveStatus: stream.status,
      startedAt: stream.startedAt,
      restriction: stream.restriction,
    ),
    links: RoomLinks(webUrl: roomUrl(stream.roomId)),
  );

  // Directory -----------------------------------------------------------------

  /// A sections page fetched with [SeventeenLiveEndpoints.sectionsQuery] of
  /// [cursor].
  ///
  /// Banner and archive sections ([SeventeenLiveEndpoints.skippedSections]) are
  /// skipped, a row is a card only when it is live and passes the platform's
  /// rules (the rows carry no owner `roomID`), a room appears once, and the next
  /// cursor is the answer's unless it is empty or repeats [cursor]. A cursor that
  /// is not text, too long or has control characters is api-changed.
  ///
  /// Unlike the reference, a section or grid that is not an object (or grids that
  /// are not a list) is skipped instead of failing the page.
  static SeventeenLiveSectionsPage sectionsPage(String body, {String? cursor, int status = 200}) {
    const what = 'sections';
    final data = object(decode(body, what: what, status: status), what);
    final sections = data['sections'];
    if (sections is! List) {
      throw const SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'sections: no sections list');
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final item in sections) {
      final section = optionalObject(item);
      if (section == null || SeventeenLiveEndpoints.skippedSections.contains(section['id'])) continue;
      final grids = section['grids'] ?? const <Object?>[];
      if (grids is! List) continue;
      for (final grid in grids) {
        final row = _liveRow(optionalObject(grid)?['stream'], ownerRequired: false);
        if (row != null && seen.add(row.roomId)) rooms.add(card(row));
      }
    }
    final raw = data['cursor'];
    if (raw != null && raw is! String) {
      throw SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'sections: cursor $raw');
    }
    final next = raw is String && raw.isNotEmpty && raw != cursor ? raw : null;
    if (next != null && (next.length > SeventeenLiveEndpoints.maxCursorLength || next.contains(_control))) {
      throw const SeventeenLiveFailure(
        SeventeenLiveFailureKind.apiChanged,
        'sections: cursor too long or with control characters',
      );
    }
    return SeventeenLiveSectionsPage(rooms: List.unmodifiable(rooms), nextCursor: next);
  }

  // Search --------------------------------------------------------------------

  /// Whether [value] is a web address (`<scheme>://…`), which the search does
  /// not send as a keyword. Unlike the reference (anything with a URI scheme),
  /// `Re:Zero` and other keywords with a colon are keywords.
  static bool isUrl(String value) => _scheme.hasMatch(value.trim());

  /// The keyword sent for [keyword]: trimmed and cut to
  /// [SeventeenLiveEndpoints.maxKeywordLength] UTF-16 code units, never inside a
  /// surrogate pair, then trimmed again (the reference found nothing for a longer
  /// one). Empty when there is nothing to search for.
  static String searchKeyword(String keyword) {
    var text = keyword.trim();
    if (text.length > SeventeenLiveEndpoints.maxKeywordLength) {
      var end = SeventeenLiveEndpoints.maxKeywordLength;
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      text = text.substring(0, end).trim();
    }
    return text;
  }

  /// `liveStreams/search` results as cards: current broadcasts only, a room
  /// once. As the reference did, a row must name its owner's `roomID` and pass
  /// its rules, else it is skipped. The answer is a list (else api-changed).
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    const what = 'liveStreams/search';
    final data = decode(body, what: what, status: status);
    if (data is! List) {
      throw const SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'liveStreams/search: not a list');
    }
    final seen = <String>{};
    return List.unmodifiable([
      for (final item in data)
        if (_liveRow(item, ownerRequired: true) case final row?)
          if (seen.add(row.roomId)) card(row),
    ]);
  }

  // Rooms ---------------------------------------------------------------------

  static Map<String, dynamic> _room(String body, {required String roomId, required int status}) {
    final what = 'lives/$roomId';
    return object(decode(body, what: what, status: status), what);
  }

  static SeventeenLiveStream _checked(Map<String, dynamic> data, String roomId) {
    try {
      return _stream(data, requested: roomId, ownerRequired: true, strict: false);
    } on _Refused catch (refused) {
      throw SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'lives/$roomId: ${refused.reason}');
    }
  }

  /// The room [roomId] from `lives/<id>` without its streams (what a refresh and
  /// a search by room showed): [card] of its stream. The answer must be this room
  /// with its owner's `roomID` and `userID` (else api-changed); a status other
  /// than live (2) or offline (0) is an unknown state. Unlike the reference, a
  /// field that is not what it expected (a blank name, a negative count) is left
  /// empty instead of failing the room.
  static LiveRoom refreshRoom(String body, {required String roomId, int status = 200}) =>
      card(_checked(_room(body, roomId: roomId, status: status), roomId));

  /// The room [roomId] from `lives/<id>` as a room entry reads it: the card of
  /// [refreshRoom] with its playback ([SeventeenLiveRoomData]) and its chat
  /// channel ([SeventeenLiveDanmakuArgs]). A room that cannot be played is
  /// entered all the same and its stream says why: offline, a state the platform
  /// did not name, a locked live ([lockedLive], whose pull URLs are not read), a
  /// live without a pull URL, or pull data that cannot be read at all
  /// (api-changed).
  static LiveRoom enteredRoom(String body, {required String roomId, int status = 200}) {
    final data = _room(body, roomId: roomId, status: status);
    final stream = _checked(data, roomId);
    final what = 'lives/$roomId';
    var offered = (qualities: const <LivePlayQuality>[], lines: const <String, List<LivePlayLine>>{});
    final SeventeenLiveFailure? unavailable;
    switch (stream.status) {
      case LiveStatus.live when (stream.restriction ?? LiveRestriction.none) != LiveRestriction.none:
        unavailable = lockedLive(what, stream.restriction!);
      case LiveStatus.live:
        final skipped = <String>[];
        offered = SeventeenLivePlayParser.streams(data, roomId: roomId, skipped: skipped);
        unavailable = offered.qualities.isNotEmpty
            ? null
            : skipped.isEmpty
            ? SeventeenLiveFailure(SeventeenLiveFailureKind.streamUnavailable, '$what: no pull URL')
            : SeventeenLiveFailure(
                SeventeenLiveFailureKind.apiChanged,
                '$what: no readable pull URL (${skipped.join('; ')})',
              );
      case LiveStatus.offline:
        unavailable = SeventeenLiveFailure(SeventeenLiveFailureKind.streamUnavailable, '$what: offline');
      case _:
        unavailable = SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, '$what: status ${data['status']}');
    }
    return card(stream).copyWith(
      runtime: RoomRuntime(
        streamHandle: SeventeenLiveRoomData(
          roomId: roomId,
          userId: stream.userId,
          qualities: offered.qualities,
          lines: offered.lines,
          unavailable: unavailable,
        ),
        danmakuHandle: SeventeenLiveDanmakuArgs(roomId: roomId),
      ),
    );
  }

  // Links ---------------------------------------------------------------------

  /// The room of a 17LIVE page: http(s) on one of
  /// [SeventeenLiveEndpoints.webHosts] exactly (any case, any port), without
  /// user info; the path (empty segments ignored, words in any case)
  /// `/live/<id>`, `/<locale>/live/<id>`, `/profile/r/<id>` or
  /// `/<locale>/profile/r/<id>`, the locale two letters with an optional `-`
  /// suffix (`ja`, `zh-Hant`), the id a room id. A path that cannot be decoded is
  /// no link. Other hosts are not rooms, and there is no short link.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        !SeventeenLiveEndpoints.webHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    bool word(int index, String value) => segments[index].toLowerCase() == value;
    final id = switch (segments.length) {
      2 when word(0, 'live') => segments[1],
      3 when _locale.hasMatch(segments[0]) && word(1, 'live') => segments[2],
      3 when word(0, 'profile') && word(1, 'r') => segments[2],
      4 when _locale.hasMatch(segments[0]) && word(1, 'profile') && word(2, 'r') => segments[3],
      _ => null,
    };
    return id == null ? null : normalizeRoomId(id);
  }
}
