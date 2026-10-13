// The named constructors spell their class name so the identity normalization
// runs; the shorthand cannot carry an initializer list.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/common/headers/site_headers.dart';
import 'package:live_sites/src/common/normalization/site_text.dart';
import 'package:live_sites/src/common/site_ids/site_ids.dart';
import 'package:live_sites/src/models/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/live_area/live_area.dart';
import 'package:live_sites/src/models/live_audience/live_audience.dart';
import 'package:live_sites/src/models/live_audience_metric_type/live_audience_metric_type.dart';
import 'package:live_sites/src/models/live_audience_numbers/live_audience_numbers.dart';
import 'package:live_sites/src/models/live_audience_platform_capability/live_audience_platform_capability.dart';
import 'package:live_sites/src/models/live_audience_rank_key/live_audience_rank_key.dart';
import 'package:live_sites/src/models/live_catch_up/live_catch_up.dart';
import 'package:live_sites/src/models/live_follow_group/live_follow_group.dart';
import 'package:live_sites/src/models/live_guide/live_guide.dart';
import 'package:live_sites/src/models/live_restriction/live_restriction.dart';
import 'package:live_sites/src/models/live_status/live_status.dart';
import 'package:meta/meta.dart';

/// A live room: what lists show, what the room page loads, and what is stored
/// for follows and history.
///
/// Immutable, with identity equality: two rooms are equal when [platform] and
/// [roomId] match (room numbers are unique only within a platform; case is
/// ignored where the platform ignores it, see [identityKey]). Platform and room
/// id are normalized on creation, so the identity used as a map key can never
/// change afterwards.
///
/// Fields a platform response may omit are nullable, and null means "not in
/// this response": [mergeFrom] keeps the stored value then.
///
/// Placeholders: an adapter that does not get the real [nick], [title] or
/// [cover] leaves it empty, never fills in a stand-in. [mergeFrom] keeps a
/// stored value only against an empty one, so a stand-in would overwrite the
/// name a follow stored. The UI shows the platform's name for an empty [nick]
/// ([displayNick]).
@immutable
final class LiveRoom {
  /// Creates a room. [platform] is lower-cased, [roomId] trimmed and
  /// [startedAt] converted to UTC; [title], [nick], [introduction] and [notice]
  /// lose invisible placeholder characters
  /// ([SiteText.stripInvisiblePlaceholders], such as Kuaishou's U+FFFC).
  LiveRoom({
    String? roomId,
    String? platform,
    this.anchor,
    this.link,
    this.nativeLink,
    String title = '',
    this.cover = '',
    this.area,
    String watching = '0',
    LiveAudienceMetricType? audienceMetricType,
    String popularity = '',
    String onlineViewers = '',
    String totalViewers = '',
    this.liveStatus,
    DateTime? startedAt,
    this.restriction,
    String? introduction,
    String? notice,
    this.data,
    this.danmakuData,
    String? epgId,
    String currentProgramme = '',
    String? currentProgrammeDescription,
    LiveCatchUp catchUp = const LiveCatchUp(),
    Map<String, String> httpHeaders = const {},
    this.lastWatchedAt,
    List<String> tagIds = const [],
  }) : roomId = roomId?.trim() ?? '',
       platform = platform?.trim().toLowerCase() ?? 'unknown',
       title = SiteText.stripInvisiblePlaceholders(title),
       introduction = SiteText.stripInvisiblePlaceholdersOrNull(introduction),
       notice = SiteText.stripInvisiblePlaceholdersOrNull(notice),
       audience = LiveAudience(
         watching: watching,
         metricType: audienceMetricType,
         popularity: popularity,
         onlineViewers: onlineViewers,
         totalViewers: totalViewers,
       ),
       guide = LiveGuide(
         epgId: epgId,
         currentProgramme: currentProgramme,
         currentProgrammeDescription: currentProgrammeDescription,
         catchUp: catchUp,
         httpHeaders: SiteHeaders.normalize(httpHeaders),
       ),
       startedAt = startedAt?.toUtc(),
       tagIds = List.unmodifiable(tagIds);

