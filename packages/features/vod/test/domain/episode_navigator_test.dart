// Module: test/domain/episode_navigator_test.dart
// Purpose: Pins identity matching across the ticket layer and the proposal/commit split.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_vod/pure_live_vod.dart';
import 'package:test/test.dart';

ContentRef _episode(String id, {Map<String, Object?> metadata = const <String, Object?>{}, String? parentId}) =>
    ContentRef(sourceId: 's1', contentId: id, kind: ContentKind.episode, metadata: metadata, parentId: parentId);

List<ContentRef> _list(int count) => <ContentRef>[for (var i = 1; i <= count; i++) _episode('e$i')];

void main() {
  test('test_episodeQueue_startsAtTheFirstEpisodeAndWalksForward', () {
    final queue = EpisodeQueue(episodes: _list(3));

    expect(queue.current?.contentId, 'e1');
    expect(queue.stepNext().episode?.contentId, 'e2');
    expect(queue.stepPrevious().hasNext, isFalse);
    expect(queue.stepPrevious().atEdge, isTrue);
  });

  test('test_episodeQueue_stepDoesNotMoveTheCursor', () {
    final queue = EpisodeQueue(episodes: _list(3));

    expect(queue.stepNext().episode?.contentId, 'e2');
    expect(queue.cursor, 0, reason: 'a failed open must not skip the episode the viewer never saw');
    expect(queue.stepNext().episode?.contentId, 'e2');
  });

  test('test_episodeQueue_commitsAnEpisodeThatCarriedExtraFields', () {
    // The defect this replaces: full ContentRef equality compared metadata and parentId too, so the
    // reference that came back from the ticket layer did not match the queue entry and 连播 stopped.
    final queue = EpisodeQueue(episodes: _list(3));
    final opened = ContentRef(
      sourceId: 's1',
      contentId: 'e2',
      kind: ContentKind.episode,
      parentId: 'series-9',
      metadata: <String, Object?>{'url': 'https://x'},
    );

    final moved = queue.commit(opened);
    expect(moved.cursor, 1);
    expect(moved.current?.contentId, 'e2');
    expect(moved.stepNext().episode?.contentId, 'e3');
  });

  test('test_episodeQueue_committingAnUnknownEpisodeIsRefused', () {
    final queue = EpisodeQueue(episodes: _list(2));

    expect(
      () => queue.commit(_episode('foreign')),
      throwsA(isA<EpisodeNavigationFailure>().having((error) => error.reason, 'reason', contains('not in this'))),
    );
  });

  test('test_episodeQueue_theEndSaysSoInsteadOfReturningNothing', () {
    final queue = EpisodeQueue(episodes: _list(2), current: _episode('e2'));
    final step = queue.stepNext();

    expect(step.direction, EpisodeDirection.none);
    expect(step.atEdge, isTrue);
    expect(step.hasNext, isFalse);
  });

  test('test_episodeQueue_anEmptyQueueIsNotAnErrorButRefusesACurrent', () {
    final empty = EpisodeQueue(episodes: const <ContentRef>[]);

    expect(empty.isEmpty, isTrue);
    expect(empty.cursor, -1);
    expect(empty.stepNext().atEdge, isTrue);
    expect(
      () => EpisodeQueue(episodes: const <ContentRef>[], current: _episode('e1')),
      throwsA(isA<EpisodeNavigationFailure>()),
    );
  });

  test('test_episodeQueue_aRefreshKeepsTheViewerWhereTheyWere', () {
    final queue = EpisodeQueue(episodes: _list(3), current: _episode('e3'));
    final refreshed = queue.withEpisodes(_list(5));

    expect(refreshed.current?.contentId, 'e3', reason: 'a reordered list must not jump back to episode 1');
    expect(refreshed.hasNext, isTrue);
  });

  test('test_episodeQueue_aRefreshThatDroppedTheCurrentEpisodeStartsOver', () {
    final queue = EpisodeQueue(episodes: _list(3), current: _episode('e3'));
    final refreshed = queue.withEpisodes(_list(1));

    expect(refreshed.current?.contentId, 'e1');
  });

  test('test_episodeQueue_episodesAreUnmodifiable', () {
    final queue = EpisodeQueue(episodes: _list(2));

    expect(() => queue.episodes.add(_episode('e3')), throwsUnsupportedError);
  });

  test('test_sameContent_ignoresTheFieldsThatDifferBetweenLayers', () {
    expect(sameContent(_episode('e1'), _episode('e1', metadata: <String, Object?>{'a': 1}, parentId: 'p')), isTrue);
    expect(sameContent(_episode('e1'), _episode('e2')), isFalse);
  });
}
