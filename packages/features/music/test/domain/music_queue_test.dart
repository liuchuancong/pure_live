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

  test('test_musicQueue_insertingAtOrBeforeTheCursorKeepsTheSong', () {
    final queue = _queue(3).withCursor(1);

    expect(queue.insertAt(0, _entry('z')).current?.ref.contentId, 'b');
    expect(queue.insertAt(0, _entry('z')).cursor, 2);
    expect(queue.insertAt(1, _entry('y')).cursor, 2, reason: 'inserting AT the cursor still shifts it');
    expect(queue.insertAt(2, _entry('n')).cursor, 1, reason: 'behind the cursor nothing moves');
    expect(queue.insertAt(3, _entry('tail')).length, 4);
    expect(() => queue.insertAt(4, _entry('out')), throwsA(isA<QueueFailure>()));
    expect(() => queue.insertAt(-1, _entry('out')), throwsA(isA<QueueFailure>()));
  });

  test('test_musicQueue_draggingARowKeepsTheAudibleSong', () {
    final queue = _queue(3).withCursor(2);

    expect(queue.move(2, 0).current?.ref.contentId, 'c', reason: 'the song that was playing rode along');
    expect(queue.move(2, 0).entries.map((entry) => entry.ref.contentId), <String>['c', 'a', 'b']);
    expect(queue.move(0, 2).current?.ref.contentId, 'c');
    expect(queue.move(1, 1), same(queue));
    expect(() => queue.move(0, 3), throwsA(isA<QueueFailure>()));
    expect(() => queue.move(-1, 0), throwsA(isA<QueueFailure>()));
  });

  test('test_musicQueue_replacingTheListKeepsTheCursorOnTheSameSongOrLosesIt', () {
    final queue = _queue(3).withCursor(2);

    expect(queue.withEntries(<QueueEntry>[_entry('z'), _entry('c')]).current?.ref.contentId, 'c');
    expect(queue.withEntries(<QueueEntry>[_entry('z'), _entry('c')]).cursor, 1);
    expect(
      queue.withEntries(<QueueEntry>[_entry('z')]).cursor,
      -1,
      reason: 'the playing song is gone; row 0 is a claim',
    );
    expect(queue.withEntries(const <QueueEntry>[]).isEmpty, isTrue);
  });

  test('test_musicQueue_upcomingIsTheNextRowsAndWrapsOnlyUnderRepeatAll', () {
    final queue = _queue(3).withCursor(1);

    expect(queue.upcoming().map((entry) => entry.ref.contentId), <String>['c']);
    expect(queue.withEndMode(QueueEndMode.repeatAll).upcoming(limit: 4).map((entry) => entry.ref.contentId), <String>[
      'c',
      'a',
      'b',
    ], reason: 'the window never shows more rows than the queue has songs');
    expect(queue.upcoming(limit: 0), isEmpty);
    expect(queue.cleared().upcoming(), isEmpty);
    expect(
      MusicQueue(entries: <QueueEntry>[_entry('a'), _entry('b')]).upcoming().length,
      2,
      reason: 'nothing playing yet means the whole list is next up',
    );
  });

  test('test_musicQueue_previousWalksBackAndRefusesTheTop', () {
    final queue = _queue(3).withCursor(2);

    expect(queue.peekPrevious().entry?.ref.contentId, 'b');
    expect(queue.peekPrevious().isActionable, isTrue);
    final top = queue.withCursor(0);
    expect(top.peekPrevious().reason, QueueAdvanceReason.atStart);
    expect(top.peekPrevious().isActionable, isFalse);
    expect(top.withEndMode(QueueEndMode.repeatAll).peekPrevious().entry?.ref.contentId, 'c');
    expect(top.withEndMode(QueueEndMode.repeatAll).peekPrevious().reason, QueueAdvanceReason.wrapped);
    expect(top.withEndMode(QueueEndMode.repeatAll).cleared().peekPrevious().reason, QueueAdvanceReason.queueEmpty);
  });

  test('test_musicQueue_aDeliberateSkipMovesOnUnderRepeatOne', () {
    final queue = _queue(3).withCursor(0).withRepeatOne(true);

    expect(queue.peekNext().reason, QueueAdvanceReason.repeatOne);
    expect(queue.nextFor(skip: true).entry?.ref.contentId, 'b', reason: 'next means next when the viewer pressed it');
    expect(queue.nextFor().reason, QueueAdvanceReason.repeatOne, reason: 'the automatic end-of-song path repeats');
    expect(queue.withRepeatOne(false).nextFor(skip: true).entry?.ref.contentId, 'b');
    expect(queue.cleared().nextFor(skip: true).reason, QueueAdvanceReason.queueEmpty);
  });

  test('test_musicQueue_songLookupCountsCopiesAndAnswersMembership', () {
    final queue = _queue(3).enqueue(_song('a'));

    expect(queue.indexOfSong(_song('a')), 0);
    expect(queue.countOfSong(_song('a')), 2);
    expect(queue.containsSong(_song('zzz')), isFalse);
    expect(queue.indexOfSong(_song('zzz')), -1);
  });

  test('test_musicQueue_theCallerListIsCopiedSoItCannotMoveTheCursor', () {
    final growable = <QueueEntry>[_entry('a'), _entry('b')];
    final queue = MusicQueue(entries: growable, cursor: 1);

    growable
      ..removeAt(0)
      ..add(_entry('c'));
    expect(queue.entries.map((entry) => entry.ref.contentId), <String>['a', 'b']);
    expect(queue.current?.ref.contentId, 'b');
    expect(queue.isNotEmpty, isTrue);
  });
}
