import 'package:live_sites/src/common/normalization/html_entities.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The state of a room as the room info or a card answers it.
///
/// The room info's `limitType` above 0 is the public chat limit (who may
/// chat), not a viewing limit: such rooms stream to anyone.
enum KugouliveState {
  /// A live session (`liveSessionId`), camera or phone; on a card, any
  /// positive state.
  live,

  /// `liveType` -1; on a card, 0 or -1.
  offline,

  /// Neither: no session and not offline.
  unknown,
}

/// One quality of a room: the streams of one protocol, bitrate tier, codec
/// and layout, gathered from every line of the stream answer.
final class KugouliveVariant {
  /// Creates the variant.
  KugouliveVariant({
    required this.id,
    required this.protocol,
    required this.rate,
    required this.codec,
    required this.layout,
    required List<LivePlayLine> lines,
  }) : lines = List.unmodifiable(lines);

  /// `<protocol>:<rate>:<codec>:<layout>` (`flv:4:1:2`), the quality id.
  final String id;

  /// `flv` or `hls`.
  final String protocol;

  /// The platform's bitrate tier (`streamProfiles[].rate`).
  final int rate;

  /// The platform's codec number (1 H.264, 2 HEVC).
  final int codec;

  /// The platform's layout number.
  final int layout;

  /// One line per distinct URL, in the answer's order of lines.
  final List<LivePlayLine> lines;

  /// Whether the variant is HEVC.
  bool get isHevc => codec == 2;
}

/// What room entry keeps for playback: the variants of a live room, or why
/// there is nothing to play.
final class KugouliveRoomData {
  /// Creates the data; [unavailable] is required when [variants] is empty.
  KugouliveRoomData({required this.roomId, this.variants = const [], this.unavailable})
    : assert(variants.isNotEmpty || unavailable != null, 'an empty playback needs its reason');

  /// The room the data belongs to.
  final String roomId;

  /// Best first (bitrate tier, then the answer's order).
  final List<KugouliveVariant> variants;

  /// Why there is nothing to play: offline, no live session, a login
  /// required, no stream in the answer.
  final KugouliveFailure? unavailable;
}

/// Pure parsing of Kugou Live (繁星, fanxing.kugou.com) responses and links:
/// the home page's areas, the room lists, the JSONP search, the room info
/// and the signed stream answer.
///
/// Anonymous and public. A room is its number, 3 to 11 digits.
abstract final class KugouliveRoomParser {
  /// The areas the home page links: every `/pcindex/category/<id>` link with
  /// a `title`, in page order, once each, without the personal routes; 推荐
  /// (8000) included. A page without such links gives the fallback areas.
  static List<LiveArea> areas(String html, {int status = 200}) {
    if (KugouliveJson.statusError(status, 'home page') case final error?) throw error;
    if (html.length > KugouliveEndpoints.responseLimit) {
      throw const KugouliveFailure(KugouliveFailureKind.apiChanged, 'home page: over the size limit');
    }
    final seen = <String>{};
    final found = [
      for (final match in KugouliveEndpoints.areaLink.allMatches(html))
        if (decodeHtmlEntities(match.group(2)!).trim() case final name
            when !KugouliveEndpoints.personalRoutes.contains(match.group(1)) &&
                name.isNotEmpty &&
                seen.add(match.group(1)!))
          (id: match.group(1)!, name: name),
    ];
    return [for (final area in found.isEmpty ? KugouliveEndpoints.fallbackAreas : found) _area(area.id, area.name)];
  }

  static LiveArea _area(String id, String name) => LiveArea.normalized(
    platform: kugouliveSiteId,
    areaId: id,
    areaName: name,
    parentAreaId: 'kugoulive',
    parentAreaName: KugouliveEndpoints.siteName,
  );

  /// The area id to list for [areaId]: 推荐 for null; null for anything that
  /// is not 1–8 digits (a caller error).
  static String? areaIdOf(String? areaId) {
    if (areaId == null) return KugouliveEndpoints.recommendAreaId;
    final id = areaId.trim();
    return KugouliveEndpoints.areaId.hasMatch(id) ? id : null;
  }

  /// A card's state (`liveStatus`, else `status`, else `liveType`): any
  /// positive value live (1 a camera, 6 a phone or game broadcast), 0 or -1
  /// offline, anything else unknown.
  static KugouliveState cardState(Object? value) => switch (KugouliveJson.integer(value)) {
    final int state when state > 0 => KugouliveState.live,
    0 || -1 => KugouliveState.offline,
    _ => KugouliveState.unknown,
  };

