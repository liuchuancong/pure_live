import 'dart:io';
import 'dart:ui' show Color;

import 'package:flame_barrage/flame_barrage.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// One recorded chat message, in file time.
///
/// [mode] keeps the Bilibili danmaku mode the recorder wrote (`1`/`6` scroll,
/// `4` bottom, `5` top) so a replayed recording looks like the room did.
class RecordingDanmakuEntry {
  const RecordingDanmakuEntry({
    required this.timeMs,
    required this.text,
    required this.userName,
    required this.color,
    required this.mode,
    required this.fontSize,
  });

  final int timeMs;
  final String text;
  final String userName;
  final Color color;
  final int mode;
  final double? fontSize;

  BarrageType get barrageType => switch (mode) {
    5 => BarrageType.topFixed,
    4 => BarrageType.bottomFixed,
    _ => BarrageType.scroll,
  };
}

/// The chat a recording carries beside it.
///
/// The recorder writes `<prefix>.xml` next to `<prefix>.mp4` (opt-in,
/// `record_danmaku`), in the Bilibili format every danmaku tool reads. Playing a
/// recording means reading that file back and replaying it against the player's
/// position, which is what this class does: parse once, then hand out the
/// entries that fall inside a moving window as the viewer scrubs or plays.
///
/// Responsibilities:
///
/// - parse a danmaku XML file into time-ordered entries
/// - resolve the chat file that belongs to a video file
///
/// It does not:
///
/// - render anything (the barrage controller does)
/// - own the player (the caller drives [position])
class RecordingDanmakuTrack {
  RecordingDanmakuTrack(this.entries);

  final List<RecordingDanmakuEntry> entries;

  bool get isEmpty => entries.isEmpty;

  int get length => entries.length;

  /// Location of the `<prefix>.xml` the recorder writes beside [video].
  ///
  /// The recorder names the pair from the same instant, so the chat file is the
  /// video path with its extension replaced. A file the recorder never wrote for
  /// simply does not exist and the caller gets null.
  static File? chatFileFor(File video) {
    final dot = video.path.lastIndexOf('.');
    final base = dot > 0 ? video.path.substring(0, dot) : video.path;
    final candidate = File(p.setExtension(base, '.xml'));
    return candidate.existsSync() ? candidate : null;
  }

  /// Reads and parses [file]; returns an empty track when it is unreadable.
  ///
  /// Parsing happens off the platform thread: an hour-long recording is a
  /// megabyte-scale document and decoding it inline made opening a recording
  /// hitch on Android.
  static Future<RecordingDanmakuTrack> load(File file) async {
    try {
      final raw = await file.readAsString();
      final entries = parse(raw);
      return RecordingDanmakuTrack(entries);
    } catch (_) {
      return RecordingDanmakuTrack(const <RecordingDanmakuEntry>[]);
    }
  }

  /// Parses the `<i><d p="time,mode,size,color,...">text</d></i>` document.
  static List<RecordingDanmakuEntry> parse(String raw) {
    final document = XmlDocument.parse(raw);
    final entries = <RecordingDanmakuEntry>[];
    for (final element in document.findAllElements('d')) {
      final p = element.getAttribute('p');
      if (p == null) continue;
      final parts = p.split(',');
      if (parts.length < 4) continue;
      final seconds = double.tryParse(parts[0]);
      if (seconds == null) continue;
      final text = element.innerText.trim();
      if (text.isEmpty) continue;
      final userName = element.getAttribute('user')?.trim();
      entries.add(
        RecordingDanmakuEntry(
          timeMs: (seconds * 1000).round(),
          text: text,
          userName: userName == null || userName.isEmpty ? '' : userName,
          color: _colorOf(parts[3]),
          mode: int.tryParse(parts[1]) ?? 1,
          fontSize: parts.length > 2 ? double.tryParse(parts[2]) : null,
        ),
      );
    }
    entries.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return entries;
  }

  static Color _colorOf(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return const Color(0xFFFFFFFF);
    final rgb = parsed & 0xFFFFFF;
    return Color(0xFF000000 | rgb);
  }
}

/// Replays a [RecordingDanmakuTrack] against a moving playback position.
///
/// The player reports its position; this class keeps a cursor into the
/// time-ordered entries and forwards everything between the cursor and the
/// current position plus a small look-ahead, so messages appear slightly before
/// their timestamp instead of a frame late. A seek simply moves the cursor
/// (backwards or forwards) and drops the backlog: rewinding must not replay the
/// whole recording at once, and skipping ahead must not emit what was skipped.
///
/// Responsibilities:
///
/// - own the replay cursor and its scheduler
/// - translate entries into barrage items
///
/// It does not:
///
/// - parse files (the track does)
/// - draw (the barrage controller does)
/// - decide whether chat is on (the caller clears the barrage instead)
class RecordingDanmakuPlayer {
  RecordingDanmakuPlayer({required this.controller});

  /// The pool the messages are pushed into.
  final BarrageController controller;

  /// How far ahead of the position a message may be admitted.
  static const Duration lookAhead = Duration(milliseconds: 400);

  /// Position jump above which playback is treated as a seek.
  static const int seekThresholdMs = 1500;

  RecordingDanmakuTrack? _track;
  int _cursor = 0;
  int _lastPositionMs = 0;
  bool _primed = false;

  bool get hasTrack => _track?.isEmpty == false;

  /// Points the player at a new recording's chat, or at nothing.
  void use(RecordingDanmakuTrack? track) {
    _track = track?.isEmpty == true ? null : track;
    reset();
  }

  /// Rewinds the cursor without touching the rendering pool.
  void reset() {
    _cursor = 0;
    _lastPositionMs = 0;
    _primed = false;
  }

  /// Drops the cursor and every message still on screen.
  void clear() {
    reset();
    controller.clear();
  }

  /// Feeds one position sample, emitting whatever became due.
  ///
  /// [seekTo] overrides the cursor instead of advancing it, for the seek case;
  /// normal playback passes null.
  void position(int positionMs) {
    final track = _track;
    if (track == null) return;
    final clamped = positionMs < 0 ? 0 : positionMs;

    if (!_primed) {
      _primed = true;
      _lastPositionMs = clamped;
      _cursor = _lowerBound(track, clamped);
      return;
    }

    if ((clamped - _lastPositionMs).abs() > seekThresholdMs) {
      _lastPositionMs = clamped;
      _cursor = _lowerBound(track, clamped);
      return;
    }

    _lastPositionMs = clamped;
    final deadline = clamped + lookAhead.inMilliseconds;
    while (_cursor < track.entries.length && track.entries[_cursor].timeMs <= deadline) {
      _emit(track.entries[_cursor]);
      _cursor++;
    }
  }

  /// Moves the cursor as if playback had jumped to [positionMs].
  void seekTo(int positionMs) {
    final track = _track;
    if (track == null) {
      reset();
      return;
    }
    final clamped = positionMs < 0 ? 0 : positionMs;
    _primed = true;
    _lastPositionMs = clamped;
    _cursor = _lowerBound(track, clamped);
  }

  void _emit(RecordingDanmakuEntry entry) {
    controller.send(
      BarrageItem(
        content: entry.text,
        type: entry.barrageType,
        userName: entry.userName,
        textColor: entry.color,
        fontSize: entry.fontSize,
      ),
    );
  }

  /// First index whose timestamp is at or after [timeMs].
  static int _lowerBound(RecordingDanmakuTrack track, int timeMs) {
    final entries = track.entries;
    var low = 0;
    var high = entries.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (entries[mid].timeMs < timeMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