  /// Reads the JSON stored for follows, history and backups.
  ///
  /// - Without `liveStatus`, the status comes from the old `status` and
  ///   `isRecord` booleans; with it, the index is authoritative (a stale
  ///   `status: true` once kept an ended room painted as live).
  /// - `isRecord: true` means [LiveStatus.replay].
  /// - Earlier builds stored Huya's popularity as concurrent viewers; it is
  ///   moved back to [popularity].
  /// - `startedAt` (ISO 8601, or epoch milliseconds) and `restriction` (a
  ///   [LiveRestriction] name) are the newer keys; a record without them has
  ///   neither.
  factory LiveRoom.fromJson(Map<String, Object?> json) {
    String? text(String key) => json[key]?.toString();
    final platform = text('platform') ?? 'UNKNOWN';
    var watching = text('watching') ?? '0';
    LiveAudienceMetricType? metric;
    for (final value in LiveAudienceMetricType.values) {
      if (value.name == json['audienceMetricType']) {
        metric = value;
        break;
      }
    }
    var popularity = text('popularity') ?? '';
    var online = text('onlineViewers') ?? '';
    if (platform.trim().toLowerCase() == 'huya' && hasExplicitAudienceValue(online)) {
      if (!hasAudienceValue(popularity)) popularity = online;
      online = '';
      metric = LiveAudienceMetricType.popularity;
      watching = popularity;
    }
    final headers = json['httpHeaders'];
    final tags = json['tagIds'];
    final watched = json['lastWatchedAt'];
    return LiveRoom(
      roomId: text('roomId') ?? '',
      platform: platform,
      anchor: _anchorFromJson(json, platform),
      link: text('link') ?? '',
      nativeLink: text('nativeLink') ?? '',
      title: text('title') ?? '',
      cover: text('cover') ?? '',
      area: _areaFromJson(json['area'], platform),
      watching: watching,
      audienceMetricType: metric ?? LiveAudienceMetricType.unknown,
      popularity: popularity,
      onlineViewers: online,
      totalViewers: text('totalViewers') ?? '',
      liveStatus: _statusFromJson(json),
      startedAt: _timeFromJson(json['startedAt']),
      restriction: json['restriction'] == null ? null : LiveRestriction.fromName(json['restriction']),
      notice: text('notice') ?? '',
      introduction: text('introduction') ?? '',
      epgId: text('epgId') ?? '',
      currentProgramme: text('currentProgramme') ?? '',
      currentProgrammeDescription: text('currentProgrammeDescription') ?? '',
      catchUp: LiveCatchUp(
        url: text('catchUpUrl'),
        active: json['isCatchUp'] == true,
        start: _int(json['catchUpStart']),
        end: _int(json['catchUpEnd']),
        mode: text('catchUpMode'),
        source: text('catchUpSource'),
        days: _finiteDouble(json['catchUpDays']),
        correctionHours: _finiteDouble(json['catchUpCorrectionHours']),
      ),
      httpHeaders: headers is Map ? SiteHeaders.normalize(headers) : const {},
      lastWatchedAt: watched is num ? watched.toInt() : null,
      tagIds: tags is List ? [for (final tag in tags) '$tag'] : const [],
    );
  }

  /// Platform id, lower case.
  final String platform;

  /// Room id within the platform.
  final String roomId;

  /// The broadcaster this room belongs to, when the platform names one. The
  /// room's [userId], [nick], [avatar] and [followers] read through to it.
  final LiveAnchor? anchor;

  /// Web link to the room.
  final String? link;

  /// The platform's app-launch scheme for this room (for example
  /// `bilibili://live/23058`), the link that opens the room in the platform's
  /// own app. Distinct from [link], the web page: a user who wants to share
  /// "open in the app" needs this, and not every platform provides one.
  final String? nativeLink;

  /// Room title.
  final String title;

  /// Cover URL.
  final String cover;

  /// The room's area (its category node), when the platform names one.
  final LiveArea? area;

  /// The audience figures the platform reported, as one snapshot.
  final LiveAudience audience;

  /// The single audience field of older records and backups; `'0'` is the old
  /// default and not a measurement.
  String get watching => audience.watching;

  /// What the platform's main audience number means; null when not given.
  LiveAudienceMetricType? get audienceMetricType => audience.metricType;

