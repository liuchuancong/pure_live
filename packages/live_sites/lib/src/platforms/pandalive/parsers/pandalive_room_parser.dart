import 'package:live_sites/src/common/hls/hls_master.dart';
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
import 'package:live_sites/src/models/play/play_geometry/play_geometry.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One quality of a broadcast with the one line that serves it: the IVS
/// variant playlist, with the media headers and the lease of its issue.
typedef PandaliveStream = ({LivePlayQuality quality, LivePlayLine line});

/// What room entry keeps for playback: the qualities with their lines, or
/// why there is nothing to play. The chat grant travels on the room's
/// danmaku handle instead.
final class PandaliveStreamData {
  /// Creates the data; [unavailable] is required when [entries] is empty and
  /// no broadcast carries it.
  PandaliveStreamData({required this.userId, required this.userIndex, this.entries = const [], this.unavailable})
    : assert(entries.isNotEmpty || unavailable != null, 'an empty playback needs its reason');

  /// The broadcaster the data belongs to (compared without case).
  final String userId;

  /// `bjInfo.idx`: the broadcaster's number (the chat channel's default).
  final int userIndex;

  /// Best first.
  final List<PandaliveStream> entries;

  /// Why there is nothing to play: not live, ended, adult, password, fans
  /// only, no login, no HLS, no video variant.
  final PandaliveFailure? unavailable;

  /// The qualities of [entries], or why there is nothing to play.
  List<LivePlayQuality> get qualities => [for (final entry in entries) entry.quality];
}

/// One broadcaster from `member/bj`: the channel (`bjInfo`) and, while the
/// platform lists a broadcast, its `media`.
final class PandaliveMember {
  /// Creates the member.
  PandaliveMember({
    required this.userId,
    required this.userIndex,
    required Map<String, dynamic> profile,
    Map<String, dynamic>? media,
  }) : profile = Map.unmodifiable(profile),
       media = media == null ? null : Map.unmodifiable(media);

  /// The broadcaster id as asked for.
  final String userId;

  /// `bjInfo.idx`: the broadcaster's number (the chat channel's default).
  final int userIndex;

  /// `bjInfo`: nick, avatar, channel title, description, banner, fans.
  final Map<String, dynamic> profile;

  /// `media`, null while the broadcaster is not listed as live; checked to
  /// be this broadcaster's.
  final Map<String, dynamic>? media;
}

/// What `live/play` answered, the second request of a room entry.
final class PandalivePlay {
  /// A refusal with `errorData.code` [code] (empty without one).
  const PandalivePlay.refused(this.code) : media = null, master = null, chatChannel = null, chatToken = null;

  /// An accepted answer: its broadcast, the first IVS master of `PlayList`
  /// (null when it has none) and the chat channel and token.
  const PandalivePlay.accepted({required this.media, this.code, this.master, this.chatChannel, this.chatToken});

  /// `errorData.code` of a refusal (`castEnd`, `needAdult`, `needLogin`,
  /// `needPassword`…; empty without one); null when accepted.
  final String? code;

  /// `media` of an accepted answer, checked to be the broadcaster's.
  final Map<String, dynamic>? media;

  /// The first `PlayList` master (`hls3`, else `hls2`, else `hls`): an
  /// Amazon IVS playlist whose token can be read once.
  final Uri? master;

  /// `channel`: the chat channel (the broadcaster's number).
  final String? chatChannel;

  /// `token`: the chat token (a JWT of about 30 minutes).
  final String? chatToken;

  /// Whether the answer was accepted and says the broadcast is live.
  bool get isLive => code == null && (PandaliveJson.flag(media?['isLive']) ?? false);
}

/// Pure parsing of PandaTV responses (3.x's `PandaLiveApi` and the card
/// rules of `PandaLiveSite`), in v2 models.
///
/// A room is a broadcaster, its id the login id as asked for. Every API
/// answer is `{result, message, ...}`; the platform puts its refusals (no
/// such broadcaster, broadcast ended, adult) in HTTP 400 answers of the
/// same shape. Answers are checked strictly, except that one unusable
/// variant of a master or one broken row of a list only loses itself.
abstract final class PandaliveRoomParser {
  // Envelope --------------------------------------------------------------

