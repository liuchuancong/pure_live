import 'package:pure_live/player/core/live_room_volume_manager.dart';

enum LiveStatus { live, offline, replay, unknown, banned }

enum AudienceMetricType { popularity, onlineViewers, totalViewers, followers, unknown }

enum AudienceOnlineAvailability { unsupported, roomRealtime, roomList }

/// Comparable audience key used when rooms from different platform metric
/// scales appear in one list.
///
/// In concurrent-viewer mode an explicit concurrent value must always rank
/// ahead of a pending value, and a pending supported room must stay ahead of a
/// heat/cumulative fallback. This prevents a multi-million popularity score
/// from outranking a real audience of a few thousand people.
class AudienceRankKey {
  const AudienceRankKey({required this.metricPriority, required this.value});

  final int metricPriority;
  final int value;
}

class AudiencePlatformCapability {
  const AudiencePlatformCapability({
    required this.hasPopularity,
    required this.hasTotalViewers,
    required this.onlineAvailability,
  });

  final bool hasPopularity;
  final bool hasTotalViewers;
  final AudienceOnlineAvailability onlineAvailability;

  bool get supportsConcurrentOnline => onlineAvailability != AudienceOnlineAvailability.unsupported;
  bool get onlineAvailableInRoomLists => onlineAvailability == AudienceOnlineAvailability.roomList;
}

class LiveRoom {
  static const Map<String, AudiencePlatformCapability> audienceCapabilities = {
    // Bilibili's room `online` field and operation-3 heartbeat are popularity;
    // WATCHED_CHANGE is cumulative. Neither is a concurrent head count.
    'bilibili': AudiencePlatformCapability(
      hasPopularity: true,
      hasTotalViewers: true,
      onlineAvailability: AudienceOnlineAvailability.unsupported,
    ),
    'douyu': AudiencePlatformCapability(
      hasPopularity: true,
      hasTotalViewers: false,
      onlineAvailability: AudienceOnlineAvailability.unsupported,
    ),
    // Huya's current website URI 8006 calls the field iAttendeeCount, but live
    // captures stay in the same multi-million popularity range as totalCount.
    // Keep it as heat until the public protocol exposes a distinct head count.
    'huya': AudiencePlatformCapability(
      hasPopularity: true,
      hasTotalViewers: false,
      onlineAvailability: AudienceOnlineAvailability.unsupported,
    ),
    'douyin': AudiencePlatformCapability(
      hasPopularity: false,
      hasTotalViewers: true,
      onlineAvailability: AudienceOnlineAvailability.roomList,
    ),
    'kuaishou': AudiencePlatformCapability(
      hasPopularity: false,
      hasTotalViewers: false,
      onlineAvailability: AudienceOnlineAvailability.roomList,
    ),
    'cc': AudiencePlatformCapability(
      hasPopularity: true,
      hasTotalViewers: false,
      onlineAvailability: AudienceOnlineAvailability.roomList,
    ),
    // Twitch GraphQL exposes viewersCount as the concurrent viewer count in
    // directory, search and room metadata responses.
    'twitch': AudiencePlatformCapability(
      hasPopularity: false,
      hasTotalViewers: false,
      onlineAvailability: AudienceOnlineAvailability.roomList,
    ),
    // SOOP lists expose total_view_cnt/view_cnt as PC + mobile concurrent
    // viewers. current_view_cnt alone is PC-only and must not be displayed as
    // the total audience; player metadata may omit the count altogether.
    'soop': AudiencePlatformCapability(
      hasPopularity: false,
      hasTotalViewers: false,
      onlineAvailability: AudienceOnlineAvailability.roomList,
    ),
    // YY's public `users` value follows the platform popularity scale. No
    // separate concurrent audience field is exposed by the current web API.
    'yy': AudiencePlatformCapability(
      hasPopularity: true,
      hasTotalViewers: false,
      onlineAvailability: AudienceOnlineAvailability.unsupported,
    ),
  };

