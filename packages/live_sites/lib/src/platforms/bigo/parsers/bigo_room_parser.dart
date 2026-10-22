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
import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_json.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_studio.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The studio data a room carries for playback: the identity and access of the
/// answer it came from, whether that answer handed out a playlist, and whether
/// the answer was a token's first use. It holds no media address — every play
/// asks the studio again (the address only comes with a first use, and only
/// once). It rides in the room's transient stream handle.
final class BigoRoomData {
  /// Wraps the studio answer.
  const BigoRoomData({
    required this.siteId,
    required this.ownerId,
    required this.access,
    this.alive,
    this.hasStream = false,
    this.complete = true,
    this.restriction,
  });

  /// `clientBigoId`: the room's identity, as the site writes it.
  final String siteId;

  /// `uid`: the streamer's account.
  final int ownerId;

  /// Who may watch.
  final BigoAccess access;

  /// Whether the studio is live, or null when the answer hides it.
  final bool? alive;

  /// Whether the studio gave its media playlist.
  final bool hasStream;

  /// Whether the answer was a token's first use, which is the only one that
  /// says whether the room has a password and gives the playlist.
  final bool complete;

  /// The restriction of the answer.
  final LiveRestriction? restriction;

  @override
  String toString() => 'BigoRoomData($siteId, ${access.name})';
}

/// What a chat connection needs to join one studio's chat: the room the socket
/// enters (`roomId`, the streamer's int64 room id), the streamer whose audience
/// it asks for (`ownerId`) and the room's identity.
final class BigoDanmakuArgs {
  /// Wraps the chat arguments.
  const BigoDanmakuArgs({required this.siteId, required this.ownerId, required this.roomId});

  /// `clientBigoId`: the room's identity.
  final String siteId;

  /// `uid`: the streamer's account.
  final int ownerId;

  /// `roomId`: the streamer's int64 room id, as written.
  final String roomId;

  @override
  String toString() => 'BigoDanmakuArgs($siteId, $ownerId, $roomId)';
}

/// Pure parsing of Bigo Live answers: the public list, a studio answer, the
/// paging of the list and the link rules. Each function takes the answer and
/// its status and returns shared models or throws a [BigoFailure].
abstract final class BigoRoomParser {
  static final RegExp _siteId = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$');
  static final RegExp _digits = RegExp(r'^[0-9]{1,20}$');
  static final RegExp _broadcastId = RegExp(r'^[1-9][0-9]{0,31}$');
  static final RegExp _language = RegExp(r'^[a-zA-Z]{2}$');
  static final RegExp _control = RegExp(r'[\x00-\x1f]');

  /// Whether [value] is a Bigo id: a numeric id or one the streamer chose
  /// (`414439909`, `qashia305`).
  static bool isSiteId(String value) => _siteId.hasMatch(value);

  /// [roomId] trimmed as a Bigo id; anything else is [BigoFailureKind.notFound]
  /// without a request.
  static String checkedSiteId(String roomId) {
    final id = roomId.trim();
    if (!_siteId.hasMatch(id)) throw BigoFailure(BigoFailureKind.notFound, 'room id "$id" is not a Bigo id');
    return id;
  }

  /// The room page of [siteId].
  static String link(String siteId) => BigoEndpoints.roomPageUrl(siteId);

  /// The one area: the public list. Bigo's website has no category tree, so
  /// every browse goes through this list and the parent name is the platform.
  static LiveArea area() => LiveArea.normalized(
    platform: bigoSiteId,
    areaId: BigoEndpoints.areaId,
    areaName: BigoEndpoints.areaName,
    parentAreaName: BigoEndpoints.siteName,
  );

  /// Whether [value] is the one area.
  static bool isAreaId(String value) => value.trim() == BigoEndpoints.areaId;

  // Public list ---------------------------------------------------------------

