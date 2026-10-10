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
//
// Positions, not values, are the internal currency: a real playlist repeats a station row verbatim (the same
// name, group and url twice is how a source lists its second CDN), and matching by value would land both rows
// on the first copy, so the second one is unreachable and the visible number is a lie.

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

/// The cursor moved to [channel]; [zapper] is the lineup positioned there.
///
/// Carrying the new position is not a convenience: without it every caller re-derives the move with
/// `selectChannel(step.channel)`, and on a lineup with a repeated row that call resolves to the *other* copy,
/// so the key press lands somewhere the viewer did not aim at.
final class ZapMoved extends ZapStep {
  const ZapMoved(this.channel, {required this.zapper});

  final ZapChannel channel;
  final ChannelZapper zapper;
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
  ///
  /// [channels] is copied: a getter that hands back an unmodifiable view while the internal field still points
  /// at the caller's growable list lets that caller reorder - or empty - the station being watched.
  ChannelZapper({required List<ZapChannel> channels, this.group, this.cursor = -1, this.skipUnplayable = true})
    : _channels = List<ZapChannel>.unmodifiable(channels) {
    _scope = <int>[
      for (var index = 0; index < _channels.length; index++)
        if (group == null || _channels[index].group == group) index,
    ];
  }

  /// Builds a zapper over [channels], positioned at the first meaningful entry.
  factory ChannelZapper.lineup(List<ZapChannel> channels, {String? group, bool skipUnplayable = true}) {
    final zapper = ChannelZapper(channels: channels, group: group, skipUnplayable: skipUnplayable);
    return zapper.at(_positionOf(zapper._scope, zapper._channels, skipUnplayable: skipUnplayable));
  }

  /// The first in-scope position, honouring [skipUnplayable]; -1 when the scope holds nothing usable.
  static int _positionOf(List<int> scope, List<ZapChannel> channels, {required bool skipUnplayable}) {
    for (final index in scope) {
      if (!skipUnplayable || channels[index].isPlayable) {
        return index;
      }
    }
    return scope.isEmpty ? -1 : scope.first;
  }

  final List<ZapChannel> _channels;
  late final List<int> _scope;

  /// The group filter narrowing the cycle, or null for the whole lineup.
  final String? group;

  /// Index into [_channels], or -1 when nothing is in scope.
  final int cursor;

  final bool skipUnplayable;

  /// The full lineup, in playlist order. Unmodifiable, because a getter that hands back the internal list
  /// lets a caller reorder the station the viewer is watching.
  List<ZapChannel> get channels => _channels;

  /// The channels in scope: the group's entries, in playlist order.
  List<ZapChannel> get visible => List<ZapChannel>.unmodifiable(_scope.map((index) => _channels[index]));

  bool get isEmpty => _scope.isEmpty;

  int get count => _channels.length;

  /// How many entries the current filter puts in scope.
  int get visibleCount => _scope.length;

  /// The channel under the cursor, or null.
  ZapChannel? get current => cursor >= 0 && cursor < _channels.length ? _channels[cursor] : null;

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
    if (candidate._holdsCursor) {
      return candidate;
    }
    return candidate.at(_positionOf(candidate._scope, candidate._channels, skipUnplayable: skipUnplayable));
  }

  /// The same lineup with a different skip rule, e.g. a settings toggle that lets the viewer walk dead rows.
  ChannelZapper withSkipUnplayable(bool skip) {
    if (skip == skipUnplayable) {
      return this;
    }
    final candidate = ChannelZapper(channels: _channels, group: group, cursor: cursor, skipUnplayable: skip);
    return candidate._holdsCursor
        ? candidate
        : candidate.at(_positionOf(candidate._scope, candidate._channels, skipUnplayable: skip));
  }

  /// Channel up on the remote: one row towards the top of the list, wrapping to the bottom.
  ///
  /// The direction is the lineup's order, not the channel *number*, and that is a choice a surface must know
  /// about before it binds a key - see the README. A future binding that follows the Android TV convention
  /// (CH+ raises the number) calls [zapDown] for CH+, which is why these two carry no "next"/"previous" name.
  ZapStep zapUp() => _step(-1);

  /// Channel down on the remote: one row towards the bottom of the list, wrapping to the top.
  ZapStep zapDown() => _step(1);

  /// The channel a viewer typed on the remote, 1-based against the visible scope.
  ///
  /// Unplayable entries are reachable here, because a typed number is a deliberate choice: a greyed-out row
  /// the viewer still wants to try.
  ChannelZapper select(int number) {
    if (_scope.isEmpty) {
      throw LineupFailure('there is no channel $number: the ${group == null ? 'lineup' : 'group "$group"'} is empty');
    }
    if (number < 1 || number > _scope.length) {
      throw LineupFailure('channel $number is outside 1..${_scope.length} of ${group ?? 'the lineup'}');
    }
    return at(_scope[number - 1]);
  }

  /// Moves to [channel], which must be part of this lineup.
  ///
  /// When the playlist repeats a row, this lands on the first copy - use [select] or [atIndex] to name a
  /// position instead of a value, and [indexOf] to see how many copies exist.
  ChannelZapper selectChannel(ZapChannel channel) {
    final index = _channels.indexOf(channel);
    if (index < 0) {
      throw LineupFailure('${channel.name} is not part of this lineup');
    }
    return at(index);
  }

  /// Moves to an absolute position in the full lineup.
  ChannelZapper atIndex(int index) {
    if (index < 0 || index >= _channels.length) {
      throw LineupFailure('position $index is outside 0..${_channels.length - 1} of the lineup');
    }
    if (group != null && !_scope.contains(index)) {
      throw LineupFailure('${_channels[index].name} is not in group "$group", so it cannot be selected');
    }
    return at(index);
  }

  /// The position of [channel] in the full lineup, or -1; a repeated row reports every copy.
  List<int> positionsOf(ZapChannel channel) => <int>[
    for (var index = 0; index < _channels.length; index++)
      if (_channels[index] == channel) index,
  ];

  /// The position of the current station within the visible scope, 1-based; 0 when nothing is in scope.
  int get visibleNumber {
    final slot = _scope.indexOf(cursor);
    return slot < 0 ? 0 : slot + 1;
  }

  /// A copy positioned at [cursor]; -1 is legal and means "nothing selected".
  ChannelZapper at(int cursor) =>
      ChannelZapper(channels: _channels, group: group, cursor: cursor, skipUnplayable: skipUnplayable);

  bool get _holdsCursor => cursor >= 0 && _scope.contains(cursor);

  ZapStep _step(int direction) {
    if (_scope.isEmpty) {
      return ZapEmpty('${group == null ? 'the lineup' : 'group "$group"'} has no channels to zap through');
    }
    final held = _scope.indexOf(cursor);
    var from = held < 0 ? (direction > 0 ? -1 : 0) : held;
    for (var attempt = 0; attempt < _scope.length; attempt++) {
      from = (from + direction) % _scope.length;
      if (from < 0) {
        from += _scope.length;
      }
      final index = _scope[from];
      if (!skipUnplayable || _channels[index].isPlayable) {
        return ZapMoved(_channels[index], zapper: at(index));
      }
    }
    // Everything in scope is unplayable: stay where the viewer is and say so, rather than wrapping onto a
    // black screen over and over.
    return ZapEmpty('all ${_scope.length} channels in ${group ?? 'the lineup'} have no playable stream');
  }

  @override
  String toString() =>
      'ChannelZapper(${_channels.length} entries${group == null ? '' : ', group "$group"'}'
      ', visible=${_scope.length}, at=$visibleNumber)';
}
