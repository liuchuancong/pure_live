import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
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
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_endpoints.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_json.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_link.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A user's LIVE state: `status` 2 is broadcasting, 4 is not broadcasting,
/// any other status (or none) is not known.
enum TiktokState {
  /// `status` 2: broadcasting.
  live,

  /// `status` 4: not broadcasting.
  offline,

  /// Any other `status`, or none.
  unknown,
}

/// One quality: a tier ([qualityId], the `stream_data` key) in one codec,
/// with its FLV and HLS URLs as lines that stand in for each other. Its
/// [id] `<codec>:<qualityId>` is the quality's id.
final class TiktokStream {
  /// Creates the stream.
  const TiktokStream({
    required this.id,
    required this.qualityId,
    required this.codec,
    this.flvUrls = const [],
    this.hlsUrls = const [],
    this.label = '',
    this.resolution = '',
    this.bitrate,
  });

  /// `h264:origin`.
  final String id;

  /// `origin`, `uhd_60`, `hd_60`, `uhd`, `hd`, `sd`, `ld`, `auto` or another
  /// key the site sends, lower case.
  final String qualityId;

  /// `h264` or `h265`.
  final String codec;

  /// The site's own name of the tier (`options.qualities[].name` of the
  /// container it came from: `720p`, `1080p60`, `Original`), else empty.
  final String label;

  /// `720x1280` or `720p` from `sdk_params`, else empty.
  final String resolution;

  /// `sdk_params.vbitrate`, bits per second.
  final int? bitrate;

  /// The FLV URLs, each once, in the order read (`streamData` before
  /// `hevcStreamData`).
  final List<Uri> flvUrls;

  /// The HLS URLs, likewise.
  final List<Uri> hlsUrls;

  /// Every URL, FLV first: the order of the lines.
  List<Uri> get urls => [...flvUrls, ...hlsUrls];
}

/// What a room's entry knows besides its card: the user behind the username,
/// the current LIVE and its streams. The username is the room (its stable
/// identity); the numeric LIVE room id changes with every broadcast.
final class TiktokRoomData {
  /// Creates the data.
  const TiktokRoomData({
    required this.username,
    required this.userId,
    required this.state,
    required this.issuedAt,
    this.status,
    this.restriction,
    this.secUid = '',
    this.liveRoomId = '',
    this.streamId = '',
    this.streams = const [],
    this.skipped = const [],
  });

  /// `user.uniqueId`, lower case: the room id.
  final String username;

  /// `user.id`, the account behind the username; empty when the site sends
  /// none that is valid.
  final String userId;

  /// `user.secUid`.
  final String secUid;

  /// `user.roomId`: the current (or last) LIVE room, the key of `share/live`
  /// links; empty when the site sends none.
  final String liveRoomId;

  /// `liveRoom.streamId`.
  final String streamId;

  /// The LIVE's state.
  final TiktokState state;

  /// `liveRoom.status` (else `user.status`) as sent.
  final int? status;

  /// Who may watch a live LIVE ([LiveRestriction.none] for everyone); null
  /// unless live.
  final LiveRestriction? restriction;

  /// The streams of a live, unrestricted LIVE, as read; empty otherwise.
  final List<TiktokStream> streams;

  /// What of the stream containers was skipped as malformed (a container, a
  /// tier or one URL, with the reason), for the error when nothing is left
  /// to play; empty when everything was read.
  final List<String> skipped;

  /// When the answer arrived: the start of the URLs' lifetime.
  final DateTime issuedAt;
}

