import 'dart:async';

import 'package:live_record_core/live_record_core.dart';

/// An in-memory slot store, so the ledger is tested without a filesystem.
class MemorySlots implements RecordSlotIo {
  /// The bytes behind each key.
  final Map<String, String> files = <String, String>{};

  /// When set, the next [read] of that key answers null: a half-written document
  /// from a power cut, which the store must skip rather than choke on.
  String? unreadable;

  @override
  Future<String?> read(String key) async {
    if (key == unreadable) {
      return null;
    }

    return files[key];
  }

  @override
  Future<void> write(String key, String value) async => files[key] = value;

  @override
  Future<void> delete(String key) async => files.remove(key);

  @override
  Future<List<String>> keys() async => files.keys.toList();
}

/// A capture whose end is decided by the test.
class FakeCapture implements RecordCapture {
  /// Creates a capture that will report [outcome] once ended.
  new(this.outcome);

  /// Progress the test pushes, as a real capture reports it.
  final StreamController<RecordProgress> _progress = StreamController<RecordProgress>.broadcast();

  /// What this capture reports once it has ended; a test may replace it.
  @override
  CaptureOutcome outcome;

  bool stopCalled = false;
  bool cancelCalled = false;

  /// Emits one progress report.
  void report(RecordProgress value) => _progress.add(value);

  @override
  Stream<RecordProgress> get onProgress => _progress.stream;

  final Completer<void> _ended = Completer<void>();

  /// Ends the capture by itself, the way a stream that stopped does.
  void end() {
    if (!_ended.isCompleted) {
      _ended.complete();
    }

    if (!_progress.isClosed) {
      unawaited(_progress.close());
    }
  }

  @override
  Future<void> get ended => _ended.future;

  @override
  Future<void> stop() async {
    stopCalled = true;
    end();
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
    end();
  }
}

/// The outside world, scripted: probe answers, captures, files, notices.
class FakeServices implements RecordServices {
  /// Answers handed back by [probe], in order; the last one repeats.
  new({required this._script, RecordFiles? files}) : files = files ?? FakeFiles();

  final List<RoomProbe> _script;
  final List<FakeCapture> captures = <FakeCapture>[];
  final List<RecordNotice> notices = <RecordNotice>[];
  final List<String> guardTexts = <String>[];
  int guardCount = 0;
  int releasedGuards = 0;

  @override
  final RecordFiles files;

  @override
  Future<RoomProbe> probe(RecordTarget target) async {
    final index = _probeIndex.clamp(0, _script.length - 1);
    _probeIndex++;

    return _script[index];
  }

  int _probeIndex = 0;

  /// Re-arms the probe sequence, for a test that needs the same script twice.
  void resetProbe() => _probeIndex = 0;

  @override
  Future<RecordCapture> openCapture({required RecordTask task, required String streamUrl}) async {
    final capture = FakeCapture(
      CaptureOutcome(
        directory: task.paths.sessionDirectory,
        prefix: task.paths.capturePrefix,
        segments: 3,
        bytes: 3000,
        mediaTime: const Duration(seconds: 30),
      ),
    );
    captures.add(capture);

    return capture;
  }

  @override
  Future<RecordGuard?> acquireGuard({required RecordTask task}) async {
    guardCount++;

    return _Guard(this);
  }

  @override
  Future<void> notify(RecordNotice notice) async => notices.add(notice);

  /// The file layer as the double it is, so a test can read what was asked of it.
  FakeFiles get fileLayer => files as FakeFiles;
}

class _Guard implements RecordGuard {
  new(this._owner);

  final FakeServices _owner;

  @override
  Future<void> update(RecordProgress progress) async => _owner.guardTexts.add('${progress.mediaTime.inSeconds}s');

  @override
  Future<void> release() async => _owner.releasedGuards++;
}

/// A file layer over a set of path strings: what exists, what merged, what was
/// renamed, and which renames are refused.
class FakeFiles implements RecordFiles {
  /// Paths the layer knows about.
  final Set<String> existing = <String>{};

  /// Every merge asked for, in order.
  final List<List<PendingAttempt>> merges = <List<PendingAttempt>>[];

  /// Every rename asked for, as `from → to`.
  final List<String> renames = <String>[];

  /// A path that is already taken, so a rename onto it fails.
  String? occupiedTarget;

  /// Free space [freeBytes] reports; null means the platform cannot answer.
  int? free = 10 * 1024 * 1024 * 1024;

  /// Why the next merge should fail.
  String? failMergeWith;

  @override
  Future<int?> freeBytes(String directory) async => free;

  @override
  Future<bool> exists(String path) async => existing.contains(path);

  @override
  Future<MergeOutcome> merge({required RecordTask task, required List<PendingAttempt> attempts}) async {
    merges.add(attempts);

    if (failMergeWith != null) {
      return MergeOutcome(path: task.paths.asciiMergedPath, bytes: 0, mediaTime: Duration.zero, failure: failMergeWith);
    }

    final media = attempts.fold(Duration.zero, (total, attempt) => total + attempt.mediaTime);
    final bytes = attempts.fold<int>(0, (total, attempt) => total + attempt.bytes);
    existing.add(task.paths.asciiMergedPath);

    return MergeOutcome(path: task.paths.asciiMergedPath, bytes: bytes, mediaTime: media);
  }

  @override
  Future<RenameOutcome> rename({required String from, required String to}) async {
    renames.add('$from → $to');

    if (occupiedTarget != null && occupiedTarget == to) {
      return RenameOutcome(applied: false, path: from, failure: '目标文件名已存在');
    }

    if (!existing.contains(from)) {
      return RenameOutcome(applied: false, path: from, failure: '源文件不在');
    }

    existing
      ..remove(from)
      ..add(to);

    return RenameOutcome(applied: true, path: to);
  }
}

/// Waits for the real timers this package schedules.
Future<void> pump([int milliseconds = 40]) => Future<void>.delayed(Duration(milliseconds: milliseconds));

/// The policy every test uses: millisecond waits, no jitter, no stall watchdog
/// unless the test asks for one.
RecordPolicy fastPolicy({
  int maxConcurrent = 2,
  Duration stallTimeout = Duration.zero,
  Duration recheck = const Duration(milliseconds: 5),
}) {
  return RecordPolicy(
    maxConcurrent: maxConcurrent,
    pollInterval: const Duration(milliseconds: 10),
    pollJitter: Duration.zero,
    retryInterval: const Duration(milliseconds: 5),
    recheckInterval: recheck,
    stallTimeout: stallTimeout,
    minUsefulRecording: Duration.zero,
  );
}

/// A room that is live at an address the platform just signed.
RoomProbe live({String url = 'https://cdn.example.test/flv?sign=abc'}) {
  return RoomProbe(outcome: ProbeOutcome.live, streamUrl: url, roomTitle: '今晚打老虎');
}

/// A room that is not broadcasting.
const RoomProbe offline = RoomProbe(outcome: ProbeOutcome.offline);

/// The target most tests use.
const RecordTarget target = RecordTarget(platform: 'douyin', roomId: '8891', anchorName: '主播8891');