  /// `OInterfaceWeb/vedioList/72`: the public list, a finite snapshot of about
  /// 20 live rooms whatever `fetchNum` asks.
  ///
  /// A row the reference would not read (an id that is not a Bigo id, a missing
  /// owner, a `room_id` that is not a positive number, an `is_locked` that is
  /// neither 0 nor 1) is left out on its own, and so is a later row repeating a
  /// Bigo id or an owner; the envelope is still checked as strictly as the
  /// reference did, and rows none of which can be read are
  /// [BigoFailureKind.apiChanged], so a changed API never shows as an empty
  /// list. Locked rooms stay listed, live and marked.
  static List<LiveRoom> directory(String body, {int status = 200}) {
    final data = successData(body, status: status, what: 'vedioList');
    final code = data['resCode'];
    if (code is! String) throw BigoFailure(BigoFailureKind.apiChanged, 'vedioList: resCode is $code');
    if (code != '0') throw BigoFailure(BigoFailureKind.apiChanged, 'vedioList: resCode $code');
    final rows = data['data'];
    if (rows is! List || rows.length > 500) {
      throw BigoFailure(
        BigoFailureKind.apiChanged,
        'vedioList: data is ${rows is List ? '${rows.length} rows' : 'not a list'}',
      );
    }
    final ids = <String>{};
    final owners = <String?>{};
    final cards = <LiveRoom>[];
    for (final row in rows) {
      final LiveRoom card;
      try {
        card = _card(row, 'vedioList row');
      } on BigoFailure {
        continue;
      }
      if (ids.add(card.roomId) && owners.add(card.anchor?.anchorId)) cards.add(card);
    }
    if (rows.isNotEmpty && cards.isEmpty) {
      throw BigoFailure(BigoFailureKind.apiChanged, 'vedioList: none of ${rows.length} rows is readable');
    }
    return List.unmodifiable(cards);
  }

