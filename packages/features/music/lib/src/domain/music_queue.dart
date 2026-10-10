// Module: lib/src/domain/music_queue.dart
// Purpose: The music play queue: the ordered songs, the cursor, and what "next" means under each mode.
// Author: liuchuancong
// Created: 2026-10-10
//
// The queue is a pure model: it never fetches urls - resolving a song is the source bridge's job. It answers
// one question, "what plays after this", and answers it as a proposal the player commits, so a failed
// resolve cannot desync the list from what is audible.
//
// Three defects in the previous version are why this is a rewrite:
//
// 1. Removing an entry *before* the cursor left the cursor where it was, silently skipping one song - the
//     list shifted under a number that no longer meant the same place.
// 2. Running off the end with endMode stop reported `queueEmpty`, which is a different fact: the queue has
//     entries, they are just finished, and a surface that confuses the two shows "nothing queued" over a
//     song list.
// 3. A peeked step could be committed after the queue had changed, moving the cursor to whatever now sat at
//     that index. An advance now names the entry it chose, and committing verifies it is still there.
//
// The queue is immutable for the same reason the live session and the zapper are: these are objects a UI
// rebuilds against while a callback from the player arrives, and a mutable list plus a cursor is two things
// that can disagree.
//
// Every transition here keeps the cursor on the *song* it was on, not on the index it was at, because the one
// operation a music surface does constantly is edit the list underneath the playing track: insert, drag,
// delete, replace the whole queue from a playlist.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// What happens after the last song of the queue.
enum QueueEndMode { stop, repeatAll }

/// Why a step returned the entry it did.
enum QueueAdvanceReason {
  /// The list-order neighbour in the direction asked for.
  sequential,

  /// Repeat-one re-offers the current song.
  repeatOne,

  /// Ran off the end (or the start) and the mode wraps.
  wrapped,

  /// The queue holds entries but there is nothing after the cursor under the current mode.
  atEnd,

  /// The queue holds entries but there is nothing before the cursor.
  atStart,

  /// The queue holds nothing at all.
  queueEmpty,
}

/// A music queue could not be changed or committed the way the caller asked.
final class QueueFailure extends DomainFailure {
  const QueueFailure(super.reason, {super.cause});
}

/// One song slot. The reference is the identity; the title and artist are the display card captured at
/// enqueue time, so a list does not need to re-resolve every row to draw itself.
final class QueueEntry with ValueEquality {
  const QueueEntry({required this.ref, this.title, this.artist});

  final ContentRef ref;
  final String? title;
  final String? artist;

  String get displayTitle => title?.isNotEmpty == true ? title! : ref.contentId;

  String get displayArtist => artist ?? '';

  /// True when both entries name the same content, ignoring the display card.
  bool sameSongAs(QueueEntry other) => ref.sourceId == other.ref.sourceId && ref.contentId == other.ref.contentId;

  @override
  List<Object?> get equalityFields => <Object?>[ref.sourceId, ref.contentId, title, artist];

  @override
  String toString() => 'QueueEntry($displayTitle${artist == null ? '' : ' - $artist'})';
}

/// The decided step, carrying the entry it chose so a commit can be checked against the current list.
final class QueueAdvance {
  const QueueAdvance({required this.reason, this.entry, this.index = -1});

  final QueueAdvanceReason reason;
  final QueueEntry? entry;
  final int index;

  bool get hasEntry => entry != null;

  /// True when the step names a song the player should go and open.
  ///
  /// `atEnd` and `atStart` deliberately are not actionable even though each carries the current entry: they
  /// answer "there is nothing on that side", and committing one would restart the current song under the
  /// guise of advancing.
  bool get isActionable =>
      hasEntry &&
      (reason == QueueAdvanceReason.sequential ||
          reason == QueueAdvanceReason.repeatOne ||
          reason == QueueAdvanceReason.wrapped);

  @override
  String toString() => 'QueueAdvance(${reason.name}${entry == null ? '' : ' ${entry!.displayTitle}@#$index'})';
}

