import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

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

  /// The task behind [id], or null when it is not stored.
  RecordingTask? taskById(String id) {
    final stored = store.get(id);
    return stored == null ? null : RecordingTask.fromJson(stored);
  }

  /// Drops the task behind [id]; a task never stored is a no-op.
  Future<void> remove(String id) => store.delete(id);

  /// Drops every task.
  Future<void> clear() async {
    await store.deleteAll(store.keys);
  }

  /// Turns the watch switch of the task behind [id].
  ///
  /// The session in flight is not touched: pausing a room stops future live
  /// checks, and a take already running is ended by its own stop. A task never
  /// stored is a no-op.
  Future<void> setEnabled(String id, {required bool enabled}) async {
    final stored = store.get(id);
    if (stored == null) return;
    await save(RecordingTask.fromJson(stored).copyWith(enabled: enabled));
  }

  /// Marks the task behind [id] as recording: a new session starts now, and
  /// the last one's facts (file, size, error) are cleared with it. A task
  /// never stored is a no-op — the engine adds its stub first.
  ///
  /// [takeDirectory] is the folder the capture writes into, stored from the
  /// first byte: a process that dies mid-take leaves a row that still names
  /// where its segments are, so the next start can finish them.
  Future<void> setRunning(String id, {String? takeDirectory}) async {
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
        enabled: task.enabled,
        anchorName: task.anchorName,
        anchorAvatarUrl: task.anchorAvatarUrl,
        coverUrl: task.coverUrl,
        state: RecordingTaskState.recording,
        startedAt: DateTime.now().toUtc(),
        filePath: takeDirectory,
        scheduleEnabled: task.scheduleEnabled,
        scheduleDays: task.scheduleDays,
        scheduleStartMinutes: task.scheduleStartMinutes,
        scheduleEndMinutes: task.scheduleEndMinutes,
        stopAtWindowEnd: task.stopAtWindowEnd,
      ),
    );
  }

  /// Marks the task behind [id] as ended in [state], stamping the end and
  /// what the session left behind. A task never stored is a no-op.
  Future<void> setEnded(
    String id,
    RecordingTaskState state, {
    String? filePath,
    int? bytes,
    int? durationMs,
    String? errorText,
    bool? postProcessing,
    String? warning,
  }) async {
    final stored = store.get(id);
    if (stored == null) return;
    final task = RecordingTask.fromJson(stored);
    await save(
      task.copyWith(
        state: state,
        endedAt: DateTime.now().toUtc(),
        filePath: filePath ?? task.filePath,
        bytes: bytes ?? task.bytes,
        durationMs: durationMs ?? task.durationMs,
        errorText: errorText ?? task.errorText,
        postProcessing: postProcessing,
        postProcessingProgress: -1,
        warning: warning,
      ),
    );
  }

  /// Marks an ended task as being finished again, for a post-recording step
  /// the viewer re-runs by hand.
  ///
  /// Guarded by [expectedStartedAt] like the other late writes: a new take of
  /// the same room may already own the entry, and its own status must not be
  /// overwritten by a retry of the older one. Returns whether it applied.
  Future<bool> beginPostProcessing(String id, {required DateTime expectedStartedAt}) async {
    final stored = store.get(id);
    if (stored == null) return false;
    final task = RecordingTask.fromJson(stored);
    if (task.isRunning || !task.startedAt.isAtSameMomentAs(expectedStartedAt)) return false;
    await save(task.copyWith(postProcessing: true, postProcessingProgress: -1, warning: ''));
    return true;
  }

  /// Writes the post-processing run's progress (0–1, or -1 unknown).
  ///
  /// Guarded like [finishPostProcessing]: a new take may replace the entry
  /// while the older take is still being joined.
  Future<bool> setPostProcessingProgress(
    String id, {
    required DateTime expectedStartedAt,
    required double progress,
  }) async {
    final stored = store.get(id);
    if (stored == null) return false;
    final task = RecordingTask.fromJson(stored);
    if (!task.postProcessing || !task.startedAt.isAtSameMomentAs(expectedStartedAt)) return false;
    await save(task.copyWith(postProcessingProgress: progress.clamp(-1, 1)));
    return true;
  }

  /// Marks the post-processing run behind [id] as finished.
  ///
  /// Guarded by [expectedStartedAt]: a new take of the same room may have
  /// replaced the entry while the older take was joined, and that older work
  /// must not clear the new session's status. Returns whether it applied.
  Future<bool> finishPostProcessing(String id, {required DateTime expectedStartedAt, String warning = ''}) async {
    final stored = store.get(id);
    if (stored == null) return false;
    final task = RecordingTask.fromJson(stored);
    if (task.state != RecordingTaskState.stopped || !task.startedAt.isAtSameMomentAs(expectedStartedAt)) {
      return false;
    }
    await save(task.copyWith(postProcessing: false, postProcessingProgress: -1, warning: warning));
    return true;
  }

  /// Points an ended task at the path the post-recording steps left.
  ///
  /// [filePath] is the joined/transcoded MP4 when there is one, otherwise the
  /// renamed take directory. Guarded by [expectedStartedAt]: a new take of the
  /// same room replaces the entry while an older take is still being finished,
  /// and that older work must not write its path over the new session.
  /// Returns whether the task was still the expected one.
  Future<bool> setFinalPath(
    String id, {
    required DateTime expectedStartedAt,
    required String filePath,
    int? bytes,
  }) async {
    final stored = store.get(id);
    if (stored == null) return false;
    final task = RecordingTask.fromJson(stored);
    if (task.state != RecordingTaskState.stopped || !task.startedAt.isAtSameMomentAs(expectedStartedAt)) {
      return false;
    }
    await save(task.copyWith(filePath: filePath, bytes: bytes));
    return true;
  }

  /// Puts the running session's [bytes] and media time on the task without
  /// touching its state or start: the engine's progress line, written on its
  /// own clock. A task never stored is a no-op.
  Future<void> setProgress(String id, int bytes, {int durationMs = 0}) async {
    final stored = store.get(id);
    if (stored == null) return;
    await save(RecordingTask.fromJson(stored).copyWith(bytes: bytes, durationMs: durationMs));
  }
}