  /// A list or search card; null without a room number.
  ///
  /// - State [cardState].
  /// - Title `label`, else `topicContent`, `performContent`, the nick, else
  ///   empty; nick `nickName`, empty when missing.
  /// - Avatar `userLogo` (a present `logo` only when it is absent), else the
  ///   cover; cover `imgPath`, else `imagePath`.
  /// - Viewers `viewerNum`/`getViewerNum`, popularity `hot`, followers
  ///   `fansCount`; the metric is viewers when given, else popularity. A
  ///   search row's viewers only count while it is live and above 0 (the
  ///   search answers 0 for everyone).
  /// - Start (live only): a search row's `lastLiveTime` (Unix seconds), a
  ///   list row's `livetime` before [answeredAt].
  /// - No restriction: a card cannot tell.
  static LiveRoom? card(Map<String, Object?> raw, {DateTime? answeredAt, bool search = false}) {
    final id = KugouliveEndpoints.parseRoomId(KugouliveJson.text(raw['roomId']));
    if (id == null) return null;
    final nick = KugouliveJson.text(raw['nickName']);
    final state = cardState(raw['liveStatus'] ?? raw['status'] ?? raw['liveType']);
    final live = state == KugouliveState.live;
    final viewers = KugouliveJson.integer(raw['viewerNum'] ?? raw['getViewerNum']);
    final userId = KugouliveJson.text(raw['userId']);
    final kugouId = KugouliveJson.text(raw['kugouId']);
    final avatar = KugouliveJson.image(raw['userLogo'] ?? raw['logo']);
    final cover = KugouliveJson.image(raw['imgPath'] ?? raw['imagePath']);
    final followers = KugouliveJson.count(raw['fansCount']);
    final popularity = KugouliveJson.count(raw['hot']);
    final shownViewers = search && !(live && viewers != null && viewers > 0) ? null : viewers;
    final startedAt = !live
        ? null
        : search
        ? KugouliveJson.unixStart(raw['lastLiveTime'], answeredAt)
        : KugouliveJson.listStart(raw['livetime'], answeredAt);
    final liveStatus = switch (state) {
      KugouliveState.live => LiveStatus.live,
      KugouliveState.offline => LiveStatus.offline,
      KugouliveState.unknown => LiveStatus.unknown,
    };
    return LiveRoom.normalized(
      platform: kugouliveSiteId,
      roomId: id,
      content: RoomContent.of(
        title: KugouliveJson.firstText([raw['label'], raw['topicContent'], raw['performContent'], nick]),
        coverUrl: cover,
        notice: KugouliveEndpoints.chatNotice,
      ),
      anchor: LiveAnchor.normalized(
        platform: kugouliveSiteId,
        anchorId: userId.isEmpty ? kugouId : userId,
        name: nick,
        avatarUrl: avatar.isEmpty ? cover : avatar,
        followerCount: followers,
        liveStatus: liveStatus,
      ),
      audience: RoomAudience.of(
        onlineViewers: shownViewers,
        popularity: popularity,
        primaryMetric: shownViewers != null
            ? LiveAudienceMetricType.onlineViewers
            : popularity != null
            ? LiveAudienceMetricType.popularity
            : LiveAudienceMetricType.unknown,
      ),
      area: LiveArea.normalized(platform: kugouliveSiteId, areaName: KugouliveEndpoints.siteName),
      broadcast: RoomBroadcast.of(liveStatus: liveStatus, startedAt: startedAt),
      links: RoomLinks.of(webUrl: KugouliveEndpoints.roomUrl(id)),
    );
  }

  // Search --------------------------------------------------------------------