/// The ordered music queue and its cursor.
final class MusicQueue {
  /// [entries] is copied. A model whose getter returns an unmodifiable view while the field still aliases the
  /// caller's list can have its playing song reordered from outside, which is the whole thing this class
  /// exists to prevent.
  MusicQueue({
    List<QueueEntry> entries = const <QueueEntry>[],
    this.cursor = -1,
    this.endMode = QueueEndMode.stop,
    this.repeatOne = false,
  }) : _entries = List<QueueEntry>.unmodifiable(entries);

  /// The proposal-free starting point: an empty queue with the caller's mode.
  const MusicQueue.empty({this.endMode = QueueEndMode.stop, this.repeatOne = false})
    : _entries = const <QueueEntry>[],
      cursor = -1;

  final List<QueueEntry> _entries;

  /// Index into [_entries], or -1 when nothing is playing.
  final int cursor;

  final QueueEndMode endMode;

  /// Re-offers the current song instead of advancing. Orthogonal to [endMode]: with repeatOne set, the end
  /// of the queue is never reached.
  final bool repeatOne;

  List<QueueEntry> get entries => _entries;

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  bool get isNotEmpty => !_entries.isEmpty;

  QueueEntry? get current => cursor >= 0 && cursor < _entries.length ? _entries[cursor] : null;

  /// The queue with [entry] appended.
  ///
  /// An empty queue becomes the playing song immediately (cursor 0); appending to a queue that is already
  /// playing does not move the cursor.
  MusicQueue withEntry(QueueEntry entry) => insertAt(_entries.length, entry);

  /// The queue with the song at [index] appended.
  MusicQueue enqueue(ContentRef ref, {String? title, String? artist}) =>
      withEntry(QueueEntry(ref: ref, title: title, artist: artist));

  /// The queue with [entry] placed at [index], which may be [length] to append.
  ///
  /// Inserting at or before the cursor shifts it right so it keeps naming the same song; inserting an empty
  /// queue's first entry selects it, matching [withEntry].
  MusicQueue insertAt(int index, QueueEntry entry) {
    if (index < 0 || index > _entries.length) {
      throw QueueFailure('cannot insert at $index in a ${_entries.length}-song queue');
    }
    final next = <QueueEntry>[..._entries]..insert(index, entry);
    final moved = _entries.isEmpty && cursor < 0 ? 0 : (index <= cursor ? cursor + 1 : cursor);
    return _copyWith(entries: next, cursor: moved);
  }

  /// The queue with [index] removed, keeping the cursor on the same *song* where that is possible.
  ///
  /// Deleting before the cursor shifts it left; deleting the current song leaves the cursor on whatever
  /// shifted into its place; deleting the last entry when it was current parks the cursor on the new last.
  MusicQueue withoutAt(int index) {
    if (index < 0 || index >= _entries.length) {
      throw QueueFailure('there is no entry at $index in a ${_entries.length}-song queue');
    }
    final next = <QueueEntry>[..._entries]..removeAt(index);
    if (next.isEmpty) {
      return _copyWith(entries: next, cursor: -1);
    }
    var moved = cursor;
    if (index < cursor) {
      moved = cursor - 1;
    } else if (index == cursor) {
      moved = cursor >= next.length ? next.length - 1 : cursor;
    }
    return _copyWith(entries: next, cursor: moved);
  }

  /// The queue with every entry of [ref] removed, for "don't play this song again" after a duplicate was
  /// enqueued from two playlists.
  ///
  /// Returns to [MusicQueue] with cursor -1 when the playing song was the one removed and nothing is left.
  MusicQueue withoutSong(ContentRef ref) {
    var queue = this;
    for (var index = _entries.length - 1; index >= 0; index--) {
      if (_entries[index].ref.sourceId == ref.sourceId && _entries[index].ref.contentId == ref.contentId) {
        queue = queue.withoutAt(index);
      }
    }
    return queue;
  }

