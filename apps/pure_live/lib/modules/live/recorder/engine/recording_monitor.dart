import 'dart:async' show TimeoutException, Timer, unawaited;
import 'dart:io' show Directory;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveDanmakuProvider;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart'
    show RecordingTasksState, recordingRepositoryProvider, recordingTasksProvider;
import 'package:pure_live/modules/live/recorder/data/recording_schedule.dart';
import 'package:pure_live/modules/live/recorder/data/recording_settings.dart'
    show RecordingSettings, recordingSettingsProvider;
import 'package:pure_live/modules/live/recorder/data/recording_task.dart' show RecordingTask, RecordingTaskState;
import 'package:pure_live/modules/live/recorder/engine/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/modules/live/recorder/engine/recording_finalize_lock.dart' show hasLiveFinalizeLock;
import 'package:pure_live/modules/live/recorder/engine/stream_resolver.dart'
    show NoRecordableStream, RecordableStream, resolveRecordableStream;

/// How long one room's live check may take before the next tick tries again.
const Duration _kLiveCheckTimeout = Duration(seconds: 20);

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
      recordingSettingsProvider.select(
        (settings) => (
          settings.pollingEnabled,
          settings.liveCheckSeconds,
          settings.checkBackoffEnabled,
          settings.maxCheckSeconds,
        ),
      ),
      (previous, next) => _arm(immediate: true),
    );
    if (_ref.read(recordingSettingsProvider).autoStartOnBoot) {
      unawaited(_resumeInterrupted());
    }
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

  /// Returns tasks interrupted by the previous process (still marked
  /// recording) to the waiting pool, so the live check can resume them.
  Future<void> _resumeInterrupted() async {
    try {
      final repository = await _ref.read(recordingRepositoryProvider.future);
      if (!_ref.mounted) return;
      var resumed = false;
      for (final task in repository.list()) {
        if (task.state != RecordingTaskState.recording) continue;
        await repository.save(task.copyWith(state: RecordingTaskState.waiting));
        resumed = true;
      }
      // The reference checks once even when the periodic live check is off;
      // let the task mirror see the writes first, then run that one round.
      if (resumed && !_ref.read(recordingSettingsProvider).pollingEnabled) {
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
      if (task.state == RecordingTaskState.waiting || task.scheduleEnabled)
        [
          task.id,
          task.state.name,
          task.startedAt.toUtc().toIso8601String(),
          task.scheduleEnabled,
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
    final polling = _ref.read(recordingSettingsProvider).pollingEnabled;
    for (final task in _ref.read(recordingTasksProvider).tasks) {
      if (polling && task.state == RecordingTaskState.waiting) return true;
      if (!task.scheduleEnabled) continue;
      if (task.state == RecordingTaskState.recording && task.stopAtWindowEnd) return true;
      if (polling && task.state == RecordingTaskState.stopped && !task.postProcessing) return true;
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
    final settings = _ref.read(recordingSettingsProvider);
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
              (task.state == RecordingTaskState.waiting && task.isWithinSchedule(now)) ||
              (task.state == RecordingTaskState.recording && task.stopAtWindowEnd),
        );
    if (busy) {
      final tick = math.min(15, math.max(5, settings.liveCheckSeconds));
      _timer = Timer.periodic(Duration(seconds: tick), (_) => unawaited(_tick()));
    } else {
      // Only future windows are left: sleep until the nearest one, capped at
      // an hour so a clock/DST change cannot strand the task for days.
      final polling = _ref.read(recordingSettingsProvider).pollingEnabled;
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

  /// The wait one task's next check owes, applying the optional backoff.
  Duration _delayFor(String id, RecordingSettings settings) {
    if (!settings.checkBackoffEnabled) return Duration(seconds: settings.liveCheckSeconds);
    final failures = _failures[id] ?? 0;
    final stretched = settings.liveCheckSeconds * math.pow(2, failures).toInt();
    return Duration(seconds: math.min(stretched, settings.maxCheckSeconds));
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
      if (!settings.pollingEnabled && !force) {
        if (!_shouldRun) _stop();
        return;
      }

      final notifier = _ref.read(recordingTasksProvider.notifier);
      final startable = <RecordingTask>[];
      for (final task in tasks) {
        if (engine.isRecording(task.id) || task.postProcessing) continue;
        final window = task.currentWindowStart(now);
        if (task.state == RecordingTaskState.waiting) {
          if (task.scheduleEnabled && window == null) continue;
          startable.add(task);
          continue;
        }
        if (task.state == RecordingTaskState.stopped && task.canRearmAt(now)) {
          // The next window opened and this task has not recorded in it yet:
          // re-arm the waiting state (which also says so in the task list).
          final waiting = task.copyWith(state: RecordingTaskState.waiting);
          await notifier.add(waiting);
          startable.add(waiting);
        }
      }

      if (startable.isEmpty) {
        if (!_shouldRun) _stop();
        return;
      }
      final liveIds = {for (final task in startable) task.id};
      _lastChecked.removeWhere((id, _) => !liveIds.contains(id));
      _failures.removeWhere((id, _) => !liveIds.contains(id));
      for (final task in startable) {
        if (!_ref.read(recordingSettingsProvider).pollingEnabled && !force) return;
        if (engine.isRecording(task.id)) continue;
        final last = _lastChecked[task.id];
        if (last != null && now.difference(last) < _delayFor(task.id, settings)) continue;
        _lastChecked[task.id] = now;
        final site = _ref.read(sitesProvider).getById(task.platform);
        if (site == null) continue;
        final RecordableStream stream;
        try {
          stream = await resolveRecordableStream(
            site: site,
            platform: task.platform,
            roomId: task.roomId,
            qualityLabel: task.quality,
          ).timeout(_kLiveCheckTimeout);
        } on NoRecordableStream {
          if (settings.checkBackoffEnabled) _failures.update(task.id, (value) => value + 1, ifAbsent: () => 1);
          continue;
        } on TimeoutException {
          if (settings.checkBackoffEnabled) _failures.update(task.id, (value) => value + 1, ifAbsent: () => 1);
          continue;
        } on Object {
          if (settings.checkBackoffEnabled) _failures.update(task.id, (value) => value + 1, ifAbsent: () => 1);
          continue;
        }
        // The task may have been removed or started while the platform
        // answered; only a task still waiting is started here.
        final current = _ref.read(recordingTasksProvider).tasks.where((item) => item.id == task.id).firstOrNull;
        if (current?.state != RecordingTaskState.waiting) continue;
        if (!_ref.read(recordingSettingsProvider).pollingEnabled) return;
        _failures.remove(task.id);
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
