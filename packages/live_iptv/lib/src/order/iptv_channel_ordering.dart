/// The rules that decide which channel comes first.
///
/// Three things order a channel list, and they are asked in this order:
/// what the user pinned, what the user numbered, and what the playlist
/// itself says (its group arrangement and its own line order). Nothing here
/// is a heuristic — a channel with no number sorts *after* every numbered
/// one, because a number is a promise the user made to their remote control
/// and inventing one would break that promise the next time the list is
/// re-imported.
///
/// Every comparison ends in the channel id, so the order is total: the same
/// library always sorts to the same list, which is what lets a screen show
/// channel 7 in position 6 and the remote still step to it correctly.
library;

import 'package:live_iptv/src/model/model.dart';

/// The key of the bucket a channel with no `group-title` belongs to.
///
/// An empty name rather than a made-up one like "未分类": the text belongs
/// to the interface, and this package must not decide what the user's
/// uncategorised channels are called.
const String iptvUngroupedKey = '';

/// The group name a channel belongs to, or [iptvUngroupedKey] when it has
/// none.
String iptvGroupKeyOf(IptvChannel channel) => channel.entry.group?.trim() ?? iptvUngroupedKey;

/// The group records in the order the user arranged them: pinned first,
/// then by the order they set, then by name so two equal orders still
/// decide, then by the name itself as the final tie.
List<IptvGroup> sortIptvGroups(Iterable<IptvGroup> groups) => [...groups]..sort(compareIptvGroups);

/// Compares two group records by the arrangement rules.
int compareIptvGroups(IptvGroup a, IptvGroup b) {
  if (a.pinned != b.pinned) {
    return a.pinned ? -1 : 1;
  }
  if (a.order != b.order) {
    return a.order.compareTo(b.order);
  }
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return byName != 0 ? byName : a.name.compareTo(b.name);
}

/// The rank of every group in the library, smallest first.
///
/// Groups the user arranged come first — pinned, then by the order they
/// set, then by name so two equal orders still decide — and every group the
/// playlist carries but the user has never touched comes after, in the
/// order its first channel appears. Dropping the unarranged groups would
/// hide channels; ranking them by name would reorder a list the user never
/// asked to have reordered.
Map<String, int> rankIptvGroups({required List<IptvChannel> channels, required List<IptvGroup> groups}) {
  final arranged = sortIptvGroups(groups);
  final ranks = <String, int>{};
  for (final (index, group) in arranged.indexed) {
    ranks[group.name] = index;
  }
  // First appearance is read off the channels as they are already ordered,
  // so an unarranged group lands where the playlist's own order puts it.
  for (final channel in [...channels]..sort((a, b) => a.position.compareTo(b.position))) {
    final name = iptvGroupKeyOf(channel);
    if (!ranks.containsKey(name)) {
      ranks[name] = ranks.length;
    }
  }
  return Map.unmodifiable(ranks);
}

