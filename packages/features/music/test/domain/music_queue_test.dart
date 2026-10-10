// Module: test/domain/music_queue_test.dart
// Purpose: Pins cursor-preserving removal, the end-of-queue distinction and commit verification.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_music_feature/pure_live_music_feature.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

ContentRef _song(String id) => ContentRef(sourceId: 'wy', contentId: id, kind: ContentKind.music);

QueueEntry _entry(String id) => QueueEntry(ref: _song(id), title: id);

MusicQueue _queue(int songs) => MusicQueue().enqueue(_song('a')).enqueue(_song('b')).enqueue(_song('c')).withCursor(0);

void main() {
  test('test_musicQueue_appendingToAnEmptyQueueStartsPlayingIt', () {
    final queue = MusicQueue().enqueue(_song('a'));

    expect(queue.cursor, 0);
    expect(queue.current?.ref.contentId, 'a');
  });

  test('test_musicQueue_appendingWhilePlayingDoesNotMoveTheCursor', () {
    final queue = _queue(3).enqueue(_song('d'));

    expect(queue.cursor, 0);
    expect(queue.length, 4);
  });

  test('test_musicQueue_removingBeforeTheCursorKeepsTheSameSongCurrent', () {
    // The defect this replaces: the cursor stayed at its number while the list shifted left underneath it,
    // silently skipping one song.
    final queue = _queue(3).withCursor(2);
    final after = queue.withoutAt(0);

    expect(after.cursor, 1);
    expect(after.current?.ref.contentId, queue.current?.ref.contentId);
  });

  test('test_musicQueue_removingTheCurrentSongLeavesTheCursorOnWhatsNext', () {
    final queue = _queue(3).withCursor(1);
    final after = queue.withoutAt(1);

    expect(after.current?.ref.contentId, 'c');
    expect(after.cursor, 1);
  });

  test('test_musicQueue_removingTheLastSongParksTheCursorInTheList', () {
    final queue = _queue(3).withCursor(2).withoutAt(2);

    expect(queue.current?.ref.contentId, 'b');
  });

  test('test_musicQueue_removingEverythingEmptiesTheQueue', () {
    var queue = _queue(3);
    queue = queue.withoutAt(2).withoutAt(1).withoutAt(0);

    expect(queue.isEmpty, isTrue);
    expect(queue.cursor, -1);
    expect(queue.peekNext().reason, QueueAdvanceReason.queueEmpty);
  });

  test('test_musicQueue_walksForwardAndStopsAtTheEnd', () {
    var queue = _queue(3);
    queue = queue.commit(queue.peekNext());
    expect(queue.current?.ref.contentId, 'b');
    queue = queue.commit(queue.peekNext());
    expect(queue.current?.ref.contentId, 'c');

    final atEnd = queue.peekNext();
    expect(atEnd.reason, QueueAdvanceReason.atEnd, reason: 'the queue is not empty, it is finished');
    expect(atEnd.isActionable, isFalse);
  });

  test('test_musicQueue_repeatAllWrapsAndNamesTheWrap', () {
    final queue = _queue(3).withCursor(2).withEndMode(QueueEndMode.repeatAll);
    final step = queue.peekNext();

    expect(step.reason, QueueAdvanceReason.wrapped);
    expect(queue.commit(step).current?.ref.contentId, 'a');
  });

  test('test_musicQueue_repeatOneReoffersTheCurrentSong', () {
    final queue = _queue(3).withCursor(1).withRepeatOne(true);
    final step = queue.peekNext();

    expect(step.reason, QueueAdvanceReason.repeatOne);
    expect(step.entry?.ref.contentId, 'b');
    expect(queue.commit(step).cursor, 1);
  });

  test('test_musicQueue_committingAStaleAdvanceIsRefused', () {
    final queue = _queue(3);
    final stale = queue.peekNext(); // 'b' at index 1
    final changed = queue.withoutAt(0); // now 'c' sits at index 1

    expect(
      () => changed.commit(stale),
      throwsA(isA<QueueFailure>().having((error) => error.reason, 'reason', contains('no longer at index'))),
    );
  });

  test('test_musicQueue_committingANonActionableStepIsRefused', () {
    final queue = _queue(3).withCursor(2);

    expect(() => queue.commit(queue.peekNext()), throwsA(isA<QueueFailure>()));
    expect(
      () => MusicQueue().commit(const QueueAdvance(reason: QueueAdvanceReason.queueEmpty)),
      throwsA(isA<QueueFailure>()),
    );
  });

  test('test_musicQueue_cursorAndIndexAreChecked', () {
    final queue = _queue(3);

    expect(() => queue.withCursor(3), throwsA(isA<QueueFailure>()));
    expect(() => queue.withoutAt(-1), throwsA(isA<QueueFailure>()));
  });

  test('test_musicQueue_withoutSongDropsEveryCopyOfADuplicate', () {
    final queue = MusicQueue().enqueue(_song('a')).enqueue(_song('dup')).enqueue(_song('b')).enqueue(_song('dup'));

    final after = queue.withoutSong(_song('dup'));
    expect(after.entries.map((entry) => entry.ref.contentId), <String>['a', 'b']);
  });

  test('test_musicQueue_entriesAreUnmodifiable', () {
    final queue = _queue(3);

    expect(() => queue.entries.clear(), throwsUnsupportedError);
  });

  test('test_musicQueue_clearedKeepsTheMode', () {
    final queue = _queue(3).withEndMode(QueueEndMode.repeatAll).withRepeatOne(true).cleared();

    expect(queue.isEmpty, isTrue);
    expect(queue.endMode, QueueEndMode.repeatAll);
    expect(queue.repeatOne, isTrue);
  });

  test('test_queueEntry_displayFallsBackToTheIdAndEqualityIgnoresNothing', () {
    expect(QueueEntry(ref: _song('only-id')).displayTitle, 'only-id');
    expect(_entry('a'), _entry('a'));
    expect(_entry('a') == QueueEntry(ref: _song('a'), title: 'remixed'), isFalse);
    expect(_entry('a').sameSongAs(QueueEntry(ref: _song('a'), title: 'remixed')), isTrue);
  });
}
