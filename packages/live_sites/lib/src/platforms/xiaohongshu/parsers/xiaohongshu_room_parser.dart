import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
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
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_html.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Whether a room can be watched without conditions (3.x's
/// `XiaohongshuAccess`), as [XiaohongshuRoomData.restriction] tells it.
enum XiaohongshuAccess {
  /// `monetizeType` 0 and no `joinLimitTypes` entry other than 0.
  public,

  /// Paid (`monetizeType` other than 0) or limited (group chat, family,
  /// region, or a limit not known yet): no public full stream.
  restricted,

  /// `monetizeType` or `joinLimitTypes` is missing: not known to be public.
  unknown,
}

/// What a room's share page said beyond its card: 3.x kept this snapshot in
/// `data` on room entry and read the stream from it.
///
/// The stream is kept as answered (`pullConfig`) and checked only when it
/// is played ([XiaohongshuRoomParser.playable]): 3.x checked it while
/// reading the page, so one malformed pull address failed the room page and
/// the follow refresh too.
final class XiaohongshuRoomData {
  /// Creates the data.
  const XiaohongshuRoomData({
    required this.roomId,
    required this.live,
    required this.restriction,
    this.pullConfig,
    this.displayViewers,
  });

  /// The room id that was asked for; a live page named the same room.
  final String roomId;

  /// `roomInfo.status`: 2 → true (live), 3 → false (ended), anything else
  /// null (not known).
  final bool? live;

  /// Who may watch, from `monetizeType` and `joinLimitTypes` (the web
  /// page's enums `Free = 0, Paid = 1` and `GroupChat = 1, Family = 2,
  /// IpFence = 4`): [LiveRestriction.none] for a public room;
  /// [LiveRestriction.paid] for a `monetizeType` other than 0;
  /// [LiveRestriction.private] for the host's group chat or family;
  /// [LiveRestriction.regionBlocked] for an IP fence;
  /// [LiveRestriction.unplayable] for a limit not known yet; null when
  /// either field is missing (not known to be public).
  final LiveRestriction? restriction;

  /// Whether the room is public (3.x's access, from [restriction]).
  XiaohongshuAccess get access => switch (restriction) {
    null => XiaohongshuAccess.unknown,
    LiveRestriction.none => XiaohongshuAccess.public,
    _ => XiaohongshuAccess.restricted,
  };

  /// `roomInfo.pullConfig` as answered (a JSON string), kept only for a
  /// live public room, as 3.x read it only then; null otherwise.
  final Object? pullConfig;

  /// `roomInfo.displayViewerCount`: the platform's display text ("300万+"),
  /// not a measured audience.
  final String? displayViewers;
}

/// One pull address of `pullConfig` (3.x's `XiaohongshuStream`).
final class XiaohongshuStream {
  /// Creates the address.
  const XiaohongshuStream({required this.url, required this.codec, required this.quality, required this.label});

  /// The address, on `*.xhscdn.com` under `/live/<room>.flv` or `.m3u8`.
  final Uri url;

  /// `h264` or `h265`, the list it was in.
  final String codec;

  /// `quality_type` (`HD`), the id of the quality the address belongs to:
  /// both codecs' addresses of one `quality_type` are one quality.
  final String quality;

  /// `quality_type_name` (`原画`).
  final String label;

  /// HLS for a `.m3u8` path, else FLV.
  LiveStreamFormat get format => url.path.endsWith('.m3u8') ? LiveStreamFormat.hls : LiveStreamFormat.flv;
}

/// A room's share page: the room (without its stream data attached) and the
/// data.
typedef XiaohongshuPage = ({LiveRoom room, XiaohongshuRoomData data});

/// Pure parsing of Xiaohongshu (3.x's `XiaohongshuShare`, `XiaohongshuLink`
/// and the page request of `XiaohongshuApi`). There is no directory,
/// keyword search or danmaku: a room is the public share page
/// `www.xiaohongshu.com/livestream/<room>`, whose hydration state holds the
/// card, the state and the pull addresses.
///
/// Room ids are broadcast rooms: a streamer gets a new one every time they
/// go live, and 3.x follows the room, not the streamer. Following the
/// streamer is blocked: the only public answer naming the streamer is the
/// live page's deep link (`host_id`), while the profile page needs a login
/// and the web live API (`live-room.xiaohongshu.com`) a signed request.
abstract final class XiaohongshuRoomParser {
  /// The first line of every room's notice (3.x's zh.json key
  /// `xiaohongshu_room_scope`, reworded for users).
  static const String roomScopeNotice = '小红书每场直播都有新的房间号，这里关注的是这一场。主播下次开播时，请重新导入新的分享链接。';

  /// The notice line of a restricted room (zh.json `xiaohongshu_restricted`,
  /// reworded; the card shows the kind, [XiaohongshuRoomData.restriction]).
  static const String restrictedNotice = '这场直播设置了观看条件（付费、仅限部分观众或限定地区），这里无法播放。';

  /// The notice line of a room whose access the page does not tell (3.x
  /// showed [restrictedNotice] for it too).
  static const String unknownAccessNotice = '暂时无法确认这场直播是否公开，这里可能无法播放。';

  /// The notice line with the platform's display count (zh.json
  /// `xiaohongshu_display_viewers`, reworded): the web page shows it as
  /// "…人看过", a rounded total, not the audience now.
  static String displayViewersNotice(String value) => '小红书显示 $value 人看过（累计的约数，不是在线人数）';

  // Share page ----------------------------------------------------------------

  /// The share page of [requestedId] (a room id), answered with [status].
  ///
  /// - Status: only 200 is a page; 401, 403 and 406 are the site's risk
  ///   control (3.x's "access"), 404 not-found, 429 throttled, 5xx and any
  ///   other status (a redirect: the page must be the one asked for) a
  ///   network failure (3.x's "service" and "transport").
  /// - `liveStream.pageStatus` "error" ("未找到直播间，请稍后再试") is
  ///   not-found; 3.x called it an unexplained page error.
  /// - The page's own `roomId`, when present, must be the one asked for; a
  ///   live page must have it. An ended page has none and may recommend
  ///   another live room in `nextRoomInfo`, which is never read.
  /// - `status` 2 with `liveStatus` "success" is live, 3 with "end" ended;
  ///   another status is not known (the room is shown as such, as in 3.x),
  ///   and a status that contradicts `liveStatus` is api-changed.
  /// - 3.x read `status`, `monetizeType` and `joinLimitTypes` as JSON
  ///   integers and a list; the same values written as strings (`"2"`,
  ///   `"[0]"`, recorded by the archived spec) are accepted too.
  ///
  /// The room's id is [requestedId] (3.x); it has no streamer id, no
  /// audience (`displayViewerCount` is display text, in the notice) and no
  /// start time (the page has none). A live room carries its restriction
  /// ([XiaohongshuRoomData.restriction]; a public one without any pull
  /// address is [LiveRestriction.unplayable]); an ended room or one whose
  /// state is not known has none.
  static XiaohongshuPage room(String body, {required String requestedId, required int status}) {
    if (!XiaohongshuEndpoints.isRoomId(requestedId)) {
      throw ArgumentError.value(requestedId, 'requestedId', 'not a Xiaohongshu room id');
    }
    XiaohongshuJson.checkStatus(status, 'share page');
    final state = XiaohongshuHtml.liveStream(body);
    final page = state['pageStatus'];
    if (page == 'error') {
      final message = state['errorMessage'];
      throw XiaohongshuFailure(
        XiaohongshuFailureKind.notFound,
        'share page $requestedId: ${message is String ? message : 'pageStatus error'}',
      );
    }
    if (page != 'success') {
      throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'share page: pageStatus ${jsonEncode(page)}');
    }
    final data = XiaohongshuJson.object(state['roomData'], 'share page: roomData');
    final info = XiaohongshuJson.object(data['roomInfo'], 'share page: roomInfo');
    final host = XiaohongshuJson.object(data['hostInfo'], 'share page: hostInfo');
    final responseId = info['roomId'];
    if (responseId != null && (responseId is! String || responseId != requestedId)) {
      throw XiaohongshuFailure(
        XiaohongshuFailureKind.apiChanged,
        'share page: asked for $requestedId, got ${jsonEncode(responseId)}',
      );
    }
    final code = XiaohongshuJson.count(info['status']);
    if (code == null) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'share page: status ${jsonEncode(info['status'])}');
    }
    final liveStatus = state['liveStatus'];
    final live = switch (code) {
      2 => true,
      3 => false,
      _ => null,
    };
    if ((live == true && liveStatus != 'success') || (live == false && liveStatus != 'end')) {
      throw XiaohongshuFailure(
        XiaohongshuFailureKind.apiChanged,
        'share page: status $code with liveStatus ${jsonEncode(liveStatus)}',
      );
    }
    if (live == true && responseId == null) {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'share page: live without roomId');
    }
    final restriction = _restriction(info['monetizeType'], info['joinLimitTypes']);
    final title = XiaohongshuJson.text(info['roomTitle'], 'roomTitle');
    final nick = XiaohongshuJson.text(host['nickName'], 'nickName');
    final cover = XiaohongshuJson.text(info['roomCover'], 'roomCover');
    final avatar = XiaohongshuJson.text(host['avatar'], 'avatar');
    final roomData = XiaohongshuRoomData(
      roomId: requestedId,
      live: live,
      restriction: restriction,
      pullConfig: live == true && restriction == LiveRestriction.none ? info['pullConfig'] : null,
      displayViewers: XiaohongshuJson.text(info['displayViewerCount'], 'displayViewerCount'),
    );
    final liveState = switch (live) {
      true => LiveStatus.live,
      false => LiveStatus.offline,
      null => LiveStatus.unknown,
    };
    final room = LiveRoom.normalized(
      platform: 'xiaohongshu',
      roomId: requestedId,
      content: RoomContent(title: title ?? '', coverUrl: normalizeImageUrl(cover), notice: notice(roomData)),
      anchor: LiveAnchor.normalized(
        platform: 'xiaohongshu',
        name: nick ?? '',
        avatarUrl: normalizeImageUrl(avatar),
        liveStatus: liveState,
      ),
      audience: const RoomAudience(primaryMetric: LiveAudienceMetricType.unknown),
      broadcast: RoomBroadcast(
        liveStatus: liveState,
        restriction: switch (live) {
          true when restriction == LiveRestriction.none && !_hasAddresses(roomData.pullConfig) =>
            LiveRestriction.unplayable,
          true => restriction,
          _ => null,
        },
      ),
      links: RoomLinks(webUrl: XiaohongshuEndpoints.roomUrl(requestedId).toString()),
    );
    return (room: room, data: roomData);
  }

  /// The notice: the room-scope line, a line for a room that is restricted
  /// or whose access is not known, and the display count when the page had
  /// one (3.x's three lines, reworded for users).
  static String notice(XiaohongshuRoomData data) => [
    roomScopeNotice,
    if (data.access == XiaohongshuAccess.restricted) restrictedNotice,
    if (data.access == XiaohongshuAccess.unknown) unknownAccessNotice,
    if (data.displayViewers case final String value when value.isNotEmpty) displayViewersNotice(value),
  ].join('\n');

  /// The room a short link's landing page names, best effort (3.x followed
  /// the redirect chain itself; the transport follows it here, so the room
  /// is read out of the page it lands on): the hydration state's `roomId`
  /// of a live share page. Null for any other page, without a throw.
  static String? roomIdInPage(String body) {
    final Map<String, dynamic> state;
    try {
      state = XiaohongshuHtml.liveStream(body);
    } on XiaohongshuFailure {
      return null;
    }
    final info = state['roomData'];
    final roomInfo = info is Map<String, dynamic> ? info['roomInfo'] : null;
    final id = roomInfo is Map<String, dynamic> ? roomInfo['roomId'] : null;
    return id is String && XiaohongshuEndpoints.isRoomId(id) ? id : null;
  }

  /// 3.x's access rule, with the kind the web page's enums name (see
  /// [XiaohongshuRoomData.restriction]); a value of the wrong shape is
  /// api-changed. Several kinds: paid first, then group chat or family,
  /// then an IP fence.
  static LiveRestriction? _restriction(Object? monetization, Object? limits) {
    final paid = XiaohongshuJson.count(monetization);
    if (monetization != null && paid == null) {
      throw XiaohongshuFailure(
        XiaohongshuFailureKind.apiChanged,
        'share page: monetizeType ${jsonEncode(monetization)}',
      );
    }
    final list = limits is String ? XiaohongshuJson.decodeOrNull(limits) : limits;
    final kinds = list is List && list.length <= 16 ? [for (final value in list) XiaohongshuJson.count(value)] : null;
    if (limits != null && (kinds == null || kinds.contains(null))) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'share page: joinLimitTypes ${jsonEncode(limits)}');
    }
    if (paid == null || kinds == null) return null;
    if (paid != 0) return LiveRestriction.paid;
    if (kinds.contains(1) || kinds.contains(2)) return LiveRestriction.private;
    if (kinds.contains(4)) return LiveRestriction.regionBlocked;
    return kinds.any((kind) => kind != 0) ? LiveRestriction.unplayable : LiveRestriction.none;
  }

  /// Whether [pullConfig] names any address row: false when it is missing,
  /// empty, or a config whose `h264` and `h265` lists are empty. A config
  /// that cannot be read counts as having rows; playing it tells why.
  static bool _hasAddresses(Object? pullConfig) {
    if (pullConfig == null || pullConfig == '') return false;
    final decoded = pullConfig is String ? XiaohongshuJson.decodeOrNull(pullConfig) : pullConfig;
    if (decoded is! Map) return true;
    return [decoded['h264'], decoded['h265']].any((rows) => rows != null && (rows is! List || rows.isNotEmpty));
  }

  // Streams -------------------------------------------------------------------

  /// The pull addresses of a room that can be played, checked as 3.x did
  /// before playing (`_snapshot`), each refusal with its reason: an ended
  /// room or one whose state is not known is stream-unavailable; a paid
  /// room, one for the host's group chat or family, or one with a limit not
  /// known yet stream-unavailable; an IP-fenced room region-blocked; a room
  /// whose access is not known needs an account (3.x); no address
  /// stream-unavailable; and a `pullConfig` without one usable address
  /// api-changed (a bad address alone is left out).
  static List<XiaohongshuStream> playable(XiaohongshuRoomData data) {
    final room = data.roomId;
    if (data.live == false) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.streamUnavailable, 'room $room has ended');
    }
    if (data.live != true) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.streamUnavailable, 'room $room: state not known');
    }
    switch (data.restriction) {
      case null:
        throw XiaohongshuFailure(
          XiaohongshuFailureKind.needsLogin,
          'room $room: the page does not tell whether it is public',
        );
      case LiveRestriction.none:
        break;
      case LiveRestriction.paid:
        throw XiaohongshuFailure(XiaohongshuFailureKind.streamUnavailable, 'room $room is a paid broadcast');
      case LiveRestriction.private:
        throw XiaohongshuFailure(
          XiaohongshuFailureKind.streamUnavailable,
          "room $room is only for the host's group chat or family (joinLimitTypes)",
        );
      case LiveRestriction.regionBlocked:
        throw XiaohongshuFailure(
          XiaohongshuFailureKind.regionBlocked,
          'room $room is limited to a region (joinLimitTypes IP fence)',
        );
      case final LiveRestriction other:
        throw XiaohongshuFailure(
          XiaohongshuFailureKind.streamUnavailable,
          'room $room is restricted (${other.name}, joinLimitTypes)',
        );
    }
    final streams = _streams(data.pullConfig, room);
    if (streams.isEmpty) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.streamUnavailable, 'room $room: no pull address');
    }
    return streams;
  }

  /// 3.x's `pullConfig` rules: the `h264` rows, then the `h265` rows, at
  /// most 32 each; every row has an address, a quality and a label; the
  /// address is http(s) on the default port, on a subdomain of
  /// `xhscdn.com`, without user or fragment, at `/live/<room>.m3u8` or
  /// `.flv`; the same codec, quality and address once. The JSON string 3.x
  /// read may also be the object itself.
  ///
  /// A row that breaks these rules is left out; a config that is not an
  /// object, a codec that is not a list of at most 32, or rows of which
  /// none is usable is api-changed.
  static List<XiaohongshuStream> _streams(Object? value, String roomId) {
    if (value == null || value == '') return const [];
    final Object? decoded;
    if (value is String) {
      if (value.length > 65536) {
        throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'pullConfig: over 65536 characters');
      }
      decoded = XiaohongshuJson.decodeOrNull(value);
    } else {
      decoded = value;
    }
    final config = XiaohongshuJson.object(decoded, 'share page: pullConfig');
    final result = <XiaohongshuStream>[];
    final seen = <String>{};
    var rows = 0;
    for (final codec in const ['h264', 'h265']) {
      final list = config[codec];
      if (list == null) continue;
      if (list is! List || list.length > 32) {
        throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'pullConfig: $codec is not a list of at most 32');
      }
      rows += list.length;
      for (final row in list) {
        final stream = _stream(row, codec, roomId);
        if (stream != null && seen.add('$codec|${stream.quality}|${stream.url}')) result.add(stream);
      }
    }
    if (rows > 0 && result.isEmpty) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'pullConfig: none of $rows rows is usable');
    }
    return List.unmodifiable(result);
  }

  /// One `pullConfig` row of [codec], or null when it breaks 3.x's rules
  /// (see [_streams]).
  static XiaohongshuStream? _stream(Object? row, String codec, String roomId) {
    if (row is! Map<String, dynamic>) return null;
    final url = row['master_url'];
    final quality = row['quality_type'];
    final label = row['quality_type_name'];
    if (url is! String ||
        url.length > 4096 ||
        quality is! String ||
        quality.isEmpty ||
        quality.length > 64 ||
        label is! String ||
        label.isEmpty ||
        label.length > 128) {
      return null;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        !(uri.host.endsWith('.xhscdn.com') && uri.host != '.xhscdn.com') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.port != (uri.scheme == 'https' ? 443 : 80) ||
        !(uri.path == '/live/$roomId.m3u8' || uri.path == '/live/$roomId.flv')) {
      return null;
    }
    return XiaohongshuStream(url: uri, codec: codec, quality: quality, label: label);
  }

  /// One quality per `quality_type`, in address order: the H.264 and H.265
  /// addresses of the recorded `HD` are one quality, named by the page
  /// (`原画`), with the id `HD`. 3.x listed one quality per codec
  /// (`原画 · H264`, `h264:HD`); [XiaohongshuEndpoints.qualityIdFromLegacy]
  /// maps those ids.
  static List<LivePlayQuality> qualities(List<XiaohongshuStream> streams) {
    final qualities = <String, LivePlayQuality>{};
    for (final stream in streams) {
      qualities.putIfAbsent(stream.quality, () => LivePlayQuality(label: stream.label, qualityId: stream.quality));
    }
    return List.unmodifiable(qualities.values);
  }

  /// Every address of [quality] as a line: H.264 before H.265, and within
  /// each codec FLV before HLS, otherwise in the page's order; with
  /// [XiaohongshuEndpoints.headers] and no lease (the addresses are not
  /// signed). The default quality is the first one. A 3.x id (`h264:HD`) is
  /// read as its quality now ([XiaohongshuEndpoints.qualityIdFromLegacy]).
  /// A quality the room no longer has is stream-unavailable.
  ///
  /// Line labels are `<format>:<first host label>` (`flv:live-source-play`),
  /// with `:hevc` for H.265 and `#2`, `#3`… for a repeat.
  static List<LivePlayLine> lines(XiaohongshuRoomData data, LivePlayQuality? quality) {
    final streams = playable(data);
    final id = quality == null
        ? streams.first.quality
        : XiaohongshuEndpoints.qualityIdFromLegacy(quality.qualityId ?? '');
    final ordered = [
      for (final codec in const ['h264', 'h265'])
        for (final format in const [LiveStreamFormat.flv, LiveStreamFormat.hls])
          ...streams.where((stream) => stream.quality == id && stream.codec == codec && stream.format == format),
    ];
    if (ordered.isEmpty) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.streamUnavailable, 'no address for quality $id');
    }
    final repeats = <String, int>{};
    return [
      for (final stream in ordered)
        LivePlayLine(
          url: stream.url.toString(),
          headers: XiaohongshuEndpoints.headers,
          format: stream.format,
          formatSource: LivePlayFormatSource.inferred,
          codec: stream.codec == 'h265' ? LiveStreamCodec.hevc : LiveStreamCodec.avc,
          lineLabel: _lineLabel(stream, repeats),
        ),
    ];
  }

  static String _lineLabel(XiaohongshuStream stream, Map<String, int> repeats) {
    final base = [
      '${stream.format.name}:${stream.url.host.split('.').first}',
      if (stream.codec == 'h265') 'hevc',
    ].join(':');
    final repeat = repeats[base] = (repeats[base] ?? 0) + 1;
    return repeat == 1 ? base : '$base#$repeat';
  }
}
