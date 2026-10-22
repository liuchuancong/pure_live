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
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/weibo/api/weibo_endpoints.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_failure.dart';
import 'package:live_sites/src/platforms/weibo/parsers/weibo_json.dart';
import 'package:live_sites/src/platforms/weibo/weibo_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Who may watch a broadcast (the reference's `WeiboAccess`).
enum WeiboAccess {
  /// Anyone: the answer carries the media URLs of a live broadcast or the
  /// recording of a replay.
  public,

  /// `watch_limit` is not 0 (friends of the anchor only, the anchor only,
  /// paid, app only): the answer carries no media URL.
  restricted,

  /// `play_switch` is 0: playback is switched off.
  disabled,
}

/// What a room's detail knows besides its broadcast id: the anchor and the
/// fields that decide whether it plays. Every broadcast has its own id (the
/// room identity); the anchor's uid is no room. It is the playback handle the
/// site keeps for the room.
final class WeiboRoomData {
  /// Creates the data.
  const WeiboRoomData({
    required this.ownerId,
    required this.status,
    required this.watchLimit,
    required this.access,
    this.mediaUrls = const [],
    this.replayUrl,
    this.tip,
  });

  /// `user.uid`: the anchor (the room's userId). A fresh answer for the same
  /// broadcast must name the same anchor.
  final int ownerId;

  /// `status` as the platform wrote it: 0 announced (the web page counts
  /// down), 1 live, 3 ended with a replay, 5 ended; anything else is not
  /// known.
  final int status;

  /// `watch_limit`: 0 for a public broadcast; see
  /// [WeiboRoomParser.restrictionOfLimit].
  final int watchLimit;

  /// Who may watch.
  final WeiboAccess access;

  /// The media URLs of a public live broadcast (FLV first), empty otherwise.
  /// Only room entry reads them; every live playback asks again.
  final List<String> mediaUrls;

  /// The recording of a public replay (`replay_origin_url`, an HLS VOD, made
  /// https as the web player does), null otherwise.
  final String? replayUrl;

  /// The platform's explanation of a restriction (`pay_dialog_info.buy_tip`,
  /// such as 本场直播只有主播的好友可观看), null without one.
  final String? tip;
}

/// Pure parsing of Weibo Live (微博直播) responses: the recommendation
/// snapshot, the broadcast detail, the nickname search over the snapshot, the
/// restriction gates and the play lines.
///
/// The site has two anonymous endpoints under `weibo.com/l/!/2/wblive/`: the
/// snapshot `pc_recommend/list.json` (no paging, no audience; only
/// broadcasts on air) and the broadcast `room/show_pc_live.json`
/// (`{code: 100000, error_code: 0, data}`). Failures are [WeiboFailure]s; a
/// broken row of the snapshot only drops that row, but a bad envelope, an
/// answer about another broadcast or a list that is not a list is api-changed
/// — a changed API is never shown as an empty directory.
abstract final class WeiboRoomParser {
  // Directory -----------------------------------------------------------------

