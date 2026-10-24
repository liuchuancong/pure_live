import 'package:live_sites/live_sites.dart';

/// The group a followed room is listed under (the reference's `groupOf`):
/// the broadcast's own [LiveFollowGroup], with a retired platform's
/// follows always offline — they can no longer be refreshed or opened.
LiveFollowGroup followGroupOf(LiveRoom room) =>
    SiteFacts.isRetired(room.ref.platform) ? LiveFollowGroup.offline : room.broadcast.followGroup;

/// Whether [room] belongs to [platform]; null is every platform.
bool onFollowPlatform(LiveRoom room, String? platform) => platform == null || room.ref.platform == platform;

/// The platforms worth a tab, in the configured order ([configured], the
/// browsing pages' visible platform ids), then any other followed platform
/// sorted — so a follow on a hidden or retired platform is never reachable
/// only through "all".
List<String> followPlatformTabs(Iterable<LiveRoom> rooms, List<String> configured) {
  final present = {for (final room in rooms) room.ref.platform};
  final ordered = <String>[];
  void addAll(Iterable<String> ids) {
    for (final raw in ids) {
      final id = raw.trim().toLowerCase();
      if (present.contains(id) && !ordered.contains(id)) ordered.add(id);
    }
  }

  addAll(configured);
  addAll(present.toList()..sort());
  return ordered;
}

/// How many follows of [platform] (null: every platform) each group holds;
/// every group is present, zero included.
Map<LiveFollowGroup, int> followGroupCounts(Iterable<LiveRoom> rooms, String? platform) {
  final counts = {for (final group in LiveFollowGroup.values) group: 0};
  for (final room in rooms) {
    if (onFollowPlatform(room, platform)) counts.update(followGroupOf(room), (count) => count + 1);
  }
  return counts;
}

/// How many follows of [platform] (null: every platform) are in [group]
/// (null: every group).
int followCount(Iterable<LiveRoom> rooms, {String? platform, LiveFollowGroup? group}) {
  var count = 0;
  for (final room in rooms) {
    if (onFollowPlatform(room, platform) && (group == null || followGroupOf(room) == group)) count++;
  }
  return count;
}
