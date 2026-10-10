// Module: lib/src/recording_manager.dart
// Purpose: The task list around the lifecycle model: schedule, start, stop, survive a crash, and stay on disk.
// Author: liuchuancong
// Created: 2026-10-11
//
// RecordingTask says which transitions are legal. Nothing said who may start one, how many may run at once,
// whether the device has room for the file before the encoder fails halfway through it, or what a task left in
// `recording` by a killed app means when the process comes back. Those are the four ways a recorder UI ends up
// lying to a user, and all four are decided here rather than at the call site.
//
// The engine itself is a port: ffmpeg/media_kit wiring belongs to the recorder wave, and a task list that
// cannot be driven without it would be untestable until then.

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'domain/recording_task.dart';

/// The recorder the manager drives. Implementations write to [outputDirectory] using the task's file name.
abstract interface class RecordingEngine {
  /// Starts writing [task]. Throwing leaves the task queued: a start that failed is not a recording.
  Future<void> start(RecordingTask task, {required String outputDirectory});

  /// Stops the run in progress for [taskId], releasing whatever the engine holds.
  Future<void> stop(String taskId);

  /// The directory the engine writes into, for the free-space check and for a "reveal the file" action.
  String outputDirectoryOf(RecordingTask task);
}

/// Reports free space, in bytes, where recordings land. A host that cannot say returns null and the manager
/// treats "unknown" as permission to try rather than as a reason to refuse.
abstract interface class StorageProbe {
  Future<int?> freeBytes(String path);
}

/// Why the manager refused.
final class RecordingRefusal implements Exception {
  const RecordingRefusal(this.reason, {this.detail});

  final RecordingRefusalReason reason;
  final String? detail;

  @override
  String toString() => 'RecordingRefusal(${reason.name}${detail == null ? '' : ': $detail'})';
}

enum RecordingRefusalReason {
  /// Another recording is running and the concurrency limit is reached.
  tooManyRunning,

  /// The destination has less free space than the reservation asks for.
  notEnoughSpace,

  /// No task with that id.
  notFound,

  /// The task cannot make that transition - already stopped, still queued, and so on.
  invalidState,

  /// A second task already writes under that file name.
  duplicateFileName,
}

/// The stored list, over a [KeyValueStore].
///
/// Whole-list granularity, like playlists: a recording's identity is its position in a list the user reads top
/// to bottom, and a per-row port would hide the history cap and the id lookup that belong to the document.
final class RecordingStore {
  RecordingStore({required this.store, this.namespace = 'recorder', this.historyLimit = 200, Clock? clock})
    : _clock = clock ?? systemClock;

  /// Terminal tasks kept. An unbounded history is a list that grows past the file it lives in.
  final int historyLimit;
  final KeyValueStore store;
  final Clock _clock;
  final String namespace;

  String get _key => '$namespace.tasks';

  Future<List<RecordingTask>> load() async {
    final raw = await store.read(_key);
    if (raw is! String || raw.trim().isEmpty) {
      return const <RecordingTask>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <RecordingTask>[];
    }
    if (decoded is! List) {
      return const <RecordingTask>[];
    }
    final out = <RecordingTask>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }
      final task = _decode(Map<String, Object?>.from(entry), _clock);
      if (task != null) {
        out.add(task);
      }
    }
    return List<RecordingTask>.unmodifiable(out);
  }

  Future<void> save(List<RecordingTask> tasks) async {
    final terminal = tasks.where((task) => task.isTerminal).toList(growable: false);
    final kept = terminal.length > historyLimit
        ? <RecordingTask>[...tasks.where((task) => !task.isTerminal), ...terminal.skip(terminal.length - historyLimit)]
        : tasks;
    await store.write(_key, jsonEncode(<Object?>[for (final task in kept) _encode(task)]));
  }

  Future<void> clear() => store.remove(_key);

  static Map<String, Object?> _encode(RecordingTask task) {
    return <String, Object?>{
      'sourceId': task.ref.sourceId,
      'contentId': task.ref.contentId,
      'kind': task.ref.kind.name,
      'fileName': task.fileName,
      'createdAt': task.createdAt.toIso8601String(),
      'beganAt': task.beganAt?.toIso8601String(),
      'stoppedAt': task.stoppedAt?.toIso8601String(),
      'state': task.state.name,
      'endReason': task.endReason?.name,
    };
  }

  static RecordingTask? _decode(Map<String, Object?> json, Clock clock) {
    final sourceId = json['sourceId'];
    final contentId = json['contentId'];
    final fileName = json['fileName'];
    final created = DateTime.tryParse('${json['createdAt']}');
    if (sourceId is! String || contentId is! String || fileName is! String || created == null) {
      return null;
    }
    final kind = _named(ContentKind.values, json['kind']) ?? ContentKind.liveRoom;
    final state = _named(RecordingState.values, json['state']);
    if (state == null) {
      return null;
    }
    final endReason = _named(RecordingEndReason.values, json['endReason']);
    return RecordingTask.restore(
      ref: ContentRef(sourceId: sourceId, contentId: contentId, kind: kind),
      fileName: fileName,
      createdAt: created.toUtc(),
      beganAt: DateTime.tryParse('${json['beganAt']}')?.toUtc(),
      stoppedAt: DateTime.tryParse('${json['stoppedAt']}')?.toUtc(),
      state: state,
      endReason: endReason,
      clock: clock,
    );
  }
}