  /// `pc_recommend`: the snapshot as the one page it is (3.x: no more).
  ///
  /// Each row is the reference's card: the broadcast id as the room, the
  /// anchor's uid, the nickname (HTML references decoded, 18-7) as title, the
  /// cover, no audience, live (18-2: the snapshot lists broadcasts on air
  /// only) and the scope notice. It does not tell restrictions, so the card's
  /// restriction is not provided (null).
  ///
  /// A bad row is skipped (18-8): not an object, without a usable broadcast
  /// id, or a broadcast listed before; a uid that is no positive integer
  /// leaves the card without an anchor, a nickname that is no string leaves
  /// it empty. A list that is no list, has over [WeiboEndpoints.maxRecommendRows]
  /// rows, or has rows but none usable fails the snapshot (api-changed).
  static List<LiveRoom> snapshot(String body, {int status = 200}) {
    const what = 'pc_recommend';
    final rows = WeiboJson.data(body, what: what, status: status)['data'];
    if (rows is! List || rows.length > WeiboEndpoints.maxRecommendRows) {
      throw const WeiboFailure(WeiboFailureKind.apiChanged, 'pc_recommend: data.data is not a list');
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final id = row['liveid'];
      if (id is! String || !WeiboEndpoints.isLiveId(id) || !seen.add(id)) continue;
      final nick = WeiboJson.text(row['nickname']);
      final uid = WeiboJson.uidOrNull(row['uid']);
      rooms.add(
        LiveRoom.normalized(
          platform: weiboSiteId,
          roomId: id,
          content: RoomContent(
            title: nick,
            coverUrl: normalizeImageUrl(row['cover']),
            notice: WeiboEndpoints.roomScopeNotice,
          ),
          anchor: uid == null ? null : LiveAnchor.normalized(platform: weiboSiteId, anchorId: '$uid', name: nick),
          audience: const RoomAudience(primaryMetric: LiveAudienceMetricType.unknown),
          broadcast: const RoomBroadcast(liveStatus: LiveStatus.live),
          links: RoomLinks(webUrl: WeiboEndpoints.roomUrl(id)),
        ),
      );
    }
    if (rooms.isEmpty && rows.isNotEmpty) {
      throw const WeiboFailure(WeiboFailureKind.apiChanged, 'pc_recommend: no usable row');
    }
    return rooms;
  }