/// Compares two channels by the library's ordering rules.
///
/// [groupRanks] comes from [rankIptvGroups]; a group missing from it ranks
/// with the unarranged ones, after every ranked group.
int compareIptvChannels(IptvChannel a, IptvChannel b, {Map<String, int> groupRanks = const {}}) {
  if (a.pinned != b.pinned) {
    return a.pinned ? -1 : 1;
  }
  final byNumber = _compareNullsLast(a.number, b.number);
  if (byNumber != 0) {
    return byNumber;
  }
  final byGroup = _compareNullsLast(groupRanks[iptvGroupKeyOf(a)], groupRanks[iptvGroupKeyOf(b)]);
  if (byGroup != 0) {
    return byGroup;
  }
  final byGroupName = iptvGroupKeyOf(a).toLowerCase().compareTo(iptvGroupKeyOf(b).toLowerCase());
  if (byGroupName != 0) {
    return byGroupName;
  }
  if (a.position != b.position) {
    return a.position.compareTo(b.position);
  }
  final byName = a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

/// Sorts [channels] into the library's display order.
List<IptvChannel> sortIptvChannels(Iterable<IptvChannel> channels, {Map<String, int> groupRanks = const {}}) =>
    [...channels]..sort((a, b) => compareIptvChannels(a, b, groupRanks: groupRanks));

/// How the engine hands out channel numbers.
enum IptvNumberingMode {
  /// One run of numbers through the whole list, `1, 2, 3 …`: what a remote
  /// control types when there is nothing better to type.
  sequential,

  /// A block of numbers per group, so the 央视 channels land on `1…20` and
  /// the 卫视 ones on `101…120`. Bigger numbers, but the group is in the
  /// number, which is how cable boxes number their line-ups.
  perGroup,

  /// The number the playlist declared (`tvg-chno`) where it declared one,
  /// and the next free number otherwise. The provider's numbering is a
  /// fact about its stream; using it keeps a user's muscle memory across a
  /// list that got re-sold under a different name.
  fromPlaylist,
}

/// The number each channel of [ordered] should get, keyed by channel id.
///
/// [ordered] must already be in display order (see [sortIptvChannels]):
/// numbers are handed out down the list, so the first channel gets the
/// smallest. When two channels want the same number the one earlier in the
/// list keeps it and the other takes the next free number — never both,
/// because typing a number has to answer with exactly one channel.
///
/// With [keepExisting] (the default) a channel that already has a number
/// keeps it: re-numbering must not shuffle the channels the user has been
/// typing. The numbers they hold are still reserved, so nothing is handed
/// out twice.
Map<String, int> assignChannelNumbers({
  required List<IptvChannel> ordered,
  IptvNumberingMode mode = IptvNumberingMode.sequential,
  Map<String, int> groupRanks = const {},
  int startAt = 1,
  int groupBlock = 100,
  bool keepExisting = true,
}) {
  final used = <int>{};
  if (keepExisting) {
    for (final channel in ordered) {
      final number = channel.number;
      if (number != null && number > 0) {
        used.add(number);
      }
    }
  }
  final assigned = <String, int>{};
  var cursor = startAt;
  var inGroup = -1;
  String? lastGroup;
  for (final channel in ordered) {
    // The place in the group is counted before anything is skipped: a
    // channel that keeps the number the user gave it still sits in the
    // group's run, and letting it slide would hand the next channel in that
    // group the number that was just taken.
    final group = iptvGroupKeyOf(channel);
    if (group != lastGroup) {
      lastGroup = group;
      inGroup = 0;
    } else {
      inGroup++;
    }
    if (keepExisting && channel.number != null && channel.number! > 0) {
      assigned[channel.id] = channel.number!;
      continue;
    }
    final wanted = switch (mode) {
      IptvNumberingMode.sequential => cursor,
      IptvNumberingMode.perGroup => startAt + (groupRanks[group] ?? groupRanks.length) * groupBlock + inGroup,
      IptvNumberingMode.fromPlaylist => channel.entry.channelNumber ?? cursor,
    };
    final number = iptvNextFreeNumber(used, wanted);
    used.add(number);
    assigned[channel.id] = number;
    cursor = number + 1;
  }
  return Map.unmodifiable(assigned);
}

/// The first number at or after [from] that is not in [used].
///
/// Numbers climb one at a time rather than jumping past a block of them: a
/// user moving a channel to 5 expects the channel that was on 5 to end up on
/// 6, not on 101.
int iptvNextFreeNumber(Iterable<int> used, int from) {
  final taken = used.toSet();
  var number = from < 1 ? 1 : from;
  while (taken.contains(number)) {
    number++;
  }
  return number;
}

/// Compares two nullable numbers; the one that is set wins, nulls last.
int _compareNullsLast(int? a, int? b) {
  if (a == b) {
    return 0;
  }
  if (a == null) {
    return b == null ? 0 : 1;
  }
  if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}
