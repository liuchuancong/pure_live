import 'dart:async' show Timer, unawaited;
import 'dart:io' show Directory;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveDanmakuProvider;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart'
    show RecordingTasksState, recordingRepositoryProvider, recordingTasksProvider;
import 'package:pure_live/modules/live/recorder/data/recording_schedule.dart';
import 'package:pure_live/modules/live/recorder/data/recording_settings.dart' show recordingSettingsProvider;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart' show RecordingTask, RecordingTaskState;
import 'package:pure_live/modules/live/recorder/engine/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/modules/live/recorder/engine/recording_claim.dart';
import 'package:pure_live/modules/live/recorder/engine/recording_finalize_lock.dart' show hasLiveFinalizeLock;
import 'package:pure_live/modules/live/recorder/engine/stream_resolver.dart'
    show RecordableStream, resolveRecordableStream;

/// How long one room's live check may take before the next tick tries again.
const Duration _kLiveCheckTimeout = Duration(seconds: 20);

/// How many rooms' live checks are read at once. More than one, because a room
/// is not owed another room's slow platform; no more than this, because a wall
/// of simultaneous reads against one site is how it answers 412 (Bilibili) or
/// throttles the device — and the tick comes round again in seconds anyway.
const int _kLiveCheckConcurrency = 4;

/// One room's live check: the row it was asked for, the stream its platform
/// served (null: there is nothing to start), and whether that empty answer
/// counts against the room's own interval.
typedef _RoomCheck = ({RecordingTask task, RecordableStream? stream, bool countsAsFailure});

/// The live check of waiting recording tasks: while the setting is on and a
/// task waits for its room, the monitor asks the room for its current stream
/// and hands a live one to the recorder engine.
///
/// A task's optional schedule is a gate on top of that model, not a second
/// scheduler: outside its window the task makes no platform request, and a
/// stopped scheduled task re-arms at the next window. The waiting state and
/// the boot recovery are unchanged.
///
/// One process runs it (the primary window); a clone does not poll, or two
/// windows would start the same waiting task twice.
final class RecordingLiveMonitor {
  RecordingLiveMonitor(this._ref) {
    _ref.listen(
      recordingSettingsProvider.select((settings) => settings.schedule.pollingEnabled),
      (previous, next) => _arm(immediate: true),
    );
    unawaited(_recoverInterrupted());
    unawaited(_recoverStaleProcessing());
    _ref.listen(recordingTasksProvider.select(_monitorKey), (previous, next) => _arm(immediate: true));
    _ref.onDispose(_stop);
    _arm(immediate: true);
  }

  final Ref _ref;
  Timer? _timer;
  bool _checking = false;
  final Map<String, DateTime> _lastChecked = {};
  final Map<String, int> _failures = {};

