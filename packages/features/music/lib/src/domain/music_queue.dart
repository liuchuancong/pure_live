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

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// What happens after the last song of the queue.
enum QueueEndMode { stop, repeatAll }

/// Why "next" returned the entry it did.
enum QueueAdvanceReason {
  sequential,
  repeatOne,
  wrapped,

  /// The queue holds entries but there is nothing after the cursor under the current mode.
  atEnd,

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

/// The decided next step, carrying the entry it chose so a commit can be checked against the current list.
final class QueueAdvance {
  const QueueAdvance({required this.reason, this.entry, this.index = -1});

  final QueueAdvanceReason reason;
  final QueueEntry? entry;
  final int index;

  bool get hasEntry => entry != null;

  /// True when the step names a song the player should go and open.
  ///
  /// `atEnd` deliberately is not actionable even though it carries the current entry: it answers "there is
  /// nothing after this", and committing it would restart the last song under the guise of advancing.
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
  const MusicQueue({
    List<QueueEntry> entries = const <QueueEntry>[],
    this.cursor = -1,
    this.endMode = QueueEndMode.stop,
    this.repeatOne = false,
  }) : _entries = entries;

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

  List<QueueEntry> get entries => List<QueueEntry>.unmodifiable(_entries);

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  QueueEntry? get current => cursor >= 0 && cursor < _entries.length ? _entries[cursor] : null;

  /// The queue with [entry] appended.
  ///
  /// An empty queue becomes the playing song immediately (cursor 0); appending to a queue that is already
  /// playing does not move the cursor.
  MusicQueue withEntry(QueueEntry entry) {
    final next = <QueueEntry>[..._entries, entry];
    return MusicQueue(entries: next, cursor: cursor < 0 ? 0 : cursor, endMode: endMode, repeatOne: repeatOne);
  }

  /// The queue with the song at [index] appended.
  MusicQueue enqueue(ContentRef ref, {String? title, String? artist}) =>
      withEntry(QueueEntry(ref: ref, title: title, artist: artist));

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
      return MusicQueue(entries: next, endMode: endMode, repeatOne: repeatOne);
    }
    var moved = cursor;
    if (index < cursor) {
      moved = cursor - 1;
    } else if (index == cursor) {
      moved = cursor >= next.length ? next.length - 1 : cursor;
    }
    return MusicQueue(entries: next, cursor: moved, endMode: endMode, repeatOne: repeatOne);
  }

  /// The queue with every entry of [ref] removed, for "don't play this song again" after a duplicate was
  /// enqueued from two playlists.
  MusicQueue withoutSong(ContentRef ref) {
    var queue = this;
    for (var index = _entries.length - 1; index >= 0; index--) {
      if (_entries[index].ref.sourceId == ref.sourceId && _entries[index].ref.contentId == ref.contentId) {
        queue = queue.withoutAt(index);
      }
    }
    return queue;
  }

  /// The queue with the cursor on [index].
  MusicQueue withCursor(int index) {
    if (index < 0 || index >= _entries.length) {
      throw QueueFailure('$index is outside 0..${_entries.length - 1} of this queue');
    }
    return MusicQueue(entries: _entries, cursor: index, endMode: endMode, repeatOne: repeatOne);
  }

  /// The queue with the end-of-queue behaviour changed.
  MusicQueue withEndMode(QueueEndMode mode) =>
      MusicQueue(entries: _entries, cursor: cursor, endMode: mode, repeatOne: repeatOne);

  /// The queue with repeat-one turned on or off.
  MusicQueue withRepeatOne(bool value) =>
      MusicQueue(entries: _entries, cursor: cursor, endMode: endMode, repeatOne: value);

  /// The queue with nothing in it.
  MusicQueue cleared() => MusicQueue(endMode: endMode, repeatOne: repeatOne);

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
    return MusicQueue(entries: _entries, cursor: found, endMode: endMode, repeatOne: repeatOne);
  }
}
