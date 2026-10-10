// Module: lib/src/domain/channel_zapper.dart
// Purpose: The channel lineup a remote zaps through: ordered, group-filterable, wrapping, and immutable.
// Author: liuchuancong
// Created: 2026-10-10
//
// What a TV remote does is press channel-up hundreds of times against a list somebody else wrote. That makes
// three properties the whole job: the position must survive the press, the cycle must wrap, and a filter must
// not move the viewer to a different station than they were on. The mutable version this replaces got the
// last one by moving the cursor to the first channel of the new scope, so switching groups on a remote was
// an unexpected jump, and `visible()` handed out the internal list, so a caller could reorder the lineup
// through a getter.
//
// Every transition here returns a new [ChannelZapper]; the surface holds one value and replaces it, which is
// what makes a double key-press and a rebuild race visible instead of silent.

import 'package:pure_live_utils/pure_live_utils.dart';

import 'zap_channel.dart';

/// Why a zap or a selection could not be carried out.
final class LineupFailure extends DomainFailure {
  const LineupFailure(super.reason, {super.cause});
}

/// What a move produced.
sealed class ZapStep {
  const ZapStep();
}

/// The cursor moved to [channel].
final class ZapMoved extends ZapStep {
  const ZapMoved(this.channel);

  final ZapChannel channel;
}

/// Nothing was in scope to move to - an empty lineup, or a group with no channels.
final class ZapEmpty extends ZapStep {
  const ZapEmpty(this.reason);

  final String reason;
}

/// The lineup plus the cursor.
final class ChannelZapper {
  /// [skipUnplayable] is the decision, not a convenience: entries with no parsable stream would otherwise
  /// land the viewer on a black screen with no error, indistinguishable from a dead station. Skipping them
  /// makes the remote feel responsive on the playlists people actually import. [select] still reaches them
  /// deliberately.
  const ChannelZapper({required List<ZapChannel> channels, this.group, this.cursor = -1, this.skipUnplayable = true})
    : _channels = channels;

  /// Builds a zapper over [channels], positioned at the first playable entry.
  factory ChannelZapper.lineup(List<ZapChannel> channels, {String? group, bool skipUnplayable = true}) {
    final scoped = channels;
    final zapper = ChannelZapper(channels: scoped, group: group, cursor: -1, skipUnplayable: skipUnplayable);
    final first = zapper.visible().isEmpty ? -1 : zapper._firstMeaningfulIndex();
    return ChannelZapper(channels: scoped, group: group, cursor: first, skipUnplayable: skipUnplayable);
  }

  final List<ZapChannel> _channels;

  /// The group filter narrowing the cycle, or null for the whole lineup.
  final String? group;

  /// Index into [_channels], or -1 when nothing is in scope.
  final int cursor;

  final bool skipUnplayable;

  /// The full lineup, in playlist order. Unmodifiable, because a getter that hands back the internal list
  /// lets a caller reorder the station the viewer is watching.
  List<ZapChannel> get channels => List<ZapChannel>.unmodifiable(_channels);

  bool get isEmpty => visible().isEmpty;

  /// The channel under the cursor, or null.
  ZapChannel? get current => cursor >= 0 && cursor < _channels.length ? _channels[cursor] : null;

  /// The channels in scope: the group's entries, in playlist order.
  List<ZapChannel> visible() {
    final wanted = group;
    if (wanted == null) {
      return List<ZapChannel>.unmodifiable(_channels);
    }
    return List<ZapChannel>.unmodifiable(_channels.where((channel) => channel.group == wanted));
  }

  /// Every group present, in first-appearance order, with the count of entries in each.
  Map<String, int> get groups {
    final counts = <String, int>{};
    for (final channel in _channels) {
      counts[channel.group] = (counts[channel.group] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(counts);
  }

  /// Entries that cannot be opened: the playlist hygiene number a surface reports after an import.
  int get unplayableCount => _channels.where((channel) => !channel.isPlayable).length;

  /// The zapper narrowed to [group], keeping the current station when the group still holds it.
  ///
  /// Clearing the filter (null) never moves the viewer either. The previous version jumped to the first
  /// channel of the new scope, which is a station change nobody asked for.
  ChannelZapper withGroup(String? group) {
    final candidate = ChannelZapper(channels: _channels, group: group, cursor: cursor, skipUnplayable: skipUnplayable);
    final held = current;
    if (held != null && candidate.visible().any((channel) => channel == held)) {
      return candidate;
    }
    final first = candidate._firstMeaningfulIndex();
    return ChannelZapper(channels: _channels, group: group, cursor: first, skipUnplayable: skipUnplayable);
  }

  /// Channel up on the remote.
  ZapStep zapUp() => _step(-1);

  /// Channel down on the remote.
  ZapStep zapDown() => _step(1);

  /// The channel a viewer typed on the remote, 1-based against the visible scope.
  ///
  /// Unplayable entries are reachable here, because a typed number is a deliberate choice: a greyed-out row
  /// the viewer still wants to try.
  ChannelZapper select(int number) {
    final scope = visible();
    if (scope.isEmpty) {
      throw LineupFailure('there is no channel $number: the ${group == null ? 'lineup' : 'group "$group"'} is empty');
    }
    if (number < 1 || number > scope.length) {
      throw LineupFailure('channel $number is outside 1..${scope.length} of ${group ?? 'the lineup'}');
    }
    final index = _channels.indexOf(scope[number - 1]);
    return ChannelZapper(channels: _channels, group: group, cursor: index, skipUnplayable: skipUnplayable);
  }

  /// Moves to [channel], which must be part of this lineup.
  ChannelZapper selectChannel(ZapChannel channel) {
    final index = _channels.indexOf(channel);
    if (index < 0) {
      throw LineupFailure('${channel.name} is not part of this lineup');
    }
    return ChannelZapper(channels: _channels, group: group, cursor: index, skipUnplayable: skipUnplayable);
  }

  /// The position of the current station within the visible scope, 1-based; 0 when nothing is in scope.
  int get visibleNumber {
    final held = current;
    if (held == null) {
      return 0;
    }
    return visible().indexOf(held) + 1;
  }

  ZapStep _step(int direction) {
    final scope = visible();
    if (scope.isEmpty) {
      return ZapEmpty('${group == null ? 'the lineup' : 'group "$group"'} has no channels to zap through');
    }
    final held = current;
    var from = held == null ? (direction > 0 ? -1 : 0) : scope.indexOf(held);
    for (var attempt = 0; attempt < scope.length; attempt++) {
      from = (from + direction) % scope.length;
      if (from < 0) {
        from += scope.length;
      }
      final candidate = scope[from];
      if (!skipUnplayable || candidate.isPlayable) {
        return ZapMoved(candidate);
      }
    }
    // Everything in scope is unplayable: stay where the viewer is and say so, rather than wrapping onto a
    // black screen over and over.
    return ZapEmpty('all ${scope.length} channels in ${group ?? 'the lineup'} have no playable stream');
  }

  int _firstMeaningfulIndex() {
    final scope = visible();
    final chosen = scope.where((channel) => !skipUnplayable || channel.isPlayable).toList(growable: false);
    final target = chosen.isEmpty ? scope.head : chosen.head;
    return target == null ? -1 : _channels.indexOf(target);
  }
}