  /// Popularity or heat; not a head count.
  String get popularity => audience.popularity;

  /// Concurrent viewers, when the platform exposes an explicit value.
  String get onlineViewers => audience.onlineViewers;

  /// Cumulative viewers of the current session.
  String get totalViewers => audience.totalViewers;

  /// Broadcast state; null when the response did not say.
  final LiveStatus? liveStatus;

  /// When the current broadcast (or the replayed one) started, UTC; null when
  /// the response did not say or the room is not on.
  final DateTime? startedAt;

  /// What keeps the current broadcast from simply playing. Null means the
  /// response did not say; [LiveRestriction.none] means the platform was
  /// checked and there is no restriction.
  final LiveRestriction? restriction;

  /// Room introduction.
  final String? introduction;

  /// Room notice.
  final String? notice;

  /// Platform data needed to resolve streams; never stored.
  final Object? data;

  /// Platform data needed to connect danmaku; never stored.
  final Object? danmakuData;

  /// The IPTV guide state: channel, programme on air, catch-up and headers.
  final LiveGuide guide;

  /// IPTV: guide channel id.
  String? get epgId => guide.epgId;

  /// IPTV: programme on air.
  String get currentProgramme => guide.currentProgramme;

  /// IPTV: description of the programme on air.
  String? get currentProgrammeDescription => guide.currentProgrammeDescription;

  /// IPTV: catch-up playback.
  LiveCatchUp get catchUp => guide.catchUp;

  /// IPTV: headers the channel's media requests need, normalized.
  Map<String, String> get httpHeaders => guide.httpHeaders;

  /// Last time this room was watched, epoch milliseconds (history).
  final int? lastWatchedAt;

  /// Tags of a followed room (local only).
  final List<String> tagIds;

  /// `platform:roomId`, the identity used by follows, tags and merges; see
  /// [identityKeyFor]. [roomId] itself keeps the spelling it was created with.
  String get identityKey => identityKeyFor(platform: platform, roomId: roomId);

  /// Whether [other] is the same room.
  bool hasSameIdentity(LiveRoom other) => identityKey == other.identityKey;

  /// Whether this is [platform]'s room [roomId], compared as [identityKeyFor]
  /// does.
  bool hasIdentity({required String platform, required String roomId}) =>
      identityKey == identityKeyFor(platform: platform, roomId: roomId);

  /// The identity of [platform]'s room [roomId]: `platform:roomId` with the
  /// platform lower-cased and the room id trimmed, and the room id also
  /// lower-cased on platforms whose room ids are user names the platform
  /// matches without regard to case ([SiteIds.ignoresRoomIdCase]). Elsewhere
  /// case is significant (a YouTube video id, for example).
  static String identityKeyFor({required String platform, required String roomId}) {
    final site = platform.trim().toLowerCase();
    final id = roomId.trim();
    return '$site:${SiteIds.ignoresRoomIdCase(site) ? id.toLowerCase() : id}';
  }

  /// The state used for display and playback: unknown when not given.
  LiveStatus get effectiveLiveStatus => liveStatus ?? LiveStatus.unknown;

  /// Broadcasting now (restricted or not).
  bool get isLiveNow => effectiveLiveStatus == LiveStatus.live;

  /// Live or replay: something can be played. A restriction does not change
  /// this (playback explains it); a carousel is not playable.
  bool get isPlayableNow => isLiveNow || effectiveLiveStatus == LiveStatus.replay;

  /// The platform said offline, banned or carousel (the streamer is off).
  bool get isExplicitlyOfflineNow => switch (effectiveLiveStatus) {
    LiveStatus.offline || LiveStatus.banned || LiveStatus.carousel => true,
    LiveStatus.live || LiveStatus.replay || LiveStatus.unknown => false,
  };

  /// The restriction, or [LiveRestriction.none] when the response did not say.
  LiveRestriction get effectiveRestriction => restriction ?? LiveRestriction.none;

  /// Whether a restriction is known (for the card's mark).
  bool get isRestricted => effectiveRestriction != LiveRestriction.none;

