import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/features/recorder/recording_task.dart';

/// The recording tasks the viewer set up, newest session first.
///
/// A task keeps its room's identity as its key — `platform:roomId`, like a
/// follow — so re-recording a room updates its entry instead of piling up
/// copies. The engine records the sessions; the live check in
/// `recording_monitor.dart` starts the waiting ones.
final class RecordingTaskRepository {
  /// Serves the [store] (the `recordings` namespace).
  RecordingTaskRepository(this.store);

  /// The recordings store: task id → the task's JSON.
  final JsonStore store;

  /// Emits after every committed change.
  Stream<void> watch() => store.watch();

  /// The tasks, newest session first.
  List<RecordingTask> list() {
    final tasks = [for (final value in store.values) RecordingTask.fromJson(value)];
    return tasks..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Stores [task] whole, replacing any entry behind its id.
  Future<void> save(RecordingTask task) => store.put(task.id, task.toJson());

  /// Drops the task behind [id]; a task never stored is a no-op.
  Future<void> remove(String id) => store.delete(id);

  /// Drops every task.
  Future<void> clear() async {
    await store.deleteAll(store.keys);
  }

  /// Marks the task behind [id] as recording: a new session starts now, and
  /// the last one's facts (file, size, error) are cleared with it. A task
  /// never stored is a no-op — the engine adds its stub first.
  Future<void> setRunning(String id) async {
    final stored = store.get(id);
    if (stored == null) return;
    final task = RecordingTask.fromJson(stored);
    await save(
      RecordingTask(
        id: task.id,
        platform: task.platform,
        roomId: task.roomId,
        roomTitle: task.roomTitle,
        quality: task.quality,
        state: RecordingTaskState.recording,
        startedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Marks the task behind [id] as ended in [state], stamping the end and
  /// what the session left behind. A task never stored is a no-op.
  Future<void> setEnded(String id, RecordingTaskState state, {String? filePath, int? bytes, String? errorText}) async {
    final stored = store.get(id);
    if (stored == null) return;
    final task = RecordingTask.fromJson(stored);
    await save(
      task.copyWith(
        state: state,
        endedAt: DateTime.now().toUtc(),
        filePath: filePath ?? task.filePath,
        bytes: bytes ?? task.bytes,
        errorText: errorText ?? task.errorText,
      ),
    );
  }

  /// Puts the running session's [bytes] on the task without touching its
  /// state or start: the engine's progress line, written on its own clock.
  /// A task never stored is a no-op.
  Future<void> setProgress(String id, int bytes) async {
    final stored = store.get(id);
    if (stored == null) return;
    await save(RecordingTask.fromJson(stored).copyWith(bytes: bytes));
  }
}

/// The recordings repository (one namespace, one process).
final recordingRepositoryProvider = FutureProvider<RecordingTaskRepository>((ref) async {
  final store = await StorageStores.instance.openStore('recordings');
  return RecordingTaskRepository(store);
});

/// What the recorder page holds: the tasks and whether the repository has
/// opened yet.
typedef RecordingTasksState = ({bool ready, List<RecordingTask> tasks});

/// Mirrors the recordings repository into the widget tree: it lists once
/// the repository opens and follows its watch stream, so every change
/// lands at once. The recording engine (arriving with the player stack)
/// will call these same methods from wherever it runs. Open, not final: a
/// room window mirrors the tasks from its seed, as its own subclass does.
class RecordingTasksController extends Notifier<RecordingTasksState> {
  StreamSubscription<void>? _subscription;

  @override
  RecordingTasksState build() {
    ref.watch(recordingRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      _refresh(repository);
    });
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    return (ready: false, tasks: const []);
  }

  void _refresh(RecordingTaskRepository repository) {
    state = (ready: true, tasks: repository.list());
  }

  /// Stores [task] as given (the engine's stub before its first session).
  Future<void> add(RecordingTask task) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.save(task);
  }

  /// Drops the task behind [id].
  Future<void> remove(String id) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.remove(id);
  }

  /// Drops every task.
  Future<void> clear() async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.clear();
  }

  /// Marks the task behind [id] as recording (a new session starts).
  Future<void> setRunning(String id) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setRunning(id);
  }

  /// Marks the task behind [id] as ended with its file saved.
  Future<void> setStopped(String id, {String? filePath, int? bytes, String? errorText}) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setEnded(id, RecordingTaskState.stopped, filePath: filePath, bytes: bytes, errorText: errorText);
  }

  /// Marks the task behind [id] as failed (its session ended in an error).
  Future<void> setFailed(String id, {String? filePath, int? bytes, String? errorText}) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setEnded(id, RecordingTaskState.failed, filePath: filePath, bytes: bytes, errorText: errorText);
  }

  /// Puts the running session's [bytes] on the task (the engine's progress).
  Future<void> setProgress(String id, int bytes) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setProgress(id, bytes);
  }
}

/// The recorder page's state.
final recordingTasksProvider = NotifierProvider<RecordingTasksController, RecordingTasksState>(
  RecordingTasksController.new,
);