  static const AudiencePlatformCapability _unknownAudienceCapability = AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.unsupported,
  );

  static AudiencePlatformCapability audienceCapabilityFor(String? platform) =>
      audienceCapabilities[platform?.toLowerCase()] ?? _unknownAudienceCapability;

  String? roomId;
  String? userId = '';
  String? link = '';
  String? title = '';
  String? nick = '';
  String? avatar = '';
  String? cover = '';
  String? area = '';

  /// Legacy single audience field kept for backup compatibility.
  String? watching = '';
  AudienceMetricType? audienceMetricType;

  /// Platform popularity/heat. This is not a head count.
  String? popularity = '';

  /// Concurrent viewers when the platform exposes an explicit value.
  String? onlineViewers = '';

  /// Cumulative viewers for the current live session.
  String? totalViewers = '';
  String? followers = '';
  String? platform = 'UNKNOWN';
  List<String> tagIds = [];

  /// 介绍
  String? introduction;

  /// 公告
  String? notice;

  /// 状态
  bool? status;

  dynamic data;

  dynamic danmakuData;

  /// 是否录播
  bool? isRecord = false;
  // 直播状态
  LiveStatus? liveStatus;

  /// EPG channel id
  String? epgId;

  /// 当前节目
  String? currentProgramme;

  /// 当前节目描述
  String? currentProgrammeDescription;

  String? catchUpUrl; // 时移播放地址
  bool? isCatchUp; // 是否正在时移
  int? catchUpStart; // 时移开始时间戳
  int? catchUpEnd; // 时移结束时间戳

  /// Local epoch-millisecond timestamp used by the viewing-history UI.
  int? lastWatchedAt;

  // 添加未命名的默认构造函数
  LiveRoom({
    this.roomId,
    this.userId,
    this.link,
    this.title = '',
    this.nick = '',
    this.avatar = '',
    this.cover = '',
    this.area,
    this.watching = '0',
    this.audienceMetricType,
    this.popularity = '',
    this.onlineViewers = '',
    this.totalViewers = '',
    this.followers = '0',
    this.platform,
    LiveStatus? liveStatus,
    this.data,
    this.danmakuData,
    this.isRecord = false,
    this.status = false,
    this.notice,
    this.introduction,
    this.epgId,
    this.currentProgramme,
    this.currentProgrammeDescription,
    this.catchUpUrl,
    this.isCatchUp = false,
    this.catchUpStart,
    this.catchUpEnd,
    this.lastWatchedAt,
    List<String>? tagIds,
  }) : liveStatus = liveStatus ?? _legacyStatusToLiveStatus(status: status, isRecord: isRecord),
       tagIds = tagIds ?? [];

  LiveRoom.fromJson(Map<String, dynamic> json)
    : roomId = json['roomId'] ?? '',
      userId = json['userId'] ?? '',
      title = json['title'] ?? '',
      link = json['link'] ?? '',
      nick = json['nick'] ?? '',
      avatar = json['avatar'] ?? '',
      cover = json['cover'] ?? '',
      area = json['area'] ?? '',
      watching = json['watching']?.toString() ?? '0',
      audienceMetricType = AudienceMetricType.values.firstWhere(
        (value) => value.name == json['audienceMetricType'],
        orElse: () => AudienceMetricType.unknown,
      ),
      popularity = json['popularity']?.toString() ?? '',
      onlineViewers = json['onlineViewers']?.toString() ?? '',
      totalViewers = json['totalViewers']?.toString() ?? '',
      followers = json['followers']?.toString() ?? '0',
      platform = json['platform'] ?? 'UNKNOWN',
      tagIds = List<String>.from(json['tagIds'] ?? []),
      liveStatus = _liveStatusFromJson(json),
      status = json['status'] ?? false,
      notice = json['notice'] ?? '',
      introduction = json['introduction'] ?? '',
      isRecord = json['isRecord'] ?? false,
      epgId = json['epgId'] ?? '',
      currentProgramme = json['currentProgramme'] ?? '',
      currentProgrammeDescription = json['currentProgrammeDescription'] ?? '',
      catchUpUrl = json['catchUpUrl'],
      isCatchUp = json['isCatchUp'] ?? false,
      catchUpStart = json['catchUpStart'],
      catchUpEnd = json['catchUpEnd'],
      lastWatchedAt = json['lastWatchedAt'] is num ? (json['lastWatchedAt'] as num).toInt() : null {
    // Earlier builds stored Huya's userCount/URI 8006 popularity in the
    // concurrent-viewer field. Current captures confirm both are popularity.
    if (normalizedPlatformId == 'huya' && _hasExplicitAudienceValue(onlineViewers)) {
      if (!_hasAudienceValue(popularity)) {
        popularity = onlineViewers;
      }
      onlineViewers = '';
      audienceMetricType = AudienceMetricType.popularity;
      watching = popularity;
    }
  }

  /// 创建一个新的LiveRoom实例，并用提供的值更新指定字段
  LiveRoom copyWith({
    String? roomId,
    String? userId,
    String? link,
    String? title,
    String? nick,
    String? avatar,
    String? cover,
    String? area,
    String? watching,
    AudienceMetricType? audienceMetricType,
    String? popularity,
    String? onlineViewers,
    String? totalViewers,
    String? followers,
    String? platform,
    String? introduction,
    String? notice,
    bool? status,
    dynamic data,
    dynamic danmakuData,
    bool? isRecord,
    LiveStatus? liveStatus,
    String? epgId,
    String? currentProgramme,
    String? currentProgrammeDescription,
    String? catchUpUrl,
    bool? isCatchUp,
    int? catchUpStart,
    int? catchUpEnd,
    int? lastWatchedAt,
    List<String>? tagIds,
  }) {
    return LiveRoom(
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      link: link ?? this.link,
      title: title ?? this.title,
      nick: nick ?? this.nick,
      avatar: avatar ?? this.avatar,
      cover: cover ?? this.cover,
      area: area ?? this.area,
      watching: watching ?? this.watching,
      audienceMetricType: audienceMetricType ?? this.audienceMetricType,
      popularity: popularity ?? this.popularity,
      onlineViewers: onlineViewers ?? this.onlineViewers,
      totalViewers: totalViewers ?? this.totalViewers,
      followers: followers ?? this.followers,
      platform: platform ?? this.platform,
      introduction: introduction ?? this.introduction,
      notice: notice ?? this.notice,
      status: status ?? this.status,
      data: data ?? this.data,
      danmakuData: danmakuData ?? this.danmakuData,
      isRecord: isRecord ?? this.isRecord,
      liveStatus: liveStatus ?? this.liveStatus,
      epgId: epgId ?? this.epgId,
      currentProgramme: currentProgramme ?? this.currentProgramme,
      currentProgrammeDescription: currentProgrammeDescription ?? this.currentProgrammeDescription,
      catchUpUrl: catchUpUrl ?? this.catchUpUrl,
      isCatchUp: isCatchUp ?? this.isCatchUp,
      catchUpStart: catchUpStart ?? this.catchUpStart,
      catchUpEnd: catchUpEnd ?? this.catchUpEnd,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      tagIds: tagIds ?? this.tagIds,
    );
  }

  String get normalizedPlatformId => platform?.trim().toLowerCase() ?? '';

  String get normalizedRoomId => roomId?.trim() ?? '';

  /// Canonical room state used by presentation and playback decisions.
  ///
  /// The project historically carried the same fact in both [status] and
  /// [liveStatus]. A number of adapters and persisted favourites only wrote
  /// one of them, so sorting by `status` while painting the badge from
  /// `liveStatus` could label the same room both live and offline. Keep the
  /// legacy boolean readable for backup compatibility, but collapse every
  /// consumer onto this single semantic value.
  ///
  /// New instances and legacy JSON without [liveStatus] derive the enum from
  /// [status] in the constructor/deserializer. Once an enum is present it is
  /// therefore authoritative: letting a stale boolean override an explicit
  /// offline response is exactly how an ended room remained painted as live.
  /// Recording/replay rooms are playable but are not classified as a current
  /// live broadcast.
  LiveStatus get effectiveLiveStatus {
    if (isRecord == true || liveStatus == LiveStatus.replay) {
      return LiveStatus.replay;
    }
    final canonical = liveStatus;
    if (canonical != null) return canonical;
    return _legacyStatusToLiveStatus(status: status, isRecord: isRecord) ?? LiveStatus.unknown;
  }

  bool get isLiveNow => effectiveLiveStatus == LiveStatus.live;

  bool get isPlayableNow =>
      effectiveLiveStatus == LiveStatus.live || effectiveLiveStatus == LiveStatus.replay;

  bool get isExplicitlyOfflineNow =>
      effectiveLiveStatus == LiveStatus.offline || effectiveLiveStatus == LiveStatus.banned;

  bool get isLiveStatusPending => effectiveLiveStatus == LiveStatus.unknown;

  /// Stable room identity used by favourites, tags and refresh merges.
  /// Room numbers are only unique inside one platform.
  String get identityKey => '$normalizedPlatformId:$normalizedRoomId';

  bool hasSameIdentity(LiveRoom other) => identityKey == other.identityKey;

  bool hasIdentity({required String platform, required String roomId}) {
    return normalizedPlatformId == platform.trim().toLowerCase() &&
        normalizedRoomId == roomId.trim();
  }

  LiveRoom normalizedIdentityCopy() {
    if (platform == normalizedPlatformId && roomId == normalizedRoomId) return this;
    return copyWith(platform: normalizedPlatformId, roomId: normalizedRoomId);
  }

  @override
  bool operator ==(covariant LiveRoom other) => hasSameIdentity(other);

  @override
  int get hashCode => identityKey.hashCode;

  @override
  String toString() {
    return 'LiveRoom{roomId: $roomId, userId: $userId, link: $link, title: $title, nick: $nick, avatar: $avatar, cover: $cover, area: $area, watching: $watching, followers: $followers, platform: $platform, tagIds: $tagIds, introduction: $introduction, notice: $notice, status: $status, data: $data, danmakuData: $danmakuData, isRecord: $isRecord, liveStatus: $liveStatus, catchUpUrl: $catchUpUrl, isCatchUp: $isCatchUp, lastWatchedAt: $lastWatchedAt}';
  }

  double getSavedVolume() {
    return LiveRoomVolumeManager.getRoomVolume(platform ?? 'UNKNOWN', roomId ?? '');
  }

  Future<void> saveCurrentVolume(double volume) async {
    await LiveRoomVolumeManager.saveRoomVolume(platform ?? 'UNKNOWN', roomId ?? '', volume);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'roomId': roomId,
      'userId': userId,
      'title': title,
      'nick': nick,
      'avatar': avatar,
      'cover': cover,
      'area': area,
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
      // Persist the canonical state instead of carrying a contradictory legacy
      // boolean into the next process or backup restore.
      'status': isLiveNow,
      'notice': notice,
      'introduction': introduction,
      'epgId': epgId,
      'currentProgramme': currentProgramme,
      'currentProgrammeDescription': currentProgrammeDescription,
      'catchUpUrl': catchUpUrl,
      'isCatchUp': isCatchUp,
      'catchUpStart': catchUpStart,
      'catchUpEnd': catchUpEnd,
      'lastWatchedAt': lastWatchedAt,
    };
  }

  static LiveStatus? _legacyStatusToLiveStatus({required bool? status, required bool? isRecord}) {
    if (isRecord == true) return LiveStatus.replay;
    if (status == true) return LiveStatus.live;
    if (status == false) return LiveStatus.offline;
    // A sparse merge object deliberately uses null to mean "not provided".
    // Preserve that distinction; callers needing an explicit pending state pass
    // LiveStatus.unknown and effectiveLiveStatus still normalizes null to it.
    return null;
  }

  static LiveStatus _liveStatusFromJson(Map<String, dynamic> json) {
    final raw = json['liveStatus'];
    final index = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (index != null && index >= 0 && index < LiveStatus.values.length) {
      return LiveStatus.values[index];
    }
    return _legacyStatusToLiveStatus(
          status: json['status'] is bool ? json['status'] as bool : null,
          isRecord: json['isRecord'] is bool ? json['isRecord'] as bool : null,
        ) ??
        LiveStatus.unknown;
  }

  AudienceMetricType get effectiveAudienceMetricType {
    if (audienceMetricType != null && audienceMetricType != AudienceMetricType.unknown) {
      return audienceMetricType!;
    }
    return switch (normalizedPlatformId) {
      'bilibili' || 'douyu' || 'huya' || 'cc' || 'yy' => AudienceMetricType.popularity,
      'kuaishou' || 'twitch' || 'soop' => AudienceMetricType.onlineViewers,
      'douyin' => AudienceMetricType.totalViewers,
      _ => AudienceMetricType.unknown,
    };
  }

  String get audienceMetricI18nKey => switch (effectiveAudienceMetricType) {
    AudienceMetricType.popularity => 'audience_popularity',
    AudienceMetricType.onlineViewers => 'audience_online',
    AudienceMetricType.totalViewers => 'audience_total',
    AudienceMetricType.followers => 'audience_followers',
    AudienceMetricType.unknown => 'audience_count',
  };

  String get effectivePopularity {
    if (_hasAudienceValue(popularity)) return popularity!.trim();
    return effectiveAudienceMetricType == AudienceMetricType.popularity
        ? (watching ?? '').trim()
        : '';
  }

  String get effectiveOnlineViewers {
    if (_hasExplicitAudienceValue(onlineViewers)) return onlineViewers!.trim();
    // `watching` defaults to the legacy sentinel "0". Treat only a positive
    // legacy value as a populated concurrent count; an adapter that really
    // reports zero writes it to [onlineViewers] explicitly and remains valid.
    return effectiveAudienceMetricType == AudienceMetricType.onlineViewers &&
            _hasAudienceValue(watching)
        ? (watching ?? '').trim()
        : '';
  }

  String get effectiveTotalViewers {
    if (_hasAudienceValue(totalViewers)) return totalViewers!.trim();
    return effectiveAudienceMetricType == AudienceMetricType.totalViewers
        ? (watching ?? '').trim()
        : '';
  }

  AudiencePlatformCapability get audienceCapability => audienceCapabilityFor(platform);

  /// Platform-level capability, independent of whether this particular room
  /// has already received its first list value or realtime heartbeat.
  bool get supportsRealOnlineCount => audienceCapability.supportsConcurrentOnline;

  bool get hasRealOnlineCount => _hasExplicitAudienceValue(effectiveOnlineViewers);

  String audienceValue({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) {
      return hasRealOnlineCount ? effectiveOnlineViewers : '';
    }
    if (_hasAudienceValue(effectivePopularity)) return effectivePopularity;
    if (_hasAudienceValue(effectiveTotalViewers)) return effectiveTotalViewers;
    if (hasRealOnlineCount) return effectiveOnlineViewers;
    return (watching ?? '0').trim();
  }

  AudienceMetricType audienceType({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) {
      return AudienceMetricType.onlineViewers;
    }
    if (_hasAudienceValue(effectivePopularity)) return AudienceMetricType.popularity;
    if (_hasAudienceValue(effectiveTotalViewers)) return AudienceMetricType.totalViewers;
    if (hasRealOnlineCount) return AudienceMetricType.onlineViewers;
    return effectiveAudienceMetricType;
  }

  int audienceSortValue({required bool preferRealOnline, required bool platformEnabled}) {
    // In concurrent mode, native heat/cumulative values must not outrank an
    // actual viewer count merely because their numeric scale is much larger.
    if (preferRealOnline && (!platformEnabled || !supportsRealOnlineCount)) return -1;
    return parseAudienceNumber(
      audienceValue(preferRealOnline: preferRealOnline, platformEnabled: platformEnabled),
    );
  }

  AudienceRankKey audienceRankKey({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) {
      return AudienceRankKey(
        metricPriority: hasRealOnlineCount ? 3 : 2,
        value: hasRealOnlineCount ? parseAudienceNumber(effectiveOnlineViewers) : 0,
      );
    }

    final nativeValue = audienceValue(preferRealOnline: false, platformEnabled: false);
    return AudienceRankKey(
      metricPriority: _hasExplicitAudienceValue(nativeValue) ? 1 : 0,
      value: parseAudienceNumber(nativeValue),
    );
  }

  /// Sorts two rooms by the selected metric policy and then by stable room
  /// identity. The deterministic tie-breaker prevents cards from shuffling on
  /// every refresh when their audience values are equal or still pending.
  static int compareAudienceRanking(
    LiveRoom left,
    LiveRoom right, {
    required bool preferRealOnline,
    required bool Function(String? platform) platformEnabled,
  }) {
    final leftKey = left.audienceRankKey(
      preferRealOnline: preferRealOnline,
      platformEnabled: platformEnabled(left.platform),
    );
    final rightKey = right.audienceRankKey(
      preferRealOnline: preferRealOnline,
      platformEnabled: platformEnabled(right.platform),
    );
    final metricOrder = rightKey.metricPriority.compareTo(leftKey.metricPriority);
    if (metricOrder != 0) return metricOrder;
    final valueOrder = rightKey.value.compareTo(leftKey.value);
    if (valueOrder != 0) return valueOrder;
    return left.identityKey.compareTo(right.identityKey);
  }

  /// Keeps a reliable audience snapshot when a room-detail request or the
  /// first websocket heartbeat omits a metric. Bilibili can transiently return
  /// `1` for a busy room while its list API still has the current popularity;
  /// accepting that value makes the room header jump from hundreds of
  /// thousands to one. A later plausible heartbeat is still accepted.
  LiveRoom withAudienceFallbackFrom(LiveRoom fallback) {
    if (!hasSameIdentity(fallback)) return this;

    final currentPopularity = effectivePopularity;
    final fallbackPopularity = fallback.effectivePopularity;
    final currentPopularityCount = parseAudienceNumber(currentPopularity);
    final fallbackPopularityCount = parseAudienceNumber(fallbackPopularity);
    final hasTransientBilibiliDrop =
        normalizedPlatformId == 'bilibili' &&
        fallbackPopularityCount >= 1000 &&
        currentPopularityCount <= 1 &&
        currentPopularityCount * 100 < fallbackPopularityCount;
    final useFallbackPopularity = !_hasAudienceValue(currentPopularity) || hasTransientBilibiliDrop;

    final mergedPopularity = useFallbackPopularity ? fallbackPopularity : currentPopularity;
    final mergedOnlineViewers = _hasExplicitAudienceValue(onlineViewers)
        ? onlineViewers
        : fallback.onlineViewers;
    final mergedTotalViewers = _hasAudienceValue(totalViewers)
        ? totalViewers
        : fallback.totalViewers;
    final mergedMetricType = useFallbackPopularity
        ? fallback.effectiveAudienceMetricType
        : effectiveAudienceMetricType;
    final mergedWatching =
        mergedMetricType == AudienceMetricType.popularity && _hasAudienceValue(mergedPopularity)
        ? mergedPopularity
        : watching;

    return copyWith(
      watching: mergedWatching,
      popularity: mergedPopularity,
      onlineViewers: mergedOnlineViewers,
      totalViewers: mergedTotalViewers,
      audienceMetricType: mergedMetricType,
    );
  }

  static int parseAudienceNumber(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return 0;
    final normalized = text.replaceAll(',', '').replaceAll('，', '');
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(亿|万|千|[kwm])?').firstMatch(normalized);
    final number = double.tryParse(match?.group(1) ?? '') ?? 0;
    final multiplier = switch (match?.group(2)) {
      '亿' => 100000000,
      '万' || 'w' => 10000,
      '千' || 'k' => 1000,
      'm' => 1000000,
      _ => 1,
    };
    return (number * multiplier).round();
  }

  static bool _hasAudienceValue(String? value) {
    final text = value?.trim() ?? '';
    return text.isNotEmpty && text != 'null' && parseAudienceNumber(text) > 0;
  }

  static bool _hasExplicitAudienceValue(String? value) {
    final text = value?.trim() ?? '';
    return text.isNotEmpty && text != 'null' && RegExp(r'[0-9]').hasMatch(text);
  }
}