  /// Where the follow page lists this room: live rooms (restricted or not) as
  /// live, playable replays as replay, everything else as offline, including a
  /// carousel and a replay marked [LiveRestriction.unplayable].
  LiveFollowGroup get followGroup => switch (effectiveLiveStatus) {
    LiveStatus.live => LiveFollowGroup.live,
    LiveStatus.replay when restriction != LiveRestriction.unplayable => LiveFollowGroup.replay,
    _ => LiveFollowGroup.offline,
  };

  /// The broadcaster's id on the platform, or '' when the room names none.
  String get userId => anchor?.anchorId ?? '';

  /// The broadcaster's display name, with invisible placeholders removed.
  String get nick => anchor == null ? '' : SiteText.stripInvisiblePlaceholders(anchor!.name);

  /// The broadcaster's avatar URL, or '' when the anchor gives none.
  String get avatar => anchor?.avatar ?? '';

  /// The broadcaster's follower count as text; `'0'` when none is known.
  String get followers {
    final count = anchor?.followerCount;
    return count == null || count <= 0 ? '0' : '$count';
  }

  /// Whether the platform gave a streamer name.
  bool get hasNick => nick.trim().isNotEmpty;

  /// The streamer name to show: [nick], or [platformName] when it is empty. The
  /// platform's display name is localized by the UI, so the caller passes it in.
  String displayNick(String platformName) => hasNick ? nick.trim() : platformName;

  /// The state is not known yet.
  bool get isLiveStatusPending => effectiveLiveStatus == LiveStatus.unknown;

  /// Playing a recording or replay.
  bool get isRecord => effectiveLiveStatus == LiveStatus.replay;

  /// IPTV: a time-shifted programme is playing.
  bool get isCatchUpActive => catchUp.isActive;

  /// The audience metric meaning, falling back to the platform's usual one.
  LiveAudienceMetricType get effectiveAudienceMetricType {
    final given = audienceMetricType;
    if (given != null && given != LiveAudienceMetricType.unknown) return given;
    return switch (platform) {
      'bilibili' || 'douyu' || 'huya' || 'cc' || 'yy' || 'missevan' => LiveAudienceMetricType.popularity,
      'kuaishou' || 'twitch' || 'soop' => LiveAudienceMetricType.onlineViewers,
      'douyin' => LiveAudienceMetricType.totalViewers,
      _ => LiveAudienceMetricType.unknown,
    };
  }

  /// Popularity, falling back to [watching] when that is what it holds.
  String get effectivePopularity {
    if (hasAudienceValue(popularity)) return popularity.trim();
    return effectiveAudienceMetricType == LiveAudienceMetricType.popularity ? watching.trim() : '';
  }

  /// Concurrent viewers, falling back to a positive [watching] when that is what
  /// it holds (the old `'0'` default is not a count; an adapter that really saw
  /// zero writes it to [onlineViewers]).
  String get effectiveOnlineViewers {
    if (hasExplicitAudienceValue(onlineViewers)) return onlineViewers.trim();
    return effectiveAudienceMetricType == LiveAudienceMetricType.onlineViewers && hasAudienceValue(watching)
        ? watching.trim()
        : '';
  }

  /// Cumulative viewers, falling back to [watching] when that is what it holds.
  String get effectiveTotalViewers {
    if (hasAudienceValue(totalViewers)) return totalViewers.trim();
    return effectiveAudienceMetricType == LiveAudienceMetricType.totalViewers ? watching.trim() : '';
  }

  /// The platform's audience metrics.
  LiveAudiencePlatformCapability get audienceCapability => LiveAudiencePlatformCapability.of(platform);

  /// Whether the platform has a concurrent-viewer count at all, whether or not
  /// this room has received it yet.
  bool get supportsRealOnlineCount => audienceCapability.supportsConcurrentOnline;

  /// Whether this room has an explicit concurrent-viewer count.
  bool get hasRealOnlineCount => hasExplicitAudienceValue(effectiveOnlineViewers);

