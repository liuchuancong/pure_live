import 'package:live_sites/src/models/audience/audience_capability/audience_capability.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

/// The tiers of an audience ranking across platforms whose figures use
/// different scales, lowest first (the reference's `AudienceRankKey`
/// priorities 0 to 3).
///
/// While concurrent viewers lead, an explicit count ranks ahead of one the
/// platform has but did not send yet, and both ahead of any heat or
/// cumulative figure, so a multi-million popularity score never outranks a
/// real audience of a few thousand.
enum LiveAudienceRankTier {
  /// No figure at all.
  none,

  /// The figure the card leads with where concurrent viewers do not lead:
  /// heat, cumulative or concurrent, as the platform and the viewer's
  /// choice give it.
  native,

  /// Concurrent viewers lead and the platform has them, but this room did
  /// not carry them (a list without them, a detail not read yet).
  pendingConcurrent,

  /// Concurrent viewers lead and this room carries the count.
  concurrent,
}

/// A room's place in an audience ranking: its [tier], then its [value]
/// within the tier.
final class LiveAudienceRankKey implements Comparable<LiveAudienceRankKey> {
  /// Creates a key.
  const new({required this.tier, required this.value});

  /// The tier; a higher one ranks first whatever the values say.
  final LiveAudienceRankTier tier;

  /// The figure within the tier: the concurrent count in
  /// [LiveAudienceRankTier.concurrent], the figure the card shows in the
  /// other tiers, 0 when there is none.
  final int value;

  /// The lower tier first, then the smaller value; largest first is
  /// `right.compareTo(left)`.
  @override
  int compareTo(LiveAudienceRankKey other) {
    final byTier = tier.index.compareTo(other.tier.index);
    return byTier != 0 ? byTier : value.compareTo(other.value);
  }
}

/// The audience ranking of a [LiveRoom].
extension LiveRoomAudienceRank on LiveRoom {
  /// This room's rank when cards lead with [lead] (null: each room's own
  /// primary metric; `RoomAudience.leadingFigure` picks the figure).
  ///
  /// Concurrent viewers lead on a platform that has them when [lead] asks
  /// for them, or when [preferRealOnline] does and [platformEnabled] says
  /// the preference reaches this room's platform: the room then ranks in
  /// the concurrent tiers. Every other room ranks by its native figure below
  /// those, so a platform without concurrent viewers never outranks a real
  /// audience. A pending room keeps the figure its card falls back to, so
  /// the cards of that tier still read in order.
  LiveAudienceRankKey audienceRankKey({
    LiveAudienceMetricType? lead,
    bool preferRealOnline = false,
    bool platformEnabled = true,
  }) {
    final figure = audience.leadingFigure(lead);
    final concurrentLeads =
        LiveAudienceCapability.of(platform).supportsConcurrentOnline &&
        (lead == LiveAudienceMetricType.onlineViewers || (preferRealOnline && platformEnabled));
    if (concurrentLeads) {
      final online = audience.onlineViewers;
      return online != null
          ? LiveAudienceRankKey(tier: LiveAudienceRankTier.concurrent, value: online)
          : LiveAudienceRankKey(tier: LiveAudienceRankTier.pendingConcurrent, value: figure ?? 0);
    }
    return figure != null
        ? LiveAudienceRankKey(tier: LiveAudienceRankTier.native, value: figure)
        : const LiveAudienceRankKey(tier: LiveAudienceRankTier.none, value: 0);
  }
}

/// Orders [left] and [right] by audience, largest first, then by identity so
/// rooms of the same rank never trade places on a refresh (the reference's
/// `compareAudienceRanking`). [platformEnabled] says which platforms
/// [preferRealOnline] reaches, every one when it is null; see
/// [LiveRoomAudienceRank.audienceRankKey] for [lead] and the tiers.
int compareAudienceRanking(
  LiveRoom left,
  LiveRoom right, {
  LiveAudienceMetricType? lead,
  bool preferRealOnline = false,
  bool Function(String platform)? platformEnabled,
}) {
  LiveAudienceRankKey keyOf(LiveRoom room) => room.audienceRankKey(
    lead: lead,
    preferRealOnline: preferRealOnline,
    platformEnabled: platformEnabled?.call(room.platform) ?? true,
  );
  final byAudience = keyOf(right).compareTo(keyOf(left));
  return byAudience != 0 ? byAudience : left.identityKey.compareTo(right.identityKey);
}