  /// The queue with the entry at [from] moved to [to], the drag on a queue row.
  ///
  /// The cursor follows the song that was playing, not the slot it vacated: reordering the list while a track
  /// runs must never change what is audible.
  MusicQueue move(int from, int to) {
    _requireSlot(from, 'move from');
    if (to < 0 || to >= _entries.length) {
      throw QueueFailure('cannot move to $to in a ${_entries.length}-song queue');
    }
    if (from == to) {
      return this;
    }
    final next = <QueueEntry>[..._entries];
    next.insert(to, next.removeAt(from));
    var moved = cursor;
    if (cursor == from) {
      moved = to;
    } else if (from < cursor && cursor <= to) {
      moved = cursor - 1;
    } else if (to <= cursor && cursor < from) {
      moved = cursor + 1;
    }
    return _copyWith(entries: next, cursor: moved);
  }

  /// The queue with the whole list replaced, keeping the cursor on the playing song when the new list still
  /// holds it.
  ///
  /// A cursor that no longer names a present song becomes -1 rather than being parked on row 0: silently
  /// starting to claim a different song is "the one playing" is the desync this model exists to prevent.
  MusicQueue withEntries(Iterable<QueueEntry> entries) {
    final next = List<QueueEntry>.unmodifiable(entries);
    final held = current;
    if (held == null) {
      return _copyWith(entries: next, cursor: -1);
    }
    final index = next.indexWhere((entry) => entry.sameSongAs(held));
    return _copyWith(entries: next, cursor: index);
  }

  /// The queue with the cursor on [index].
  MusicQueue withCursor(int index) {
    _requireSlot(index, 'withCursor');
    return _copyWith(cursor: index);
  }

  /// The queue with the end-of-queue behaviour changed.
  MusicQueue withEndMode(QueueEndMode mode) => _copyWith(endMode: mode);

  /// The queue with repeat-one turned on or off.
  MusicQueue withRepeatOne(bool value) => _copyWith(repeatOne: value);

  /// The queue with nothing in it.
  MusicQueue cleared() => _copyWith(entries: const <QueueEntry>[], cursor: -1);

