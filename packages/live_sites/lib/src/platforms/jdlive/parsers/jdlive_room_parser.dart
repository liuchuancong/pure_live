import 'dart:convert';

import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
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
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A broadcast's state as the play answer or a card says it (`status`; an
/// app-only broadcast is marked by [JdliveBroadcast.appOnly], whatever the
/// state).
enum JdliveState {
  /// `status` 1.
  live,

  /// `status` 0: announced, not started.
  preview,

  /// `status` 2: ended (the answer may still carry the stopped live
  /// addresses).
  offline,

  /// `status` 3: ended, with the recording on JD Cloud's video service.
  replay,

  /// `status` 10 or 11: paused by the streamer.
  paused,

  /// Any other status, or none.
  unknown,
}

/// One broadcast: a featured list card, or the play answer of a room (with
/// its media when live or a replay), completed from a card already seen
/// ([enrich]). The play answer has no title, shop name, avatar, cover or
/// views; they stay empty then, so a follow keeps what it stored.
final class JdliveBroadcast {
  /// Creates a broadcast.
  const JdliveBroadcast({
    required this.liveId,
    required this.state,
    this.authorId = '',
    this.nick = '',
    this.title = '',
    this.avatar = '',
    this.cover = '',
    this.background = '',
    this.totalViews,
    this.hls,
    this.flv,
    this.recording,
    this.appOnly = false,
    this.restriction,
  });

  /// The broadcast (`liveId`): the room's identity. Every broadcast has its
  /// own.
  final String liveId;

  /// The shop's account (`authorId`); `''` when unknown.
  final String authorId;

  /// The shop's name (`userName`); `''` when unknown.
  final String nick;

  /// The title; `''` when unknown.
  final String title;

  /// The shop's avatar (`userPic`); `''` when unknown.
  final String avatar;

  /// The card's cover (`indexImage`); `''` when no card was seen (the play
  /// answer's blurred image is only the [background]).
  final String cover;

  /// The play answer's `blurredImg`: a blurred frame for the room page's
  /// background; `''` for a card.
  final String background;

  /// Cumulative views (`pv`); null when unknown.
  final int? totalViews;

  /// The state.
  final JdliveState state;

  /// The HLS playlist (`h5VideoUrl`) of a live broadcast.
  final Uri? hls;

  /// The FLV stream (`videoUrl`, else `pcVideoUrl`) of a live broadcast.
  final Uri? flv;

  /// The recording (an HLS playlist on JD Cloud's video service) of a
  /// replay; null otherwise.
  final Uri? recording;

  /// `secret` 1: watchable in JD's app only, whatever the state.
  final bool appOnly;

  /// What keeps this client from playing it, as the play answer tells:
  /// app-only, unplayable (live without an address, or a replay without a
  /// recording) or none; null for a card (the list does not say).
  final LiveRestriction? restriction;

  /// Whether this is a play answer (a card's restriction is unknown).
  bool get hasPlayAnswer => restriction != null;

  /// This play answer with what it lacks taken from [known], a card of the
  /// same broadcast: the account, the names, the avatar, the cover and the
  /// views while this answer has none. State, background, media and
  /// restriction stay this answer's.
  JdliveBroadcast enrich(JdliveBroadcast known) => JdliveBroadcast(
    liveId: liveId,
    authorId: authorId.isEmpty ? known.authorId : authorId,
    nick: nick.isEmpty ? known.nick : nick,
    title: title.isEmpty ? known.title : title,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    cover: cover.isEmpty ? known.cover : cover,
    background: background.isEmpty ? known.background : background,
    totalViews: totalViews ?? known.totalViews,
    state: state,
    hls: hls,
    flv: flv,
    recording: recording,
    appOnly: appOnly,
    restriction: restriction,
  );

