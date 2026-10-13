// The named constructors spell their class name so the identity normalization
// runs; the shorthand cannot carry an initializer list.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/common/audience/audience_numbers.dart';
import 'package:live_sites/src/common/headers/site_headers.dart';
import 'package:live_sites/src/common/normalization/site_text.dart';
import 'package:live_sites/src/common/site_ids/site_ids.dart';
import 'package:live_sites/src/models/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/live_area/live_area.dart';
import 'package:live_sites/src/models/live_audience/live_audience.dart';
import 'package:live_sites/src/models/live_audience_metric_type/live_audience_metric_type.dart';
import 'package:live_sites/src/models/live_audience_platform_capability/live_audience_platform_capability.dart';
import 'package:live_sites/src/models/live_audience_rank_key/live_audience_rank_key.dart';
import 'package:live_sites/src/models/live_broadcast/live_broadcast.dart';
import 'package:live_sites/src/models/live_catch_up/live_catch_up.dart';
import 'package:live_sites/src/models/live_follow_group/live_follow_group.dart';
import 'package:live_sites/src/models/live_guide/live_guide.dart';
import 'package:live_sites/src/models/live_restriction/live_restriction.dart';
import 'package:live_sites/src/models/live_room_content/live_room_content.dart';
import 'package:live_sites/src/models/live_room_links/live_room_links.dart';
import 'package:live_sites/src/models/live_room_local/live_room_local.dart';
import 'package:live_sites/src/models/live_room_runtime/live_room_runtime.dart';
import 'package:live_sites/src/models/live_status/live_status.dart';
import 'package:meta/meta.dart';

/// A live room: what lists show, what the room page loads, and what is stored
/// for follows and history.
///
/// Immutable, with identity equality: two rooms are equal when [platform] and
/// [roomId] match. The room is a thin aggregate over the concerns each of which
/// is its own type — [anchor] (the broadcaster), [area] (its category),
/// [audience] (its viewer counts), [guide] (IPTV programme and catch-up),
/// [links] (web and app), [content] (title, cover, introduction, notice),
/// [broadcast] (live state, start, restriction), [runtime] (the transient
/// play/danmaku handles) and [local] (tags and last-watched). The room keeps
/// only identity plus these, and delegates field access to them.
///
/// Fields a platform response may omit are nullable, and null means "not in
/// this response": [mergeFrom] keeps the stored value then.
@immutable
final class LiveRoom {
  /// Creates a room. [platform] is lower-cased, [roomId] trimmed; [title],
  /// [nick], [introduction] and [notice] lose invisible placeholder characters
  /// ([SiteText.stripInvisiblePlaceholders]); [startedAt] becomes UTC.
  LiveRoom({
    String? roomId,
    String? platform,
    this.anchor,
    this.area,
    String title = '',
    String cover = '',
    String? introduction,
    String? notice,
    String? link,
    String? nativeLink,
    String watching = '0',
    LiveAudienceMetricType? audienceMetricType,
    String popularity = '',
    String onlineViewers = '',
    String totalViewers = '',
    LiveStatus? liveStatus,
    DateTime? startedAt,
    LiveRestriction? restriction,
    Object? data,
    Object? danmakuData,
    String? epgId,
    String currentProgramme = '',
    String? currentProgrammeDescription,
    LiveCatchUp catchUp = const LiveCatchUp(),
    Map<String, String> httpHeaders = const {},
    int? lastWatchedAt,
    List<String> tagIds = const [],
    this.createdAt,
    this.updatedAt,
    this.rawData = const {},
  }) : roomId = roomId?.trim() ?? '',
       platform = platform?.trim().toLowerCase() ?? 'unknown',
       links = LiveRoomLinks(link: link, nativeLink: nativeLink),
       content = LiveRoomContent(
         title: SiteText.stripInvisiblePlaceholders(title),
         cover: cover,
         introduction: SiteText.stripInvisiblePlaceholdersOrNull(introduction),
         notice: SiteText.stripInvisiblePlaceholdersOrNull(notice),
       ),
       broadcast = LiveBroadcast(liveStatus: liveStatus, startedAt: startedAt?.toUtc(), restriction: restriction),
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
       runtime = LiveRoomRuntime(streamData: data, danmakuData: danmakuData),
       local = LiveRoomLocal(lastWatchedAt: lastWatchedAt, tagIds: List.unmodifiable(tagIds));

