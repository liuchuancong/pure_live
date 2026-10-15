import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_urls.dart';
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
import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What an answer says about a broadcast (the reference's `LiveMeState`):
/// `online` 1 with `status` 0 and `roomstate` 0 is live; `online` 0, another
/// `status` or `roomstate`, or no current broadcast is offline; anything the
/// answer does not say is unknown.
enum LivemeState {
  /// On air.
  live,

  /// Not broadcasting, or over.
  offline,

  /// The answer did not say.
  unknown,
}

/// The media URLs of one quality: FLV lines first, then HLS lines, standing
/// in for each other.
final class LivemeStream {
  /// Creates the stream.
  LivemeStream({required this.qualityId, Iterable<String> flv = const [], Iterable<String> hls = const []})
    : flv = List.unmodifiable(flv),
      hls = List.unmodifiable(hls);

  /// [LivemeEndpoints.sourceQualityId] or [LivemeEndpoints.smoothQualityId].
  final String qualityId;

  /// FLV URLs, main field first, then the `*more` alternatives.
  final List<String> flv;

  /// HLS URLs.
  final List<String> hls;

  /// Every URL, in line order.
  List<String> get urls => [...flv, ...hls];
}

/// What one answer says about a room: a featured card, a search row, a
/// broadcast (`queryinfosimple`), an anchor without one, or a broadcast
/// completed from the anchor's profile.
final class LivemeSnapshot {
  /// Creates the snapshot.
  LivemeSnapshot({
    required this.shortId,
    required this.userId,
    required this.nickname,
    required this.title,
    required this.state,
    this.videoId = '',
    this.avatar = '',
    this.cover = '',
    this.bio = '',
    this.countryCode = '',
    this.followers,
    this.currentViewers,
    this.totalViewers,
    this.heat,
    this.likes,
    this.startedAt,
    this.restriction,
    Iterable<LivemeStream> streams = const [],
  }) : streams = List.unmodifiable(streams);

  /// The room id.
  final String shortId;

  /// The anchor's user id.
  final String userId;

  /// The broadcast (`vid`); empty when none.
  final String videoId;

  /// Anchor name.
  final String nickname;

  /// Title (the name when the broadcast has none, or only the app's default
  /// title).
  final String title;

  /// Avatar.
  final String avatar;

  /// Cover.
  final String cover;

  /// Introduction.
  final String bio;

  /// Two-letter country code, or empty.
  final String countryCode;

  /// Followers, when the answer says.
  final int? followers;

  /// `playnumber` of a live broadcast.
  final int? currentViewers;

  /// `watchnumber` of a live broadcast.
  final int? totalViewers;

  /// `heat` of a live broadcast.
  final int? heat;

  /// `likenum`.
  final int? likes;

  /// `vtime` of a live broadcast (UTC).
  final DateTime? startedAt;

  /// Of a live broadcast: private, paid or none; null when the answer does
  /// not say (a search row, an anchor without a broadcast).
  final LiveRestriction? restriction;

  /// Broadcast state.
  final LivemeState state;

  /// Media of a live, unrestricted broadcast, when asked for.
  final List<LivemeStream> streams;
}

/// An anchor's public profile (`user/getinfo`).
final class LivemeProfile {
  /// Creates the profile.
  const LivemeProfile({
    required this.shortId,
    required this.userId,
    required this.nickname,
    this.avatar = '',
    this.cover = '',
    this.bio = '',
    this.countryCode = '',
    this.followers,
  });

  /// The anchor's short id.
  final String shortId;

  /// The anchor's user id.
  final String userId;

  /// Display name.
  final String nickname;

  /// `big_face`, else `face`.
  final String avatar;

  /// `big_cover`, else `cover`.
  final String cover;

  /// `usign`, the anchor's signature.
  final String bio;

  /// Two-letter country code, or empty.
  final String countryCode;

  /// `count_info.follower_count`.
  final int? followers;
}

/// What room entry learnt about a room's current broadcast; it rides on the
/// room as the playback's stream handle and is never stored.
final class LivemeRoomData {
  /// Creates the data.
  LivemeRoomData({
    required this.shortId,
    required this.userId,
    required this.state,
    this.videoId = '',
    this.restriction,
    Iterable<LivemeStream> streams = const [],
  }) : streams = List.unmodifiable(streams);

  /// The room id.
  final String shortId;

  /// The anchor's user id.
  final String userId;

  /// The current broadcast; empty when none.
  final String videoId;

  /// Its state.
  final LivemeState state;

  /// Its restriction, when live.
  final LiveRestriction? restriction;

  /// Its media, [LivemeEndpoints.qualityIds] in order.
  final List<LivemeStream> streams;
}

/// Pure parsing of LiveMe responses (the reference's `LiveMeApi`): the
/// featured list, the search page, the room mapping, the anchor profile, the
/// broadcast answer, and the v2 rooms, qualities and lines.
///
/// A room is an anchor's short id (`ushortid`, `short_id`); the user id and
/// the broadcast's video id are only used for requests. Answers are checked
/// strictly: an id that does not match what was asked, a text field that is
/// not text or a negative count is api-changed, never a room. In lists and
/// search a malformed row only drops itself.
abstract final class LivemeRoomParser {
  // Directory and search ------------------------------------------------------

  /// A `featurelist` page: the rooms, each once; another page when
  /// `next_page` is 1. A card without `ushortid` (a union room) is skipped.
  /// Private and paid broadcasts are listed as live and marked. A malformed
  /// card only drops itself; a page whose cards are all malformed is
  /// api-changed, so a changed API never reads as an empty page.
  static ({List<LiveRoom> rooms, bool hasMore}) featuredPage(String body, {int status = 200}) {
    const what = 'featurelist';
    final data = LivemeJson.object(LivemeJson.envelope(body, what, status)['data'], '$what.data');
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    LivemeFailure? broken;
    for (final row in LivemeJson.list(data['video_info'], '$what.video_info', max: 100)) {
      final LivemeSnapshot snapshot;
      try {
        final video = LivemeJson.object(row, '$what row');
        if (video['ushortid'] == null) continue;
        snapshot = videoSnapshot(video);
      } on LivemeFailure catch (failure) {
        broken ??= failure;
        continue;
      }
      if (seen.add(snapshot.shortId)) rooms.add(room(snapshot));
    }
    if (rooms.isEmpty && broken != null) throw broken;
    return (rooms: rooms, hasMore: LivemeJson.integer(data['next_page']) == 1);
  }

  /// A `searchKeyword` page: the anchors, live or not, each once, named (also
  /// as the title) by `nickname`, else `uname`. Live when `is_live` is 1,
  /// offline when it is 0, else unknown (the union projects report 0 while
  /// live; room entry has the truth). A malformed row only drops itself; a
  /// page whose rows are all malformed is api-changed.
  static List<LiveRoom> searchPage(String body, {int status = 200}) {
    const what = 'searchKeyword';
    final data = LivemeJson.object(LivemeJson.envelope(body, what, status)['data'], '$what.data');
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    LivemeFailure? broken;
    for (final raw in LivemeJson.list(data['data_info'], '$what.data_info', max: 100)) {
      final LivemeSnapshot snapshot;
      try {
        final row = LivemeJson.object(raw, '$what row');
        final nickname = LivemeJson.firstText([row['nickname'], row['uname']], '$what nickname');
        snapshot = LivemeSnapshot(
          shortId: LivemeJson.shortId(row['short_id'], '$what short_id'),
          userId: LivemeJson.longId(row['user_id'], '$what user_id'),
          nickname: nickname,
          title: nickname,
          avatar: image(row['face']),
          countryCode: LivemeJson.countryCode(row['countryCode']),
          followers: LivemeJson.count(row['fans_num'] ?? row['follower_count'], '$what fans_num'),
          state: switch (LivemeJson.integer(row['is_live'])) {
            1 => LivemeState.live,
            0 => LivemeState.offline,
            _ => LivemeState.unknown,
          },
        );
      } on LivemeFailure catch (failure) {
        broken ??= failure;
        continue;
      }
      if (seen.add(snapshot.shortId)) rooms.add(room(snapshot));
    }
    if (rooms.isEmpty && broken != null) throw broken;
    return rooms;
  }

  // Rooms ---------------------------------------------------------------------

  /// `uid_vid_by_short_id`: the anchor's user id and the current broadcast's
  /// video id (empty when not broadcasting). An unknown short id is business
  /// 400 (not-found).
  static ({String userId, String videoId}) mapping(String body, {int status = 200}) {
    const what = 'uid_vid_by_short_id';
    final data = LivemeJson.object(LivemeJson.envelope(body, what, status)['data'], '$what.data');
    final userId = LivemeJson.longId(data['uid'], '$what uid');
    final videoId = LivemeJson.text(data['vid'], '$what vid');
    return (userId: userId, videoId: videoId.isEmpty ? '' : LivemeJson.longId(videoId, '$what vid'));
  }

  /// `user/getinfo` of [userId]: the answer must be that anchor's. The avatar
  /// is `big_face`, else `face`, and the cover `big_cover`, else `cover`,
  /// also when the first is empty. An unknown anchor is business 500 "user
  /// not exist" (not-found).
  static LivemeProfile profile(String body, {required String userId, int status = 200}) {
    const what = 'getinfo';
    final data = LivemeJson.object(LivemeJson.envelope(body, what, status)['data'], '$what.data');
    final user = LivemeJson.object(data['user'], '$what.user');
    final info = LivemeJson.object(user['user_info'], '$what.user_info');
    final actual = LivemeJson.longId(info['uid'] ?? info['userid'] ?? info['cm_openid'], '$what uid');
    if (actual != userId) throw LivemeFailure(LivemeFailureKind.apiChanged, '$what: asked $userId, got $actual');
    final counts = LivemeJson.object(user['count_info'], '$what.count_info');
    return LivemeProfile(
      shortId: LivemeJson.shortId(info['short_id'], '$what short_id'),
      userId: actual,
      nickname: LivemeJson.firstText([info['nickname'], info['uname']], '$what nickname'),
      avatar: _firstImage([info['big_face'], info['face']]),
      cover: _firstImage([info['big_cover'], info['cover']]),
      bio: LivemeJson.text(info['usign'], '$what usign'),
      countryCode: LivemeJson.countryCode(info['countryCode']),
      followers: LivemeJson.count(counts['follower_count'], '$what follower_count'),
    );
  }

  /// `live/queryinfosimple` of [videoId]: its `video_info`, completed by
  /// `user_info`, must be that broadcast and, when [shortId] is given, that
  /// room's. The media is read only with [media].
  static LivemeSnapshot video(
    String body, {
    required String videoId,
    String? shortId,
    bool media = false,
    int status = 200,
  }) {
    const what = 'queryinfosimple';
    final data = LivemeJson.object(LivemeJson.envelope(body, what, status)['data'], '$what.data');
    final user = data['user_info'] is Map
        ? LivemeJson.object(data['user_info'], '$what.user_info')
        : const <String, dynamic>{};
    return videoSnapshot(
      LivemeJson.object(data['video_info'], '$what.video_info'),
      user: user,
      shortId: shortId,
      videoId: videoId,
      media: media,
    );
  }

  /// A `video_info` object, completed by [user]. The ids must be [shortId]
  /// and [videoId] when given. While live it carries the viewers, total,
  /// heat, the start (`vtime`) and the restriction; the media only with
  /// [media] and without a restriction. The title is the name when the
  /// broadcast has none or only one of the app's default titles. The cover is
  /// `videocapture`, else `smallcover`, and the avatar `uface`, else the
  /// user's `face` or `icon`, also when the first is empty. The introduction
  /// is the user's `usign` only: `user_info.desc` is the anchor's name.
  static LivemeSnapshot videoSnapshot(
    Map<String, dynamic> video, {
    Map<String, dynamic> user = const {},
    String? shortId,
    String? videoId,
    bool media = false,
  }) {
    const what = 'video';
    final actualShortId = LivemeJson.shortId(video['ushortid'] ?? user['short_id'], '$what ushortid');
    final userId = LivemeJson.longId(video['userid'] ?? user['userid'] ?? user['uid'], '$what userid');
    final rawVideoId = LivemeJson.text(video['vid'] ?? video['vdoid'], '$what vid');
    final actualVideoId = rawVideoId.isEmpty ? '' : LivemeJson.longId(rawVideoId, '$what vid');
    if ((shortId != null && actualShortId != shortId) || (videoId != null && actualVideoId != videoId)) {
      throw LivemeFailure(
        LivemeFailureKind.apiChanged,
        'queryinfosimple: asked $shortId/$videoId, got $actualShortId/$actualVideoId',
      );
    }
    final online = LivemeJson.integer(video['online']);
    final state = LivemeJson.integer(video['status']);
    final roomState = LivemeJson.integer(video['roomstate']);
    final liveState = online == 1 && state == 0 && roomState == 0
        ? LivemeState.live
        : online == 0 || (state != null && state != 0) || (roomState != null && roomState != 0)
        ? LivemeState.offline
        : LivemeState.unknown;
    final live = liveState == LivemeState.live;
    final restriction = live ? restrictionOf(video) : null;
    final nickname = LivemeJson.firstText([video['uname'], user['uname'], user['nickname']], '$what uname');
    final title = LivemeJson.text(video['title'], '$what title');
    return LivemeSnapshot(
      shortId: actualShortId,
      userId: userId,
      videoId: actualVideoId,
      nickname: nickname,
      title: title.isEmpty || LivemeEndpoints.defaultTitles.contains(title) ? nickname : title,
      avatar: _firstImage([video['uface'], user['face'], user['icon']]),
      cover: _firstImage([video['videocapture'], video['smallcover']]),
      bio: LivemeJson.text(user['usign'], '$what usign'),
      countryCode: LivemeJson.countryCode(video['countryCode'] ?? video['country_code'] ?? user['countryCode']),
      currentViewers: live ? LivemeJson.count(video['playnumber'], '$what playnumber') : null,
      totalViewers: live ? LivemeJson.count(video['watchnumber'], '$what watchnumber') : null,
      heat: live ? LivemeJson.count(video['heat'], '$what heat') : null,
      likes: LivemeJson.count(video['likenum'], '$what likenum'),
      startedAt: live ? startedAt(video['vtime']) : null,
      restriction: restriction,
      state: liveState,
      streams: media && restriction == LiveRestriction.none ? streams(video) : const [],
    );
  }

  /// The restriction of a `video_info` object, by the web client's own rule
  /// (its `hot_label_v2` is JSON text): `ispvt` 1 is private; `livebptype` 7
  /// or the label text "Paid broadcast" (any case) is paid; anything else is
  /// none.
  static LiveRestriction restrictionOf(Map<String, dynamic> video) {
    if (LivemeJson.integer(video['ispvt']) == 1) return LiveRestriction.private;
    if (LivemeJson.integer(video['livebptype']) == 7 || isPaidLabel(video['hot_label_v2'])) {
      return LiveRestriction.paid;
    }
    return LiveRestriction.none;
  }

  /// Whether [label] (`hot_label_v2`: JSON text, as the site sends it, or an
  /// object, as the reference read it) says "Paid broadcast". A label that
  /// does not parse says nothing (the web client reads it as `{}`).
  static bool isPaidLabel(Object? label) {
    var value = label;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text.length > 65536) return false;
      final Object? decoded;
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        return false;
      }
      value = decoded;
    }
    return value is Map && '${value['text'] ?? ''}'.trim().toLowerCase() == 'paid broadcast';
  }

  /// The start of a broadcast from its `vtime` (Unix seconds, the time the
  /// answer gives less `videolength`); null unless positive whole seconds of
  /// at most ten digits.
  static DateTime? startedAt(Object? value) {
    final seconds = value is int ? value : (value is String ? int.tryParse(value.trim()) : null);
    if (seconds == null || seconds <= 0 || seconds > 9999999999) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// An anchor without a current broadcast: offline, the name as the title,
  /// the profile's cover.
  static LivemeSnapshot offline(LivemeProfile profile) => LivemeSnapshot(
    shortId: profile.shortId,
    userId: profile.userId,
    nickname: profile.nickname,
    title: profile.nickname,
    avatar: profile.avatar,
    cover: profile.cover,
    bio: profile.bio,
    countryCode: profile.countryCode,
    followers: profile.followers,
    state: LivemeState.offline,
  );

  /// A broadcast completed by its anchor's profile: avatar, cover and country
  /// where the broadcast has none, the followers, and the anchor's signature
  /// as the introduction (the broadcast's own only when the profile has
  /// none).
  static LivemeSnapshot withProfile(LivemeSnapshot video, LivemeProfile profile) => LivemeSnapshot(
    shortId: video.shortId,
    userId: video.userId,
    videoId: video.videoId,
    nickname: video.nickname,
    title: video.title,
    avatar: video.avatar.isEmpty ? profile.avatar : video.avatar,
    cover: video.cover.isEmpty ? profile.cover : video.cover,
    bio: profile.bio.isEmpty ? video.bio : profile.bio,
    countryCode: video.countryCode.isEmpty ? profile.countryCode : video.countryCode,
    followers: profile.followers,
    currentViewers: video.currentViewers,
    totalViewers: video.totalViewers,
    heat: video.heat,
    likes: video.likes,
    startedAt: video.startedAt,
    restriction: video.restriction,
    state: video.state,
    streams: video.streams,
  );

  /// The room of [snapshot]: the short id is the room id and the room page
  /// its link. The heat is the popularity (and the leading audience figure)
  /// when live, else the audience is the concurrent viewers; every room
  /// carries [LivemeEndpoints.chatNotice]. A restricted broadcast is live and
  /// marked. The country code rides as the room's area display name. [data]
  /// is kept as the playback's stream handle.
  static LiveRoom room(LivemeSnapshot snapshot, {LivemeRoomData? data}) {
    final liveStatus = switch (snapshot.state) {
      LivemeState.live => LiveStatus.live,
      LivemeState.offline => LiveStatus.offline,
      LivemeState.unknown => LiveStatus.unknown,
    };
    return LiveRoom.normalized(
      platform: 'liveme',
      roomId: snapshot.shortId,
      content: RoomContent(
        title: snapshot.title,
        coverUrl: snapshot.cover,
        introduction: snapshot.bio.isEmpty ? null : snapshot.bio,
        notice: LivemeEndpoints.chatNotice,
      ),
      anchor: LiveAnchor.normalized(
        platform: 'liveme',
        anchorId: snapshot.userId,
        name: snapshot.nickname,
        avatarUrl: snapshot.avatar,
        followerCount: snapshot.followers,
        liveStatus: liveStatus,
      ),
      area: snapshot.countryCode.isEmpty
          ? null
          : LiveArea.normalized(platform: 'liveme', areaName: snapshot.countryCode),
      audience: RoomAudience(
        popularity: snapshot.heat,
        onlineViewers: snapshot.currentViewers,
        totalViewers: snapshot.totalViewers,
        primaryMetric: snapshot.heat != null
            ? LiveAudienceMetricType.popularity
            : snapshot.currentViewers != null
            ? LiveAudienceMetricType.onlineViewers
            : LiveAudienceMetricType.unknown,
      ),
      broadcast: RoomBroadcast(
        liveStatus: liveStatus,
        startedAt: snapshot.startedAt,
        restriction: snapshot.restriction,
      ),
      links: RoomLinks(webUrl: LivemeEndpoints.roomUrl(snapshot.shortId)),
      runtime: RoomRuntime(streamHandle: data),
    );
  }

  /// The stream data of [snapshot].
  static LivemeRoomData roomData(LivemeSnapshot snapshot) => LivemeRoomData(
    shortId: snapshot.shortId,
    userId: snapshot.userId,
    videoId: snapshot.videoId,
    state: snapshot.state,
    restriction: snapshot.restriction,
    streams: snapshot.streams,
  );

  // Streams -------------------------------------------------------------------

  /// The media of a live `video_info`: [LivemeEndpoints.sourceQualityId] with
  /// the FLV URLs of `videosource` and `videosourcemore` and the HLS URL of
  /// `hlsvideosource`; [LivemeEndpoints.smoothQualityId] with the FLV URLs of
  /// `smallsource` and `smallsourcemore`. Each [mediaUrl] once; a quality
  /// without one is left out. A field may be a URL, JSON text or a list or
  /// object of them.
  static List<LivemeStream> streams(Map<String, dynamic> video) {
    List<String> urls(List<String> fields, LiveStreamFormat format) => <String>{
      for (final field in fields)
        for (final raw in _flattenUrls(video[field])) ?mediaUrl(raw, format),
    }.toList();
    final source = LivemeStream(
      qualityId: LivemeEndpoints.sourceQualityId,
      flv: urls(['videosource', 'videosourcemore'], LiveStreamFormat.flv),
      hls: urls(['hlsvideosource'], LiveStreamFormat.hls),
    );
    final smooth = LivemeStream(
      qualityId: LivemeEndpoints.smoothQualityId,
      flv: urls(['smallsource', 'smallsourcemore'], LiveStreamFormat.flv),
    );
    return [
      for (final stream in [source, smooth])
        if (stream.urls.isNotEmpty) stream,
    ];
  }

  /// Why room [shortId] with [restriction] is not played, or null without
  /// one.
  static LivemeFailure? restricted(String shortId, LiveRestriction? restriction) => switch (restriction) {
    null || LiveRestriction.none => null,
    final kind => LivemeFailure(LivemeFailureKind.streamUnavailable, '$shortId is restricted (${kind.name})'),
  };

  /// The qualities of the broadcast [data] holds: `原画`, `流畅`, those it
  /// has, best first. A private or paid broadcast (naming it), one that is
  /// not live, or a live one without media is stream-unavailable.
  static List<LivePlayQuality> qualities(LivemeRoomData data) {
    if (restricted(data.shortId, data.restriction) case final error?) throw error;
    if (data.state != LivemeState.live) {
      throw LivemeFailure(LivemeFailureKind.streamUnavailable, '${data.shortId} is ${data.state.name}');
    }
    if (data.streams.isEmpty) {
      throw LivemeFailure(LivemeFailureKind.streamUnavailable, '${data.shortId} has no media URL');
    }
    return [
      for (final (index, stream) in data.streams.indexed)
        LivePlayQuality(
          label: LivemeEndpoints.qualityNames[stream.qualityId]!,
          qualityId: stream.qualityId,
          platformOrder: index,
        ),
    ];
  }

  /// The lines of [qualityId] (by its id; one of the reference's stored ids
  /// is read through [LivemeEndpoints.qualityIdFromLegacy]) of [data]'s
  /// broadcast: FLV then HLS, each with the media headers and its format; the
  /// line label is the format (`flv`, `hls`), and the `*more` alternatives
  /// add `#2`, `#3` (the media hosts change with dispatch and name no line).
  /// No lease: the URLs' `wsABStime` is fixed for the broadcast and not
  /// enforced. A quality the broadcast does not offer is stream-unavailable.
  static List<LivePlayLine> lines(LivemeRoomData data, String qualityId) {
    qualities(data);
    final wanted = LivemeEndpoints.qualityIdFromLegacy(qualityId);
    final stream = data.streams.where((stream) => stream.qualityId == wanted).firstOrNull;
    if (stream == null) {
      throw LivemeFailure(LivemeFailureKind.streamUnavailable, 'quality $qualityId is not offered');
    }
    return [
      for (final (format, urls) in [(LiveStreamFormat.flv, stream.flv), (LiveStreamFormat.hls, stream.hls)])
        for (final (index, url) in urls.indexed)
          LivePlayLine(
            url: url,
            format: format,
            formatSource: LivePlayFormatSource.declared,
            lineLabel: index == 0 ? format.name : '${format.name}#${index + 1}',
            headers: LivemeEndpoints.mediaHeaders(data.shortId),
          ),
    ];
  }

  /// A media URL of [format]: http(s) with a host, without user info or
  /// fragment, with a `.flv` or `.m3u8` path. On the site's CDN hosts
  /// (`linkv.fun`, `emolm.com`, `liveme.com` or a subdomain, no explicit
  /// port) it is made https as the reference did (the site's own web player
  /// forces https too); on any other host, which the reference refused, it is
  /// kept as written. Null otherwise.
  static String? mediaUrl(String raw, LiveStreamFormat format) {
    if (raw.isEmpty || raw.length > 65536 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !uri.path.toLowerCase().endsWith(format == LiveStreamFormat.hls ? '.m3u8' : '.flv')) {
      return null;
    }
    if (!_mediaHost(uri.host.toLowerCase()) || uri.hasPort) return raw;
    return uri.replace(scheme: 'https').toString();
  }

  /// An image address as the reference kept it, made absolute first
  /// ([normalizeImageUrl]): http(s) without user info or fragment on
  /// `esxscloud.com`, `liveme.com` or `linkv.fun` (or a subdomain), made
  /// https; else empty.
  static String image(Object? value) {
    if (value is! String || value.length > 8192) return '';
    final uri = Uri.tryParse(normalizeImageUrl(value));
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_imageHost(uri.host.toLowerCase())) {
      return '';
    }
    return uri.replace(scheme: 'https').toString();
  }

  /// The first of [values] that is an [image]: an empty or unusable field
  /// falls back to the next.
  static String _firstImage(List<Object?> values) {
    for (final value in values) {
      final url = image(value);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  static bool _mediaHost(String host) => ['linkv.fun', 'emolm.com', 'liveme.com'].any((root) => _under(host, root));

  static bool _imageHost(String host) => ['esxscloud.com', 'liveme.com', 'linkv.fun'].any((root) => _under(host, root));

  static bool _under(String host, String root) => host == root || host.endsWith('.$root');

  /// The http(s) strings in [value]: JSON text (up to 128 KiB), lists and
  /// objects (up to 32 entries) three levels deep.
  static Iterable<String> _flattenUrls(Object? value, [int depth = 0]) sync* {
    if (depth > 3 || value == null) return;
    if (value is String) {
      final text = value.trim();
      if (text.startsWith('http://') || text.startsWith('https://')) {
        yield text;
        return;
      }
      if (text.length <= 131072 && (text.startsWith('[') || text.startsWith('{'))) {
        final Object? decoded;
        try {
          decoded = jsonDecode(text);
        } on FormatException {
          return;
        }
        yield* _flattenUrls(decoded, depth + 1);
      }
      return;
    }
    if (value is List && value.length <= 32) {
      for (final item in value) {
        yield* _flattenUrls(item, depth + 1);
      }
      return;
    }
    if (value is Map && value.length <= 32) {
      for (final item in value.values) {
        yield* _flattenUrls(item, depth + 1);
      }
    }
  }
}
