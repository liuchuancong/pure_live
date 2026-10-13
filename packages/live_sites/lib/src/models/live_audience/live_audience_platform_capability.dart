// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_audience/live_audience_online_availability.dart';
import 'package:meta/meta.dart';

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
