// Module: lib/src/domain/music_queue.dart
// Purpose: The music play queue: the ordered songs, the cursor, and the
// repeat/shuffle rules that decide what "next" means.
// Author: liuchuancong
// Created: 2026-10-10
//
// The queue is a pure model: it never fetches urls. Resolving a song to a
// play url is the source host's job (providers/music); the queue only answers
// "what plays after this".

import 'package:pure_live_platform/pure_live_platform.dart';

/// What happens after the last song of the queue.
enum QueueEndMode { stop, repeatAll }

/// One song slot in the queue. The ref is the stable identity; the summary is
/// the display card captured at enqueue time.
final class QueueEntry {
  const QueueEntry({required this.ref, this.title, this.artist});

  final ContentRef ref;
  final String? title;
  final String? artist;

  String get displayTitle => title ?? ref.contentId;
}

/// Why "next" returned the entry it did.
enum QueueAdvanceReason { sequential, repeatOne, repeatAll, wrapped, queueEmpty }

/// The decided next step.
final class QueueAdvance {
  const QueueAdvance({required this.reason, this.entry, this.index = -1});

  final QueueAdvanceReason reason;
  final QueueEntry? entry;
  final int index;

  bool get hasEntry => entry != null;
}

/// The ordered music queue.
final class MusicQueue {
  MusicQueue({this.endMode = QueueEndMode.stop, this.repeatOne = false});

  final List<QueueEntry> _entries = <QueueEntry>[];
  int _cursor = -1;
  QueueEndMode endMode;
  bool repeatOne;

  List<QueueEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;
  int get cursor => _cursor;
  bool get isEmpty => _entries.isEmpty;

  QueueEntry? get current => (_cursor >= 0 && _cursor < _entries.length) ? _entries[_cursor] : null;

  /// Appends [ref] to the end. Returns its index.
  int enqueue(ContentRef ref, {String? title, String? artist}) {
    _entries.add(QueueEntry(ref: ref, title: title, artist: artist));
    if (_cursor < 0) {
      _cursor = 0;
    }
    return _entries.length - 1;
  }

  /// Jumps the cursor to [index] without touching the entries.
  bool jumpTo(int index) {
    if (index < 0 || index >= _entries.length) {
      return false;
    }
    _cursor = index;
    return true;
  }

  /// Removes one entry. A removed current entry keeps the cursor on the song
  /// that shifted into its place; removing the last entry parks the cursor.
  void removeAt(int index) {
    if (index < 0 || index >= _entries.length) {
      return;
    }
    _entries.removeAt(index);
    if (_entries.isEmpty) {
      _cursor = -1;
      return;
    }
    if (_cursor >= _entries.length) {
      _cursor = _entries.length - 1;
    }
  }

  void clear() {
    _entries.clear();
    _cursor = -1;
  }

  /// The next step per the mode rules. Does not move the cursor - the player
  /// calls [commitAdvance] when playback actually starts, so a failed resolve
  /// does not desync the queue from what is audible.
  QueueAdvance peekNext() {
    if (_entries.isEmpty) {
      return const QueueAdvance(reason: QueueAdvanceReason.queueEmpty);
    }
    if (repeatOne) {
      return QueueAdvance(reason: QueueAdvanceReason.repeatOne, entry: _entries[_cursor], index: _cursor);
    }
    final next = _cursor + 1;
    if (next < _entries.length) {
      return QueueAdvance(reason: QueueAdvanceReason.sequential, entry: _entries[next], index: next);
    }
    if (endMode == QueueEndMode.repeatAll) {
      return QueueAdvance(reason: QueueAdvanceReason.wrapped, entry: _entries.first, index: 0);
    }
    return const QueueAdvance(reason: QueueAdvanceReason.queueEmpty);
  }

  /// Moves the cursor onto the step [peekNext] returned. Only meaningful for
  /// reasons that carry an entry.
  void commitAdvance(QueueAdvance advance) {
    if (advance.hasEntry) {
      _cursor = advance.index;
    }
  }
}