  /// Why this broadcast cannot be played, or null: app-only, any state but
  /// live or replay, live without an address and a replay without a
  /// recording, each with its reason.
  JdliveFailure? get streamError {
    if (appOnly) {
      return JdliveFailure(JdliveFailureKind.streamUnavailable, '$liveId: JD app only (secret)');
    }
    return switch (state) {
      JdliveState.live when hls == null && flv == null => JdliveFailure(
        JdliveFailureKind.streamUnavailable,
        '$liveId: live without media',
      ),
      JdliveState.replay when recording == null => JdliveFailure(
        JdliveFailureKind.streamUnavailable,
        '$liveId: replay without a recording',
      ),
      JdliveState.live || JdliveState.replay => null,
      _ => JdliveFailure(JdliveFailureKind.streamUnavailable, '$liveId is ${state.name}'),
    };
  }
}

/// Pure parsing of JD Live answers (3.x's `JdLiveApi` and the room mapping of
/// its `JdLiveSite`): the featured list, the play answer, the playlist
/// check, and the v2 room, qualities and lines.
abstract final class JdliveRoomParser {
  /// The one area of the catalog.
  static LiveArea area() =>
      LiveArea.normalized(platform: 'jdlive', areaId: JdliveEndpoints.areaId, areaName: JdliveEndpoints.areaName);

  /// The 3.x state of a `status`: 1 live, 0 preview, 2 ended, 3 replay, 10
  /// and 11 paused, anything else (or none) unknown.
  static JdliveState state(Object? status) => switch (JdliveJson.integer(status)) {
    1 => JdliveState.live,
    0 => JdliveState.preview,
    2 => JdliveState.offline,
    3 => JdliveState.replay,
    10 || 11 => JdliveState.paused,
    _ => JdliveState.unknown,
  };

  // Featured list -------------------------------------------------------------

  /// `liveListWithTabToM` (3.x's `parseDirectoryJson`): the `templateType` 1
  /// entries are broadcasts, the others (promotions, official replays) are
  /// skipped. An entry without a valid id, whose `liveId` differs from its
  /// `id`, or repeating one, is skipped. An entry that cannot be read is
  /// skipped too, unless nothing on the page can be read: then the page is
  /// api-changed, as is a list that is not one or lacks `currentCount`.
  /// Names left blank stay empty.
  static ({List<JdliveBroadcast> rooms, int nextCount, bool hasMore}) directory(
    String body, {
    required int after,
    int status = 200,
  }) {
    const what = 'liveListWithTabToM';
    final data = JdliveJson.data(body, status: status, what: what);
    final rows = data['list'];
    if (rows is! List || rows.length > 1000) {
      throw JdliveFailure(
        JdliveFailureKind.apiChanged,
        '$what: list is ${rows is List ? '${rows.length} entries' : 'not a list'}',
      );
    }
    final seen = <String>{};
    final rooms = <JdliveBroadcast>[];
    var unreadable = 0;
    for (final row in rows) {
      final JdliveBroadcast? card;
      try {
        card = _card(row);
      } on JdliveFailure {
        unreadable++;
        continue;
      }
      if (card != null && seen.add(card.liveId)) rooms.add(card);
    }
    if (unreadable > 0 && rooms.isEmpty) {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: $unreadable unreadable entries, no broadcast');
    }
    final next = JdliveJson.count(data['currentCount']);
    if (next == null) {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: currentCount is ${data['currentCount']}');
    }
    return (rooms: rooms, nextCount: next, hasMore: rooms.isNotEmpty && next > after);
  }

  /// The broadcast of a list entry, or null for another kind of entry or an
  /// invalid id; api-changed when it cannot be read.
  static JdliveBroadcast? _card(Object? row) {
    const what = 'liveListWithTabToM';
    final card = JdliveJson.object(row, '$what entry');
    if (JdliveJson.integer(card['templateType']) != 1) return null;
    final item = JdliveJson.object(card['data'], '$what broadcast');
    final liveId = _id(item['liveId'] ?? item['id']);
    if (liveId == null || _id(item['id']) != liveId) return null;
    return JdliveBroadcast(
      liveId: liveId,
      authorId: _id(item['authorId']) ?? '',
      nick: JdliveJson.optionalText(item['userName'], 'userName of $liveId'),
      title: JdliveJson.optionalText(item['title'], 'title of $liveId'),
      avatar: _image(item['userPic'], 'userPic of $liveId'),
      cover: _image(item['indexImage'], 'indexImage of $liveId'),
      totalViews: JdliveJson.count(item['pv']),
      state: state(item['status']),
    );
  }

