import 'package:live_sites/live_sites.dart' show LiveAudienceMetricType, LiveRoom, LiveStatus;

/// How search results are ordered (the reference's `LiveSearchSortMode`).
enum SearchSortMode {
  /// Audience, then followers, then the platform order.
  smart,

  /// Platform order, then audience, then followers.
  platform,

  /// Audience, then platform order, then followers.
  audience,

  /// Followers, then audience, then platform order.
  followers,
}

/// The order [rooms] are shown in: live rooms first, then rooms that can
/// play here, then the rest; inside a state the picked mode decides, and a
/// final title-then-identity comparison keeps equal rooms from shuffling.
///
/// [playable] answers "can this room play here" (the discovery rule);
/// [includeOffline] false drops everything that is not live and not playable.
List<LiveRoom> rankedSearchRooms(
  Iterable<LiveRoom> rooms, {
  required SearchSortMode mode,
  required bool includeOffline,
  required List<String> platformOrder,
  required bool Function(LiveRoom room) playable,
}) {
  final ranks = {
    for (var index = 0; index < platformOrder.length; index++) platformOrder[index].trim().toLowerCase(): index,
  };
  final kept = [
    for (final room in rooms)
      if (includeOffline || _isLive(room) || playable(room)) room,
  ];
  return kept..sort((a, b) => _compare(a, b, mode: mode, ranks: ranks, playable: playable));
}

/// Whether [room] is broadcasting now.
bool _isLive(LiveRoom room) => room.broadcast.effectiveLiveStatus == LiveStatus.live;

/// The state rank: live (2), playable (1), anything else (0). A hidden
/// stream sorts under every playable one.
int _stateRank(LiveRoom room, bool Function(LiveRoom) playable) => _isLive(room) ? 2 : (playable(room) ? 1 : 0);

int _compare(
  LiveRoom a,
  LiveRoom b, {
  required SearchSortMode mode,
  required Map<String, int> ranks,
  required bool Function(LiveRoom) playable,
}) {
  final state = _stateRank(b, playable).compareTo(_stateRank(a, playable));
  if (state != 0) {
    return state;
  }
  int platform() => (ranks[a.ref.platform.toLowerCase()] ?? ranks.length).compareTo(
    ranks[b.ref.platform.toLowerCase()] ?? ranks.length,
  );
  int audience() => _audienceOf(b).compareTo(_audienceOf(a));
  int followers() => _followersOf(b).compareTo(_followersOf(a));
  final order = switch (mode) {
    SearchSortMode.smart => [audience, followers, platform],
    SearchSortMode.platform => [platform, audience, followers],
    SearchSortMode.audience => [audience, platform, followers],
    SearchSortMode.followers => [followers, audience, platform],
  };
  for (final step in order) {
    final result = step();
    if (result != 0) {
      return result;
    }
  }
  final title = a.content.title.toLowerCase().compareTo(b.content.title.toLowerCase());
  if (title != 0) {
    return title;
  }
  return '${a.ref.platform}:${a.ref.roomId}'.compareTo('${b.ref.platform}:${b.ref.roomId}');
}

/// The audience figure a result ranks by — the same reading the cards lead
/// with.
int _audienceOf(LiveRoom room) =>
    room.audience.onlineViewers ?? room.audience.popularity ?? room.audience.totalViewers ?? 0;

/// The follower count: a room whose primary figure counts followers reports
/// it there; other rooms report none, so the mode falls through to audience.
int _followersOf(LiveRoom room) =>
    room.audience.primaryMetric == LiveAudienceMetricType.followers ? _audienceOf(room) : 0;
