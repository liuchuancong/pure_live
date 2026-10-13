// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:freezed_annotation/freezed_annotation.dart';

/// What a room's audience number means. Stored by name in room JSON.
enum AudienceMetricType {
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
enum AudienceOnlineAvailability {
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
final class AudiencePlatformCapability {
  /// Creates a capability.
  const AudiencePlatformCapability({
    required this.hasPopularity,
    required this.hasTotalViewers,
    required this.onlineAvailability,
  });

  /// A platform without known metrics.
  static const AudiencePlatformCapability unknown = AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.unsupported,
  );

  /// Whether the platform has a popularity or heat value.
  final bool hasPopularity;

  /// Whether the platform has a cumulative viewer value.
  final bool hasTotalViewers;

  /// Where the concurrent-viewer count is available.
  final AudienceOnlineAvailability onlineAvailability;

  /// Whether the platform has a concurrent-viewer count at all.
  bool get supportsConcurrentOnline => onlineAvailability != AudienceOnlineAvailability.unsupported;

  /// Whether room lists already carry the concurrent-viewer count.
  bool get onlineAvailableInRoomLists => onlineAvailability == AudienceOnlineAvailability.roomList;

  /// The capability of [platform] (case-insensitive), or [unknown].
  static AudiencePlatformCapability of(String? platform) =>
      audienceCapabilities[platform?.trim().toLowerCase()] ?? unknown;
}

/// Audience metrics per platform id. A platform not listed is
/// [AudiencePlatformCapability.unknown].
const Map<String, AudiencePlatformCapability> audienceCapabilities = {
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
  'twitch': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'soop': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'yy': AudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.unsupported,
  ),
  'picarto': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'twitcasting': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'showroom': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.unsupported,
  ),
  'chzzk': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'kick': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  '17live': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomRealtime,
  ),
  'liveme': AudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'tiktok': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomRealtime,
  ),
  'youtube': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomRealtime,
  ),
  'bigo': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'pandalive': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'fc2live': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'steambroadcast': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'jdlive': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomRealtime,
  ),
  'kugoulive': AudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'baidulive': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'sixroom': AudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.unsupported,
  ),
  'looklive': AudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'missevan': AudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomRealtime,
  ),
  'inke': AudiencePlatformCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'acfun': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: AudienceOnlineAvailability.roomList,
  ),
  'kilakila': AudiencePlatformCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: AudienceOnlineAvailability.roomRealtime,
  ),
};

/// A sortable audience key for rooms whose platforms use different scales. In
/// concurrent-viewer mode an explicit concurrent value ranks ahead of a pending
/// one, and a pending supported room ahead of a heat or cumulative fallback.
@immutable
final class AudienceRankKey {
  /// Creates a key.
  const AudienceRankKey({required this.metricPriority, required this.value});

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
/// the room, which knows its platform and its [AudiencePlatformCapability].
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
  final AudienceMetricType? metricType;

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
      metricType: given != null && given != AudienceMetricType.unknown ? given : metricType,
      popularity: prefer(incoming.popularity, popularity),
      onlineViewers: prefer(incoming.onlineViewers, onlineViewers),
      totalViewers: prefer(incoming.totalViewers, totalViewers),
    );
  }

  @override
  String toString() =>
      'LiveAudience(watching: $watching, popularity: $popularity, online: $onlineViewers, total: $totalViewers)';
}