  /// The position of the song named by [ref], or -1. The first copy of a song queued twice is reported.
  int indexOfSong(ContentRef ref) {
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (entry.ref.sourceId == ref.sourceId && entry.ref.contentId == ref.contentId) {
        return index;
      }
    }
    return -1;
  }

  bool containsSong(ContentRef ref) => indexOfSong(ref) >= 0;

  /// How many copies of [ref] are queued; a duplicate from two playlists is the number a surface shows
  /// before it offers "remove all copies".
  int countOfSong(ContentRef ref) =>
      _entries.where((entry) => entry.ref.sourceId == ref.sourceId && entry.ref.contentId == ref.contentId).length;

  /// The next songs in list order, starting after the cursor, wrapping only when [endMode] repeats.
  ///
  /// This is the "next up" window, not a prediction under repeat-one: [peekNext] is what actually plays next,
  /// which under repeat-one is the current song again. Capped at [length] so a two-song queue cannot yield
  /// ten rows.
  List<QueueEntry> upcoming({int limit = 5}) {
    if (limit <= 0 || _entries.isEmpty) {
      return const <QueueEntry>[];
    }
    final start = cursor < 0 ? 0 : cursor + 1;
    final span = limit > _entries.length ? _entries.length : limit;
    final rows = <QueueEntry>[];
    for (var offset = 0; offset < span; offset++) {
      final index = start + offset;
      if (index >= _entries.length) {
        if (endMode != QueueEndMode.repeatAll) {
          break;
        }
        rows.add(_entries[index % _entries.length]);
      } else {
        rows.add(_entries[index]);
      }
    }
    return List<QueueEntry>.unmodifiable(rows);
  }

  /// The next step per the mode rules, without moving anything.
  QueueAdvance peekNext() {
    if (_entries.isEmpty) {
      return const QueueAdvance(reason: QueueAdvanceReason.queueEmpty);
    }
    if (repeatOne && current != null) {
      return QueueAdvance(reason: QueueAdvanceReason.repeatOne, entry: current, index: cursor);
    }
    final next = cursor + 1;
    if (next < _entries.length) {
      return QueueAdvance(reason: QueueAdvanceReason.sequential, entry: _entries[next], index: next);
    }
    if (endMode == QueueEndMode.repeatAll) {
      return QueueAdvance(reason: QueueAdvanceReason.wrapped, entry: _entries.first, index: 0);
    }
    return QueueAdvance(reason: QueueAdvanceReason.atEnd, entry: current, index: cursor);
  }

  /// The step the player takes when it has finished, or when the viewer pressed next.
  ///
  /// [skip] means "the viewer pressed next", which under repeat-one must move on: the point of the flag is
  /// that an intentional skip is not the automatic end-of-song path. A single function for both made a
  /// repeat-one queue impossible to skip past its first song.
  QueueAdvance nextFor({bool skip = false}) => skip && repeatOne ? _nextIgnoringRepeat() : peekNext();

  QueueAdvance _nextIgnoringRepeat() {
    if (_entries.isEmpty) {
      return const QueueAdvance(reason: QueueAdvanceReason.queueEmpty);
    }
    final next = cursor + 1;
    if (next < _entries.length) {
      return QueueAdvance(reason: QueueAdvanceReason.sequential, entry: _entries[next], index: next);
    }
    if (endMode == QueueEndMode.repeatAll) {
      return QueueAdvance(reason: QueueAdvanceReason.wrapped, entry: _entries.first, index: 0);
    }
    return QueueAdvance(reason: QueueAdvanceReason.atEnd, entry: current, index: cursor);
  }

  /// The previous step, for the "back" key: the list-order neighbour before the cursor, wrapping only when
  /// [endMode] repeats.
  QueueAdvance peekPrevious() {
    if (_entries.isEmpty) {
      return const QueueAdvance(reason: QueueAdvanceReason.queueEmpty);
    }
    if (cursor > 0) {
      return QueueAdvance(reason: QueueAdvanceReason.sequential, entry: _entries[cursor - 1], index: cursor - 1);
    }
    if (endMode == QueueEndMode.repeatAll && _entries.length > 1) {
      return QueueAdvance(reason: QueueAdvanceReason.wrapped, entry: _entries.last, index: _entries.length - 1);
    }
    return QueueAdvance(reason: QueueAdvanceReason.atStart, entry: current, index: cursor);
  }

  /// The queue after the player reported it started [advance]'s song.
  ///
  /// Throws when the entry is no longer at that index: the alternative is moving the cursor onto a different
  /// song than the one that was proposed, which is how a queue ends up showing the wrong row as playing.
  MusicQueue commit(QueueAdvance advance) {
    final wanted = advance.entry;
    if (!advance.isActionable || wanted == null) {
      throw QueueFailure('a ${advance.reason.name} step has nothing to commit');
    }
    final found = advance.index;
    if (found < 0 || found >= _entries.length || !_entries[found].sameSongAs(wanted)) {
      throw QueueFailure(
        'the queued song "${wanted.displayTitle}" is no longer at index $found of a ${_entries.length}-song queue',
      );
    }
    return _copyWith(cursor: found);
  }

  MusicQueue _copyWith({List<QueueEntry>? entries, int? cursor, QueueEndMode? endMode, bool? repeatOne}) => MusicQueue(
    entries: entries ?? _entries,
    cursor: cursor ?? this.cursor,
    endMode: endMode ?? this.endMode,
    repeatOne: repeatOne ?? this.repeatOne,
  );

  void _requireSlot(int index, String what) {
    if (index < 0 || index >= _entries.length) {
      throw QueueFailure('$what: $index is outside 0..${_entries.length - 1} of this queue');
    }
  }

  @override
  String toString() =>
      'MusicQueue($length songs${cursor < 0 ? ', nothing playing' : ', at #${cursor + 1}'}'
      '${endMode.name}${repeatOne ? '+repeatOne' : ''})';
}