/// Drives the task list.
final class RecordingManager {
  RecordingManager({
    required RecordingEngine engine,
    required RecordingStore store,
    this.probe,
    this.maxConcurrent = 1,
    this.reserveBytes = 512 * 1024 * 1024,
    Clock? clock,
  }) : _engine = engine,
       _store = store,
       _clock = clock ?? systemClock {
    if (maxConcurrent < 1) {
      throw ArgumentError.value(maxConcurrent, 'maxConcurrent', 'must allow at least one recording');
    }
  }

  /// Most devices, and every phone this app targets, can encode one stream at a time.
  static const int defaultMaxConcurrent = 1;

  final RecordingEngine _engine;
  final RecordingStore _store;
  final StorageProbe? probe;
  final int maxConcurrent;

  /// Free bytes a start requires. The number is a reservation, not a measurement of the result: recording a
  /// two-hour stream produces a file nobody predicted, and refusing at 500 MB free is the honest version of
  /// "this may fail halfway".
  final int reserveBytes;
  final Clock _clock;

  List<RecordingTask> _tasks = const <RecordingTask>[];
  bool _loaded = false;

  /// The list, newest first, as the store holds it.
  List<RecordingTask> get tasks => List<RecordingTask>.unmodifiable(_tasks);

  List<RecordingTask> get running => _tasks.where((task) => task.isRecording).toList(growable: false);

  bool get hasRunning => running.isNotEmpty;

  /// Loads the list and closes out anything left `recording` by a killed process.
  ///
  /// The engine died with the app, so a task still marked recording is a lie - it keeps the concurrency slot,
  /// the UI shows a growing timer, and stopping it writes nothing. They are marked failed with `engineLost`
  /// and stay in the list so the user can see the file they did not get.
  Future<List<RecordingTask>> restore() async {
    final loaded = await _store.load();
    var changed = false;
    final recovered = <RecordingTask>[];
    for (final task in loaded) {
      if (task.isRecording) {
        recovered.add(task.fail(RecordingEndReason.engineLost));
        changed = true;
      } else {
        recovered.add(task);
      }
    }
    _tasks = List<RecordingTask>.unmodifiable(reversedIfNewest(recovered));
    _loaded = true;
    if (changed) {
      await _store.save(_tasks);
    }
    return tasks;
  }

  /// Keeps the newest at the front, the order the list screen reads.
  static List<RecordingTask> reversedIfNewest(List<RecordingTask> tasks) =>
      List<RecordingTask>.unmodifiable(tasks.reversed);

  /// Schedules a recording. Refuses a duplicate file name: two tasks writing one name produce one file that
  /// is neither.
  Future<RecordingTask> schedule(ContentRef ref, String fileName) async {
    await _ensureLoaded();
    final wanted = fileName.trim();
    if (_tasks.any((task) => task.fileName == wanted && !task.isTerminal)) {
      throw RecordingRefusal(RecordingRefusalReason.duplicateFileName, detail: wanted);
    }
    final task = RecordingTask(ref: ref, fileName: wanted, clock: _clock);
    _tasks = List<RecordingTask>.unmodifiable(<RecordingTask>[..._tasks, task]);
    await _store.save(_tasks);
    return task;
  }