  /// An API answer as a JSON object with a boolean `result`; a refusal is
  /// kept for the caller (see [play]).
  static Map<String, dynamic> answer(String body, {required String what, int status = 200}) {
    PandaliveJson.checkBody(body, what, status);
    final data = PandaliveJson.json(body, what, status);
    if (data['result'] is! bool) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: no result flag');
    }
    return data;
  }

  /// A successful answer, or the typed refusal (see [refusal]).
  static Map<String, dynamic> ok(String body, {required String what, int status = 200}) {
    final data = answer(body, what: what, status: status);
    if (data['result'] == true) return data;
    throw refusal(data, what: what);
  }

  /// `errorData.code` of a refused answer, empty without one.
  static String refusalCode(Map<String, dynamic> data) {
    final errorData = data['errorData'];
    return errorData is Map ? PandaliveJson.text(errorData['code']) : '';
  }

  /// The failure of a refused answer: `유저 정보가 없습니다` (no such
  /// broadcaster) is not-found, an adult or fans-only broadcast
  /// (`needAdult`, `needLogin`) stream-unavailable for its login, another
  /// code stream-unavailable, a refusal without a code api-changed.
  static PandaliveFailure refusal(Map<String, dynamic> data, {required String what}) {
    final message = PandaliveJson.text(data['message']);
    final code = refusalCode(data);
    if (message.contains('유저 정보가 없습니다')) {
      return PandaliveFailure(PandaliveFailureKind.notFound, '$what: no such broadcaster');
    }
    return switch (code) {
      '' => PandaliveFailure(PandaliveFailureKind.apiChanged, '$what refused: $message'),
      _ => PandaliveFailure(PandaliveFailureKind.streamUnavailable, '$what: $code'),
    };
  }

  // Restrictions ----------------------------------------------------------

  /// The restriction a broadcast's flags show: adult (`isAdult`), else a
  /// password (`isPw`), else fans only (`type` `fan`), else none for a free
  /// broadcast (`type` `free`); null when its `type` says neither (not
  /// known).
  static LiveRestriction? restrictionOf(Map<String, dynamic> media) {
    if (PandaliveJson.flag(media['isAdult']) ?? false) return LiveRestriction.adult;
    if (PandaliveJson.flag(media['isPw']) ?? false) return LiveRestriction.password;
    return switch (PandaliveJson.text(media['type'])) {
      'fan' => LiveRestriction.subscribersOnly,
      'free' => LiveRestriction.none,
      _ => null,
    };
  }

  /// The restriction of a `live/play` refusal with [code] (not `castEnd`)
  /// of a broadcast listed with [media]: the code when it names one
  /// (`needAdult` adult, `needPassword`/`password` a password), else the
  /// broadcast's flags (an anonymous viewer of a password room is refused
  /// `needLogin`), else `needLogin` needs a login and any other code is
  /// unplayable.
  static LiveRestriction refusalRestriction(String code, Map<String, dynamic>? media) {
    switch (code) {
      case 'needAdult':
        return LiveRestriction.adult;
      case 'needPassword' || 'password':
        return LiveRestriction.password;
    }
    final flagged = media == null ? null : restrictionOf(media);
    if (flagged != null && flagged != LiveRestriction.none) return flagged;
    return code == 'needLogin' ? LiveRestriction.needsLogin : LiveRestriction.unplayable;
  }

  /// Why a broadcast with [restriction] cannot be played.
  static PandaliveFailure restrictionError(LiveRestriction restriction, String what) =>
      PandaliveFailure(PandaliveFailureKind.streamUnavailable, '$what (${restriction.name})');

  /// The notice of a broadcast with [restriction]: adult, password, fans
  /// only, other conditions, else (none, or not known) the chat notice.
  static String noticeOf(LiveRestriction? restriction) => switch (restriction) {
    LiveRestriction.adult => PandaliveEndpoints.adultNotice,
    LiveRestriction.password => PandaliveEndpoints.passwordNotice,
    LiveRestriction.subscribersOnly => PandaliveEndpoints.fansNotice,
    LiveRestriction.none || null => PandaliveEndpoints.chatNotice,
    _ => PandaliveEndpoints.restrictedNotice,
  };

  // Cards -----------------------------------------------------------------

  /// Whether an on-air broadcast is a recording played again (`onAirType`
  /// or `liveType` `rec`): a replay. It plays like a live broadcast.
  static bool isRerun(Map<String, dynamic> media) =>
      PandaliveJson.text(media['onAirType']) == 'rec' || PandaliveJson.text(media['liveType']) == 'rec';

  /// The state of an on-air broadcast: a replay for a rerun, else live.
  static LiveStatus onAirStatus(Map<String, dynamic> media) => isRerun(media) ? LiveStatus.replay : LiveStatus.live;

  /// The content area of a broadcast's category [code]: the code's
  /// translated name; null without a code.
  static LiveArea? areaOf(String code) => code.isEmpty
      ? null
      : LiveArea.normalized(
          platform: PandaliveEndpoints.siteId,
          areaId: code.toLowerCase(),
          areaName: PandaliveEndpoints.areaNameOf(code),
          parentAreaId: PandaliveEndpoints.siteId,
          parentAreaName: PandaliveEndpoints.siteName,
        );

  /// A live card of the directory and the LIVE search: the broadcast title
  /// (else the nick), the nick, avatar, snapshot as cover, the category's
  /// name, viewers now, this broadcast's cumulative viewers (`playCnt`),
  /// fans, the start, and the restriction its flags show, with that
  /// restriction's notice; live, or a replay for a rerun. The card id is
  /// the login id; the broadcaster's number rides on the anchor's profile.
  /// Null for a row without a broadcaster id or that is not on air.
  static LiveRoom? liveCard(Map<String, dynamic> row) {
    final id = PandaliveEndpoints.normalizeUserId(row['userId']);
    if (id == null || PandaliveJson.flag(row['isLive']) != true) return null;
    final nick = PandaliveJson.text(row['userNick']);
    final restriction = restrictionOf(row);
    final status = onAirStatus(row);
    final category = PandaliveJson.text(row['category']);
    return LiveRoom.normalized(
      platform: PandaliveEndpoints.siteId,
      roomId: id,
      content: RoomContent.of(
        title: PandaliveJson.firstText([row['title'], nick]),
        coverUrl: PandaliveJson.image(row['thumbUrl'] ?? row['ivsThumbnail']),
        notice: noticeOf(restriction),
      ),
      anchor: LiveAnchor.normalized(
        platform: PandaliveEndpoints.siteId,
        anchorId: id,
        name: nick,
        avatarUrl: _blankless(PandaliveJson.image(row['userImg'])),
        liveStatus: status,
        followerCount: PandaliveJson.count(row['fanCnt']),
      ),
      area: areaOf(category),
      audience: RoomAudience.of(
        onlineViewers: PandaliveJson.count(row['user']),
        totalViewers: PandaliveJson.count(row['playCnt']),
        primaryMetric: LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast.of(
        liveStatus: status,
        startedAt: PandaliveJson.koreanTime(row['startTime']),
        restriction: restriction,
      ),
      links: RoomLinks.of(webUrl: PandaliveEndpoints.roomUrl(id)),
    );
  }

  /// A broadcaster of the BJ search, live or not. Skipped when the service
  /// blocked the row, it has no broadcaster id or number, or its `media` is
  /// not this broadcaster's. Without `media` the broadcaster is offline,
  /// titled by the nick; with it, the broadcast's title, cover, category
  /// and fans, live by `isLive` (unknown when it says neither).
  static LiveRoom? profileCard(Map<String, dynamic> row) {
    if (PandaliveJson.flag(row['blockService']) == true) return null;
    final id = PandaliveEndpoints.normalizeUserId(row['userId']);
    final index = PandaliveJson.positive(row['userIdx']);
    if (id == null || index == null) return null;
    final nick = PandaliveJson.text(row['userNick']);
    final avatar = PandaliveJson.image(row['thumbUrl']);
    final media = PandaliveJson.maybeObject(row['media']);
    if (media == null) {
      return _anchorRoom(id, index, nick: nick, avatar: avatar);
    }
    if (!owns(media, id, index)) {
      return null;
    }
    final live = PandaliveJson.flag(media['isLive']);
    final isLive = live ?? false;
    final restriction = restrictionOf(media);
    final status = switch (live) {
      true => onAirStatus(media),
      false => LiveStatus.offline,
      null => LiveStatus.unknown,
    };
    final category = PandaliveJson.text(media['category']);
    return LiveRoom.normalized(
      platform: PandaliveEndpoints.siteId,
      roomId: id,
      content: RoomContent.of(
        title: PandaliveJson.firstText([media['title'], nick]),
        coverUrl: PandaliveJson.image(media['thumbUrl'] ?? media['ivsThumbnail']),
        notice: noticeOf(restriction),
      ),
      anchor: LiveAnchor.normalized(
        platform: PandaliveEndpoints.siteId,
        anchorId: id,
        name: nick,
        avatarUrl: _blankless(avatar),
        liveStatus: status,
        followerCount: PandaliveJson.count(media['fanCnt']),
      ),
      area: areaOf(category),
      audience: RoomAudience.of(
        onlineViewers: isLive ? PandaliveJson.count(media['user']) : null,
        totalViewers: isLive ? PandaliveJson.count(media['playCnt']) : null,
        primaryMetric: isLive ? LiveAudienceMetricType.onlineViewers : LiveAudienceMetricType.unknown,
      ),
      broadcast: RoomBroadcast.of(
        liveStatus: status,
        startedAt: isLive ? PandaliveJson.koreanTime(media['startTime']) : null,
        restriction: isLive ? restriction : null,
      ),
      links: RoomLinks.of(webUrl: PandaliveEndpoints.roomUrl(id)),
    );
  }

  /// An offline broadcaster room: titled by the nick, no audience, unknown
  /// viewers.
  static LiveRoom _anchorRoom(String id, int index, {required String nick, required String avatar}) =>
      LiveRoom.normalized(
        platform: PandaliveEndpoints.siteId,
        roomId: id,
        content: RoomContent.of(title: nick, notice: PandaliveEndpoints.chatNotice),
        anchor: LiveAnchor.normalized(
          platform: PandaliveEndpoints.siteId,
          anchorId: id,
          name: nick,
          avatarUrl: _blankless(avatar),
          liveStatus: LiveStatus.offline,
        ),
        broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
        links: RoomLinks.of(webUrl: PandaliveEndpoints.roomUrl(id)),
      );

  // Rooms -----------------------------------------------------------------

  /// Whether [media]'s broadcaster is [userId] (without case) and, when
  /// given, number [index].
  static bool owns(Map<String, dynamic> media, String userId, [int? index]) =>
      PandaliveEndpoints.normalizeUserId(media['userId'])?.toLowerCase() == userId.toLowerCase() &&
      (index == null || PandaliveJson.positive(media['userIdx']) == index);

  /// Whether `member/bj` lists [member]'s broadcast as live: it has a
  /// `media` whose `isLive` is not false (one that says neither is still
  /// live).
  static bool listedLive(PandaliveMember member) =>
      member.media != null && PandaliveJson.flag(member.media!['isLive']) != false;

  /// Broadcaster [userId] from `member/bj`. No such broadcaster (HTTP 400,
  /// `유저 정보가 없습니다`) is not-found; a `bjInfo` of another broadcaster
  /// or without a number, or a `media` that is not an object of this
  /// broadcaster, is api-changed.
  static PandaliveMember member(String body, {required String userId, int status = 200}) {
    const what = 'member/bj';
    final data = ok(body, what: what, status: status);
    final info = PandaliveJson.maybeObject(data['bjInfo']);
    if (info == null) {
      throw const PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: no bjInfo');
    }
    final id = PandaliveEndpoints.normalizeUserId(info['id']);
    if (id == null || id.toLowerCase() != userId.toLowerCase()) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: bjInfo of ${info['id']} for $userId');
    }
    final index = PandaliveJson.positive(info['idx']);
    if (index == null) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: bjInfo.idx ${info['idx']}');
    }
    final media = data['media'] == null ? null : PandaliveJson.maybeObject(data['media']);
    if (data['media'] != null && (media == null || !owns(media, userId, index))) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: media of ${media?['userId']} for $userId');
    }
    return PandaliveMember(userId: userId, userIndex: index, profile: info, media: media);
  }

  /// The room of a broadcaster the platform lists as not live: the channel
  /// title (else the nick), the banner as cover, the channel description,
  /// fans, offline.
  static LiveRoom profileRoom(PandaliveMember member) {
    final profile = member.profile;
    final nick = PandaliveJson.text(profile['nick']);
    return LiveRoom.normalized(
      platform: PandaliveEndpoints.siteId,
      roomId: member.userId,
      content: RoomContent.of(
        title: PandaliveJson.firstText([profile['channelTitle'], nick]),
        coverUrl: PandaliveJson.image(profile['channelBannerUrl']),
        introduction: _blankless(PandaliveJson.text(profile['channelDesc'])),
        notice: PandaliveEndpoints.chatNotice,
      ),
      anchor: LiveAnchor.normalized(
        platform: PandaliveEndpoints.siteId,
        anchorId: member.userId,
        name: nick,
        avatarUrl: _blankless(PandaliveJson.image(profile['thumbUrl'])),
        liveStatus: LiveStatus.offline,
        followerCount: PandaliveJson.count(profile['fanCnt']),
      ),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
      links: RoomLinks.of(webUrl: PandaliveEndpoints.roomUrl(member.userId)),
    );
  }

  /// The room of a broadcast: the broadcast's nick, title (else the channel
  /// title, else the nick), avatar, cover (the snapshot, for a playable
  /// broadcast also `ivsThumbnail`, else the banner), category name, fans,
  /// viewers and cumulative viewers, its start, with the channel
  /// description; live (a replay for a rerun), with [notice] and
  /// [restriction].
  static LiveRoom mediaRoom(
    PandaliveMember member,
    Map<String, dynamic> media, {
    required String notice,
    LiveRestriction? restriction,
    bool playable = false,
  }) {
    final profile = member.profile;
    final nick = PandaliveJson.firstText([media['userNick'] ?? profile['nick'], profile['nick']]);
    final cover = playable
        ? media['thumbUrl'] ?? media['ivsThumbnail'] ?? profile['channelBannerUrl']
        : media['thumbUrl'] ?? profile['channelBannerUrl'];
    final category = PandaliveJson.text(media['category']);
    return LiveRoom.normalized(
      platform: PandaliveEndpoints.siteId,
      roomId: member.userId,
      content: RoomContent.of(
        title: PandaliveJson.firstText([media['title'], profile['channelTitle'], profile['nick'], nick]),
        coverUrl: PandaliveJson.image(cover),
        introduction: _blankless(PandaliveJson.text(profile['channelDesc'])),
        notice: notice,
      ),
      anchor: LiveAnchor.normalized(
        platform: PandaliveEndpoints.siteId,
        anchorId: member.userId,
        name: nick,
        avatarUrl: _blankless(PandaliveJson.image(media['userImg'] ?? profile['thumbUrl'])),
        liveStatus: onAirStatus(media),
        followerCount: PandaliveJson.count(media['fanCnt'] ?? profile['fanCnt']),
      ),
      area: areaOf(category),
      audience: RoomAudience.of(
        onlineViewers: PandaliveJson.count(media['user']),
        totalViewers: PandaliveJson.count(media['playCnt']),
        primaryMetric: LiveAudienceMetricType.onlineViewers,
      ),
      broadcast: RoomBroadcast.of(
        liveStatus: onAirStatus(media),
        startedAt: PandaliveJson.koreanTime(media['startTime']),
        restriction: restriction,
      ),
      links: RoomLinks.of(webUrl: PandaliveEndpoints.roomUrl(member.userId)),
    );
  }

  /// The room of a follow refresh and of the exact searches: not listed as
  /// live is the profile room, offline; listed is the `member/bj`
  /// broadcast, live, with the restriction its flags show and that
  /// restriction's notice.
  static LiveRoom refreshRoom(PandaliveMember member) {
    if (!listedLive(member)) return profileRoom(member);
    final restriction = restrictionOf(member.media!);
    return mediaRoom(member, member.media!, notice: noticeOf(restriction), restriction: restriction);
  }

  /// `live/play` for [member]. A refusal (HTTP 400: ended, adult, fans
  /// only, password) is kept with its code for [playRoom]; an accepted
  /// answer must carry this broadcaster's `media` and, when live, a
  /// `PlayList` whose first usable master is an IVS URL (api-changed when
  /// it has masters and none is usable; none at all is null).
  static PandalivePlay play(String body, {required PandaliveMember member, int status = 200}) {
    const what = 'live/play';
    final data = answer(body, what: what, status: status);
    if (data['result'] != true) return PandalivePlay.refused(refusalCode(data));
    final media = PandaliveJson.maybeObject(data['media']);
    if (media == null || !owns(media, member.userId, member.userIndex)) {
      throw PandaliveFailure(
        PandaliveFailureKind.apiChanged,
        '$what: media of ${media?['userId']} for ${member.userId}',
      );
    }
    if (PandaliveJson.flag(media['isLive']) != true) {
      return PandalivePlay.accepted(media: media);
    }
    final playlist = PandaliveJson.maybeObject(data['PlayList']);
    if (playlist == null) {
      throw const PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: no PlayList');
    }
    return PandalivePlay.accepted(
      media: media,
      master: masterUrl(playlist),
      chatChannel: data['channel'] is String ? (data['channel'] as String).trim() : null,
      chatToken: data['token'] is String ? (data['token'] as String).trim() : null,
    );
  }

  /// The first IVS master of `hls3`, `hls2`, `hls` in that order; null when
  /// none has a URL. A list or entry that is not usable (not a list, not an
  /// object, not an IVS playlist) is passed over for the next one; some and
  /// none usable is api-changed.
  static Uri? masterUrl(Map<String, dynamic> playlist) {
    String? broken;
    for (final key in const ['hls3', 'hls2', 'hls']) {
      final entries = playlist[key];
      if (entries == null) continue;
      if (entries is! List || entries.length > 16) {
        broken ??= 'PlayList.$key';
        continue;
      }
      for (final entry in entries) {
        final item = PandaliveJson.maybeObject(entry);
        if (item == null) {
          broken ??= 'PlayList.$key item';
          continue;
        }
        final url = item['url'];
        if (url is String && url.isNotEmpty) {
          if (mediaUrl(url) case final master?) return master;
          broken ??= '$key is not an IVS playlist';
        }
      }
    }
    if (broken != null) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, 'live/play: $broken');
    }
    return null;
  }

  /// [text] as an IVS playlist URL: https on a `live-video.net` subdomain,
  /// a `.m3u8` path, no user info, fragment, blank or control character;
  /// else null.
  static Uri? mediaUrl(String text) {
    if (text.isEmpty || text.length > 65536 || RegExp(r'[\s\x00-\x1f]').hasMatch(text)) return null;
    final uri = Uri.tryParse(text);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !host.endsWith('.live-video.net') ||
        !uri.path.toLowerCase().endsWith('.m3u8')) {
      return null;
    }
    return uri;
  }

  /// The room of room entry from [member] and its [play], and why it cannot
  /// be played when so:
  /// - ended (`castEnd`), or accepted as not live: the profile room,
  ///   offline, stream-unavailable;
  /// - another refusal: the `member/bj` broadcast, live, with the
  ///   restriction of [refusalRestriction], its notice and its error;
  /// - accepted and live: the `live/play` broadcast with the chat notice,
  ///   without restriction; unplayable (stream-unavailable) when it has no
  ///   HLS master, else nothing yet (the master decides).
  static ({LiveRoom room, PandaliveFailure? unavailable}) playRoom(PandaliveMember member, PandalivePlay play) {
    final code = play.code;
    if (code == 'castEnd') {
      return (
        room: profileRoom(member),
        unavailable: const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'live/play: castEnd'),
      );
    }
    if (code != null) {
      final restriction = refusalRestriction(code, member.media);
      return (
        room: mediaRoom(member, member.media ?? const {}, notice: noticeOf(restriction), restriction: restriction),
        unavailable: restrictionError(restriction, 'live/play: ${code.isEmpty ? 'refused' : code}'),
      );
    }
    if (!play.isLive) {
      return (
        room: profileRoom(member),
        unavailable: const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'live/play: not live'),
      );
    }
    if (play.master == null) {
      return (
        room: mediaRoom(
          member,
          play.media!,
          notice: PandaliveEndpoints.chatNotice,
          restriction: LiveRestriction.unplayable,
          playable: true,
        ),
        unavailable: const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'live/play: no HLS'),
      );
    }
    return (
      room: mediaRoom(
        member,
        play.media!,
        notice: PandaliveEndpoints.chatNotice,
        restriction: LiveRestriction.none,
        playable: true,
      ),
      unavailable: null,
    );
  }

  /// The chat grant of an accepted, live [play]: the `live/play` channel
  /// (the broadcaster's number when it has none, or one that is not a
  /// number) and token; null for a refused or not-live answer, which has no
  /// token.
  static ({String channel, String? token})? chatGrantOf(PandaliveMember member, PandalivePlay play) {
    if (!play.isLive) return null;
    final channel = play.chatChannel;
    return (
      channel: channel != null && RegExp(r'^[0-9]{1,19}$').hasMatch(channel) ? channel : '${member.userIndex}',
      token: play.chatToken,
    );
  }

  // Pages -----------------------------------------------------------------

  /// The rows of a paged answer asked at [page] of [size]: `page.offset`,
  /// `limit` and `page` must be what was asked, `total` a count, and `list`
  /// at most [PandaliveEndpoints.maxRows] rows; more pages while the rows so
  /// far are fewer than `total`.
  static (List<Object?> rows, bool hasMore, int? total) rows(
    Map<String, dynamic> data, {
    required int page,
    required int size,
    required String what,
  }) {
    final paging = PandaliveJson.maybeObject(data['page']);
    final offset = (page - 1) * size;
    if (paging == null ||
        PandaliveJson.integer(paging['offset']) != offset ||
        PandaliveJson.integer(paging['limit']) != size ||
        PandaliveJson.integer(paging['page']) != page) {
      throw PandaliveFailure(
        PandaliveFailureKind.apiChanged,
        '$what: page ${data['page']} for offset $offset, limit $size',
      );
    }
    final total = PandaliveJson.count(paging['total']);
    if (total == null) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: page.total ${paging['total']}');
    }
    final list = data['list'];
    if (list is! List || list.length > PandaliveEndpoints.maxRows) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: list is not a list of 64 rows');
    }
    return (list, offset + list.length < total, total);
  }

  /// A page of live broadcasts (`live/index`: the directory and the LIVE
  /// search): the live cards, a broadcaster once. A row that cannot be a
  /// live card (no broadcaster id, not live) is skipped instead of failing
  /// the page.
  static ({List<LiveRoom> rooms, bool hasMore, int? total}) livePage(
    String body, {
    required int page,
    int size = PandaliveEndpoints.pageSize,
    int status = 200,
  }) {
    const what = 'live/index';
    final data = ok(body, what: what, status: status);
    final (rows, hasMore, total) = PandaliveRoomParser.rows(data, page: page, size: size, what: what);
    final seen = <String>{};
    return (
      rooms: [
        for (final row in rows)
          if (row is Map)
            if (liveCard(PandaliveJson.object(row, what)) case final card? when seen.add(card.roomId.toLowerCase()))
              card,
      ],
      hasMore: hasMore,
      total: total,
    );
  }

  /// A page of the BJ search (`live/bj_list`): broadcasters live or not. A
  /// row the card rules refuse (blocked, no id, another broadcaster's
  /// `media`) is skipped.
  static ({List<LiveRoom> rooms, bool hasMore, int? total}) broadcasterPage(
    String body, {
    required int page,
    required int size,
    int status = 200,
  }) {
    const what = 'live/bj_list';
    final data = ok(body, what: what, status: status);
    final (rows, hasMore, total) = PandaliveRoomParser.rows(data, page: page, size: size, what: what);
    return (
      rooms: [
        for (final row in rows)
          if (row is Map) ?profileCard(PandaliveJson.object(row, what)),
      ],
      hasMore: hasMore,
      total: total,
    );
  }

  // Master and variants ---------------------------------------------------

  /// A master playlist answer: its text, or the failure. The master is part
  /// of the broadcast, so a missing one (404) means the stream is gone; its
  /// token is single use, so a second read is refused (403).
  static String master(String body, {int status = 200}) {
    const what = 'IVS master';
    if (status == 404) {
      throw const PandaliveFailure(PandaliveFailureKind.streamUnavailable, '$what: HTTP 404');
    }
    if (status == 400) {
      throw const PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: HTTP 400');
    }
    PandaliveJson.checkBody(body, what, status, limit: PandaliveEndpoints.manifestLimit);
    return body;
  }

  /// The streams of an IVS master read once (3.x's `parseManifest`): one
  /// per video variant, id `<height>p`, plus `60` from 50 fps (a repeated
  /// id still gets `_<n>`, n counting the video variants in the master's
  /// order); the source rendition (`VIDEO="chunked"`, the master's video
  /// group) named 原画, the others by their id. Best first: the source, then
  /// by height, frame rate, bandwidth. Each stream's line is the variant
  /// playlist, with the media headers, HLS, the codec of `CODECS`, the
  /// line label `ivs` and the lease of [issuedAt] (see [lease]).
  ///
  /// The master is read by the shared HLS parser. A text that is not a
  /// master is api-changed, and a variant without a resolution (audio only)
  /// is left out. A variant without its URI, with a frame rate out of
  /// range, or whose URL is not IVS only loses itself; none left is
  /// api-changed when some were such, else stream-unavailable.
  static List<PandaliveStream> qualities(
    String body, {
    required Uri master,
    required String userId,
    required DateTime issuedAt,
  }) {
    const what = 'IVS master';
    if (mediaUrl('$master') == null) {
      throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: $master is not an IVS playlist');
    }
    final parsed = parseHlsMaster(body, masterUrl: master);
    if (parsed == null) {
      throw const PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: not a playlist');
    }
    final variants =
        <({String id, bool source, int height, double frameRate, int bandwidth, Uri url, LiveStreamCodec? codec})>[];
    final ids = <String>{};
    var count = 0;
    String? broken;
    for (final entry in parsed.master.variants) {
      final uri = entry.uri;
      if (uri.toString().isEmpty) {
        broken ??= 'a variant without its URI';
        continue;
      }
      final height = entry.height ?? 0;
      if (height <= 0 || height > 99999) continue;
      final frameRate = entry.frameRate ?? 0;
      final bandwidth = entry.bandwidth;
      if (frameRate < 0 || frameRate > 240) {
        broken ??= 'frame rate $frameRate';
        continue;
      }
      final Uri url;
      try {
        url = resolveHlsVariantUri(uri, master: master);
      } on FormatException {
        broken ??= 'a variant that does not resolve';
        continue;
      }
      final resolved = mediaUrl('$url');
      if (resolved == null) {
        broken ??= 'a variant that is not an IVS playlist';
        continue;
      }
      final label = '${height}p${frameRate >= 50 ? '60' : ''}';
      count++;
      variants.add((
        id: ids.add(label) ? label : '${label}_$count',
        source: (entry.videoGroupId ?? '').toLowerCase() == 'chunked',
        height: height,
        frameRate: frameRate,
        bandwidth: bandwidth,
        url: resolved,
        codec: hlsVideoCodecOf(entry.codecs),
      ));
    }
    if (variants.isEmpty) {
      if (broken != null) {
        throw PandaliveFailure(PandaliveFailureKind.apiChanged, '$what: no usable variant ($broken)');
      }
      throw const PandaliveFailure(PandaliveFailureKind.streamUnavailable, '$what: no video variant');
    }
    variants.sort((left, right) {
      if (left.source != right.source) return left.source ? -1 : 1;
      final height = right.height.compareTo(left.height);
      if (height != 0) return height;
      final fps = right.frameRate.compareTo(left.frameRate);
      return fps != 0 ? fps : right.bandwidth.compareTo(left.bandwidth);
    });
    final headers = PandaliveEndpoints.mediaHeaders(userId);
    final total = variants.length;
    return [
      for (final (index, variant) in variants.indexed)
        (
          quality: LivePlayQuality.of(
            label: variant.source ? PandaliveEndpoints.originalQualityName : variant.id,
            qualityId: variant.id,
            platformOrder: total - index,
            codec: variant.codec,
          ),
          line: LivePlayLine.of(
            url: '${variant.url}',
            format: LiveStreamFormat.hls,
            formatSource: LivePlayFormatSource.declared,
            headers: headers,
            codec: variant.codec,
            lineLabel: PandaliveEndpoints.lineLabel,
            lease: lease(issuedAt),
            geometry: PlayGeometry.of(
              height: variant.height,
              frameRate: variant.frameRate > 0 ? variant.frameRate.round() : null,
              bitrateKbps: variant.bandwidth > 0 ? variant.bandwidth ~/ 1000 : null,
            ),
          ),
        ),
    ];
  }

  /// A variant's lease: renewed [PandaliveEndpoints.variantRefresh] after
  /// `live/play` issued it. The token is opaque, so the expiry is not
  /// known; an expired playlist stops playback, so the renewal cuts over
  /// ([LivePlayLease.requiresReconnect]).
  static LivePlayLease lease(DateTime issuedAt) =>
      LivePlayLease.of(refreshAt: issuedAt.add(PandaliveEndpoints.variantRefresh), requiresReconnect: true);

  /// The id for [id] as a stored preference from the older adapter:
  /// `<height>p30` (25 to 49 fps) is now `<height>p`, and its repeated
  /// `<height>p30_<n>` becomes `<height>p_<n>`; every other id
  /// (`<height>p60`, `<height>p`…) is kept as it is.
  static String qualityIdFromLegacy(String id) {
    final match = RegExp(r'^([1-9][0-9]{1,4})p30(_[0-9]+)?$').firstMatch(id.trim());
    if (match == null) return id.trim();
    return '${match.group(1)}p${match.group(2) ?? ''}';
  }

  /// The stream of [quality] (by its id; an older `<height>p30` id is read
  /// as the new one) among [data]'s streams; a quality the broadcast does
  /// not offer is stream-unavailable, and a room with nothing to play says
  /// why.
  static LivePlayLine line(PandaliveStreamData data, LivePlayQuality quality) {
    if (data.entries.isEmpty) {
      throw data.unavailable ?? const PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'no quality');
    }
    final wanted = qualityIdFromLegacy(quality.qualityId ?? '');
    final match = data.entries.where((entry) => entry.quality.qualityId == wanted).firstOrNull;
    if (match == null) {
      throw PandaliveFailure(PandaliveFailureKind.streamUnavailable, 'quality $wanted is not offered');
    }
    return match.line;
  }

  static String? _blankless(String value) => value.isEmpty ? null : value;
}
