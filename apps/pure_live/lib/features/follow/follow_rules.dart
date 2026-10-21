import 'package:live_sites/live_sites.dart' show LiveRoom;

/// The audience figure a follow card leads with (the same reading the room
/// cards use): concurrent viewers, else the platform's popularity, else the
/// session total.
int? followAudienceOf(LiveRoom room) =>
    room.audience.onlineViewers ?? room.audience.popularity ?? room.audience.totalViewers;

/// Whether [room] belongs to [platform]; null is the "all" tab and matches
/// every room.
bool followOnPlatform(LiveRoom room, String? platform) => platform == null || room.ref.platform == platform;

/// The platform tabs: the "all" tab first, then the platforms that have a
/// follow — the user's stored platform order first, the rest after it in the
/// registry's order, unknown ids last. A follow is therefore never reachable
/// only through "all", and the tabs follow the same order the discovery
/// pages show.
List<String> followPlatformTabs(
  Iterable<LiveRoom> rooms,
  List<String> platformOrder, {
  List<String> registryOrder = const [],
}) {
  final present = <String>{for (final room in rooms) room.ref.platform};
  final ordered = <String>[];
  void take(String id) {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty && present.contains(trimmed) && !ordered.contains(trimmed)) {
      ordered.add(trimmed);
    }
  }

  platformOrder.forEach(take);
  registryOrder.forEach(take);
  (present.toList()..sort()).forEach(take);
  return ordered;
}

/// The order follows are shown in inside a tab: a chosen tag ranks rooms
/// that carry it higher (its position in the strip is its weight), then the
/// audience ranking — largest first, with the "real viewers" preference
/// lifting rooms on the platforms whose concurrent count is trusted, and a
/// stable identity tie-break so equal or pending numbers never shuffle the
/// grid on refresh.
final class FollowOrdering {
  /// Orders by [tagRank] and the audience settings.
  const new({required this.preferRealOnline, required this.realOnlinePlatforms, this.tagRank = const {}});

  /// The tag weight per room identity — see [tagRank].

  /// The `preferRealOnlineCounts` answer.
  final bool preferRealOnline;

  /// The platforms whose concurrent count is trusted (`realOnlinePlatforms`).
  final Set<String> realOnlinePlatforms;

  /// Each room identity's best tag rank; empty when no tag is chosen.
  final Map<String, int> tagRank;

  /// Negative when [left] ranks before [right].
  int compare(LiveRoom left, LiveRoom right) {
    final tag = (tagRank[_identityOf(right)] ?? 0).compareTo(tagRank[_identityOf(left)] ?? 0);
    if (tag != 0) {
      return tag;
    }
    final leftRank = _audienceRank(left);
    final rightRank = _audienceRank(right);
    final tier = rightRank.tier.compareTo(leftRank.tier);
    if (tier != 0) {
      return tier;
    }
    final value = rightRank.value.compareTo(leftRank.value);
    if (value != 0) {
      return value;
    }
    return _identityOf(left).compareTo(_identityOf(right));
  }

  /// The room's place in the ranking: a trusted real-viewer count leads,
  /// then any explicit audience figure, then rooms that said nothing.
  ({int tier, int value}) _audienceRank(LiveRoom room) {
    final online = room.audience.onlineViewers;
    if (preferRealOnline && realOnlinePlatforms.contains(room.ref.platform)) {
      return online == null ? (tier: 2, value: 0) : (tier: 3, value: online);
    }
    final native = followAudienceOf(room);
    return native == null ? (tier: 0, value: 0) : (tier: 1, value: native);
  }

  static String _identityOf(LiveRoom room) => '${room.ref.platform}:${room.ref.roomId}';
}
