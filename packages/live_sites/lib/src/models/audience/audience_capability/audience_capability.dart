import 'package:live_sites/src/models/enums/live_audience_online_availability.dart';

/// Which audience metrics a platform reports (the reference's per-platform
/// table; the comments keep the reason each value is what it is).
final class LiveAudienceCapability {
  /// Creates a capability.
  const new({
    required this.hasPopularity,
    required this.hasTotalViewers,
    required this.onlineAvailability,
  });

  /// A platform without known metrics.
  static const LiveAudienceCapability unknown = LiveAudienceCapability(
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
  static LiveAudienceCapability of(String? platform) =>
      kAudienceCapabilities[platform?.trim().toLowerCase()] ?? unknown;
}

/// Audience metrics per platform id.
const Map<String, LiveAudienceCapability> kAudienceCapabilities = {
  // Bilibili's room `online` field and heartbeat are popularity; WATCHED_CHANGE
  // is cumulative. Neither is a concurrent head count.
  'bilibili': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'douyu': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  // Huya's public figures stay in the same multi-million popularity range.
  'huya': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'douyin': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'kuaishou': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'cc': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'twitch': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // SOOP lists expose total_view_cnt/view_cnt as PC + mobile viewers.
  'soop': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // YY's public `users` value follows the popularity scale.
  'yy': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'picarto': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'twitcasting': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // SHOWROOM's view_num is session traffic, not a concurrent audience.
  'showroom': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'chzzk': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'kick': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // The room detail keeps liveViewerCount apart from cumulative viewerCount.
  '17live': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'liveme': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'tiktok': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'youtube': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'bigo': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'pandalive': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'fc2live': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'steambroadcast': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // JD's directory `pv` is cumulative; the room chat carries current_viewer.
  'jdlive': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'kugoulive': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'baidulive': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // Six Rooms keeps its homepage count as platform popularity.
  'sixroom': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
  'looklive': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // Missevan's public heat is `score`; listeners arrive through chat only.
  'missevan': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  'inke': LiveAudienceCapability(
    hasPopularity: true,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  'acfun': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: false,
    onlineAvailability: LiveAudienceOnlineAvailability.roomList,
  ),
  // KilaKila's profile/broadcast carries onlineNumber; timeline numbers are
  // cumulative.
  'kilakila': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.roomRealtime,
  ),
  // Niconico's public figures are the programme's cumulative views; no
  // concurrent audience is exposed.
  'niconico': LiveAudienceCapability(
    hasPopularity: false,
    hasTotalViewers: true,
    onlineAvailability: LiveAudienceOnlineAvailability.unsupported,
  ),
};