  // Play answer ---------------------------------------------------------------

  /// `getImmediatePlayToM` (3.x's `parseRoomJson`): the state, `secret`, the
  /// blurred background and the media. The answer has no names, cover or
  /// views; an answer for another broadcast is api-changed.
  ///
  /// Media, one bad address costing only its quality: the HLS playlist
  /// (`h5VideoUrl`) and FLV stream of JD Cloud's live CDN (https,
  /// `*.jdcloud.com`, under `/live/`); the FLV is `videoUrl`, else
  /// `pcVideoUrl`, the first one of the playlist's stream key when there is
  /// a playlist. A replay's recording is the first of `h5VideoUrl`,
  /// `videoUrl` and `pcVideoUrl` that is an HLS playlist on JD Cloud's video
  /// service.
  ///
  /// The restriction: app-only for `secret` 1; unplayable for a live
  /// broadcast without an address or a replay without a recording; none
  /// otherwise.
  static JdliveBroadcast play(String body, {required String liveId, int status = 200}) {
    const what = 'getImmediatePlayToM';
    final data = JdliveJson.data(body, status: status, what: what);
    final answered = _id(data['liveId']);
    if (answered != liveId) {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: asked $liveId, got ${data['liveId']}');
    }
    final current = state(data['status']);
    final appOnly = JdliveJson.integer(data['secret']) == 1;
    final hls = _media(data['h5VideoUrl'], '.m3u8');
    Uri? flv;
    for (final field in ['videoUrl', 'pcVideoUrl']) {
      final candidate = _media(data[field], '.flv');
      if (candidate != null && (hls == null || _streamKey(candidate) == _streamKey(hls))) {
        flv = candidate;
        break;
      }
    }
    Uri? recording;
    if (current == JdliveState.replay) {
      for (final field in ['h5VideoUrl', 'videoUrl', 'pcVideoUrl']) {
        if (_recording(data[field]) case final found?) {
          recording = found;
          break;
        }
      }
    }
    final unplayable =
        (current == JdliveState.live && hls == null && flv == null) ||
        (current == JdliveState.replay && recording == null);
    return JdliveBroadcast(
      liveId: liveId,
      state: current,
      background: _image(data['blurredImg'], null),
      hls: hls,
      flv: flv,
      recording: recording,
      appOnly: appOnly,
      restriction: appOnly
          ? LiveRestriction.appOnly
          : unplayable
          ? LiveRestriction.unplayable
          : LiveRestriction.none,
    );
  }

