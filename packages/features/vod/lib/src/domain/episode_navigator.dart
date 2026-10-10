// Module: lib/src/domain/episode_navigator.dart
// Purpose: Consecutive-playback decisions for a vod's episode list, as a pure
// model the player surface asks: what plays after this?
// Author: liuchuancong
// Created: 2026-10-10
//
// docs/sources/vod/vod-architecture.md: 连播 = PlaybackQueue. The navigator is
// that queue for one detail's children, positional (the episode list's order
// is the source's order), with no knowledge of urls or tickets.

import 'package:pure_live_platform/pure_live_platform.dart';

/// The next step after the current episode.
final class EpisodeStep {
  const EpisodeStep({required this.direction, this.next});

  final EpisodeDirection direction;
  final ContentRef? next;

  bool get hasNext => next != null;
}

enum EpisodeDirection { next, previous, none }

/// The positional navigator over one detail's children.
final class EpisodeNavigator {
  EpisodeNavigator({required List<ContentRef> episodes, ContentRef? current})
    : _episodes = List.of(episodes),
      _current = current ?? (episodes.isNotEmpty ? episodes.first : null) {
    _syncIndex();
  }

  final List<ContentRef> _episodes;
  ContentRef? _current;
  int _index = -1;

  List<ContentRef> get episodes => List.unmodifiable(_episodes);
  ContentRef? get current => _current;
  int get index => _index;
  bool get hasNext => _index >= 0 && _index + 1 < _episodes.length;
  bool get hasPrevious => _index > 0;

  void _syncIndex() {
    _index = _current == null ? -1 : _episodes.indexWhere((episode) => episode == _current);
  }

  /// Replaces the current episode after the player opened it, and resyncs the
  /// position.
  void setCurrent(ContentRef ref) {
    _current = ref;
    _syncIndex();
  }

  /// The next episode, when one exists. Does not move the cursor - call
  /// [setCurrent] when the player actually opened it, so a failed open does
  /// not skip an episode the viewer never saw.
  EpisodeStep next() {
    if (!hasNext) {
      return const EpisodeStep(direction: EpisodeDirection.none);
    }
    return EpisodeStep(direction: EpisodeDirection.next, next: _episodes[_index + 1]);
  }

  EpisodeStep previous() {
    if (!hasPrevious) {
      return const EpisodeStep(direction: EpisodeDirection.none);
    }
    return EpisodeStep(direction: EpisodeDirection.previous, next: _episodes[_index - 1]);
  }
}
