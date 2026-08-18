import 'package:pure_live/common/models/live_room.dart';

enum LiveSearchSortMode { smart, platform, audience, followers }

class LiveSearchRanking {
  const LiveSearchRanking._();

  static List<LiveRoom> apply({
    required Iterable<LiveRoom> rooms,
    required LiveSearchSortMode mode,
    required bool includeOffline,
    required List<String> platformOrder,
    required int Function(LiveRoom room) audienceValue,
  }) {
    final platformRanks = <String, int>{
      for (var index = 0; index < platformOrder.length; index++) platformOrder[index]: index,
    };
    final ranked = rooms.where((room) => includeOffline || room.liveStatus == LiveStatus.live).toList();
    ranked.sort((a, b) => compare(a, b, mode: mode, platformRanks: platformRanks, audienceValue: audienceValue));
    return ranked;
  }

  static int compare(
    LiveRoom a,
    LiveRoom b, {
    required LiveSearchSortMode mode,
    required Map<String, int> platformRanks,
    required int Function(LiveRoom room) audienceValue,
  }) {
    final liveOrder = _descending(_isLive(a), _isLive(b));
    if (liveOrder != 0) return liveOrder;

    final platformOrder = _ascending(_platformRank(a, platformRanks), _platformRank(b, platformRanks));
    final audienceOrder = _descending(audienceValue(a), audienceValue(b));
    final followerOrder = _descending(_followers(a), _followers(b));

    final orderedComparisons = switch (mode) {
      LiveSearchSortMode.smart => [audienceOrder, followerOrder, platformOrder],
      LiveSearchSortMode.platform => [platformOrder, audienceOrder, followerOrder],
      LiveSearchSortMode.audience => [audienceOrder, platformOrder, followerOrder],
      LiveSearchSortMode.followers => [followerOrder, audienceOrder, platformOrder],
    };
    for (final comparison in orderedComparisons) {
      if (comparison != 0) return comparison;
    }

    final titleOrder = (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase());
    if (titleOrder != 0) return titleOrder;
    return '${a.platform}:${a.roomId}'.compareTo('${b.platform}:${b.roomId}');
  }

  static int _isLive(LiveRoom room) => room.liveStatus == LiveStatus.live ? 1 : 0;

  static int _platformRank(LiveRoom room, Map<String, int> platformRanks) {
    return platformRanks[room.platform] ?? platformRanks.length;
  }

  static int _followers(LiveRoom room) {
    final explicit = LiveRoom.parseAudienceNumber(room.followers);
    if (explicit > 0) return explicit;
    if (room.effectiveAudienceMetricType == AudienceMetricType.followers) {
      return LiveRoom.parseAudienceNumber(room.watching);
    }
    return 0;
  }

  static int _descending(int a, int b) => b.compareTo(a);
  static int _ascending(int a, int b) => a.compareTo(b);
}