  /// The tasks the previous process left mid-take (still marked recording,
  /// their claim held by nobody): the take on disk is finished first — the
  /// same join, archive and rename a stop runs, read back from the folder
  /// the row names — and the row then either returns to the waiting pool
  /// (the boot setting on, so the live check resumes the room) or settles as
  /// stopped with the finished take. A kill between the capture and the join
  /// must not cost the recording its single file.
  Future<void> _recoverInterrupted() async {
    try {
      final repository = await _ref.read(recordingRepositoryProvider.future);
      if (!_ref.mounted) return;
      final claims = _ref.read(appPathsProvider).recordingClaims;
      final resume = _ref.read(recordingSettingsProvider).schedule.autoStartOnBoot;
      final engine = _ref.read(recorderEngineProvider);
      var resumed = false;
      for (final task in repository.list()) {
        if (task.state != RecordingTaskState.recording) continue;
        // A row whose claim another process holds is not interrupted: that
        // window is recording it right now, and touching the row would tell
        // both windows otherwise. The probe is held across the write so a
        // start cannot slip in between the check and the change.
        final probe = await acquireRecordingClaim(claims, task.id);
        if (probe == null) continue;
        try {
          await repository.setEnded(task.id, RecordingTaskState.stopped);
        } finally {
          await releaseRecordingClaim(probe);
        }
        // The finish runs from the folder alone (see `retryFinalize`): it
        // begins here and goes on in the background, guarded by the take's
        // own lock and start time, so a resumed room's new take never
        // collides with it.
        final stopped = repository.taskById(task.id) ?? task;
        if (stopped.takeDirectory.isNotEmpty) await engine.retryFinalize(stopped);
        if (!resume) continue;
        final settled = repository.taskById(task.id) ?? stopped;
        await repository.save(settled.copyWith(state: RecordingTaskState.waiting));
        resumed = true;
      }
      // The reference checks once even when the periodic live check is off;
      // let the task mirror see the writes first, then run that one round.
      if (resumed && !_ref.read(recordingSettingsProvider).schedule.pollingEnabled) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (_ref.mounted) unawaited(_tick(force: true));
      }
    } on Object {
      // A store that cannot open leaves the tasks as they were.
    }
  }

  /// Clears a `postProcessing` flag left by a process that died.
  ///
  /// The finalize lock is the evidence: if this process can take it, no other
  /// window is joining/transcoding that take, so the status is stale and the
  /// files are simply what the capture wrote. A lock still held is left alone.
  Future<void> _recoverStaleProcessing() async {
    try {
      final repository = await _ref.read(recordingRepositoryProvider.future);
      for (final task in repository.list()) {
        if (!task.postProcessing) continue;
        // The take's own folder, read from the row: whether the path it names
        // is a file or the directory, and whether anything is there at all.
        final take = task.takeDirectory;
        final directory = take.isEmpty ? null : Directory(take);
        final live = directory != null && directory.existsSync() && await hasLiveFinalizeLock(directory);
        if (live) continue;
        await repository.finishPostProcessing(task.id, expectedStartedAt: task.startedAt, warning: 'stale');
      }
    } on Object {
      // A store that cannot open leaves the flags for the next start.
    }
  }

  /// The tasks the monitor must see change: a waiting task's identity and
  /// requested quality, and any scheduled task's state and window. Progress
  /// writes (bytes, duration) are deliberately absent, or every tick would
  /// re-arm the clock.
  static String _monitorKey(RecordingTasksState state) => [
    for (final task in state.tasks)
      if (task.isArmed || task.scheduleEnabled)
        [
          task.id,
          task.enabled,
          task.state.name,
          task.startedAt.toUtc().toIso8601String(),
          task.scheduleEnabled,
          task.checkSeconds,
          task.checkBackoff,
          task.maxCheckSeconds,
          task.scheduleDays.join(','),
          task.scheduleStartMinutes,
          task.scheduleEndMinutes,
          task.stopAtWindowEnd,
          task.postProcessing,
        ].join('|'),
  ].join('\n');

  /// Whether the clock has anything to do: start a waiting task, re-arm a
  /// scheduled one at its next window, or stop a take at its window's end.
  ///
  /// A scheduled waiting or stopped task keeps the clock alive even outside
  /// its window, because that is how the window's next opening is noticed.
  bool get _shouldRun {
    final polling = _ref.read(recordingSettingsProvider).schedule.pollingEnabled;
    for (final task in _ref.read(recordingTasksProvider).tasks) {
      if (polling && task.isArmed && task.isWithinSchedule(DateTime.now())) return true;
      if (!task.scheduleEnabled) continue;
      if (task.state == RecordingTaskState.recording && task.stopAtWindowEnd) return true;
    }
    return false;
  }

  /// Restarts the clock over what it has to watch; an immediate tick makes a
  /// just-added task (or a just-enabled switch) check without the wait.
  ///
  /// The clock ticks at most every 15 seconds and each task is checked when
  /// its own interval is due, so a per-task backoff can stretch one task
  /// without delaying the others.
  void _arm({required bool immediate}) {
    _timer?.cancel();
    if (!_shouldRun) {
      _timer = null;
      return;
    }
    // A task that is actually waiting or being watched for a window end needs
    // the live-check cadence. A schedule that is merely far in the future does
    // not: a minute is enough to notice its next opening without waking the
    // app every fifteen seconds for a day.
    final now = DateTime.now();
    final busy = _ref
        .read(recordingTasksProvider)
        .tasks
        .any(
          (task) =>
              (task.isArmed && task.isWithinSchedule(now)) ||
              (task.state == RecordingTaskState.recording && task.stopAtWindowEnd),
        );
    if (busy) {
      // The clock wakes for the fastest armed room; each room still waits its
      // own interval before it is checked again.
      final fastest = _ref
          .read(recordingTasksProvider)
          .tasks
          .where((task) => task.isArmed && task.isWithinSchedule(now))
          .fold<int>(15, (value, task) => math.min(value, task.checkSeconds));
      final tick = math.min(15, math.max(5, fastest));
      _timer = Timer.periodic(Duration(seconds: tick), (_) => unawaited(_tick()));
    } else {
      // Only future windows are left: sleep until the nearest one, capped at
      // an hour so a clock/DST change cannot strand the task for days.
      final polling = _ref.read(recordingSettingsProvider).schedule.pollingEnabled;
      DateTime? next;
      if (polling) {
        for (final task in _ref.read(recordingTasksProvider).tasks) {
          final candidate = task.nextWindowStart(now);
          if (candidate == null) continue;
          if (next == null || candidate.isBefore(next)) next = candidate;
        }
      }
      if (next == null) {
        _timer = null;
        return;
      }
      var delay = next.difference(now);
      if (delay <= Duration.zero) delay = const Duration(seconds: 1);
      if (delay > const Duration(hours: 1)) delay = const Duration(hours: 1);
      _timer = Timer(delay, () => _arm(immediate: true));
    }
    if (immediate) unawaited(_tick());
  }

  /// The wait one task's next check owes: the room's own interval, stretched
  /// by its failures when its backoff is on.
  Duration _delayFor(RecordingTask task) {
    if (!task.checkBackoff) return Duration(seconds: task.checkSeconds);
    final failures = _failures[task.id] ?? 0;
    final stretched = task.checkSeconds * math.pow(2, failures).toInt();
    return Duration(seconds: math.min(stretched, task.maxCheckSeconds));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops recordings whose window has ended when their task asked for it.
  Future<void> _stopExpired(DateTime now) async {
    final engine = _ref.read(recorderEngineProvider);
    for (final task in _ref.read(recordingTasksProvider).tasks) {
      if (!task.scheduleEnabled || !task.stopAtWindowEnd) continue;
      if (!engine.isRecording(task.id)) continue;
      if (task.isWithinSchedule(now)) continue;
      try {
        await engine.stop(task.id);
      } on Object {
        // The next tick tries again; a failed stop never blocks the clock.
      }
    }
  }

  /// The platform reads of [tasks], a few at a time, answered in the order the
  /// tasks came in.
  Future<List<_RoomCheck>> _checkRooms(List<RecordingTask> tasks) async {
    if (tasks.isEmpty) return const <_RoomCheck>[];
    final answers = List<_RoomCheck?>.filled(tasks.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < tasks.length) {
        final index = next++;
        answers[index] = await _checkRoom(tasks[index]);
      }
    }

    await Future.wait([for (var slot = 0; slot < math.min(_kLiveCheckConcurrency, tasks.length); slot++) worker()]);

    return [for (final answer in answers) ?answer];
  }

  /// One room's current stream. An offline room, a read that timed out and a
  /// read that threw all answer with nothing and stretch the room's own
  /// interval; a platform the registry no longer serves is not the room's
  /// failure, so it keeps its normal cadence.
  Future<_RoomCheck> _checkRoom(RecordingTask task) async {
    final site = _ref.read(sitesProvider).getById(task.platform);
    if (site == null) return (task: task, stream: null, countsAsFailure: false);
    try {
      final stream = await resolveRecordableStream(
        site: site,
        platform: task.platform,
        roomId: task.roomId,
        qualityLabel: task.quality,
      ).timeout(_kLiveCheckTimeout);

      return (task: task, stream: stream, countsAsFailure: false);
    } on Object {
      return (task: task, stream: null, countsAsFailure: true);
    }
  }

  /// Checks every startable task once. A task that is still offline, whose
  /// platform answers slowly or whose start fails stays as it is; the next
  /// tick tries again (the reference's failure backoff is REC-20).
  Future<void> _tick({bool force = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final now = DateTime.now();
      final engine = _ref.read(recorderEngineProvider);
      final tasks = _ref.read(recordingTasksProvider).tasks;
      await _stopExpired(now);

      final settings = _ref.read(recordingSettingsProvider);
      if (!settings.schedule.pollingEnabled && !force) {
        if (!_shouldRun) _stop();
        return;
      }

      final notifier = _ref.read(recordingTasksProvider.notifier);
      final startable = <RecordingTask>[];
      for (final task in tasks) {
        if (engine.isRecording(task.id) || task.postProcessing) continue;
        // A paused subscription is not watched: its last take stays with it.
        if (!task.enabled) continue;
        final window = task.currentWindowStart(now);
        if (task.state == RecordingTaskState.waiting) {
          if (task.scheduleEnabled && window == null) continue;
          startable.add(task);
          continue;
        }
        // A settled (or failed) session keeps the room watched: the row is a
        // subscription, so its next live check begins the next take. A
        // scheduled room only re-arms inside its window, and only once per
        // window.
        if (task.state == RecordingTaskState.stopped || task.state == RecordingTaskState.failed) {
          if (task.scheduleEnabled && !task.canRearmAt(now)) continue;
          startable.add(task);
        }
      }

      if (startable.isEmpty) {
        if (!_shouldRun) _stop();
        return;
      }
      final liveIds = {for (final task in startable) task.id};
      _lastChecked.removeWhere((id, _) => !liveIds.contains(id));
      _failures.removeWhere((id, _) => !liveIds.contains(id));
      // The sweep owes each room its own cadence, so the rooms that are due are
      // picked first and their platform reads run together: one room whose
      // platform answers slowly — or not at all until the read times out — would
      // otherwise push every other room's check past its own interval, because
      // the guard at the top of the tick skips an overlapping sweep and the
      // whole sweep costs the sum of its rooms.
      final due = <RecordingTask>[];
      for (final task in startable) {
        if (!_ref.read(recordingSettingsProvider).schedule.pollingEnabled && !force) return;
        if (engine.isRecording(task.id)) continue;
        final last = _lastChecked[task.id];
        if (last != null && now.difference(last) < _delayFor(task)) continue;
        _lastChecked[task.id] = now;
        if (_ref.read(sitesProvider).getById(task.platform) == null) continue;
        due.add(task);
      }
      // What the platforms answered, in task order: which room reaches the
      // concurrency cap of the recording engine first stays the order the rows
      // are listed in, not the order the networks happened to finish in.
      final answers = await _checkRooms(due);
      for (final check in answers) {
        final task = check.task;
        final stream = check.stream;
        if (stream == null) {
          // A room that is simply not live, a read that timed out and a read
          // that failed all stretch that room's own interval when its backoff is
          // on; a platform the registry no longer serves is not a failure of the
          // room and stays on its normal cadence.
          if (check.countsAsFailure && settings.schedule.checkBackoffEnabled) {
            _failures.update(task.id, (value) => value + 1, ifAbsent: () => 1);
          }
          continue;
        }
        // The task may have been removed or started while the platforms
        // answered. A settled row is re-armed to waiting here, only once the
        // room has answered with a live stream, so a room that stays offline
        // writes nothing to the store on every tick.
        final current = _ref.read(recordingTasksProvider).tasks.where((item) => item.id == task.id).firstOrNull;
        if (current == null || !current.enabled) continue;
        if (current.state != RecordingTaskState.waiting) {
          if (current.state != RecordingTaskState.stopped && current.state != RecordingTaskState.failed) continue;
          await notifier.add(current.copyWith(state: RecordingTaskState.waiting));
        }
        if (!_ref.read(recordingSettingsProvider).schedule.pollingEnabled) return;
        _failures.remove(task.id);
        final site = _ref.read(sitesProvider).getById(task.platform);
        if (site == null) continue;
        try {
          await engine.start(task, stream.line, room: stream.room, danmaku: site.capability<LiveDanmakuProvider>());
        } on Object {
          // A start that throws leaves the task for the next check.
        }
      }
    } on Object {
      // A failing check must never stop the clock; the next tick tries again.
    } finally {
      _checking = false;
    }
  }
}

/// The monitor (one per process; the primary window's root holds it).
final recordingLiveMonitorProvider = Provider<RecordingLiveMonitor>(RecordingLiveMonitor.new);
