import 'package:pure_live/player/core/live_room_volume_manager.dart';

enum LiveStatus { live, offline, replay, unknown, banned }

enum AudienceMetricType { popularity, onlineViewers, totalViewers, followers, unknown }

class LiveRoom {
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
  LiveStatus? liveStatus = LiveStatus.offline;

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
    this.liveStatus,
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
    List<String>? tagIds,
  }) : tagIds = tagIds ?? [];

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
      liveStatus = LiveStatus.values.firstWhere((e) => e.index == json['liveStatus'], orElse: () => LiveStatus.unknown),
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
      catchUpEnd = json['catchUpEnd'] {
    // Builds created before v2.0.32 temporarily copied Huya's multi-million
    // room heat from userCount into onlineViewers. Clear only the recognizable
    // duplicated value; a later URI 8006 heartbeat has a distinct count and is
    // preserved.
    if (platform == 'huya' &&
        _hasExplicitAudienceValue(onlineViewers) &&
        _hasAudienceValue(popularity) &&
        parseAudienceNumber(onlineViewers) == parseAudienceNumber(popularity)) {
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
      tagIds: tagIds ?? this.tagIds,
    );
  }

  @override
  bool operator ==(covariant LiveRoom other) => platform == other.platform && roomId == other.roomId;

  @override
  int get hashCode => Object.hash(platform, roomId);

  @override
  String toString() {
    return 'LiveRoom{roomId: $roomId, userId: $userId, link: $link, title: $title, nick: $nick, avatar: $avatar, cover: $cover, area: $area, watching: $watching, followers: $followers, platform: $platform, tagIds: $tagIds, introduction: $introduction, notice: $notice, status: $status, data: $data, danmakuData: $danmakuData, isRecord: $isRecord, liveStatus: $liveStatus, catchUpUrl: $catchUpUrl, isCatchUp: $isCatchUp}';
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
      'liveStatus': liveStatus?.index ?? LiveStatus.offline.index,
      'isRecord': isRecord,
      'status': status,
      'notice': notice,
      'introduction': introduction,
      'epgId': epgId,
      'currentProgramme': currentProgramme,
      'currentProgrammeDescription': currentProgrammeDescription,
      'catchUpUrl': catchUpUrl,
      'isCatchUp': isCatchUp,
      'catchUpStart': catchUpStart,
      'catchUpEnd': catchUpEnd,
    };
  }

  AudienceMetricType get effectiveAudienceMetricType {
    if (audienceMetricType != null && audienceMetricType != AudienceMetricType.unknown) {
      return audienceMetricType!;
    }
    return switch (platform) {
      'bilibili' || 'douyu' => AudienceMetricType.popularity,
      'kuaishou' => AudienceMetricType.onlineViewers,
      'huya' => AudienceMetricType.popularity,
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
    return effectiveAudienceMetricType == AudienceMetricType.popularity ? (watching ?? '').trim() : '';
  }

  String get effectiveOnlineViewers {
    if (_hasExplicitAudienceValue(onlineViewers)) return onlineViewers!.trim();
    return effectiveAudienceMetricType == AudienceMetricType.onlineViewers && _hasExplicitAudienceValue(watching)
        ? (watching ?? '').trim()
        : '';
  }

  String get effectiveTotalViewers {
    if (_hasAudienceValue(totalViewers)) return totalViewers!.trim();
    return effectiveAudienceMetricType == AudienceMetricType.totalViewers ? (watching ?? '').trim() : '';
  }

  bool get supportsRealOnlineCount => _hasExplicitAudienceValue(effectiveOnlineViewers);

  String audienceValue({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) return effectiveOnlineViewers;
    if (_hasAudienceValue(effectivePopularity)) return effectivePopularity;
    if (_hasAudienceValue(effectiveTotalViewers)) return effectiveTotalViewers;
    if (supportsRealOnlineCount) return effectiveOnlineViewers;
    return (watching ?? '0').trim();
  }

  AudienceMetricType audienceType({required bool preferRealOnline, required bool platformEnabled}) {
    if (preferRealOnline && platformEnabled && supportsRealOnlineCount) return AudienceMetricType.onlineViewers;
    if (_hasAudienceValue(effectivePopularity)) return AudienceMetricType.popularity;
    if (_hasAudienceValue(effectiveTotalViewers)) return AudienceMetricType.totalViewers;
    if (supportsRealOnlineCount) return AudienceMetricType.onlineViewers;
    return effectiveAudienceMetricType;
  }

  int audienceSortValue({required bool preferRealOnline, required bool platformEnabled}) {
    return parseAudienceNumber(audienceValue(preferRealOnline: preferRealOnline, platformEnabled: platformEnabled));
  }

  /// Keeps a reliable audience snapshot when a room-detail request or the
  /// first websocket heartbeat omits a metric. Bilibili can transiently return
  /// `1` for a busy room while its list API still has the current popularity;
  /// accepting that value makes the room header jump from hundreds of
  /// thousands to one. A later plausible heartbeat is still accepted.
  LiveRoom withAudienceFallbackFrom(LiveRoom fallback) {
    if (roomId != fallback.roomId || platform != fallback.platform) return this;

    final currentPopularity = effectivePopularity;
    final fallbackPopularity = fallback.effectivePopularity;
    final currentPopularityCount = parseAudienceNumber(currentPopularity);
    final fallbackPopularityCount = parseAudienceNumber(fallbackPopularity);
    final hasTransientBilibiliDrop =
        platform == 'bilibili' &&
        fallbackPopularityCount >= 1000 &&
        currentPopularityCount <= 1 &&
        currentPopularityCount * 100 < fallbackPopularityCount;
    final useFallbackPopularity = !_hasAudienceValue(currentPopularity) || hasTransientBilibiliDrop;

    final mergedPopularity = useFallbackPopularity ? fallbackPopularity : currentPopularity;
    final mergedOnlineViewers = _hasExplicitAudienceValue(onlineViewers) ? onlineViewers : fallback.onlineViewers;
    final mergedTotalViewers = _hasAudienceValue(totalViewers) ? totalViewers : fallback.totalViewers;
    final mergedMetricType = useFallbackPopularity ? fallback.effectiveAudienceMetricType : effectiveAudienceMetricType;
    final mergedWatching = mergedMetricType == AudienceMetricType.popularity && _hasAudienceValue(mergedPopularity)
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
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(text.replaceAll(',', ''));
    final number = double.tryParse(match?.group(1) ?? '') ?? 0;
    final multiplier = text.contains('亿')
        ? 100000000
        : (text.contains('万') || text.contains('w'))
        ? 10000
        : text.contains('k')
        ? 1000
        : 1;
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
