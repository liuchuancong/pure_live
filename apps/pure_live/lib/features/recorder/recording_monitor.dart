import 'dart:async' show TimeoutException, Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveDanmakuProvider;

import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/recorder/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/features/recorder/recording_repository.dart'
    show RecordingTasksState, recordingRepositoryProvider, recordingTasksProvider;
import 'package:pure_live/features/recorder/recording_settings.dart'
    show RecordingSettings, recordingSettingsProvider;
import 'package:pure_live/features/recorder/recording_task.dart' show RecordingTaskState;
import 'package:pure_live/features/recorder/stream_resolver.dart'
    show NoRecordableStream, RecordableStream, resolveRecordableStream;

/// How long one room's live check may take before the next tick tries again.
const Duration _kLiveCheckTimeout = Duration(seconds: 20);

/// The live check of waiting recording tasks: while the setting is on and a
/// task waits for its room, the monitor asks the room for its current stream
/// and hands a live one to the recorder engine.
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
      (previous, next) {
        if (previous?.$1 != next.$1) {
          _onPollingChanged(next.$1);
        } else if (next.$1) {
          _arm(immediate: true);
        }
      },
    );
    if (_ref.read(recordingSettingsProvider).autoStartOnBoot) {
      unawaited(_resumeInterrupted());
    }
    _ref.listen(
      recordingTasksProvider.select(_waitingKey),
      (previous, next) => _onWaitingChanged(),
    );
    _ref.onDispose(_stop);
    _onPollingChanged(_ref.read(recordingSettingsProvider).pollingEnabled);
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

  /// The waiting tasks' identities and requested qualities: a change (a task
  /// added, removed or started) re-arms the check with an immediate tick.
  static String _waitingKey(RecordingTasksState state) => [
    for (final task in state.tasks)
      if (task.state == RecordingTaskState.waiting) '${task.id}|${task.quality}',
  ].join('\n');

  bool get _hasWaitingTasks =>
      _ref.read(recordingTasksProvider).tasks.any((task) => task.state == RecordingTaskState.waiting);

  void _onPollingChanged(bool enabled) {
    if (!enabled) {
      _stop();
      return;
    }
    _arm(immediate: true);
  }

  void _onWaitingChanged() {
    if (!_ref.read(recordingSettingsProvider).pollingEnabled) {
      _stop();
      return;
    }
    if (_hasWaitingTasks) {
      _arm(immediate: true);
    } else {
      _stop();
    }
  }

  /// Restarts the clock over the waiting tasks; an immediate tick makes a
  /// just-added task (or a just-enabled switch) check without the wait.
  ///
  /// The clock ticks at most every 15 seconds and each task is checked when
  /// its own interval is due, so a per-task backoff can stretch one task
  /// without delaying the others.
  void _arm({required bool immediate}) {
    _timer?.cancel();
    if (!_hasWaitingTasks) {
      _timer = null;
      return;
    }
    final settings = _ref.read(recordingSettingsProvider);
    final tick = math.min(15, math.max(5, settings.liveCheckSeconds));
    _timer = Timer.periodic(Duration(seconds: tick), (_) => unawaited(_tick()));
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

  /// Checks every waiting task once. A task that is still offline, whose
  /// platform answers slowly or whose start fails stays as it is; the next
  /// tick tries again (the reference's failure backoff is REC-20).
  Future<void> _tick({bool force = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      if (!_ref.read(recordingSettingsProvider).pollingEnabled && !force) return;
      final waiting = [
        for (final task in _ref.read(recordingTasksProvider).tasks)
          if (task.state == RecordingTaskState.waiting) task,
      ];
      if (waiting.isEmpty) {
        _stop();
        return;
      }
      final engine = _ref.read(recorderEngineProvider);
      final settings = _ref.read(recordingSettingsProvider);
      final now = DateTime.now();
      final liveIds = {for (final task in waiting) task.id};
      _lastChecked.removeWhere((id, _) => !liveIds.contains(id));
      _failures.removeWhere((id, _) => !liveIds.contains(id));
      for (final task in waiting) {
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
          await engine.start(
            task,
            stream.line,
            room: stream.room,
            danmaku: site.capability<LiveDanmakuProvider>(),
          );
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