  /// A card of the list: the topic as title, else the name; the cover as the
  /// avatar too; `user_count` as concurrent viewers; `time_stamp` as the
  /// broadcast's start and `is_locked` as the restriction.
  static LiveRoom _card(Object? raw, String what) {
    final row = object(raw, what);
    final siteId = _bigoId(row['bigo_id'], 'bigo_id');
    final ownerId = owner(row['owner'], 'owner of $siteId');
    final broadcast = row['room_id'];
    if (broadcast is! int || broadcast < 1) {
      throw BigoFailure(BigoFailureKind.apiChanged, 'vedioList: room_id of $siteId is $broadcast');
    }
    owner(row['sid'], 'sid of $siteId');
    final topic = text(row['room_topic'], 'room_topic of $siteId');
    final nickname = text(row['nick_name'], 'nick_name of $siteId');
    final cover = row['cover_m'] == null ? '' : picture(row['cover_m']);
    final viewers = row['user_count'] == null ? null : count(row['user_count'], 'user_count of $siteId');
    final locked = binary(row['is_locked'], 'is_locked of $siteId');
    count(row['room_flag'], 'room_flag of $siteId');
    return LiveRoom.normalized(
      platform: bigoSiteId,
      roomId: siteId,
      content: RoomContent(title: topic.isEmpty ? nickname : topic, coverUrl: cover),
      anchor: LiveAnchor.normalized(
        platform: bigoSiteId,
        anchorId: '$ownerId',
        name: nickname,
        avatarUrl: cover,
        liveStatus: LiveStatus.live,
      ),
      area: LiveArea.normalized(platform: bigoSiteId, areaName: BigoEndpoints.siteName),
      audience: RoomAudience(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast(
        liveStatus: LiveStatus.live,
        startedAt: startedAt(row['time_stamp']),
        restriction: locked ? LiveRestriction.password : LiveRestriction.none,
      ),
      links: RoomLinks(webUrl: link(siteId)),
    );
  }

  /// A list row's `time_stamp` (Unix seconds) as the broadcast's start, in UTC:
  /// it stays the same while a room is listed, also when it drops out of the
  /// list and comes back, and is new for the streamer's next broadcast. Anything
  /// that is not an integer between 2000 and 2100 gives no start time; a bad
  /// value drops only the start, never the card.
  static DateTime? startedAt(Object? value) {
    if (value is! int || value < 946684800 || value > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  /// Page [page] (from 1) of [cards], 20 a page: the list is a snapshot the
  /// adapter pages locally, so a page past the end is empty without a request.
  static ({List<LiveRoom> rooms, bool hasMore}) directoryPage(List<LiveRoom> cards, {required int page}) => (
    rooms: slice(cards, page: page, pageSize: BigoEndpoints.directoryPageSize),
    hasMore: page * BigoEndpoints.directoryPageSize < cards.length,
  );

  /// Page [page] of [pageSize] of [values]: nothing for a page or size below 1,
  /// a size over [BigoEndpoints.maxPageSize] or a page past the end.
  static List<T> slice<T>(List<T> values, {required int page, required int pageSize}) {
    if (!validSlice(page: page, pageSize: pageSize)) return const [];
    final start = (page - 1) * pageSize;
    if (start >= values.length) return const [];
    return values.sublist(start, (start + pageSize).clamp(start, values.length));
  }

  /// Whether a page of [pageSize] is served at all.
  static bool validSlice({required int page, required int pageSize}) =>
      page >= 1 && pageSize >= 1 && pageSize <= BigoEndpoints.maxPageSize;

  // Studio --------------------------------------------------------------------

  /// `studio/getInternalStudioInfo` asked with the web token, for
  /// [requestedSiteId]. Checked as strictly as the reference: `code` 0, `uid`,
  /// the `needLogin`/`passRoom`/`isPaidShow` gates, `alive` 0 or 1,
  /// `clientBigoId`, `roomStatus`, `roomType`, the broadcast id, the texts, and
  /// an https `.m3u8` playlist only for a public live studio. The three
  /// exceptions it kept:
  /// - the avatar and the snapshot: an http(s) picture is kept and any other is
  ///   left out (the reference failed the whole room on the site's `http://`
  ///   ones);
  /// - `passRoom` may be null: every use of a web token after its first answers
  ///   without it and without `hls_src`;
  /// - an id the site does not know is answered with `code` 0 and neither `uid`
  ///   nor `clientBigoId`: [BigoFailureKind.notFound].
  static BigoStudio studio(String body, {required String requestedSiteId, int status = 200}) {
    const what = 'getInternalStudioInfo';
    final data = successData(body, status: status, what: what);
    if (data['uid'] == null && data['clientBigoId'] == null) {
      throw BigoFailure(BigoFailureKind.notFound, '$what: no studio for "$requestedSiteId"');
    }
    final ownerId = owner(data['uid'], 'uid');
    final login = boolean(data['needLogin'], 'needLogin');
    final password = data['passRoom'] == null ? null : boolean(data['passRoom'], 'passRoom');
    final paid = data['isPaidShow'];
    if (paid is! String || !const {'', '0', '1'}.contains(paid)) {
      throw BigoFailure(BigoFailureKind.apiChanged, '$what: isPaidShow is $paid');
    }
    final alive = binary(data['alive'], 'alive');
    final access = login
        ? BigoAccess.loginRequired
        : (password ?? false) || paid == '1'
        ? BigoAccess.restricted
        : BigoAccess.public;
    final siteId = _bigoId(data['clientBigoId'], 'clientBigoId');
    final roomStatus = count(data['roomStatus'], 'roomStatus');
    final roomType = text(data['roomType'], 'roomType');
    final rawBroadcast = data['roomId'];
    final broadcastId = rawBroadcast == null || rawBroadcast == '' || rawBroadcast == '0'
        ? null
        : text(rawBroadcast, 'roomId');
    if (broadcastId != null && !_broadcastId.hasMatch(broadcastId)) {
      throw BigoFailure(BigoFailureKind.apiChanged, '$what: roomId is $broadcastId');
    }
    final rawHls = data['hls_src'];
    final hls = rawHls == null || rawHls == '' ? null : playlist(rawHls);
    if (hls != null && (access != BigoAccess.public || !alive)) {
      throw BigoFailure(BigoFailureKind.apiChanged, '$what: hls_src for a ${alive ? access.name : 'offline'} studio');
    }
    return BigoStudio(
      requestedSiteId: requestedSiteId,
      siteId: siteId,
      ownerId: ownerId,
      access: access,
      alive: switch (access) {
        BigoAccess.loginRequired => null,
        BigoAccess.restricted => alive ? true : null,
        BigoAccess.public => alive,
      },
      roomStatus: roomStatus,
      roomType: roomType,
      broadcastId: broadcastId,
      nickname: optionalText(data['nick_name'], 'nick_name'),
      title: optionalText(data['roomTopic'], 'roomTopic'),
      category: optionalText(data['gameTitle'], 'gameTitle'),
      avatar: picture(data['avatar']),
      snapshot: picture(data['snapshot']),
      hls: hls,
      password: password,
      paid: paid == '1',
      complete: password != null,
    );
  }

  /// The room of [studio]: the Bigo id as the site writes it, whatever the room
  /// was asked for by; the topic as title, else the name; the snapshot as cover
  /// (the avatar stays the fallback); the game as area, else the platform's
  /// name; no audience (the studio gives none — the chat socket brings the
  /// count). An offline studio names nobody (`nick_name` and `avatar` are
  /// empty), so they stay empty and a follow keeps its stored name and picture.
  static LiveRoom room(BigoStudio studio) => LiveRoom.normalized(
    platform: bigoSiteId,
    roomId: studio.siteId,
    content: RoomContent(
      title: studio.title.isEmpty ? studio.nickname : studio.title,
      coverUrl: studio.snapshot.isEmpty ? studio.avatar : studio.snapshot,
    ),
    anchor: LiveAnchor.normalized(
      platform: bigoSiteId,
      anchorId: '${studio.ownerId}',
      name: studio.nickname,
      avatarUrl: studio.avatar,
      liveStatus: studio.liveStatus,
    ),
    area: LiveArea.normalized(
      platform: bigoSiteId,
      areaName: studio.category.isEmpty ? BigoEndpoints.siteName : studio.category,
    ),
    audience: const RoomAudience(primaryMetric: LiveAudienceMetricType.onlineViewers),
    broadcast: RoomBroadcast(liveStatus: studio.liveStatus, restriction: studio.restriction),
    links: RoomLinks(webUrl: link(studio.siteId)),
  );

  /// The chat arguments of [studio], or null where the website does not open
  /// its chat (see [BigoStudio.opensChat]).
  static BigoDanmakuArgs? danmakuArgs(BigoStudio studio) => studio.opensChat
      ? BigoDanmakuArgs(siteId: studio.siteId, ownerId: studio.ownerId, roomId: studio.broadcastId!)
      : null;

  /// The studio data of [studio] for the room's stream handle.
  static BigoRoomData roomData(BigoStudio studio) => BigoRoomData(
    siteId: studio.siteId,
    ownerId: studio.ownerId,
    access: studio.access,
    alive: studio.alive,
    hasStream: studio.hls != null,
    complete: studio.complete,
    restriction: studio.restriction,
  );

  // Search --------------------------------------------------------------------

  /// Whether search takes [query] (already trimmed) at all: not blank, at most
  /// 100 characters, no control characters and not a URL (a room link is looked
  /// up before this check).
  static bool isSearchable(String query) =>
      query.isNotEmpty && query.length <= 100 && !_control.hasMatch(query) && Uri.tryParse(query)?.hasScheme != true;

  /// The id of a room link, else [text] (trimmed) when it is a Bigo id, else
  /// null.
  static String? siteIdOf(String text) {
    final value = text.trim();
    return siteIdFromUrl(value) ?? (isSiteId(value) ? value : null);
  }

  /// Whether search looks [query] up as an id before filtering: a Bigo id
  /// holding a digit, `_`, `.` or `-` (a word of letters is a name first).
  static bool looksLikeId(String query) => isSiteId(query) && RegExp('[0-9_.-]').hasMatch(query);

  /// The cards whose streamer name or topic contains [query], case ignored, once
  /// per Bigo id (case ignored), in list order.
  static List<LiveRoom> filter(List<LiveRoom> cards, String query) {
    final needle = query.toLowerCase();
    final seen = <String>{};
    return List.unmodifiable([
      for (final card in cards)
        if (((card.anchor?.name.toLowerCase().contains(needle) ?? false) ||
                card.content.title.toLowerCase().contains(needle)) &&
            seen.add(card.roomId.toLowerCase()))
          card,
    ]);
  }

  // Links ---------------------------------------------------------------------

  /// The Bigo id of a room link: http(s) on `bigo.tv` or any of its subdomains,
  /// on the default port and without user info, one path segment holding the id
  /// or two with a two-letter language first, not a site page
  /// ([BigoEndpoints.reservedPaths]); null for anything else. A fragment is
  /// ignored.
  static String? siteIdFromUrl(String raw) {
    if (raw.length > 8192 || RegExp(r'[\x00-\x20\x7f]').hasMatch(raw)) return null;
    final Uri parsed;
    try {
      parsed = Uri.parse(raw.trim());
    } on FormatException {
      return null;
    }
    if ((!parsed.isScheme('http') && !parsed.isScheme('https')) ||
        parsed.userInfo.isNotEmpty ||
        (parsed.hasPort && parsed.port != (parsed.isScheme('https') ? 443 : 80))) {
      return null;
    }
    final uri = parsed.removeFragment();
    final host = uri.host.toLowerCase();
    if (host != 'bigo.tv' && !host.endsWith('.bigo.tv')) return null;
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    final candidate = switch (segments) {
      [final id] => id,
      [final language, final id] when _language.hasMatch(language) => id,
      _ => null,
    };
    if (candidate == null || BigoEndpoints.reservedPaths.contains(candidate.toLowerCase())) return null;
    return isSiteId(candidate) ? candidate : null;
  }

  /// [value] as a Bigo id, or api-changed.
  static String _bigoId(Object? value, String what) {
    if (value is! String || !isSiteId(value)) {
      throw BigoFailure(BigoFailureKind.apiChanged, '$what "$value" is not a Bigo id');
    }
    return value;
  }

  /// Whether [value] is 1–20 digits (a broadcast id on the socket).
  static bool isDigits(String value) => _digits.hasMatch(value);
}