extension LiveRoomExtension on LiveRoom {
  /// Applies a fresh room-detail snapshot without discarding local metadata.
  ///
  /// Platform responses are intentionally sparse: an omitted live status,
  /// title or audience field means "unknown in this response", not "offline"
  /// or "erase the stored value". Tags belong to the local favourite and must
  /// never be replaced by network data.
  LiveRoom mergeFrom(LiveRoom incoming) {
    if (!hasSameIdentity(incoming)) return this;

    return copyWith(
      roomId: incoming.normalizedRoomId,
      platform: incoming.normalizedPlatformId,
      userId: _preferValue(incoming.userId, userId),
      link: _preferValue(incoming.link, link),
      title: _preferValue(incoming.title, title),
      nick: _preferValue(incoming.nick, nick),
      avatar: _preferValue(incoming.avatar, avatar),
      cover: _preferValue(incoming.cover, cover),
      area: _preferValue(incoming.area, area),

      watching: _preferValue(incoming.watching, watching),
      audienceMetricType:
          incoming.audienceMetricType != null &&
              incoming.audienceMetricType != AudienceMetricType.unknown
          ? incoming.audienceMetricType
          : audienceMetricType,
      popularity: _preferValue(incoming.popularity, popularity),
      onlineViewers: _preferValue(incoming.onlineViewers, onlineViewers),
      totalViewers: _preferValue(incoming.totalViewers, totalViewers),
      followers: _preferValue(incoming.followers, followers),

      tagIds: tagIds,

      introduction: _preferValue(incoming.introduction, introduction),
      notice: _preferValue(incoming.notice, notice),

      status: incoming.status ?? status,
      liveStatus: incoming.liveStatus ?? liveStatus,
      isRecord: incoming.isRecord ?? isRecord,

      data: incoming.data ?? data,
      danmakuData: incoming.danmakuData ?? danmakuData,

      epgId: _preferValue(incoming.epgId, epgId),
      currentProgramme: _preferValue(incoming.currentProgramme, currentProgramme),
      currentProgrammeDescription: _preferValue(
        incoming.currentProgrammeDescription,
        currentProgrammeDescription,
      ),

      catchUpUrl: _preferValue(incoming.catchUpUrl, catchUpUrl),
      isCatchUp: incoming.isCatchUp ?? isCatchUp,
      catchUpStart: incoming.catchUpStart ?? catchUpStart,
      catchUpEnd: incoming.catchUpEnd ?? catchUpEnd,

      lastWatchedAt: incoming.lastWatchedAt ?? lastWatchedAt,
    );
  }

  String? _preferValue(String? incoming, String? current) {
    if (incoming == null || incoming.trim().isEmpty) {
      return current;
    }
    return incoming;
  }

  LiveRoom getLiveRoomWithError() {
    return copyWith(liveStatus: LiveStatus.offline, status: false, isRecord: false);
  }

  LiveRoom fillFromDetail(LiveRoom? detail) {
    if (detail == null) return this;

    return copyWith(
      area: _getValueIfEmpty(area, detail.area),
      nick: _getValueIfEmpty(nick, detail.nick),
      avatar: _getValueIfEmpty(avatar, detail.avatar),
    );
  }

  String? _getValueIfEmpty(String? current, String? newValue) {
    return (current == null || current.isEmpty) ? newValue : current;
  }
}