  /// The audience text to show. With [preferRealOnline] on a platform that has
  /// concurrent viewers and is [platformEnabled], only the concurrent count is
  /// shown (empty while pending); otherwise popularity, then cumulative, then
  /// concurrent, then the old field unless it is the `'0'` default of an unknown
  /// metric.
  String audienceValue({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) {
      return hasRealOnlineCount ? effectiveOnlineViewers : '';
    }
    if (hasAudienceValue(effectivePopularity)) return effectivePopularity;
    if (hasAudienceValue(effectiveTotalViewers)) return effectiveTotalViewers;
    if (hasRealOnlineCount) return effectiveOnlineViewers;
    final legacy = watching.trim();
    if (effectiveAudienceMetricType == LiveAudienceMetricType.unknown && !hasAudienceValue(legacy)) return '';
    return legacy;
  }

  /// What [audienceValue] means, for its label.
  LiveAudienceMetricType audienceType({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) return LiveAudienceMetricType.onlineViewers;
    if (hasAudienceValue(effectivePopularity)) return LiveAudienceMetricType.popularity;
    if (hasAudienceValue(effectiveTotalViewers)) return LiveAudienceMetricType.totalViewers;
    if (hasRealOnlineCount) return LiveAudienceMetricType.onlineViewers;
    return effectiveAudienceMetricType;
  }

  /// [audienceValue] as a number; -1 in concurrent mode for a platform that has
  /// no concurrent count, so heat never outranks real viewers.
  int audienceSortValue({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && (!platformEnabled || !supportsRealOnlineCount)) return -1;
    return parseAudienceNumber(audienceValue(preferRealOnline: preferRealOnline, platformEnabled: platformEnabled));
  }

  /// The ranking key; see [LiveAudienceRankKey].
  LiveAudienceRankKey audienceRankKey({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) {
      return LiveAudienceRankKey(
        metricPriority: hasRealOnlineCount ? 3 : 2,
        value: hasRealOnlineCount ? parseAudienceNumber(effectiveOnlineViewers) : 0,
      );
    }
    final native = audienceValue(preferRealOnline: false, platformEnabled: false);
    return LiveAudienceRankKey(
      metricPriority: hasExplicitAudienceValue(native) ? 1 : 0,
      value: parseAudienceNumber(native),
    );
  }

  /// Orders rooms by audience (largest first), then by identity so equal or
  /// pending values never shuffle cards on refresh.
  static int compareAudienceRanking(
    LiveRoom left,
    LiveRoom right, {
    required bool preferRealOnline,
    required bool Function(String platform) platformEnabled,
  }) {
    final leftKey = left.audienceRankKey(
      preferRealOnline: preferRealOnline,
      platformEnabled: platformEnabled(left.platform),
    );
    final rightKey = right.audienceRankKey(
      preferRealOnline: preferRealOnline,
      platformEnabled: platformEnabled(right.platform),
    );
    final tier = rightKey.metricPriority.compareTo(leftKey.metricPriority);
    if (tier != 0) return tier;
    final value = rightKey.value.compareTo(leftKey.value);
    if (value != 0) return value;
    return left.identityKey.compareTo(right.identityKey);
  }

  /// This room with [fallback]'s audience where this one has none, or where
  /// Bilibili's detail transiently answers `1` for a busy room (the header would
  /// jump from hundreds of thousands to one). A later plausible heartbeat is
  /// still accepted. Rooms of another identity are ignored.
  LiveRoom withAudienceFallbackFrom(LiveRoom fallback) {
    if (!hasSameIdentity(fallback)) return this;
    final current = effectivePopularity;
    final previous = fallback.effectivePopularity;
    final currentCount = parseAudienceNumber(current);
    final previousCount = parseAudienceNumber(previous);
    final bilibiliDrop =
        platform == 'bilibili' && previousCount >= 1000 && currentCount <= 1 && currentCount * 100 < previousCount;
    final useFallback = !hasAudienceValue(current) || bilibiliDrop;
    final mergedPopularity = useFallback ? previous : current;
    final mergedMetric = useFallback ? fallback.effectiveAudienceMetricType : effectiveAudienceMetricType;
    return copyWith(
      watching: mergedMetric == LiveAudienceMetricType.popularity && hasAudienceValue(mergedPopularity)
          ? mergedPopularity
          : watching,
      popularity: mergedPopularity,
      onlineViewers: hasExplicitAudienceValue(onlineViewers) ? onlineViewers : fallback.onlineViewers,
      totalViewers: hasAudienceValue(totalViewers) ? totalViewers : fallback.totalViewers,
      audienceMetricType: mergedMetric,
    );
  }