/// Pure parsing of TikTok LIVE responses.
///
/// Two anonymous endpoints: a user's LIVE (`www.tiktok.com/api-live/user/
/// room`, `{statusCode, message, data: {user, stats, liveRoom}}`, the pull
/// URLs in JSON strings inside it) and a LIVE room's owner
/// (`webcast.tiktok.com/webcast/room/info`, `{status_code, data}`). There is
/// no anonymous directory, search or chat.
///
/// Answers are checked strictly where identity and playability depend on
/// them; fields that only fill the card (`nickname`, `title`, `signature`,
/// the stats, the long ids) lose themselves when malformed instead of
/// failing the answer.
abstract final class TiktokRoomParser {
  /// `api-live/user/room` for [username] (normalized).
  ///
  /// The answer must be that user (`uniqueId`), or it is api-changed;
  /// `statusCode` [TiktokEndpoints.missingUserCode] (or a message saying so)
  /// is not-found, any other code api-changed. The fields the state, the
  /// restriction and the streams depend on keep the strict checks (`secret`,
  /// `paidEvent`); the others no longer fail the answer when malformed.
  ///
  /// The card: the username as the room, `user.id` as the anchor id, the
  /// title (the nickname when empty; offline it is the last LIVE's), avatar
  /// and cover from trusted https hosts, the signature, the follower count
  /// and the state. While live (restricted or not) it also has `userCount`
  /// as viewers now, `enterCount` as cumulative entries, the start
  /// (`startTime`) and who may watch ([restrictionOf]). With [includeMedia]
  /// (room entry) `data` is the [TiktokRoomData] in the runtime handle and a
  /// live, unrestricted LIVE's streams are read; without it (search cards)
  /// nothing of them is read.
  static LiveRoom room(
    String body, {
    required String username,
    required bool includeMedia,
    required DateTime issuedAt,
    int status = 200,
  }) {
    const what = 'user/room';
    final root = TiktokJson.envelope(body, status: status, what: what);
    final code = TiktokJson.integer(root['statusCode']);
    if (code != 0) {
      final message = TiktokJson.optionalText(root['message'], '$what.message');
      final lower = message.toLowerCase();
      if (code == TiktokEndpoints.missingUserCode || lower.contains('not exist') || lower.contains('not_found')) {
        throw TiktokFailure(TiktokFailureKind.notFound, '$what: $username ($code $message)');
      }
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: statusCode $code $message');
    }
    final data = TiktokJson.object(root['data'], '$what.data');
    final user = TiktokJson.object(data['user'], '$what.data.user');
    final live = TiktokJson.object(data['liveRoom'], '$what.data.liveRoom');
    final actual = TiktokJson.username(user['uniqueId'], 'user.uniqueId');
    if (actual != username) {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: asked $username, got $actual');
    }

    final liveStatus = TiktokJson.integer(live['status'] ?? user['status']);
    final state = switch (liveStatus) {
      2 => TiktokState.live,
      4 => TiktokState.offline,
      _ => TiktokState.unknown,
    };
    final isLive = state == TiktokState.live;
    // Checked in every state; kept only while live.
    final restriction = restrictionOf(user, live);
    final stats = TiktokJson.lenientObject(data['stats']);
    final roomStats = TiktokJson.lenientObject(live['liveRoomStats']);
    final nickname = TiktokJson.lenientText(user['nickname']);
    final title = TiktokJson.lenientText(live['title']);
    final userId = TiktokJson.lenientLongId(user['id']);
    final followers = TiktokJson.lenientCount(stats['followerCount']);
    final online = isLive ? TiktokJson.lenientCount(roomStats['userCount']) : null;
    final entered = isLive ? TiktokJson.lenientCount(roomStats['enterCount']) : null;
    final signature = TiktokJson.lenientText(user['signature']);
    final avatar = TiktokJson.image([user['avatarLarger'], user['avatarMedium'], user['avatarThumb']]);
    final read = isLive && includeMedia && restriction == LiveRestriction.none ? _streams(live) : null;
    final handle = TiktokRoomData(
      username: username,
      userId: userId,
      secUid: TiktokJson.lenientText(user['secUid']),
      liveRoomId: TiktokJson.lenientLongId(user['roomId']),
      streamId: TiktokJson.lenientLongId(live['streamId']),
      state: state,
      status: liveStatus,
      restriction: isLive ? restriction : null,
      streams: read?.streams ?? const [],
      skipped: read?.skipped ?? const [],
      issuedAt: issuedAt,
    );
    return LiveRoom.normalized(
      platform: tiktokSiteId,
      roomId: username,
      content: RoomContent(
        title: title.isEmpty ? nickname : title,
        coverUrl: TiktokJson.image([live['coverUrl'], live['squareCoverImg']]),
        introduction: signature.isEmpty ? null : signature,
        notice: TiktokEndpoints.chatNotice,
      ),
      anchor: LiveAnchor.normalized(
        platform: tiktokSiteId,
        anchorId: userId,
        name: nickname,
        avatarUrl: avatar.isEmpty ? null : avatar,
        followerCount: followers,
        introduction: signature.isEmpty ? null : signature,
        liveStatus: switch (state) {
          TiktokState.live => LiveStatus.live,
          TiktokState.offline => LiveStatus.offline,
          TiktokState.unknown => LiveStatus.unknown,
        },
      ),
      audience: RoomAudience(
        onlineViewers: online,
        totalViewers: entered,
        primaryMetric: isLive ? LiveAudienceMetricType.onlineViewers : LiveAudienceMetricType.unknown,
      ),
      broadcast: RoomBroadcast(
        liveStatus: switch (state) {
          TiktokState.live => LiveStatus.live,
          TiktokState.offline => LiveStatus.offline,
          TiktokState.unknown => LiveStatus.unknown,
        },
        startedAt: isLive ? TiktokJson.startTime(live['startTime']) : null,
        restriction: isLive ? restriction : null,
      ),
      links: RoomLinks(webUrl: TiktokEndpoints.roomUrl(username)),
      runtime: includeMedia ? RoomRuntime(streamHandle: handle) : const RoomRuntime(),
    );
  }

