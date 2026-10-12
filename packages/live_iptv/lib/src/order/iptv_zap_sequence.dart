/// The channel list as a remote control steps through it.
///
/// Zapping is its own concept rather than an index into a screen, because
/// the two disagree: a screen shows a group, a favourites filter, or a
/// search result, while the up and down keys walk the *whole* visible list
/// and come back round at the ends. This is that walk — a value object
/// built from an ordered list, with the wrap-around, the reversal some
/// remotes want, and the two cases a player must not treat as a channel
/// change (stepping in a one-channel list, and stepping at all when the
/// list is empty).
///
/// Nothing here is stored: it is derived from the library every time the
/// ordering or the visibility rules change, so a hidden channel cannot
/// stay reachable by an old sequence, and a re-import cannot leave a
/// phantom channel that types itself.
library;

import 'package:live_iptv/src/model/model.dart';
import 'package:meta/meta.dart';

/// Where a step of the zap sequence ended up.
enum IptvZapEdge {
  /// Another channel.
  moved,

  /// Another channel, reached by going past the top or the bottom of the
  /// list and coming back round the other end.
  wrapped,

  /// The channel that was already selected: a list of one, or a step that
  /// asked for the id it started from.
  same,

  /// Nothing at all: the sequence is empty.
  empty,
}

/// The answer to one step.
@immutable
class IptvZapStep {
  /// A step.
  const new(this.channel, this.edge);

  /// The channel to play, null when [edge] is [IptvZapEdge.empty].
  final IptvChannel? channel;

  /// How the step landed.
  final IptvZapEdge edge;

  /// Whether this step is a new channel the player has to load.
  ///
  /// A step that lands where it started must not reload the stream: the
  /// 3.x generation of this app re-fetched a channel when the user pressed
  /// down on the only channel of a group, and the picture restarted from
  /// the beginning for no reason the user could see.
  bool get needsLoad => edge == IptvZapEdge.moved || edge == IptvZapEdge.wrapped;

  /// Whether the step went past an end of the list to get here.
  bool get wrapped => edge == IptvZapEdge.wrapped;

  @override
  bool operator ==(Object other) => other is IptvZapStep && other.channel == channel && other.edge == edge;

  @override
  int get hashCode => Object.hash(channel, edge);

  @override
  String toString() => 'IptvZapStep(${channel?.entry.name ?? '-'}, ${edge.name})';
}

/// An ordered, wrap-around walk over a set of channels.
final class IptvZapSequence {
  /// A walk over [channels], which must already be in display order.
  ///
  /// [reversed] swaps the meaning of the up and down keys — the reversal
  /// some remote layouts want — without reordering the list, so a screen
  /// still reads top to bottom the same way.
  new({required List<IptvChannel> channels, this.reversed = false}) : _channels = List.unmodifiable(channels);

  final List<IptvChannel> _channels;

  /// Whether the up and down keys are swapped.
  final bool reversed;

  /// The channels, in the order the walk visits them.
  List<IptvChannel> get channels => _channels;

  /// How many channels the walk covers.
  int get length => _channels.length;

  /// Whether there is nothing to walk.
  bool get isEmpty => _channels.isEmpty;

  /// The first channel, null in an empty sequence.
  IptvChannel? get first => _channels.isEmpty ? null : _channels.first;

  /// The last channel, null in an empty sequence.
  IptvChannel? get last => _channels.isEmpty ? null : _channels.last;

  /// The channel at [index], or null when it is out of range.
  IptvChannel? at(int index) => index >= 0 && index < _channels.length ? _channels[index] : null;

  /// The index of [channelId], or null when the sequence does not carry it.
  int? indexOf(String channelId) {
    for (final (index, channel) in _channels.indexed) {
      if (channel.id == channelId) {
        return index;
      }
    }
    return null;
  }

  /// The channel numbered [number], or null.
  ///
  /// A typed number is looked up rather than stepped to, because the remote
  /// has already said which channel it wants: `203` means channel 203, not
  /// "twenty steps on".
  IptvChannel? byNumber(int number) {
    for (final channel in _channels) {
      if (channel.number == number) {
        return channel;
      }
    }
    return null;
  }

  /// Steps [delta] places from [fromId], wrapping at both ends.
  ///
  /// An unknown or missing [fromId] is not an error: stepping forward starts
  /// at the top of the list and stepping back at the bottom, which is what a
  /// user pressing a key as the page opens means, and what keeps a channel
  /// that was deleted between two presses from stranding the remote.
  IptvZapStep step(int delta, {String? fromId}) {
    if (_channels.isEmpty || delta == 0) {
      final current = fromId == null ? null : _byId(fromId);
      return IptvZapStep(current, current == null ? IptvZapEdge.empty : IptvZapEdge.same);
    }
    final offset = reversed ? -delta : delta;
    final index = fromId == null ? null : indexOf(fromId);
    if (index == null) {
      return IptvZapStep(offset > 0 ? _channels.first : _channels.last, IptvZapEdge.moved);
    }
    if (_channels.length == 1) {
      return IptvZapStep(_channels.single, IptvZapEdge.same);
    }
    final count = _channels.length;
    final target = ((index + offset) % count + count) % count;
    if (target == index) {
      return IptvZapStep(_channels[target], IptvZapEdge.same);
    }
    // Wrapping is a fact the interface reports ("back to the first
    // channel"), so a long list does not look like it stopped working.
    final wrapped = index + offset < 0 || index + offset >= count;
    return IptvZapStep(_channels[target], wrapped ? IptvZapEdge.wrapped : IptvZapEdge.moved);
  }

  /// The channel one place on from [fromId].
  IptvZapStep next({String? fromId}) => step(1, fromId: fromId);

  /// The channel one place back from [fromId].
  IptvZapStep previous({String? fromId}) => step(-1, fromId: fromId);

  IptvChannel? _byId(String channelId) {
    for (final channel in _channels) {
      if (channel.id == channelId) {
        return channel;
      }
    }
    return null;
  }
}