  /// Starts a queued task, after the concurrency and free-space checks.
  Future<RecordingTask> start(String id) async {
    await _ensureLoaded();
    final index = _indexOf(id);
    final task = _tasks[index];
    if (!task.isQueued) {
      throw RecordingRefusal(RecordingRefusalReason.invalidState, detail: 'a ${task.state.name} task cannot start');
    }
    if (running.length >= maxConcurrent) {
      throw RecordingRefusal(
        RecordingRefusalReason.tooManyRunning,
        detail: '$maxConcurrent recording(s) already running',
      );
    }
    final directory = _engine.outputDirectoryOf(task);
    final free = await probe?.freeBytes(directory);
    if (free != null && free < reserveBytes) {
      // Refused before the engine touches a file: a recording that dies at 90 % leaves a truncated file the
      // user believed they owned.
      throw RecordingRefusal(RecordingRefusalReason.notEnoughSpace, detail: 'free $free bytes, needs $reserveBytes');
    }
    final started = task.begin();
    try {
      await _engine.start(started, outputDirectory: directory);
    } catch (error) {
      // The engine said no, so the task never began: it stays queued and can be started again.
      throw RecordingRefusal(RecordingRefusalReason.invalidState, detail: 'engine refused: $error');
    }
    _replaceAt(index, started);
    await _store.save(_tasks);
    return started;
  }

  /// Stops a running task. The engine is told first, so a user pressing stop never gets a "stopped" row while
  /// the encoder is still writing.
  Future<RecordingTask> stop(String id, {RecordingEndReason reason = RecordingEndReason.userStopped}) async {
    await _ensureLoaded();
    final index = _indexOf(id);
    final task = _tasks[index];
    if (!task.isRecording) {
      throw RecordingRefusal(RecordingRefusalReason.invalidState, detail: 'a ${task.state.name} task is not recording');
    }
    await _engine.stop(task.id);
    final stopped = task.stop(reason);
    _replaceAt(index, stopped);
    await _store.save(_tasks);
    return stopped;
  }

  /// Records a failure the engine reported on its own (disk full mid-write, stream ended, encoder died).
  Future<RecordingTask> markEnded(String id, RecordingEndReason reason) async {
    await _ensureLoaded();
    final index = _indexOf(id);
    final task = _tasks[index];
    if (task.isTerminal) {
      return task;
    }
    final ended = reason == RecordingEndReason.userStopped ? task.stop(reason) : task.fail(reason);
    _replaceAt(index, ended);
    await _store.save(_tasks);
    return ended;
  }

  /// Forgets a task. Only a terminal one: dropping a running task from the list would strand the file and the
  /// engine handle with nothing pointing at either.
  Future<void> remove(String id) async {
    await _ensureLoaded();
    final index = _indexOf(id);
    if (!_tasks[index].isTerminal) {
      throw RecordingRefusal(RecordingRefusalReason.invalidState, detail: 'stop the recording before removing it');
    }
    _tasks = List<RecordingTask>.unmodifiable(<RecordingTask>[
      ..._tasks.sublist(0, index),
      ..._tasks.sublist(index + 1),
    ]);
    await _store.save(_tasks);
  }

  /// Rebuilds the list with one row replaced: the stored list is unmodifiable by contract, so writing through
  /// an index would throw on the first start a user ever makes.
  void _replaceAt(int index, RecordingTask task) {
    _tasks = List<RecordingTask>.unmodifiable(<RecordingTask>[
      for (var position = 0; position < _tasks.length; position++) position == index ? task : _tasks[position],
    ]);
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) {
      await restore();
    }
  }

  int _indexOf(String id) {
    for (var index = 0; index < _tasks.length; index++) {
      if (_tasks[index].id == id) {
        return index;
      }
    }
    throw RecordingRefusal(RecordingRefusalReason.notFound, detail: id);
  }
}

/// An enum member by its name as it appears in stored JSON, or null when the value is unknown.
///
/// Unknown names come back null rather than a guess: a task whose state cannot be read is a row this build
/// should not re-save under a meaning it did not have.
T? _named<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}