  /// Who may watch the LIVE of [user] ([live] its `liveRoom`), in order: a
  /// private account (`user.secret`) is for its followers
  /// ([LiveRestriction.private]), `liveSubOnly` 1 for subscribers
  /// ([LiveRestriction.subscribersOnly]), `paidEvent.paid_type` above 0 is a
  /// paid LIVE ([LiveRestriction.paid]); else [LiveRestriction.none].
  /// `secret` must be a boolean and `paidEvent` an object (or absent, null,
  /// an empty list); anything else is api-changed.
  static LiveRestriction restrictionOf(Map<String, dynamic> user, Map<String, dynamic> live) {
    final paidValue = live['paidEvent'];
    final paid = paidValue == null || (paidValue is List && paidValue.isEmpty)
        ? const <String, dynamic>{}
        : TiktokJson.object(paidValue, 'liveRoom.paidEvent');
    final secret = TiktokJson.optionalBool(user['secret'], 'user.secret') ?? false;
    if (secret) return LiveRestriction.private;
    if (TiktokJson.integer(live['liveSubOnly']) == 1) return LiveRestriction.subscribersOnly;
    if ((TiktokJson.integer(paid['paid_type']) ?? 0) > 0) return LiveRestriction.paid;
    return LiveRestriction.none;
  }

  /// `webcast/room/info`: the username owning LIVE room [liveRoomId]
  /// (`data.owner.display_id`). A `status_code` other than 0 is not-found;
  /// an answer about another LIVE room, or without a username, is
  /// api-changed.
  static String owner(String body, {required String liveRoomId, int status = 200}) {
    const what = 'room/info';
    final root = TiktokJson.envelope(body, status: status, what: what);
    final code = TiktokJson.integer(root['status_code']);
    if (code != 0) {
      throw TiktokFailure(TiktokFailureKind.notFound, '$what: LIVE room $liveRoomId (status_code $code)');
    }
    final data = TiktokJson.object(root['data'], '$what.data');
    final id = TiktokJson.longId(data['id'], '$what.data.id');
    if (id != liveRoomId) {
      throw TiktokFailure(TiktokFailureKind.apiChanged, '$what: asked $liveRoomId, got $id');
    }
    return TiktokJson.username(TiktokJson.object(data['owner'], '$what.data.owner')['display_id'], 'owner.display_id');
  }