  /// A fresh detail [incoming] applied without losing local data.
  ///
  /// Responses are sparse: an omitted state, title or audience means "not in
  /// this response", not "offline" or "erase". An empty name, title or cover
  /// keeps the stored one. Tags stay local; IPTV headers come from the playlist.
  /// Rooms of another identity are ignored.
  ///
  /// [startedAt] and [restriction] describe one broadcast. The incoming value
  /// wins whenever it is given ([LiveRestriction.none] clears a stored
  /// restriction). An omitted one keeps the stored value while [incoming] reports
  /// no other state; once the state changes it becomes null (not known), so a
  /// later broadcast never shows the last one's start time or restriction.
  LiveRoom mergeFrom(LiveRoom incoming) {
    if (!hasSameIdentity(incoming)) return this;
    String prefer(String incoming, String current) => incoming.trim().isEmpty ? current : incoming;
    String? preferNullable(String? incoming, String? current) =>
        incoming == null || incoming.trim().isEmpty ? current : incoming;
    final given = incoming.audienceMetricType;
    final sameBroadcast = switch ((liveStatus, incoming.liveStatus)) {
      (_, null || LiveStatus.unknown) || (null || LiveStatus.unknown, _) => true,
      (final current, final next) => current == next,
    };
    return LiveRoom(
      roomId: roomId,
      platform: platform,
      anchor: _mergedAnchor(incoming.anchor, anchor),
      link: preferNullable(incoming.link, link),
      nativeLink: preferNullable(incoming.nativeLink, nativeLink),
      title: prefer(incoming.title, title),
      cover: prefer(incoming.cover, cover),
      area: incoming.area ?? area,
      watching: prefer(incoming.watching, watching),
      audienceMetricType: given != null && given != LiveAudienceMetricType.unknown ? given : audienceMetricType,
      popularity: prefer(incoming.popularity, popularity),
      onlineViewers: prefer(incoming.onlineViewers, onlineViewers),
      totalViewers: prefer(incoming.totalViewers, totalViewers),
      liveStatus: incoming.liveStatus ?? liveStatus,
      startedAt: incoming.startedAt ?? (sameBroadcast ? startedAt : null),
      restriction: incoming.restriction ?? (sameBroadcast ? restriction : null),
      introduction: preferNullable(incoming.introduction, introduction),
      notice: preferNullable(incoming.notice, notice),
      data: incoming.data ?? data,
      danmakuData: incoming.danmakuData ?? danmakuData,
      epgId: preferNullable(incoming.epgId, epgId),
      currentProgramme: prefer(incoming.currentProgramme, currentProgramme),
      currentProgrammeDescription: preferNullable(incoming.currentProgrammeDescription, currentProgrammeDescription),
      catchUp: LiveCatchUp(
        url: preferNullable(incoming.catchUp.url, catchUp.url),
        active: incoming.catchUp.active,
        start: incoming.catchUp.start ?? catchUp.start,
        end: incoming.catchUp.end ?? catchUp.end,
        mode: preferNullable(incoming.catchUp.mode, catchUp.mode),
        source: preferNullable(incoming.catchUp.source, catchUp.source),
        days: incoming.catchUp.days ?? catchUp.days,
        correctionHours: incoming.catchUp.correctionHours ?? catchUp.correctionHours,
      ),
      httpHeaders: incoming.platform == 'iptv' ? incoming.httpHeaders : httpHeaders,
      lastWatchedAt: incoming.lastWatchedAt ?? lastWatchedAt,
      tagIds: tagIds,
    );
  }

  /// After a failed detail request: identity and metadata stay, the state
  /// becomes pending (a failed request is no evidence the broadcast ended) and
  /// the `'0'` default audience is dropped.
  LiveRoom pendingAfterError() =>
      copyWith(liveStatus: LiveStatus.unknown, watching: watching.trim() == '0' ? '' : watching);

