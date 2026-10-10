// Module: lib/src/domain/episode_navigator.dart
// Purpose: Consecutive-playback decisions for one detail's episode list, as a pure model the player asks.
// Author: liuchuancong
// Created: 2026-10-10
//
// docs/sources/vod/vod-architecture.md defines 连播 as a PlaybackQueue. This is that queue for one detail's
// children: positional (the episode list's order *is* the source's order), with no knowledge of urls or
// tickets, and with the same rule the live session uses - a proposal is not a commitment, because a failed
// open must not skip the episode the viewer never saw.
//
// Two defects from the previous version are the reason this file is a rewrite rather than an extension:
// episodes were matched with `ContentRef`'s full equality, which also compares parentId, providerId and
// metadata - so a reference that came back from the ticket layer with any extra field did not match the
// queue entry and consecutive playback stopped working silently. And a current episode that was not in the
// list left the object in a state with `index == -1`, where both `next()` and `previous()` returned nothing
// without ever saying why.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// The direction a step moves in.
enum EpisodeDirection { next, previous, none }

/// Why a navigation request could not be answered with the queue it was given.
final class EpisodeNavigationFailure extends DomainFailure {
  const EpisodeNavigationFailure(super.reason, {super.cause});
}

/// One proposed move: what would play, and whether the queue is at its edge either way.
final class EpisodeStep {
  const EpisodeStep({required this.direction, this.episode, required this.atEdge});

  final EpisodeDirection direction;

  /// The episode the player should open, null when there is nowhere to go.
  final ContentRef? episode;

  /// True when the queue ends in this direction, which is what distinguishes "no more episodes" from
  /// "this queue is empty" on screen.
  final bool atEdge;

  bool get hasNext => episode != null;

  @override
  String toString() => 'EpisodeStep(${direction.name}${episode == null ? '' : ' -> $episode'})';
}

/// The positional navigator over one detail's children.
///
/// Immutable: `stepNext` proposes, `commit` moves, and the queue the player holds is replaced by the result.
final class EpisodeQueue {
  EpisodeQueue({required List<ContentRef> episodes, ContentRef? current})
    : _episodes = List<ContentRef>.unmodifiable(episodes) {
    // The cursor is derived, never supplied: an index that disagrees with `current` is exactly the drift
    // this object exists to make unrepresentable.
    if (episodes.isEmpty) {
      if (current != null) {
        throw EpisodeNavigationFailure('cannot select $current from an empty episode list');
      }
      _current = null;
      _cursor = -1;
      return;
    }
    final wanted = current ?? episodes.first;
    final found = _indexOf(wanted);
    if (found < 0) {
      throw EpisodeNavigationFailure('$wanted is not one of the ${episodes.length} episodes in this queue');
    }
    _cursor = found;
    _current = _episodes[found];
  }

  final List<ContentRef> _episodes;

  late final ContentRef? _current;

  int _cursor = -1;

  /// The list in source order.
  List<ContentRef> get episodes => _episodes;

  /// The committed episode, or null for an empty queue.
  ContentRef? get current => _current;

  /// The committed position, or -1 when the queue holds nothing.
  int get cursor => _cursor;

  bool get isEmpty => _episodes.isEmpty;

  bool get hasNext => cursor >= 0 && cursor + 1 < _episodes.length;

  bool get hasPrevious => cursor > 0;

  /// The episode after the current one, without moving anything.
  EpisodeStep stepNext() => hasNext
      ? EpisodeStep(direction: EpisodeDirection.next, episode: _episodes[cursor + 1], atEdge: false)
      : EpisodeStep(direction: EpisodeDirection.none, atEdge: true);

  /// The episode before the current one, without moving anything.
  EpisodeStep stepPrevious() => hasPrevious
      ? EpisodeStep(direction: EpisodeDirection.previous, episode: _episodes[cursor - 1], atEdge: false)
      : EpisodeStep(direction: EpisodeDirection.none, atEdge: true);

  /// The queue after the player reports it opened [episode].
  ///
  /// Throws for an episode this queue does not hold: a queue built from one detail's children cannot commit
  /// a reference from somewhere else, and pretending otherwise is how the cursor silently lands on -1.
  EpisodeQueue commit(ContentRef episode) {
    final found = _indexOf(episode);
    if (found < 0) {
      throw EpisodeNavigationFailure(
        'the player opened $episode, which is not in this ${_episodes.length}-episode queue',
      );
    }
    return EpisodeQueue(episodes: _episodes, current: _episodes[found]);
  }

  /// The queue with a new episode list, keeping the current one when the new list still holds it.
  ///
  /// A detail refresh that reordered the list must not jump the viewer back to episode 1.
  EpisodeQueue withEpisodes(List<ContentRef> episodes) {
    if (current == null || !_holds(episodes, current!)) {
      return EpisodeQueue(episodes: episodes);
    }
    return EpisodeQueue(episodes: episodes, current: current);
  }

  int _indexOf(ContentRef ref) {
    for (var index = 0; index < _episodes.length; index++) {
      if (sameContent(_episodes[index], ref)) {
        return index;
      }
    }
    return -1;
  }

  bool _holds(List<ContentRef> episodes, ContentRef ref) => episodes.any((candidate) => sameContent(candidate, ref));
}

/// True when two references name the same content: source and id only.
///
/// Deliberately narrower than `ContentRef`'s own equality, which also compares parentId, providerId and
/// metadata. Those fields legitimately differ between a detail's child entry and the reference that came
/// back from the ticket layer, and treating them as identity is what broke consecutive playback.
bool sameContent(ContentRef left, ContentRef right) =>
    left.sourceId == right.sourceId && left.contentId == right.contentId;
