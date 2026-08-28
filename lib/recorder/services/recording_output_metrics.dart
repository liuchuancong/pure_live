import 'dart:io';

import 'package:path/path.dart' as p;

class RecordingOutputSnapshot {
  const RecordingOutputSnapshot({required this.bytes, required this.segmentCount, this.latestModified});

  static const empty = RecordingOutputSnapshot(bytes: 0, segmentCount: 0);

  final int bytes;
  final int segmentCount;
  final DateTime? latestModified;
}

/// Converts per-FFmpeg-attempt counters into totals for one user recording
/// session. Native statistics restart at zero whenever a signed URL is
/// refreshed; recorder cards must stay monotonic across those retries.
class RecordingAttemptProgress {
  const RecordingAttemptProgress({required this.baseBytes, required this.baseSeconds});

  final int baseBytes;
  final int baseSeconds;

  int totalBytes(int attemptBytes) => baseBytes + attemptBytes.clamp(0, 1 << 62).toInt();

  int totalSeconds(int attemptSeconds) => baseSeconds + attemptSeconds.clamp(0, 1 << 31).toInt();
}

/// Reads the recorder's actual segment files instead of relying on FFmpeg's
/// aggregate `size` statistic. The segment muxer commonly reports `N/A`/zero
/// while individual files are already growing on disk.
class RecordingOutputMetrics {
  const RecordingOutputMetrics();

  RecordingOutputTracker track({required String directoryPath, required String filePrefix}) {
    return RecordingOutputTracker(directoryPath: directoryPath, filePrefix: filePrefix);
  }

  Future<RecordingOutputSnapshot> measure({required String directoryPath, required String filePrefix}) async {
    final normalizedDirectory = directoryPath.trim();
    final normalizedPrefix = filePrefix.trim();
    if (normalizedDirectory.isEmpty || normalizedPrefix.isEmpty) return RecordingOutputSnapshot.empty;

    final directory = Directory(normalizedDirectory);
    if (!await directory.exists()) return RecordingOutputSnapshot.empty;

    var bytes = 0;
    var segmentCount = 0;
    DateTime? latestModified;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('${normalizedPrefix}_') || !name.toLowerCase().endsWith('.ts')) continue;
        try {
          final stat = await entity.stat();
          bytes += stat.size;
          segmentCount++;
          if (latestModified == null || stat.modified.isAfter(latestModified)) latestModified = stat.modified;
        } on FileSystemException {
          // A segment can rotate between directory enumeration and stat. The
          // next one-second sample will observe the completed replacement.
        }
      }
    } on FileSystemException {
      return RecordingOutputSnapshot.empty;
    }

    return RecordingOutputSnapshot(bytes: bytes, segmentCount: segmentCount, latestModified: latestModified);
  }
}

/// Incremental tracker for FFmpeg's deterministic `%06d.ts` segment output.
/// It stats only the active segment and, on rotation, the next sequential
/// file. Long recordings therefore remain O(1) per UI sample instead of
/// rescanning every historical segment once per second.
class RecordingOutputTracker {
  RecordingOutputTracker({required String directoryPath, required String filePrefix})
    : _directoryPath = directoryPath.trim(),
      _filePrefix = filePrefix.trim();

  final String _directoryPath;
  final String _filePrefix;
  var _currentIndex = 0;
  var _firstIndex = 0;
  var _finalizedBytes = 0;
  RecordingOutputSnapshot _lastSnapshot = RecordingOutputSnapshot.empty;

  Future<RecordingOutputSnapshot> sample() async {
    if (_directoryPath.isEmpty || _filePrefix.isEmpty) return _lastSnapshot;

    while (true) {
      final current = File(_segmentPath(_currentIndex));
      if (!await current.exists()) {
        if (_lastSnapshot.segmentCount > 0 || !await _locateFirstExistingSegment()) return _lastSnapshot;
        continue;
      }
      try {
        final currentStat = await current.stat();
        final next = File(_segmentPath(_currentIndex + 1));
        if (await next.exists()) {
          _finalizedBytes += currentStat.size;
          _currentIndex++;
          continue;
        }
        _lastSnapshot = RecordingOutputSnapshot(
          bytes: _finalizedBytes + currentStat.size,
          segmentCount: _currentIndex - _firstIndex + 1,
          latestModified: currentStat.modified,
        );
        return _lastSnapshot;
      } on FileSystemException {
        return _lastSnapshot;
      }
    }
  }

  /// Normally FFmpeg starts at 000000. Recovery after a process restart or a
  /// platform-specific segment-number override may leave the first visible
  /// segment at another index. Discover that index once, then return to the
  /// O(1) sequential tracker path.
  Future<bool> _locateFirstExistingSegment() async {
    final directory = Directory(_directoryPath);
    if (!await directory.exists()) return false;
    final matcher = RegExp('^${RegExp.escape(_filePrefix)}_(\\d{6})\\.ts\$', caseSensitive: false);
    int? firstIndex;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final match = matcher.firstMatch(p.basename(entity.path));
        if (match == null) continue;
        final index = int.tryParse(match.group(1)!);
        if (index != null && (firstIndex == null || index < firstIndex)) firstIndex = index;
      }
    } on FileSystemException {
      return false;
    }
    if (firstIndex == null) return false;
    _currentIndex = firstIndex;
    _firstIndex = firstIndex;
    return true;
  }

  String _segmentPath(int index) {
    final suffix = index.toString().padLeft(6, '0');
    return p.join(_directoryPath, '${_filePrefix}_$suffix.ts');
  }
}