  /// The streamers of a search answer: JSONP to [callback] (when given) with
  /// nothing after it but `;`; `status` (else `code`) 0 or 1; the search
  /// cards of `data.anchor.list`, a room once.
  static List<LiveRoom> searchRooms(String body, {String? callback, int status = 200}) {
    const what = 'search';
    if (KugouliveJson.statusError(status, what) case final error?) throw error;
    if (body.length > KugouliveEndpoints.responseLimit) {
      throw const KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: answer over the size limit');
    }
    final text = body.trim();
    final open = text.indexOf('(');
    final close = text.lastIndexOf(')');
    if (open <= 0 || close <= open || text.substring(close + 1).trim().replaceAll(';', '').isNotEmpty) {
      throw const KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: not JSONP');
    }
    final name = text.substring(0, open).trim();
    if (!KugouliveEndpoints.callbackName.hasMatch(name) || (callback != null && name != callback)) {
      throw KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: JSONP to $name, not $callback');
    }
    final root = KugouliveJson.map(KugouliveJson.decode(text.substring(open + 1, close), what: what, status: status));
    final code = KugouliveJson.integer(root?['status'] ?? root?['code']);
    if (code != null && code != 0 && code != 1) {
      throw KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: code $code');
    }
    final at = KugouliveJson.answeredAt(root ?? const {});
    final list = KugouliveJson.map(KugouliveJson.map(root?['data'])?['anchor'])?['list'];
    final seen = <String>{};
    return [
      for (final row in KugouliveJson.list(list))
        if (KugouliveRoomParser.card(KugouliveJson.map(row) ?? const {}, answeredAt: at, search: true) case final room?
            when seen.add(room.roomId))
          room,
    ];
  }

  // Rooms ---------------------------------------------------------------------

  /// Room [roomId] from `getEnterRoomInfo`, with its state:
  /// - no such room (`normalRoomInfo` without a nick and with `kugouId` 0)
  ///   is not-found;
  /// - `liveType` -1 offline, a `liveSessionId` live, else unknown;
  ///   `limitType` is the chat limit and changes nothing;
  /// - no title: the room info has none, its `publicMesg` and `privateMesg`
  ///   are the public and private chat announcements; an empty title keeps
  ///   the one a list card or a follow holds;
  /// - notice: the two announcements, then the chat notice;
  /// - nick (empty when missing), avatar `userLogo`, cover `imgPath`,
  ///   followers `fansCount`; no audience (the list cards have it);
  /// - start: the session's start while live;
  /// - no restriction: the room info cannot tell.
  static ({LiveRoom room, KugouliveState state}) roomInfo(String body, {required String roomId, int status = 200}) {
    const what = 'getEnterRoomInfo';
    final (:root, :data) = KugouliveJson.answer(body, what: what, status: status);
    final info = KugouliveJson.map(data['normalRoomInfo']);
    if (info == null || info.isEmpty) {
      throw const KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: no normalRoomInfo');
    }
    final nick = KugouliveJson.text(info['nickName']);
    final kugouId = KugouliveJson.text(info['kugouId']);
    if (nick.isEmpty && (kugouId.isEmpty || KugouliveJson.integer(kugouId) == 0)) {
      throw KugouliveFailure(KugouliveFailureKind.notFound, 'room $roomId');
    }
    final session = KugouliveJson.text(data['liveSessionId']);
    final state = KugouliveJson.integer(data['liveType']) == -1
        ? KugouliveState.offline
        : session.isNotEmpty
        ? KugouliveState.live
        : KugouliveState.unknown;
    final announcements = [
      for (final value in [info['publicMesg'], info['privateMesg']])
        if (KugouliveJson.text(value) case final text when text.isNotEmpty) text,
    ];
    final liveStatus = switch (state) {
      KugouliveState.live => LiveStatus.live,
      KugouliveState.offline => LiveStatus.offline,
      KugouliveState.unknown => LiveStatus.unknown,
    };
    final userId = KugouliveJson.text(info['userId']);
    final cover = KugouliveJson.image(info['imgPath']);
    final avatar = KugouliveJson.image(info['userLogo']);
    final room = LiveRoom.normalized(
      platform: kugouliveSiteId,
      roomId: roomId,
      content: RoomContent.of(coverUrl: cover, notice: [...announcements, KugouliveEndpoints.chatNotice].join('\n')),
      anchor: LiveAnchor.normalized(
        platform: kugouliveSiteId,
        anchorId: userId.isEmpty ? kugouId : userId,
        name: nick,
        avatarUrl: avatar.isEmpty ? cover : avatar,
        followerCount: KugouliveJson.count(info['fansCount']),
        liveStatus: liveStatus,
      ),
      area: LiveArea.normalized(platform: kugouliveSiteId, areaName: KugouliveEndpoints.siteName),
      audience: RoomAudience.of(primaryMetric: LiveAudienceMetricType.unknown),
      broadcast: RoomBroadcast.of(
        liveStatus: liveStatus,
        startedAt: state == KugouliveState.live
            ? KugouliveJson.sessionStart(session, ownerId: kugouId, answered: KugouliveJson.answeredAt(root))
            : null,
      ),
      links: RoomLinks.of(webUrl: KugouliveEndpoints.roomUrl(roomId)),
    );
    return (room: room, state: state);
  }

