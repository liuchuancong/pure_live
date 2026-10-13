// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:freezed_annotation/freezed_annotation.dart';

/// What a room's audience number means. Stored by name in room JSON.
enum LiveAudienceMetricType {
  /// Platform popularity or heat; not a head count.
  popularity,

  /// Concurrent viewers.
  onlineViewers,

  /// Cumulative viewers of the current session.
  totalViewers,

  /// Followers of the streamer.
  followers,

  /// Not known.
  unknown,
}

/// Where a platform exposes its concurrent-viewer count.
enum LiveAudienceOnlineAvailability {
  /// Nowhere.
  unsupported,

  /// Only in the room (detail or realtime messages).
  roomRealtime,

  /// Already in room lists.
  roomList,
}

/// Which audience metrics a platform has (the per-platform table; the comments
/// record why each value is what it is).
@immutable
final class LiveAudiencePlatformCapability {
  /// Creates a capability.
  const LiveAudiencePlatformCapability({
    required this.hasPopularity,
    required this.hasTotalViewers,
    required this.onlineAvailability,
  });

  /// A platform without known metrics.
  static const LiveAudiencePlatformCapability unknown = LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  );

  /// Whether the platform has a popularity or heat value.
  final bool hasPopularity;

  /// Whether the platform has a cumulative viewer value.
  final bool hasTotalViewers;

  /// Where the concurrent-viewer count is available.
  final LiveAudienceOnlineAvailability onlineAvailability;

  /// Whether the platform has a concurrent-viewer count at all.
  bool get supportsConcurrentOnline => onlineAvailability != LiveAudienceOnlineAvailability.unsupported;

  /// Whether room lists already carry the concurrent-viewer count.
  bool get onlineAvailableInRoomLists => onlineAvailability == LiveAudienceOnlineAvailability.roomList;

  /// The capability of [platform] (case-insensitive), or [unknown].
  static LiveAudiencePlatformCapability of(String? platform) =>
      audienceCapabilities[platform?.trim().toLowerCase()] ?? unknown;
}

/// Audience metrics per platform id. A platform not listed is
/// [LiveAudiencePlatformCapability.unknown].
const Map<String, LiveAudiencePlatformCapability> audienceCapabilities = {
  'bilibili': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'douyu': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'huya': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'douyin': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'kuaishou': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'cc': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'twitch': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'soop': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'yy': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'picarto': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'twitcasting': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'showroom': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'chzzk': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'kick': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  '17live': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'liveme': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'tiktok': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'youtube': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'bigo': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'pandalive': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'fc2live': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'steambroadcast': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'jdlive': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'kugoulive': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'baidulive': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'sixroom': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'looklive': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'missevan': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'inke': LiveAudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'acfun': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'kilakila': LiveAudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
};

/// A sortable audience key for rooms whose platforms use different scales. In
/// concurrent-viewer mode an explicit concurrent value ranks ahead of a pending
/// one, and a pending supported room ahead of a heat or cumulative fallback.
@immutable
final class LiveAudienceRankKey {
  /// Creates a key.
  const LiveAudienceRankKey({required this.metricPriority, required this.value});

  /// Higher ranks first: 3 explicit concurrent, 2 pending concurrent, 1 a
  /// native value, 0 nothing.
  final int metricPriority;

  /// The number within the tier.
  final int value;
}

/// The number in an audience text: `5.6万` → 56000, `1.2亿`, `18.3k`, `1.5M`,
/// `2.4千`, `534，739`; 0 when there is none.
int parseAudienceNumber(String? value) {
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

/// Whether [value] is a measured, positive audience number.
bool hasAudienceValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isNotEmpty && text != 'null' && parseAudienceNumber(text) > 0;
}

/// Whether [value] carries any digit, zero included (an explicit count).
bool hasExplicitAudienceValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isNotEmpty && text != 'null' && RegExp('[0-9]').hasMatch(text);
}

/// The audience figures a room reports, as the platform wrote them.
///
/// A value is the platform's own text (`'5.6万'`, `'1234'`); `'0'` in
/// [watching] is the old default and not a measurement. What the main number
/// means is given by [metricType], or by the platform's usual one when it is
/// null or unknown (see `LiveRoom.effectiveAudienceMetricType`, which supplies
/// the platform). This is pure data; the ranking and fallback logic lives on
/// the room, which knows its platform and its [LiveAudiencePlatformCapability].
@immutable
final class LiveAudience {
  /// Creates an audience snapshot.
  const LiveAudience({
    this.watching = '0',
    this.metricType,
    this.popularity = '',
    this.onlineViewers = '',
    this.totalViewers = '',
  });

  /// The single audience field of older records and backups.
  final String watching;

  /// What the platform's main audience number means; null when not given.
  final LiveAudienceMetricType? metricType;

  /// Popularity or heat; not a head count.
  final String popularity;

  /// Concurrent viewers, when the platform exposes an explicit value.
  final String onlineViewers;

  /// Cumulative viewers of the current session.
  final String totalViewers;

  /// This snapshot with only the fields [incoming] actually reported kept from
  /// it; an empty incoming value falls back to the stored one, so a sparse
  /// refresh never erases an audience figure already known.
  LiveAudience mergedWith(LiveAudience incoming) {
    String prefer(String next, String current) => next.trim().isEmpty ? current : next;
    final given = incoming.metricType;
    return LiveAudience(
      watching: prefer(incoming.watching, watching),
      metricType: given != null && given != LiveAudienceMetricType.unknown ? given : metricType,
      popularity: prefer(incoming.popularity, popularity),
      onlineViewers: prefer(incoming.onlineViewers, onlineViewers),
      totalViewers: prefer(incoming.totalViewers, totalViewers),
    );
  }

  @override
  String toString() =>
      'LiveAudience(watching: $watching, popularity: $popularity, online: $onlineViewers, total: $totalViewers)';
}