  /// The username the page a short link landed on names: the canonical or
  /// `og:url` address (`https://www.tiktok.com/@<user>/…`), else the page's
  /// hydration state (`"uniqueId":"<user>"`); null when neither is there.
  /// An answer that is refused, over the limit or empty fails as an API
  /// answer would.
  static String? usernameInPage(String body, {int status = 200}) {
    TiktokJson.checkBody(body, 'short link', status);
    if (body.isEmpty) {
      throw const TiktokFailure(TiktokFailureKind.riskControl, 'short link: empty answer');
    }
    for (final match in _canonicalAddress.allMatches(body)) {
      final user = _userInAddress(match.group(1)!);
      if (user != null) return user;
    }
    for (final match in _uniqueId.allMatches(body)) {
      final user = TiktokLink.normalizeUsername(match.group(1)!);
      if (user != null) return user;
    }
    return null;
  }

  static final RegExp _canonicalAddress = RegExp(
    r'(?:rel|property)\s*=\s*"(?:canonical|og:url)"[^>]*?(?:href|content)\s*=\s*"([^"]+)"',
    caseSensitive: false,
  );
  static final RegExp _uniqueId = RegExp(r'"uniqueId"\s*:\s*"([a-zA-Z0-9._]{1,24})"');

  /// The username an address on the site names (`…/@<user>/…`), or null.
  static String? _userInAddress(String address) {
    final uri = Uri.tryParse(address);
    if (uri == null) return null;
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty || !segments.first.startsWith('@')) return null;
    return TiktokLink.normalizeUsername(segments.first.substring(1));
  }

  /// Why the LIVE [data] describes cannot be played, or null when it can:
  /// a state not known, or offline, is stream-unavailable; so is a live
  /// restricted one (the app has no TikTok account, so no login would help),
  /// and a live one without a stream — api-changed when streams were sent
  /// but none could be read ([TiktokRoomData.skipped]).
  static TiktokFailure? unplayable(TiktokRoomData data) {
    final who = '@${data.username}';
    return switch (data.state) {
      TiktokState.unknown => TiktokFailure(
        TiktokFailureKind.streamUnavailable,
        '$who: status ${data.status} not known',
      ),
      TiktokState.offline => TiktokFailure(TiktokFailureKind.streamUnavailable, '$who is offline'),
      TiktokState.live => switch (data.restriction ?? LiveRestriction.none) {
        LiveRestriction.private => TiktokFailure(
          TiktokFailureKind.streamUnavailable,
          "$who: a private account's LIVE, for its followers only",
        ),
        LiveRestriction.subscribersOnly => TiktokFailure(
          TiktokFailureKind.streamUnavailable,
          '$who: a LIVE for subscribers only',
        ),
        LiveRestriction.paid => TiktokFailure(TiktokFailureKind.streamUnavailable, '$who: a paid LIVE'),
        LiveRestriction.none when data.streams.isEmpty && data.skipped.isNotEmpty => TiktokFailure(
          TiktokFailureKind.apiChanged,
          '$who: no stream could be read (${data.skipped.join('; ')})',
        ),
        LiveRestriction.none when data.streams.isEmpty => TiktokFailure(
          TiktokFailureKind.streamUnavailable,
          '$who: live without a stream',
        ),
        LiveRestriction.none => null,
        _ => TiktokFailure(
          TiktokFailureKind.streamUnavailable,
          '$who: ${(data.restriction ?? LiveRestriction.none).name}',
        ),
      },
    };
  }

  // Streams -------------------------------------------------------------------

  /// The qualities of [data], one per tier and codec, named by
  /// [qualityName]. With [preferH264] every H.264 quality comes first, best
  /// first, then the H.265 ones, so the default is H.264 and H.265 is only
  /// picked by hand; off, best tier first, H.264 before H.265 within a tier.
  /// A name used twice gets its tier key.
  static List<LivePlayQuality> qualities(TiktokRoomData data, {bool preferH264 = true}) {
    final ordered = [...data.streams]
      ..sort(
        (a, b) => switch (qualitySort(b).compareTo(qualitySort(a))) {
          0 => a.id.compareTo(b.id),
          final rank => rank,
        },
      );
    final streams = preferH264
        ? [
            for (final stream in ordered)
              if (stream.codec == 'h264') stream,
            for (final stream in ordered)
              if (stream.codec != 'h264') stream,
          ]
        : ordered;
    final names = [for (final stream in streams) qualityName(stream)];
    return List.unmodifiable([
      for (final (index, stream) in streams.indexed)
        LivePlayQuality(
          label: names.where((name) => name == names[index]).length > 1
              ? '${names[index]} (${stream.qualityId})'
              : names[index],
          qualityId: stream.id,
          platformOrder: qualitySort(stream),
          codec: stream.codec == 'h264' ? LiveStreamCodec.avc : LiveStreamCodec.hevc,
        ),
    ]);
  }

  /// A stream's quality name: [TiktokEndpoints.originName] for `origin`, else
  /// the site's own name ([TiktokStream.label]: `720p`, `1080p60`), else one
  /// made the site's way from the resolution (`720x1280` → `720p`, and `60`
  /// for a `_60` tier), else the table [TiktokEndpoints.qualityNames], else
  /// the key upper case; H.265 adds the H.265 suffix.
  static String qualityName(TiktokStream stream) {
    final tier = stream.qualityId;
    final base = tier == 'origin'
        ? TiktokEndpoints.originName
        : stream.label.isNotEmpty
        ? stream.label
        : _resolutionName(stream.resolution, frames60: tier.endsWith('_60')) ??
              TiktokEndpoints.qualityNames[tier] ??
              tier.toUpperCase();
    return stream.codec == 'h264' ? base : '$base${TiktokEndpoints.h265Suffix}';
  }

  /// `720x1280` or `720p` as the site names it (`720p`, `720p60`); null for
  /// no resolution.
  static String? _resolutionName(String resolution, {required bool frames60}) {
    final String lines;
    if (RegExp(r'^[0-9]+p$').hasMatch(resolution)) {
      lines = resolution.substring(0, resolution.length - 1);
    } else if (RegExp(r'^([0-9]+)x([0-9]+)$').firstMatch(resolution) case final match?) {
      final (width, height) = (int.parse(match[1]!), int.parse(match[2]!));
      lines = '${width < height ? width : height}';
    } else {
      return null;
    }
    return '${lines}p${frames60 ? '60' : ''}';
  }

  /// The rank of the tier (origin 10000 … auto 3000, others 1000), plus 100
  /// for H.264: best first, H.264 before H.265 within a tier.
  static int qualitySort(TiktokStream stream) {
    final tier = switch (stream.qualityId) {
      'origin' => 10000,
      'uhd_60' => 9000,
      'hd_60' => 8000,
      'uhd' => 7000,
      'hd' => 6000,
      'sd' => 5000,
      'ld' => 4000,
      'auto' => 3000,
      _ => 1000,
    };
    return tier + (stream.codec == 'h264' ? 100 : 0);
  }

  /// The quality id for a stored one: the per-protocol ids of the previous
  /// generation (`<codec>:<tier>:<flv|hls>`, e.g. `h264:origin:flv`) are now
  /// the lines of `<codec>:<tier>`. Any other id is kept (trimmed); applying
  /// it twice changes nothing.
  static String qualityIdFromLegacy(String id) {
    final value = id.trim();
    final match = _legacyQualityId.firstMatch(value);
    return match == null ? value : '${match[1]!.toLowerCase()}:${match[2]!.toLowerCase()}';
  }

  static final RegExp _legacyQualityId = RegExp(r'^(h26[45]):([a-z0-9_]{1,24}):(?:flv|hls)$', caseSensitive: false);

  /// The lines of [quality] in [data] (null is the best one; a stored
  /// per-protocol id is read through [qualityIdFromLegacy]): FLV then HLS,
  /// each with the media headers of the room, the protocol's format, the
  /// codec, `flv` or `hls` as the line label (`flv#2` for a second FLV URL)
  /// and the lease of the URL's `expire`. A LIVE that cannot play says so; a
  /// quality [data] does not offer is stream-unavailable.
  static List<LivePlayLine> lines(TiktokRoomData data, LivePlayQuality? quality, {bool preferH264 = true}) {
    final blocked = unplayable(data);
    if (blocked != null) throw blocked;
    final TiktokStream stream;
    if (quality == null) {
      // The default is the head of the offered list under the current
      // preference (the H.264 best tier while "prefer H.264" is on).
      final top = qualities(data, preferH264: preferH264).first;
      stream = data.streams.firstWhere((candidate) => candidate.id == top.qualityId);
    } else {
      final id = qualityIdFromLegacy(quality.qualityId ?? '');
      final found = data.streams.where((candidate) => candidate.id == id).firstOrNull;
      if (found == null) {
        throw TiktokFailure(TiktokFailureKind.streamUnavailable, '@${data.username}: quality $id is not offered');
      }
      stream = found;
    }
    final headers = TiktokEndpoints.mediaHeaders(data.username);
    final codec = stream.codec == 'h264' ? LiveStreamCodec.avc : LiveStreamCodec.hevc;
    final lines = <LivePlayLine>[];
    void add(String protocol, LiveStreamFormat format, List<Uri> urls) {
      for (final (index, url) in urls.indexed) {
        lines.add(
          LivePlayLine(
            url: '$url',
            format: format,
            formatSource: LivePlayFormatSource.declared,
            headers: headers,
            codec: codec,
            lineLabel: index == 0 ? protocol : '$protocol#${index + 1}',
            lease: lease(url, data.issuedAt),
          ),
        );
      }
    }

    add('flv', LiveStreamFormat.flv, stream.flvUrls);
    add('hls', LiveStreamFormat.hls, stream.hlsUrls);
    return lines;
  }

  /// The lease of a pull URL received at [issuedAt], from its `expire` (Unix
  /// seconds; the site signs for about 14 days): renewed the lead
  /// ([TiktokEndpoints.leaseLead], at most a quarter of the lifetime) before
  /// its end. Expiry does not cut an established FLV connection, but an HLS
  /// playlist must be fetched again, so only an HLS line says so. No
  /// `expire`, or one already past, is no lease.
  static LivePlayLease? lease(Uri url, DateTime issuedAt) {
    final expire = int.tryParse(url.queryParameters['expire'] ?? '');
    if (expire == null || expire <= 0) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expire * 1000, isUtc: true);
    final lifetime = expiresAt.difference(issuedAt);
    if (lifetime <= Duration.zero) return null;
    final quarter = lifetime ~/ 4;
    final lead = quarter < TiktokEndpoints.leaseLead ? quarter : TiktokEndpoints.leaseLead;
    return LivePlayLease(
      refreshAt: expiresAt.subtract(lead),
      expiresAt: expiresAt,
      requiresReconnect: url.path.endsWith('.m3u8'),
    );
  }

  /// The reading of `streamData` (codec H.264 unless `sdk_params` says) then
  /// `hevcStreamData` (H.265 unless it says): `pull_data.stream_data` is JSON
  /// in a string, its `data` maps at most 32 tier keys to `main` with `flv`
  /// and `hls` URLs and `sdk_params` (JSON in a string again); the
  /// container's `pull_data.options.qualities` name the tiers (`sdk_key` →
  /// `name`). The audio-only `ao` is left out; a tier of the same codec in
  /// both containers is one stream.
  ///
  /// A malformed part only loses itself: a container that does not decode, a
  /// tier with a bad key, `main`, `sdk_params` or codec, one URL that is no
  /// string or not a TikTok media URL — each is noted in `skipped`.
  static ({List<TiktokStream> streams, List<String> skipped}) _streams(Map<String, dynamic> live) {
    final builders = <String, _StreamBuilder>{};
    final skipped = <String>[];
    for (final (key, fallback) in const [('streamData', 'h264'), ('hevcStreamData', 'h265')]) {
      final value = live[key];
      if (value == null) continue;
      final Map<String, dynamic> tiers;
      final Map<String, String> labels;
      try {
        final pull = TiktokJson.object(TiktokJson.object(value, 'liveRoom.$key')['pull_data'], '$key.pull_data');
        final raw = TiktokJson.optionalText(pull['stream_data'], '$key.stream_data');
        if (raw.isEmpty || raw.length > TiktokEndpoints.streamDataLimit) continue;
        tiers = TiktokJson.object(
          TiktokJson.object(TiktokJson.decode(raw, '$key.stream_data'), '$key.stream_data')['data'],
          '$key.data',
        );
        if (tiers.length > 32) {
          throw TiktokFailure(TiktokFailureKind.apiChanged, '$key: ${tiers.length} tiers');
        }
        labels = _labels(pull['options']);
      } on TiktokFailure catch (error) {
        skipped.add(error.message);
        continue;
      }
      for (final entry in tiers.entries) {
        final String tier;
        final String codec;
        final Map<String, dynamic> main;
        final Map<String, dynamic> sdk;
        try {
          tier = TiktokJson.tier(entry.key, key);
          if (tier == 'ao') continue;
          main = TiktokJson.object(TiktokJson.object(entry.value, '$key.$tier')['main'], '$key.$tier.main');
          final sdkRaw = TiktokJson.optionalText(main['sdk_params'], '$key.$tier.sdk_params');
          sdk = sdkRaw.isEmpty
              ? const <String, dynamic>{}
              : TiktokJson.object(TiktokJson.decode(sdkRaw, '$key.$tier.sdk_params'), '$key.$tier.sdk_params');
          codec = TiktokJson.codec(sdk['VCodec'] ?? sdk['v_codec'], fallback, '$key.$tier');
        } on TiktokFailure catch (error) {
          skipped.add(error.message);
          continue;
        }
        for (final protocol in const ['flv', 'hls']) {
          final Uri url;
          try {
            final text = TiktokJson.optionalText(main[protocol], '$key.$tier.$protocol');
            if (text.isEmpty) continue;
            url = TiktokJson.mediaUrl(text, '$key.$tier.$protocol');
          } on TiktokFailure catch (error) {
            skipped.add(error.message);
            continue;
          }
          final id = '$codec:$tier';
          final builder = builders.putIfAbsent(id, () => _StreamBuilder(id: id, tier: tier, codec: codec));
          if (builder.label.isEmpty) builder.label = labels[tier] ?? '';
          if (builder.resolution.isEmpty) builder.resolution = TiktokJson.resolution(sdk['resolution']);
          builder.bitrate ??= TiktokJson.lenientCount(sdk['vbitrate']);
          final urls = protocol == 'flv' ? builder.flv : builder.hls;
          if (!urls.contains(url)) urls.add(url);
        }
      }
    }
    final streams = [
      for (final builder in builders.values)
        TiktokStream(
          id: builder.id,
          qualityId: builder.tier,
          codec: builder.codec,
          label: builder.label,
          resolution: builder.resolution,
          bitrate: builder.bitrate,
          flvUrls: List.unmodifiable(builder.flv),
          hlsUrls: List.unmodifiable(builder.hls),
        ),
    ];
    return (streams: List.unmodifiable(streams), skipped: List.unmodifiable(skipped));
  }

  /// A container's tier names: `options.qualities[]` as `sdk_key` (lower
  /// case) → `name` (trimmed, at most 32 characters). Entries of another
  /// shape are passed over.
  static Map<String, String> _labels(Object? options) {
    final listed = options is Map ? options['qualities'] : null;
    return {
      if (listed is List)
        for (final item in listed)
          if (item is Map)
            if ((item['sdk_key'], item['name']) case (final String key, final String name)
                when key.trim().isNotEmpty && name.trim().isNotEmpty && name.trim().length <= 32)
              key.trim().toLowerCase(): name.trim(),
    };
  }
}

final class _StreamBuilder {
  _StreamBuilder({required this.id, required this.tier, required this.codec});

  final String id;
  final String tier;
  final String codec;
  String label = '';
  String resolution = '';
  int? bitrate;
  final List<Uri> flv = [];
  final List<Uri> hls = [];
}