  /// The check of a live broadcast's HLS playlist at room entry
  /// (`validatePlaylist`): at most [JdliveEndpoints.playlistLimit]
  /// characters, starting with `#EXTM3U`, and every media reference (a URI
  /// line or a tag's `URI="…"` ) resolving to https on [expected]'s host
  /// (port 443), under `/live/`, named after its stream key; at least one
  /// and at most 1000 of them. A 404 is stream-unavailable (the stream is
  /// not on the CDN); another status is mapped as the API's; a playlist that
  /// fails the check is api-changed.
  static void checkPlaylist(String body, {required Uri expected, int status = 200}) {
    const what = 'playlist';
    if (status == 404) {
      throw const JdliveFailure(JdliveFailureKind.streamUnavailable, '$what: HTTP 404');
    }
    JdliveJson.checkStatus(status, what: what);
    if (body.length > JdliveEndpoints.playlistLimit || !body.trimLeft().startsWith('#EXTM3U')) {
      throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: not an HLS playlist (${JdliveJson.snippet(body)})');
    }
    final stem = _streamKey(expected);
    var references = 0;
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        for (final match in RegExp('URI="([^"]+)"').allMatches(line)) {
          if (!_isChild(expected, match.group(1)!, stem)) {
            throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: foreign ${match.group(1)}');
          }
          references++;
        }
        continue;
      }
      if (!_isChild(expected, line, stem)) {
        throw JdliveFailure(JdliveFailureKind.apiChanged, '$what: foreign ${JdliveJson.snippet(line)}');
      }
      references++;
      if (references > 1000) {
        throw const JdliveFailure(JdliveFailureKind.apiChanged, '$what: over 1000 media references');
      }
    }
    if (references < 1) {
      throw const JdliveFailure(JdliveFailureKind.apiChanged, '$what: no media reference');
    }
  }

  static bool _isChild(Uri expected, String raw, String stem) {
    final Uri child;
    try {
      child = expected.resolve(raw);
    } on FormatException {
      return false;
    }
    return child.isScheme('https') &&
        child.userInfo.isEmpty &&
        !child.hasFragment &&
        child.host.toLowerCase() == expected.host.toLowerCase() &&
        (!child.hasPort || child.port == 443) &&
        child.path.startsWith('/live/') &&
        child.pathSegments.isNotEmpty &&
        child.pathSegments.last.startsWith(stem);
  }

  // Rooms and streams ---------------------------------------------------------

  /// The room of [room]: the broadcast id; the shop's account as user; the
  /// title, shop name, avatar and cover as known, else empty, so a follow
  /// keeps what it stored; the one area; the views as cumulative viewers
  /// when known; live for live (app-only too, marked by the restriction),
  /// offline for preview and ended, replay for a replay, unknown for paused
  /// and unknown; the notice and the media headers. [withData] gives a live
  /// broadcast that is not app-only its chat arguments.
  static LiveRoom room(JdliveBroadcast room, {bool withData = false}) {
    final total = room.totalViews;
    final liveStatus = switch (room.state) {
      JdliveState.live => LiveStatus.live,
      JdliveState.preview || JdliveState.offline => LiveStatus.offline,
      JdliveState.replay => LiveStatus.replay,
      JdliveState.paused || JdliveState.unknown => LiveStatus.unknown,
    };
    return LiveRoom.normalized(
      platform: 'jdlive',
      roomId: room.liveId,
      content: RoomContent(
        title: room.title,
        coverUrl: room.cover,
        notice: room.appOnly ? JdliveEndpoints.restrictedNotice : JdliveEndpoints.chatNotice,
      ),
      anchor: LiveAnchor.normalized(
        platform: 'jdlive',
        anchorId: room.authorId,
        name: room.nick,
        avatarUrl: room.avatar,
        liveStatus: liveStatus,
      ),
      area: area(),
      audience: RoomAudience(
        totalViewers: total,
        primaryMetric: total == null ? LiveAudienceMetricType.unknown : LiveAudienceMetricType.totalViewers,
      ),
      broadcast: RoomBroadcast(liveStatus: liveStatus, restriction: room.restriction),
      links: RoomLinks(webUrl: JdliveEndpoints.link(room.liveId)),
      runtime: RoomRuntime(
        danmakuHandle: withData && room.state == JdliveState.live && !room.appOnly
            ? JdliveDanmakuArgs(liveId: room.liveId)
            : null,
      ),
    );
  }

  /// The qualities of a playable [room]: HLS, then FLV, for a live one (only
  /// those with an address); the recording for a replay.
  static List<LivePlayQuality> qualities(JdliveBroadcast room) {
    if (room.state == JdliveState.replay) {
      return [
        if (room.recording != null)
          const LivePlayQuality(
            label: JdliveEndpoints.replayLabel,
            qualityId: JdliveEndpoints.replayId,
            platformOrder: 2,
          ),
      ];
    }
    var order = 0;
    return [
      for (final (label, id) in JdliveEndpoints.liveQualities)
        if ((id == JdliveEndpoints.hlsId ? room.hls : room.flv) != null)
          LivePlayQuality(label: label, qualityId: id, platformOrder: order++),
    ];
  }

  /// The line of quality [qualityId] of a playable [room]: a live one's
  /// playlist (HLS) or stream (FLV), a replay's recording (HLS); the host as
  /// line label, and the media headers. No lease: the addresses carry no
  /// signature or expiry. The codec is not written (the answer does not say
  /// it). A quality the room lacks is stream-unavailable; another quality is
  /// a caller error.
  static LivePlayLine line(JdliveBroadcast room, String qualityId) {
    final url = switch (qualityId) {
      JdliveEndpoints.hlsId => room.state == JdliveState.live ? room.hls : null,
      JdliveEndpoints.flvId => room.state == JdliveState.live ? room.flv : null,
      JdliveEndpoints.replayId => room.state == JdliveState.replay ? room.recording : null,
      _ => throw JdliveFailure(JdliveFailureKind.invalidArgument, 'quality "$qualityId" is not a JD Live quality'),
    };
    if (url == null) {
      throw JdliveFailure(JdliveFailureKind.streamUnavailable, '${room.liveId}: no $qualityId');
    }
    return LivePlayLine(
      url: '$url',
      format: JdliveEndpoints.formatOf(qualityId),
      formatSource: LivePlayFormatSource.declared,
      lineLabel: url.host,
      headers: JdliveEndpoints.mediaHeaders(room.liveId),
    );
  }

  // Readers of the site's shapes ----------------------------------------------

  /// A broadcast id: a number or text of 5–18 digits, not starting with 0.
  static String? _id(Object? value) {
    final text = switch (value) {
      final int number => '$number',
      final String text => text.trim(),
      _ => '',
    };
    return JdliveEndpoints.isLiveId(text) ? text : null;
  }

  /// A JD Cloud live stream of [extension], or null: https, `*.jdcloud.com`,
  /// port 443, no user info or fragment, under `/live/`, without spaces or
  /// control characters, at most 8192 characters. A value that is not text
  /// is no stream.
  static Uri? _media(Object? value, String extension) {
    final uri = _address(value);
    if (uri == null ||
        !_hostIs(uri.host, 'jdcloud.com') ||
        !uri.path.startsWith('/live/') ||
        !uri.path.toLowerCase().endsWith(extension)) {
      return null;
    }
    return uri;
  }

  /// A replay's recording, or null: an HLS playlist (`.m3u8`) on JD Cloud's
  /// video service (`*.300hu.com`), otherwise as [_media].
  static Uri? _recording(Object? value) {
    final uri = _address(value);
    if (uri == null || !_hostIs(uri.host, '300hu.com') || !uri.path.toLowerCase().endsWith('.m3u8')) {
      return null;
    }
    return uri;
  }

  /// An https address on the default port, without user info, fragment,
  /// spaces or control characters, at most 8192 characters; null otherwise.
  static Uri? _address(Object? value) {
    if (value is! String) return null;
    final raw = value.trim();
    if (raw.isEmpty || raw.length > 8192 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    return uri;
  }

  /// The stream key of a JD Cloud address: its file name without `.m3u8` or
  /// `.flv`.
  static String _streamKey(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return name.replaceFirst(RegExp(r'\.(?:m3u8|flv)$', caseSensitive: false), '');
  }

  /// A JD image: https on `*.360buyimg.com`, no user info or fragment; `''`
  /// for anything else. A value that is not text is api-changed (a list
  /// entry that cannot be read), or no image when [what] is null (the play
  /// answer's background).
  static String _image(Object? value, String? what) {
    final text = what == null
        ? (value is String && value.length <= 65536 ? value.trim() : '')
        : JdliveJson.optionalText(value, what);
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_hostIs(uri.host, '360buyimg.com')) {
      return '';
    }
    return '$uri';
  }

  static bool _hostIs(String host, String root) {
    final value = host.toLowerCase();
    return value == root || value.endsWith('.$root');
  }
}
