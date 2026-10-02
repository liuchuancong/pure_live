import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Attempt-owned CSV from the clock-v1 segment muxing profile. This journal is
/// not interchangeable with legacy TS produced with per-child timestamp shifts.
class RecordingSegmentClock {
  RecordingSegmentClock._(this.paths, this.starts);
  static const maxBytes = 8 * 1024 * 1024;
  static const maxSegments = 100000;
  // The profile is in every TS name so a missing journal is never mistaken
  // for a legacy recording and merged with the old, shifted clock semantics.
  static const segmentSuffix = '.clock-v1.ts';
  final List<String> paths;
  final List<int> starts;

  static String segmentPattern(String prefix) {
    _prefix(prefix);
    return '${prefix}_%06d$segmentSuffix';
  }

  static String segmentName(String prefix, int index) {
    _prefix(prefix);
    if (index < 0 || index >= maxSegments) throw const FormatException('Recording clock segment index');
    return '${prefix}_${index.toString().padLeft(6, '0')}$segmentSuffix';
  }

  static String journalName(String prefix) {
    _prefix(prefix);
    return '$prefix.clock-v1.csv';
  }

  static void _prefix(String prefix) {
    if (prefix.isEmpty || prefix.length > 256 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(prefix)) {
      throw const FormatException('Recording clock attempt prefix');
    }
  }

  static Future<RecordingSegmentClock> read(File file, {required String prefix, required List<File> segments}) async {
    final bytes = <int>[];
    await for (final chunk in file.openRead()) {
      if (chunk.length > maxBytes - bytes.length) throw const FormatException('Recording clock journal budget');
      bytes.addAll(chunk);
    }
    return RecordingSegmentClock.parse(
      utf8.decode(bytes),
      prefix: prefix,
      segments: segments.map((f) => f.path).toList(),
    );
  }

  factory RecordingSegmentClock.parse(String csv, {required String prefix, required List<String> segments}) {
    _prefix(prefix);
    if (csv.length > maxBytes || segments.isEmpty || segments.length > maxSegments || !csv.endsWith('\n')) {
      throw const FormatException('Recording clock journal shape or unfinished row');
    }
    final rows = const LineSplitter().convert(csv);
    if (rows.length != segments.length) throw const FormatException('Recording clock missing or extra segment');
    final starts = <int>[];
    final paths = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final fields = rows[i].split(',');
      final expected = segmentName(prefix, i);
      if (fields.length != 3 || fields[0] != expected || p.basename(segments[i]) != expected) {
        throw const FormatException('Recording clock segment identity or order');
      }
      final start = _time(fields[1]);
      final end = _time(fields[2]);
      if ((i == 0 && start != 0) || (i > 0 && start <= starts.last) || end <= start) {
        throw const FormatException('Recording clock timestamp order');
      }
      // End is not used to guess the next boundary. VFR/reordered frames may
      // end before/after a following segment's reference-stream start.
      starts.add(start);
      final path = p.absolute(segments[i]);
      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(path)) throw const FormatException('Recording clock path controls');
      paths.add(path);
    }
    if (paths.map(p.dirname).toSet().length != 1) throw const FormatException('Recording clock mixed directories');
    return RecordingSegmentClock._(List.unmodifiable(paths), List.unmodifiable(starts));
  }

  static int _time(String value) {
    if (!RegExp(r'^\d{1,10}(?:\.\d{1,6})?$').hasMatch(value)) throw const FormatException('Recording clock timestamp');
    final parts = value.split('.');
    final micros = int.parse(parts[0]) * 1000000 + (parts.length == 1 ? 0 : int.parse(parts[1].padRight(6, '0')));
    if (micros > 9007199254740991) throw const FormatException('Recording clock timestamp range');
    return micros;
  }

  String toConcatManifest() {
    final manifest = StringBuffer('ffconcat version 1.0\n');
    for (var i = 0; i < paths.length; i++) {
      final escaped = paths[i].replaceAll('\\', '/').replaceAll("'", r"'\''");
      manifest.writeln("file '$escaped'\ninpoint 0");
      if (i + 1 < paths.length) {
        final duration = starts[i + 1] - starts[i];
        manifest.writeln('duration ${duration ~/ 1000000}.${(duration % 1000000).toString().padLeft(6, '0')}');
      }
    }
    return manifest.toString();
  }
}

/// Owns a new clock-v1 output across asynchronous native initialization and
/// execution. FFmpeg's -n does not protect its auxiliary segment-list file.
/// This prevents same-process collisions and rejects existing on-disk output.
class RecordingClockReservation {
  RecordingClockReservation._(this._key);
  static final _active = <String>{};
  final String _key;
  bool _released = false;

  static Future<RecordingClockReservation?> acquire(List<String> arguments) async {
    if (arguments.isEmpty || !arguments.last.endsWith('_%06d${RecordingSegmentClock.segmentSuffix}')) return null;
    final output = p.normalize(p.absolute(arguments.last));
    final basename = p.basename(output);
    final prefix = basename.substring(0, basename.length - '_%06d${RecordingSegmentClock.segmentSuffix}'.length);
    final journal = p.join(p.dirname(output), RecordingSegmentClock.journalName(prefix));
    final index = arguments.indexOf('-segment_list');
    if (index < 0 ||
        index + 1 >= arguments.length ||
        !p.equals(p.normalize(p.absolute(arguments[index + 1])), journal)) {
      throw const FormatException('Recording clock journal output identity');
    }
    final key = Platform.isWindows ? journal.toLowerCase() : journal;
    if (!_active.add(key)) throw StateError('Recording clock output is already active');
    try {
      if (await FileSystemEntity.type(journal, followLinks: false) != FileSystemEntityType.notFound) {
        throw const FileSystemException('Recording clock output already exists');
      }
      // Partial cleanup/recovery may leave only a non-zero segment. Check both
      // profiles before FFmpeg can create/truncate the auxiliary CSV.
      final matcher = RegExp('^${RegExp.escape(prefix)}_\\d{6,}(?:\\.clock-v1)?\\.ts\$', caseSensitive: false);
      await for (final entity in Directory(p.dirname(output)).list(followLinks: false)) {
        if (matcher.hasMatch(p.basename(entity.path))) {
          throw const FileSystemException('Recording clock segment already exists');
        }
      }
      return RecordingClockReservation._(key);
    } catch (_) {
      _active.remove(key);
      rethrow;
    }
  }

  void release() {
    if (_released) return;
    _released = true;
    _active.remove(_key);
  }
}