  /// Why a room in [state] cannot be played, or null when it is live.
  static KugouliveFailure? playbackError(KugouliveState state, String roomId) => switch (state) {
    KugouliveState.live => null,
    KugouliveState.offline => KugouliveFailure(KugouliveFailureKind.streamUnavailable, 'room $roomId is offline'),
    KugouliveState.unknown => KugouliveFailure(
      KugouliveFailureKind.streamUnavailable,
      'room $roomId has no live session',
    ),
  };

  /// The live [room] once its stream answer told what this client may play:
  /// [LiveRestriction.none] with a stream, [LiveRestriction.needsLogin] when
  /// the answer asks for a login (the restricted notice leads the notice),
  /// [LiveRestriction.unplayable] when it gives no playable stream.
  static LiveRoom withRestriction(LiveRoom room, LiveRestriction restriction) {
    final notice = restriction == LiveRestriction.needsLogin
        ? [
            KugouliveEndpoints.restrictedNotice,
            if (room.content.notice case final text? when text.isNotEmpty) text,
          ].join('\n')
        : room.content.notice;
    return room.rebuild(
      (b) => b
        ..broadcast.replace(room.broadcast.rebuild((b) => b..restriction = restriction))
        ..content.replace(room.content.rebuild((b) => b..notice = notice)),
    );
  }

  // Streams -------------------------------------------------------------------

  /// The variants of a stream answer for [roomId]: the `httpsFlv` and
  /// `httpsHls` URLs of every line's profiles, grouped by protocol, rate,
  /// codec and layout, each URL once (the first line wins), only URLs
  /// [mediaUrl] accepts; groups without a URL dropped; sorted by rate,
  /// highest first, the answer's order otherwise. Lines name their codec.
  ///
  /// `code` -1 is needs-login; `status` other than 1 (offline) or no
  /// accepted URL is stream-unavailable; an answer for another room is
  /// api-changed.
  static List<KugouliveVariant> variants(String body, {required String roomId, int status = 200}) {
    const what = 'streamaddr';
    final root = KugouliveJson.map(KugouliveJson.decode(body, what: what, status: status));
    if (KugouliveJson.integer(root?['code']) == KugouliveEndpoints.loginRequiredCode) {
      throw const KugouliveFailure(KugouliveFailureKind.needsLogin, '$what: the room asks for a login');
    }
    final data = KugouliveJson.answerOf(root, what: what).data;
    final answered = KugouliveJson.text(data['roomId']);
    if (answered != roomId) {
      throw KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: asked $roomId, got $answered');
    }
    if (KugouliveJson.integer(data['status']) != 1) {
      throw KugouliveFailure(KugouliveFailureKind.streamUnavailable, '$what: status ${data['status']}');
    }
    final headers = KugouliveEndpoints.mediaHeaders(roomId);
    final groups = <String, ({String protocol, int rate, int codec, int layout, List<LivePlayLine> lines})>{};
    for (final lineValue in KugouliveJson.list(data['lines'])) {
      final line = KugouliveJson.map(lineValue) ?? const {};
      final sid = line['sid'] is String ? line['sid']! as String : null;
      for (final profileValue in KugouliveJson.list(line['streamProfiles'])) {
        final profile = KugouliveJson.map(profileValue) ?? const {};
        final rate = KugouliveJson.integer(profile['rate']) ?? 0;
        final codec = KugouliveJson.integer(profile['codec']) ?? 0;
        final layout = KugouliveJson.integer(profile['layout']) ?? 0;
        for (final (key, protocol, format) in const [
          ('httpsFlv', 'flv', LiveStreamFormat.flv),
          ('httpsHls', 'hls', LiveStreamFormat.hls),
        ]) {
          final group = groups.putIfAbsent(
            '$protocol:$rate:$codec:$layout',
            () => (protocol: protocol, rate: rate, codec: codec, layout: layout, lines: <LivePlayLine>[]),
          );
          for (final raw in KugouliveJson.list(profile[key])) {
            final url = mediaUrl(KugouliveJson.text(raw), protocol: protocol);
            if (url == null || group.lines.any((line) => line.url == '$url')) continue;
            group.lines.add(
              LivePlayLine.of(
                url: '$url',
                headers: headers,
                format: format,
                formatSource: LivePlayFormatSource.declared,
                codec: codecName(codec),
                lineLabel: sid == null ? null : 'sid$sid',
                lease: _lease(url),
              ),
            );
          }
        }
      }
    }
    final ordered = [
      for (final MapEntry(key: id, value: group) in groups.entries)
        if (group.lines.isNotEmpty)
          KugouliveVariant(
            id: id,
            protocol: group.protocol,
            rate: group.rate,
            codec: group.codec,
            layout: group.layout,
            lines: group.lines,
          ),
    ];
    // A stable sort, as the reference's short lists were.
    final indexed = ordered.indexed.toList()
      ..sort((left, right) {
        final byRate = right.$2.rate.compareTo(left.$2.rate);
        return byRate != 0 ? byRate : left.$1.compareTo(right.$1);
      });
    if (indexed.isEmpty) {
      throw KugouliveFailure(KugouliveFailureKind.streamUnavailable, '$what: no playable URL for $roomId');
    }
    return [for (final (_, variant) in indexed) variant];
  }