  /// The reference's nickname search: [rooms] (the snapshot) whose nickname
  /// contains [keyword] (trimmed, case ignored), the first [pageSize]. There
  /// is no server search and no second page.
  static List<LiveRoom> searchSnapshot(String keyword, Iterable<LiveRoom> rooms, {required int pageSize}) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return List.unmodifiable(rooms.where((room) => room.content.title.toLowerCase().contains(query)).take(pageSize));
  }

  // Rooms ---------------------------------------------------------------------

  /// `show_pc_live`: broadcast [liveId], under that id.
  ///
  /// The answer must be that broadcast (`liveId`), of an anchor (`user.uid`,
  /// [ownerId] when given), with integer `status` and `watch_limit` and a 0/1
  /// `play_switch`, or it is api-changed; the missing code is not-found.
  /// Fields it does not use are not checked (18-8: `width`, `height`,
  /// `pay_live_status`); a title or nickname that is no string is empty.
  ///
  /// The state: `status` 1 is live, 3 a replay, 5 offline (18-3), anything
  /// else unknown. A restricted or switched-off broadcast keeps its state
  /// (18-4), carries the restriction ([restrictionOf]) and a notice line, and
  /// plays nothing. Only a public live broadcast reads its media URLs
  /// (`live_origin_flv_url`, then `live_origin_hls_url`, which usually repeats
  /// the FLV), each once; only a public replay reads its recording
  /// (`replay_origin_url`, 18-5).
  ///
  /// Also: the 1024 px `avatar` before the 50 px `profileImageUrl` (18-6);
  /// title and nickname with HTML references decoded (18-7); the start
  /// (`startTime`, epoch milliseconds) while live; no audience; and the
  /// answer as the room's stream handle ([WeiboRoomData]).
  static LiveRoom detail(String body, {required String liveId, int? ownerId, int status = 200}) {
    const what = 'show_pc_live';
    final item = WeiboJson.data(body, what: what, status: status, missing: true);
    final id = WeiboJson.liveId(item['liveId'], 'show_pc_live.liveId');
    final user = WeiboJson.object(item['user'], 'show_pc_live.user');
    final owner = WeiboJson.uid(user['uid'], 'show_pc_live.user.uid');
    if (id != liveId) throw WeiboFailure(WeiboFailureKind.apiChanged, 'show_pc_live: asked $liveId, got $id');
    if (ownerId != null && owner != ownerId) {
      throw WeiboFailure(WeiboFailureKind.apiChanged, 'show_pc_live: $id of $owner, not of $ownerId');
    }
    final state = WeiboJson.count(item['status'], 'show_pc_live.status');
    final limit = WeiboJson.count(item['watch_limit'], 'show_pc_live.watch_limit');
    final enabled = WeiboJson.flag(item['play_switch'], 'show_pc_live.play_switch');
    final access = enabled == 0
        ? WeiboAccess.disabled
        : limit != 0
        ? WeiboAccess.restricted
        : WeiboAccess.public;
    final liveStatus = switch (state) {
      WeiboEndpoints.liveStatusCode => LiveStatus.live,
      WeiboEndpoints.replayStatusCode => LiveStatus.replay,
      WeiboEndpoints.endedStatusCode => LiveStatus.offline,
      _ => LiveStatus.unknown,
    };
    final public = access == WeiboAccess.public;
    final urls = <String>{
      if (public && state == WeiboEndpoints.liveStatusCode)
        for (final key in const ['live_origin_flv_url', 'live_origin_hls_url']) ?WeiboJson.mediaUrl(item[key]),
    };
    final dialog = item['pay_dialog_info'];
    String? tip;
    if (access == WeiboAccess.restricted && dialog is Map) {
      final value = dialog['buy_tip'];
      tip = value is String ? value : null;
    }
    final roomData = WeiboRoomData(
      ownerId: owner,
      status: state,
      watchLimit: limit,
      access: access,
      mediaUrls: List.unmodifiable(urls),
      replayUrl: public && state == WeiboEndpoints.replayStatusCode
          ? WeiboJson.replayUrl(item['replay_origin_url'])
          : null,
      tip: tip,
    );
    final avatar = normalizeImageUrl(user['avatar']);
    return LiveRoom.normalized(
      platform: weiboSiteId,
      roomId: id,
      content: RoomContent(
        title: WeiboJson.text(item['title']),
        coverUrl: normalizeImageUrl(item['cover']),
        notice: [
          if (access == WeiboAccess.restricted) WeiboEndpoints.restrictedNotice,
          if (access == WeiboAccess.disabled) WeiboEndpoints.disabledNotice,
          WeiboEndpoints.roomScopeNotice,
        ].join('\n'),
      ),
      anchor: LiveAnchor.normalized(
        platform: weiboSiteId,
        anchorId: '$owner',
        name: WeiboJson.text(user['screenName']),
        avatarUrl: avatar.isNotEmpty ? avatar : normalizeImageUrl(user['profileImageUrl']),
      ),
      audience: const RoomAudience(primaryMetric: LiveAudienceMetricType.unknown),
      broadcast: RoomBroadcast(
        liveStatus: liveStatus,
        startedAt: state == WeiboEndpoints.liveStatusCode ? WeiboJson.startedAt(item['startTime']) : null,
        restriction: restrictionOf(roomData),
      ),
      links: RoomLinks(webUrl: WeiboEndpoints.roomUrl(id)),
      runtime: RoomRuntime(streamHandle: roomData),
    );
  }

  /// The kind of a `watch_limit` that is not 0: [WeiboEndpoints.appOnlyLimit]
  /// app only, friends-only and self-only private, paid paid; another value
  /// (9 was seen, without a text) is unplayable, the kind kept for a
  /// restriction that cannot be told apart.
  static LiveRestriction restrictionOfLimit(int watchLimit) => switch (watchLimit) {
    WeiboEndpoints.appOnlyLimit => LiveRestriction.appOnly,
    WeiboEndpoints.friendsOnlyLimit || WeiboEndpoints.selfOnlyLimit => LiveRestriction.private,
    WeiboEndpoints.paidLimit => LiveRestriction.paid,
    _ => LiveRestriction.unplayable,
  };

  /// The restriction of a live broadcast or a replay, null for any other
  /// state (not provided):
  /// - restricted: [restrictionOfLimit];
  /// - playback switched off: unplayable;
  /// - public: none, or unplayable when a live broadcast has no media URL or
  ///   a replay no recording.
  static LiveRestriction? restrictionOf(WeiboRoomData data) {
    if (data.status != WeiboEndpoints.liveStatusCode && data.status != WeiboEndpoints.replayStatusCode) return null;
    return switch (data.access) {
      WeiboAccess.restricted => restrictionOfLimit(data.watchLimit),
      WeiboAccess.disabled => LiveRestriction.unplayable,
      WeiboAccess.public =>
        (data.status == WeiboEndpoints.liveStatusCode ? data.mediaUrls.isNotEmpty : data.replayUrl != null)
            ? LiveRestriction.none
            : LiveRestriction.unplayable,
    };
  }

  /// Why the broadcast [data] describes cannot be played, or null when it can
  /// (then [qualityOf] is its quality). Every reason is stream-unavailable,
  /// with the reason in the message:
  /// - ended (5) or a state that is not known;
  /// - restricted (the kind and the platform's text) or switched off;
  /// - live without a media URL, a replay without a recording.
  static WeiboFailure? unplayable(WeiboRoomData data) {
    if (data.status == WeiboEndpoints.endedStatusCode) {
      return const WeiboFailure(WeiboFailureKind.streamUnavailable, 'the broadcast has ended');
    }
    if (data.status != WeiboEndpoints.liveStatusCode && data.status != WeiboEndpoints.replayStatusCode) {
      return WeiboFailure(WeiboFailureKind.streamUnavailable, 'status ${data.status}');
    }
    if (data.access == WeiboAccess.restricted) {
      final kind = restrictionOfLimit(data.watchLimit).name;
      final tip = data.tip == null ? '' : ': ${data.tip}';
      return WeiboFailure(
        WeiboFailureKind.streamUnavailable,
        'restricted broadcast ($kind, watch_limit ${data.watchLimit})$tip',
      );
    }
    if (data.access == WeiboAccess.disabled) {
      return const WeiboFailure(WeiboFailureKind.streamUnavailable, 'play_switch 0');
    }
    if (data.status == WeiboEndpoints.liveStatusCode && data.mediaUrls.isEmpty) {
      return const WeiboFailure(WeiboFailureKind.streamUnavailable, 'live without a media URL');
    }
    if (data.status == WeiboEndpoints.replayStatusCode && data.replayUrl == null) {
      return const WeiboFailure(WeiboFailureKind.streamUnavailable, 'an ended broadcast without a replay');
    }
    return null;
  }

  /// The one quality the broadcast [data] plays: [WeiboEndpoints.original]
  /// live, [WeiboEndpoints.replay] for a replay; null when it plays nothing
  /// ([unplayable]).
  static LivePlayQuality? qualityOf(WeiboRoomData data) {
    if (unplayable(data) != null) return null;
    return data.status == WeiboEndpoints.liveStatusCode ? WeiboEndpoints.original : WeiboEndpoints.replay;
  }

  // Streams -------------------------------------------------------------------

  /// The line of media [url]: no headers (the player and the recorder send
  /// their own defaults), the format by extension (`.flv`, `.m3u8`; the HLS
  /// field usually holds the FLV; anything else the unknown container), the
  /// codec of the stream name (`…_wb720avc.flv` is H.264, checked in the FLV
  /// header), the first path segment (`alicdn`) as the line label, else the
  /// host. The URLs carry no signature or expiry: no lease, and the same
  /// address can be re-opened.
  static LivePlayLine line(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final name = segments.isEmpty ? '' : segments.last.toLowerCase();
    return LivePlayLine(
      url: url,
      format: path.endsWith('.flv')
          ? LiveStreamFormat.flv
          : path.endsWith('.m3u8')
          ? LiveStreamFormat.hls
          : LiveStreamFormat.other,
      formatSource: LivePlayFormatSource.inferred,
      codec: name.contains('hevc') || name.contains('h265')
          ? LiveStreamCodec.hevc
          : name.contains('avc')
          ? LiveStreamCodec.avc
          : null,
      lineLabel: segments.length > 1 ? segments.first : uri.host,
    );
  }

  /// The lines of the live broadcast's media [urls] (one per URL, FLV first;
  /// the site has one stream, so the list usually repeats it in two
  /// containers).
  static List<LivePlayLine> lines(Iterable<String> urls) => [for (final url in urls) line(url)];

  /// The one line of a replay's recording [url]: an unsigned HLS VOD
  /// (`#EXT-X-ENDLIST`) without headers or lease.
  static List<LivePlayLine> replayLines(String url) => [line(url)];
}