  /// Reads the JSON stored for follows, history and backups.
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
      createdAt: _timeFromJson(json['createdAt']),
      updatedAt: _timeFromJson(json['updatedAt']),
      rawData: switch (json['rawData']) {
        final Map<Object?, Object?> map => map.cast<String, Object?>(),
        _ => const {},
      },
    );
  }

  /// Platform id, lower case.
  final String platform;

  /// Room id within the platform.
  final String roomId;

  /// When this room record was first stored (follow/history/backup), UTC; null
  /// for a transient parse.
  final DateTime? createdAt;

  /// When this room was last refreshed from the platform, UTC.
  final DateTime? updatedAt;

  /// The untouched platform payload this room was parsed from, for debugging and
  /// re-parsing after a schema change; empty when not kept.
  final Map<String, Object?> rawData;

  /// The broadcaster this room belongs to, when the platform names one.
  final LiveAnchor? anchor;

  /// The room's area (its category node), when the platform names one.
  final LiveArea? area;

  /// The audience figures the platform reported.
  final LiveAudience audience;

  /// The IPTV guide state: channel, programme on air, catch-up and headers.
  final LiveGuide guide;

  /// How to reach the room (web and app links).
  final LiveRoomLinks links;

  /// The room's display text (title, cover, introduction, notice).
  final LiveRoomContent content;

  /// The broadcast state (live status, start time, restriction).
  final LiveBroadcast broadcast;

  /// The transient play/danmaku handles; never stored.
  final LiveRoomRuntime runtime;

  /// The per-user local follow state (tags, last watched).
  final LiveRoomLocal local;

  // --- accessors delegating to the concern objects (kept for a stable API) ---

  /// Web link to the room.
  String? get link => links.link;

  /// The platform's app-launch scheme for this room (`bilibili://live/23058`).
  String? get nativeLink => links.nativeLink;

  /// Room title.
  String get title => content.title;

  /// Cover URL.
  String get cover => content.cover;

  /// Room introduction.
  String? get introduction => content.introduction;

  /// Room notice.
  String? get notice => content.notice;

  /// Broadcast state; null when the response did not say.
  LiveStatus? get liveStatus => broadcast.liveStatus;

  /// When the current broadcast started, UTC.
  DateTime? get startedAt => broadcast.startedAt;

  /// What keeps the current broadcast from simply playing.
  LiveRestriction? get restriction => broadcast.restriction;

  /// Platform data needed to resolve streams; never stored.
  Object? get data => runtime.streamData;

  /// Platform data needed to connect danmaku; never stored.
  Object? get danmakuData => runtime.danmakuData;

  /// Last time this room was watched, epoch milliseconds (history).
  int? get lastWatchedAt => local.lastWatchedAt;

  /// Tags of a followed room (local only).
  List<String> get tagIds => local.tagIds;

  /// The single audience field of older records and backups.
  String get watching => audience.watching;

  /// What the platform's main audience number means; null when not given.
  LiveAudienceMetricType? get audienceMetricType => audience.metricType;

  /// Popularity or heat; not a head count.
  String get popularity => audience.popularity;

  /// Concurrent viewers, when the platform exposes an explicit value.
  String get onlineViewers => audience.onlineViewers;

  /// Cumulative viewers of the current session.
  String get totalViewers => audience.totalViewers;

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

  /// `platform:roomId`, the identity used by follows, tags and merges; see
  /// [identityKeyFor].
  String get identityKey => identityKeyFor(platform: platform, roomId: roomId);

  /// Whether [other] is the same room.
  bool hasSameIdentity(LiveRoom other) => identityKey == other.identityKey;

  /// Whether this is [platform]'s room [roomId], compared as [identityKeyFor].
  bool hasIdentity({required String platform, required String roomId}) =>
      identityKey == identityKeyFor(platform: platform, roomId: roomId);

  /// The identity of [platform]'s room [roomId]: `platform:roomId` with the
  /// platform lower-cased and the room id trimmed, and the room id also
  /// lower-cased on platforms whose room ids are user names the platform
  /// matches without regard to case ([SiteIds.ignoresRoomIdCase]).
  static String identityKeyFor({required String platform, required String roomId}) {
    final site = platform.trim().toLowerCase();
    final id = roomId.trim();
    return '$site:${SiteIds.ignoresRoomIdCase(site) ? id.toLowerCase() : id}';
  }

  /// The state used for display and playback: unknown when not given.
  LiveStatus get effectiveLiveStatus => broadcast.effectiveLiveStatus;

  /// Broadcasting now (restricted or not).
  bool get isLiveNow => broadcast.isLiveNow;

  /// Live or replay: something can be played.
  bool get isPlayableNow => broadcast.isPlayableNow;

  /// The platform said offline, banned or carousel (the streamer is off).
  bool get isExplicitlyOfflineNow => broadcast.isExplicitlyOfflineNow;

  /// The restriction, or [LiveRestriction.none] when the response did not say.
  LiveRestriction get effectiveRestriction => broadcast.effectiveRestriction;

  /// Whether a restriction is known (for the card's mark).
  bool get isRestricted => broadcast.isRestricted;

  /// Where the follow page lists this room.
  LiveFollowGroup get followGroup => broadcast.followGroup;

  /// Whether the platform gave a streamer name.
  bool get hasNick => nick.trim().isNotEmpty;

  /// The streamer name to show: [nick], or [platformName] when it is empty.
  String displayNick(String platformName) => hasNick ? nick.trim() : platformName;

  /// The state is not known yet.
  bool get isLiveStatusPending => broadcast.isPending;

  /// Playing a recording or replay.
  bool get isRecord => broadcast.isRecord;

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
  /// it holds.
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

  /// Whether the platform has a concurrent-viewer count at all.
  bool get supportsRealOnlineCount => audienceCapability.supportsConcurrentOnline;

  /// Whether this room has an explicit concurrent-viewer count.
  bool get hasRealOnlineCount => hasExplicitAudienceValue(effectiveOnlineViewers);

  /// The audience text to show.
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
  /// Bilibili's detail transiently answers `1` for a busy room. Rooms of another
  /// identity are ignored.
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

  /// A fresh detail [incoming] applied without losing local data. Responses are
  /// sparse; an omitted value means "not in this response", not "erase".
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
      createdAt: createdAt ?? incoming.createdAt,
      updatedAt: incoming.updatedAt ?? updatedAt,
      rawData: incoming.rawData.isNotEmpty ? incoming.rawData : rawData,
    );
  }

  /// After a failed detail request: identity and metadata stay, the state
  /// becomes pending and the `'0'` default audience is dropped.
  LiveRoom pendingAfterError() =>
      copyWith(liveStatus: LiveStatus.unknown, watching: watching.trim() == '0' ? '' : watching);

  /// Back to the live stream: the played catch-up interval is removed.
  LiveRoom withoutCatchUp() => copyWith(catchUp: catchUp.withoutInterval());

  /// Title, area, name, avatar and cover from [detail] where this room has none.
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
    String? introduction,
    String? notice,
    LiveArea? area,
    String? watching,
    LiveAudienceMetricType? audienceMetricType,
    String? popularity,
    String? onlineViewers,
    String? totalViewers,
    LiveStatus? liveStatus,
    DateTime? startedAt,
    LiveRestriction? restriction,
    Object? data,
    Object? danmakuData,
    String? epgId,
    String? currentProgramme,
    String? currentProgrammeDescription,
    LiveCatchUp? catchUp,
    Map<String, String>? httpHeaders,
    int? lastWatchedAt,
    List<String>? tagIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Object?>? rawData,
  }) => LiveRoom(
    roomId: roomId,
    platform: platform,
    anchor: anchor ?? this.anchor,
    area: area ?? this.area,
    link: link ?? this.link,
    nativeLink: nativeLink ?? this.nativeLink,
    title: title ?? this.title,
    cover: cover ?? this.cover,
    introduction: introduction ?? this.introduction,
    notice: notice ?? this.notice,
    watching: watching ?? this.watching,
    audienceMetricType: audienceMetricType ?? this.audienceMetricType,
    popularity: popularity ?? this.popularity,
    onlineViewers: onlineViewers ?? this.onlineViewers,
    totalViewers: totalViewers ?? this.totalViewers,
    liveStatus: liveStatus ?? this.liveStatus,
    startedAt: startedAt ?? this.startedAt,
    restriction: restriction ?? this.restriction,
    data: data ?? this.data,
    danmakuData: danmakuData ?? this.danmakuData,
    epgId: epgId ?? this.epgId,
    currentProgramme: currentProgramme ?? this.currentProgramme,
    currentProgrammeDescription: currentProgrammeDescription ?? this.currentProgrammeDescription,
    catchUp: catchUp ?? this.catchUp,
    httpHeaders: httpHeaders ?? this.httpHeaders,
    lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    tagIds: tagIds ?? this.tagIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rawData: rawData ?? this.rawData,
  );

  /// The JSON stored for follows, history and backups. `data` and [danmakuData]
  /// are transient and never stored.
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
    if (createdAt case final at?) 'createdAt': at.toIso8601String(),
    if (updatedAt case final at?) 'updatedAt': at.toIso8601String(),
    if (rawData.isNotEmpty) 'rawData': rawData,
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

  static const int _maxEpochMillis = 8640000000000000;

  static bool _isDigits(String text) {
    if (text.isEmpty) return false;
    for (final code in text.runes) {
      if (code < 0x30 || code > 0x39) return false;
    }
    return true;
  }

  static int? _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static LiveArea? _areaFromJson(Object? value, String platform) {
    if (value is Map) {
      return LiveArea.fromJson(value.cast<String, Object?>());
    }
    final name = value?.toString().trim() ?? '';
    return name.isEmpty ? null : LiveArea(platform: platform, areaName: name);
  }

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