  /// The line codec of a codec number: `avc` for 1, `hevc` for 2, else null.
  static LiveStreamCodec? codecName(int codec) => switch (codec) {
    1 => LiveStreamCodec.avc,
    2 => LiveStreamCodec.hevc,
    _ => null,
  };

  static final RegExp _txTime = RegExp(r'^[0-9A-Fa-f]{8,16}$');

  /// [raw] as a media URL: https on `liveplay.live.kugou.com` or a
  /// subdomain, the default port, no user info or fragment, a `/live/` path
  /// ending in `.flv` (`.m3u8` for `hls`), a `txSecret` and a hex `txTime`;
  /// else null.
  static Uri? mediaUrl(String raw, {required String protocol}) {
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        !kugouliveHostIs(uri.host, 'liveplay.live.kugou.com') ||
        !uri.path.startsWith('/live/') ||
        !uri.path.toLowerCase().endsWith(protocol == 'hls' ? '.m3u8' : '.flv')) {
      return null;
    }
    final Map<String, String> query;
    try {
      query = uri.queryParameters;
    } on FormatException {
      return null;
    }
    return KugouliveJson.text(query['txSecret']).isEmpty || !_txTime.hasMatch(KugouliveJson.text(query['txTime']))
        ? null
        : uri;
  }

  /// When [url] stops opening connections: its `txTime`, hex Unix seconds
  /// (about 12 hours after issue). Null without a valid one.
  static DateTime? invalidAt(String url) {
    final String? value;
    try {
      value = Uri.tryParse(url)?.queryParameters['txTime'];
    } on FormatException {
      return null;
    }
    if (value == null || !_txTime.hasMatch(value)) return null;
    final seconds = int.tryParse(value, radix: 16);
    return seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// When to renew [url]: the lead before [invalidAt], or [now] when that
  /// has passed.
  static DateTime? refreshAt(String url, {required DateTime now}) {
    final invalid = invalidAt(url);
    if (invalid == null) return null;
    final refresh = invalid.subtract(KugouliveEndpoints.leaseLead);
    return refresh.isAfter(now) ? refresh : now;
  }

  /// The lease of a media [url]: renewed before its `txTime`. Expiry is
  /// checked when a connection opens (Tencent Cloud's signature), so it only
  /// prefetches.
  static LivePlayLease? _lease(Uri url) {
    final expires = invalidAt('$url');
    return expires == null
        ? null
        : LivePlayLease.of(refreshAt: expires.subtract(KugouliveEndpoints.leaseLead), expiresAt: expires);
  }

  /// The qualities: one per variant, `<FLV|HLS> 码率档 <rate>`, id the
  /// variant id, order rate first. With [preferH264] ("优先 H.264") the H.264
  /// (not HEVC) variants come first, each part in the variants' order, so
  /// the default is never HEVC; off, the variants' order.
  static List<LivePlayQuality> qualities(List<KugouliveVariant> variants, {bool preferH264 = true}) {
    final ordered = preferH264
        ? [...variants.where((variant) => !variant.isHevc), ...variants.where((variant) => variant.isHevc)]
        : variants;
    var order = 0;
    return [
      for (final variant in ordered)
        LivePlayQuality.of(
          label: '${variant.protocol.toUpperCase()} 码率档 ${variant.rate}',
          qualityId: variant.id,
          platformOrder: order++,
          codec: codecName(variant.codec),
        ),
    ];
  }

  /// The lines of [variant].
  static List<LivePlayLine> lines(KugouliveVariant variant) => variant.lines;
}
