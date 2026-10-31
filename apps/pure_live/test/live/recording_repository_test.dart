// The recording repository's write guards: the rules that keep an older take's
// late work (a progress tick, a finished join) from writing over a newer take of
// the same room. They are the class of bug a double-branch finalize once had, so
// each one is pinned here against an in-memory store rather than trusted.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// Just enough of [JsonStore] for the repository: an ordered map and the two
/// change streams the interface promises.
final class _MemoryStore implements JsonStore {
  final Map<String, Object?> _values = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<String> _keys = StreamController<String>.broadcast();

  @override
  String get namespace => 'recordings';

  @override
  Object? get(String key) => _values[key];

  @override
  bool contains(String key) => _values.containsKey(key);

  @override
  List<String> get keys => _values.keys.toList();

  @override
  List<Object?> get values => _values.values.toList();

  @override
  Map<String, Object?> get entries => Map<String, Object?>.of(_values);

  @override
  int get length => _values.length;

  @override
  bool get isEmpty => _values.isEmpty;

  @override
  bool get isNotEmpty => _values.isNotEmpty;

  @override
  Stream<void> watch() => _changes.stream;

  @override
  Stream<String> watchKeys() => _keys.stream;

  @override
  Future<void> put(String key, Object? value) async {
    _values[key] = value;
    _keys.add(key);
    _changes.add(null);
  }

  @override
  Future<void> putAll(Map<String, Object?> values) async {
    _values.addAll(values);
    _changes.add(null);
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
    _keys.add(key);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    keys.forEach(_values.remove);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _values.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {
    await _changes.close();
    await _keys.close();
  }
}

RecordingTask _task({required DateTime startedAt, RecordingTaskState state = RecordingTaskState.stopped}) => RecordingTask(
  id: 'bili:1',
  platform: 'bili',
  roomId: '1',
  roomTitle: '房间',
  quality: '原画',
  state: state,
  startedAt: startedAt,
  filePath: r'D:\rec\take_a',
  bytes: 100,
  durationMs: 1000,
  scheduleEnabled: true,
  scheduleDays: const [1, 3, 5],
  scheduleStartMinutes: 1260,
  scheduleEndMinutes: 1320,
  stopAtWindowEnd: true,
);

void main() {
  final first = DateTime.utc(2026, 10, 31, 12);
  final second = first.add(const Duration(minutes: 30));

  test('a new take keeps the schedule and drops the last take’s facts', () async {
    final repo = RecordingTaskRepository(_MemoryStore());
    await repo.save(_task(startedAt: first));
    final before = DateTime.now().toUtc();

    await repo.setRunning('bili:1');

    final task = repo.taskById('bili:1')!;
    expect(task.state, RecordingTaskState.recording);
    expect(task.startedAt.isBefore(before), isFalse);
    expect(task.scheduleEnabled, isTrue);
    expect(task.scheduleDays, [1, 3, 5]);
    expect(task.scheduleStartMinutes, 1260);
    expect(task.scheduleEndMinutes, 1320);
    expect(task.stopAtWindowEnd, isTrue);
    expect(task.filePath, isNull);
    expect(task.bytes, 0);
    expect(task.warning, '');
    expect(task.postProcessing, isFalse);
  });

  test('post-processing begins only for an ended take of the expected session', () async {
    final repo = RecordingTaskRepository(_MemoryStore());
    await repo.save(_task(startedAt: first));

    expect(await repo.beginPostProcessing('bili:1', expectedStartedAt: second), isFalse, reason: 'a newer take owns the row');
    expect(repo.taskById('bili:1')!.postProcessing, isFalse);

    await repo.save(_task(startedAt: first, state: RecordingTaskState.recording));
    expect(await repo.beginPostProcessing('bili:1', expectedStartedAt: first), isFalse, reason: 'a running take is not ended');

    await repo.save(_task(startedAt: first).copyWith(warning: 'join-failed'));
    expect(await repo.beginPostProcessing('bili:1', expectedStartedAt: first), isTrue);
    final task = repo.taskById('bili:1')!;
    expect(task.postProcessing, isTrue);
    expect(task.postProcessingProgress, -1);
    expect(task.warning, '', reason: 'the new run owns the warning line');
  });

  test('progress and the final path are refused for another session', () async {
    final repo = RecordingTaskRepository(_MemoryStore());
    await repo.save(_task(startedAt: first).copyWith(postProcessing: true));

    expect(await repo.setPostProcessingProgress('bili:1', expectedStartedAt: second, progress: 0.5), isFalse);
    expect(await repo.setFinalPath('bili:1', expectedStartedAt: second, filePath: r'D:\rec\new.mp4'), isFalse);
    expect(repo.taskById('bili:1')!.filePath, r'D:\rec\take_a');

    expect(await repo.setPostProcessingProgress('bili:1', expectedStartedAt: first, progress: 0.5), isTrue);
    expect(repo.taskById('bili:1')!.postProcessingProgress, 0.5);
  });

  test('finishing clears the flag and records the warning', () async {
    final repo = RecordingTaskRepository(_MemoryStore());
    await repo.save(_task(startedAt: first).copyWith(postProcessing: true, postProcessingProgress: 0.7));

    expect(await repo.finishPostProcessing('bili:1', expectedStartedAt: first, warning: 'canceled'), isTrue);
    final task = repo.taskById('bili:1')!;
    expect(task.postProcessing, isFalse);
    expect(task.postProcessingProgress, -1);
    expect(task.warning, 'canceled');
  });

  test('the run’s progress does not touch the state it travels with', () async {
    final repo = RecordingTaskRepository(_MemoryStore());
    await repo.save(_task(startedAt: first, state: RecordingTaskState.recording));

    await repo.setProgress('bili:1', 4096, durationMs: 9000);

    final task = repo.taskById('bili:1')!;
    expect(task.bytes, 4096);
    expect(task.durationMs, 9000);
    expect(task.state, RecordingTaskState.recording, reason: 'a ticking capture has not ended');
    expect(task.startedAt, first);
  });

  test('an ended take reports its verdict and keeps the path it was given', () async {
    final repo = RecordingTaskRepository(_MemoryStore());
    await repo.save(_task(startedAt: first, state: RecordingTaskState.recording));

    await repo.setEnded(
      'bili:1',
      RecordingTaskState.stopped,
      filePath: r'D:\rec\take_a\take.mp4',
      bytes: 2048,
      durationMs: 3000,
      postProcessing: true,
    );

    final task = repo.taskById('bili:1')!;
    expect(task.state, RecordingTaskState.stopped);
    expect(task.endedAt, isNotNull);
    expect(task.filePath, r'D:\rec\take_a\take.mp4');
    expect(task.bytes, 2048);
    expect(task.durationMs, 3000);
    expect(task.postProcessing, isTrue);
  });
}