  /// Back to the live stream: the played catch-up interval is removed as one
  /// snapshot, so a later guide render never highlights a retired programme.
  LiveRoom withoutCatchUp() => copyWith(catchUp: catchUp.withoutInterval());

  /// Title, area, name, avatar and cover from [detail] where this room has none
  /// (blank counts as none). [detail] is the card the room was entered from, so
  /// the history entry, the audio-only cover, the mini player and the
  /// notification keep a title or cover the room page itself does not give.
  LiveRoom fillFromDetail(LiveRoom? detail) {
    if (detail == null) return this;
    return copyWith(
      title: title.trim().isEmpty && detail.title.trim().isNotEmpty ? detail.title : title,
      area: (area?.areaName ?? '').isEmpty ? detail.area : area,
      anchor: anchor ?? detail.anchor,
      cover: cover.trim().isEmpty ? detail.cover : cover,
    );
  }

  /// A copy with the given fields replaced (identity cannot change).
  LiveRoom copyWith({
    LiveAnchor? anchor,
    String? link,
    String? nativeLink,
    String? title,
    String? cover,
    LiveArea? area,
    String? watching,
    LiveAudienceMetricType? audienceMetricType,
    String? popularity,
    String? onlineViewers,
    String? totalViewers,
    LiveStatus? liveStatus,
    DateTime? startedAt,
    LiveRestriction? restriction,
    String? introduction,
    String? notice,
    Object? data,
    Object? danmakuData,
    String? epgId,
    String? currentProgramme,
    String? currentProgrammeDescription,
    LiveCatchUp? catchUp,
    Map<String, String>? httpHeaders,
    int? lastWatchedAt,
    List<String>? tagIds,
  }) => LiveRoom(
    roomId: roomId,
    platform: platform,
    anchor: anchor ?? this.anchor,
    link: link ?? this.link,
    nativeLink: nativeLink ?? this.nativeLink,
    title: title ?? this.title,
    cover: cover ?? this.cover,
    area: area ?? this.area,
    watching: watching ?? this.watching,
    audienceMetricType: audienceMetricType ?? this.audienceMetricType,
    popularity: popularity ?? this.popularity,
    onlineViewers: onlineViewers ?? this.onlineViewers,
    totalViewers: totalViewers ?? this.totalViewers,
    liveStatus: liveStatus ?? this.liveStatus,
    startedAt: startedAt ?? this.startedAt,
    restriction: restriction ?? this.restriction,
    introduction: introduction ?? this.introduction,
    notice: notice ?? this.notice,
    data: data ?? this.data,
    danmakuData: danmakuData ?? this.danmakuData,
    epgId: epgId ?? this.epgId,
    currentProgramme: currentProgramme ?? this.currentProgramme,
    currentProgrammeDescription: currentProgrammeDescription ?? this.currentProgrammeDescription,
    catchUp: catchUp ?? this.catchUp,
    httpHeaders: httpHeaders ?? this.httpHeaders,
    lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    tagIds: tagIds ?? this.tagIds,
  );

  /// The JSON stored for follows, history and backups. `status` and `isRecord`
  /// are derived from the canonical state, so a restored backup never carries a
  /// contradiction. `nativeLink` is written for an app-shared room. `data` and
  /// [danmakuData] are transient and never stored.
  Map<String, Object?> toJson() => {
    'roomId': roomId,
    'userId': userId,
    'link': link,
    'nativeLink': nativeLink,
    'title': title,
    'nick': nick,
    'avatar': avatar,
    'cover': cover,
    'area': area?.toJson(),
    'watching': watching,
    'audienceMetricType': effectiveAudienceMetricType.name,
    'popularity': popularity,
    'onlineViewers': onlineViewers,
    'totalViewers': totalViewers,
    'followers': followers,
    'platform': platform,
    'tagIds': tagIds,
    'liveStatus': effectiveLiveStatus.index,
    'isRecord': isRecord,
    'status': isLiveNow,
    if (startedAt case final at?) 'startedAt': at.toIso8601String(),
    if (restriction case final kind?) 'restriction': kind.name,
    'notice': notice,
    'introduction': introduction,
    'epgId': epgId,
    'currentProgramme': currentProgramme,
    'currentProgrammeDescription': currentProgrammeDescription,
    'catchUpUrl': catchUp.url,
    'isCatchUp': catchUp.active,
    'catchUpStart': catchUp.start,
    'catchUpEnd': catchUp.end,
    'catchUpMode': catchUp.mode,
    'catchUpSource': catchUp.source,
    'catchUpDays': catchUp.days,
    'catchUpCorrectionHours': catchUp.correctionHours,
    'httpHeaders': httpHeaders,
    'lastWatchedAt': lastWatchedAt,
  };