/// The tasks with a take that the given recording folder does not hold.
///
/// A viewer who moved the recording folder leaves their old takes where they
/// were written — a take keeps the folder it started in — and this is the
/// settled subset of that: rows whose session is neither capturing nor being
/// finished, read from the task list alone, so a page can count and name them
/// without touching the disk.
List<RecordingTask> strandedTasksOf(Iterable<RecordingTask> tasks, String rootPath) {
  final normalized = _normalizePath(rootPath);
  return [
    for (final task in tasks)
      if (!task.isRunning &&
          !task.postProcessing &&
          task.filePath != null &&
          (task.filePath ?? '').trim().isNotEmpty &&
          !_isWithin(normalized, _normalizePath(task.takeDirectory)))
        task,
  ];
}

/// Whether [path] is [root] itself or below it, on either separator style.
bool _isWithin(String root, String path) =>
    path.isNotEmpty && (root.isEmpty || path == root || path.startsWith('$root${_styleOf(path)}'));

/// The separator [path] uses — Windows reads a POSIX one, macOS and Linux do
/// not read a Windows one, and a stranded take on the wrong platform is simply
/// not this folder's.
String _styleOf(String path) => path.contains(r'\') ? r'\' : '/';

/// [path] with its own separators and no trailing one, so two paths written on
/// different days still compare equal.
String _normalizePath(String path) {
  final value = path.trim().replaceAll(r'\', _styleOf(path));
  if (value.length <= 1) return value;
  final separator = _styleOf(value);
  final trimmed = value.endsWith(separator) ? value.substring(0, value.length - separator.length) : value;
  return trimmed.isEmpty ? value : trimmed;
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
    ref.onDispose(() => unawaited(_subscription?.cancel() ?? Future<void>.value()));
    // The refresh has to come back as the return value: a `state =` inside
    // build is discarded — the build's return is the initial state — and a
    // hardcoded loading tuple here would leave the page on its skeleton
    // forever.
    var initial = (ready: false, tasks: const <RecordingTask>[]);
    ref.watch(recordingRepositoryProvider).whenData((repository) {
      _subscription ??= repository.watch().listen((_) => _refresh(repository));
      initial = (ready: true, tasks: repository.list());
    });
    return initial;
  }

  void _refresh(RecordingTaskRepository repository) {
    state = (ready: true, tasks: repository.list());
  }

  /// Reads the tasks back from the store (the page's pull); the store's
  /// own changes arrive on their own, so this only re-reads what is there.
  Future<void> reload() async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository != null) _refresh(repository);
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
  Future<void> setRunning(String id, {String? takeDirectory}) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setRunning(id, takeDirectory: takeDirectory);
  }

  /// Turns the watch switch of the task behind [id] on or off.
  Future<void> setEnabled(String id, {required bool enabled}) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setEnabled(id, enabled: enabled);
  }

  /// Marks the task behind [id] as ended with its file saved; [warning] is
  /// the post-recording note the card shows under it.
  Future<void> setStopped(String id, {String? filePath, int? bytes, String? errorText, String? warning}) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setEnded(
      id,
      RecordingTaskState.stopped,
      filePath: filePath,
      bytes: bytes,
      errorText: errorText,
      warning: warning,
    );
  }

  /// Marks the task behind [id] as failed (its session ended in an error).
  Future<void> setFailed(String id, {String? filePath, int? bytes, String? errorText}) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setEnded(id, RecordingTaskState.failed, filePath: filePath, bytes: bytes, errorText: errorText);
  }

  /// Puts the running session's [bytes] and media time on the task (the
  /// engine's progress).
  Future<void> setProgress(String id, int bytes, {int durationMs = 0}) async {
    final repository = ref.read(recordingRepositoryProvider).value;
    if (repository == null) return;
    await repository.setProgress(id, bytes, durationMs: durationMs);
  }
}

/// The recorder page's state.
final recordingTasksProvider = NotifierProvider<RecordingTasksController, RecordingTasksState>(
  RecordingTasksController.new,
);