  static LiveStatus _statusFromJson(Map<String, Object?> json) {
    if (json['isRecord'] == true) return LiveStatus.replay;
    final raw = json['liveStatus'];
    final index = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (index != null && index >= 0 && index < LiveStatus.values.length) return LiveStatus.values[index];
    return switch (json['status']) {
      true => LiveStatus.live,
      false => LiveStatus.offline,
      _ => LiveStatus.unknown,
    };
  }

  /// An ISO 8601 text (without an offset it is UTC, as written) or epoch
  /// milliseconds (a number or a text of digits); anything else, or a time not
  /// after the epoch, is null.
  static DateTime? _timeFromJson(Object? value) {
    final text = value is String ? value.trim() : null;
    final millis = switch (value) {
      num() when value.isFinite && value > 0 && value <= _maxEpochMillis => value.toInt(),
      String() when text != null && _isDigits(text) => int.tryParse(text),
      _ => null,
    };
    if (millis != null) {
      return millis > 0 && millis <= _maxEpochMillis ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true) : null;
    }
    final parsed = text == null || _isDigits(text) ? null : DateTime.tryParse(text);
    if (parsed == null) return null;
    final utc = parsed.isUtc
        ? parsed
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );
    return utc.millisecondsSinceEpoch > 0 ? utc : null;
  }

  /// The largest time [DateTime] can hold, epoch milliseconds.
  static const int _maxEpochMillis = 8640000000000000;

  static bool _isDigits(String text) {
    if (text.isEmpty) return false;
    for (final code in text.runes) {
      if (code < 0x30 || code > 0x39) return false;
    }
    return true;
  }

  static int? _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  /// The stored [LiveRoom.area]: a new record writes a `LiveArea` object, an
  /// older one a bare name string; blank or absent is null.
  static LiveArea? _areaFromJson(Object? value, String platform) {
    if (value is Map) {
      return LiveArea.fromJson(value.cast<String, Object?>());
    }
    final name = value?.toString().trim() ?? '';
    return name.isEmpty ? null : LiveArea(platform: platform, areaName: name);
  }

  /// The stored [LiveRoom.anchor]: a record's flat `userId`/`nick`/`avatar`/
  /// `followers` keys become a [LiveAnchor]; a record with none of them has null.
  static LiveAnchor? _anchorFromJson(Map<String, Object?> json, String platform) {
    final anchorId = json['userId']?.toString().trim() ?? '';
    final name = json['nick']?.toString().trim() ?? '';
    final avatar = json['avatar']?.toString().trim() ?? '';
    final followers = parseAudienceNumber(json['followers']?.toString());
    if (anchorId.isEmpty && name.isEmpty && avatar.isEmpty && followers <= 0) return null;
    return LiveAnchor(
      platform: platform.trim().toLowerCase(),
      anchorId: anchorId,
      name: name,
      avatar: avatar,
      followerCount: followers > 0 ? followers : null,
    );
  }

  /// The stored room's anchor after a refresh: [stored] keeps what it has and
  /// [incoming] fills the gaps; null on either side takes the other.
  static LiveAnchor? _mergedAnchor(LiveAnchor? incoming, LiveAnchor? stored) {
    if (incoming == null) return stored;
    if (stored == null) return incoming;
    return stored.mergedWith(incoming);
  }

  static double? _finiteDouble(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString().trim() ?? '');
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  @override
  bool operator ==(Object other) => other is LiveRoom && other.identityKey == identityKey;

  @override
  int get hashCode => identityKey.hashCode;

  @override
  String toString() => 'LiveRoom($platform:$roomId, ${effectiveLiveStatus.name}, $title)';
}
