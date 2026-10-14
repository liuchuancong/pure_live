import 'dart:async';
import 'dart:math';

import 'package:live_record_core/src/record_naming.dart';
import 'package:live_record_core/src/record_policy.dart';
import 'package:live_record_core/src/record_services.dart';
import 'package:live_record_core/src/record_status.dart';
import 'package:live_record_core/src/record_store.dart';
import 'package:live_record_core/src/record_task.dart';

/// What the launch sweep did.
final class RecoveryReport {
  /// Creates a report.
  const new({
    required this.restored,
    required this.joined,
    required this.published,
    required this.nothingToFinish,
    this.failures = const <String>[],
  });

  /// Tasks read back from the store.
  final int restored;

  /// Recordings whose segments had never been joined, and now are.
  final int joined;

  /// Merged files that still needed their display name, and got it.
  final int published;

  /// Tasks that turned out to owe nothing.
  final int nothingToFinish;

  /// Task ids whose finish attempt failed; their files are left alone and the task
  /// keeps the work recorded, so the next launch tries again.
  final List<String> failures;
}

/// Drives recordings: watches rooms, captures what is live, finishes what is left.
///
/// This is where the two decisions that a recording tool gets wrong live:
///
/// - **A dropped stream and an ended broadcast are not the same event.** The first
///   is retried with the same files still open; the second closes them and joins
///   them. Only the room's own answer plus this session's memory of having seen it
///   live can tell them apart, which is why [RoomState.ended] is derived rather
///   than probed, and why `sawLive` is persisted.
/// - **A launch is not a clean slate.** Segments on disk with no task to finish
///   them are the residue of a power cut or a pulled cable, and they are recoverable
///   — so [restore] runs before anything is watched, joins them, gives them their
///   names, and only then starts polling.
final class RecordOrchestrator {
  /// Creates an orchestrator.
  new({
    required this.services,
    required this.store,
    required this.naming,
    this.policy = const RecordPolicy(),
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random();

  /// The outside world: probe, capture, files, guard, notices.
  final RecordServices services;

  /// Where tasks are persisted between launches.
  final RecordStore store;

  /// Where a new task's files live and what they are called.
  final RecordNaming naming;

  /// Waiting, retrying and finishing rules.
  final RecordPolicy policy;

  final DateTime Function() _now;
  final Random _random;

  final StreamController<RecordTask> _changed = StreamController<RecordTask>.broadcast();
  final Map<String, _Running> _running = <String, _Running>{};
  final List<RecordTask> _tasks = <RecordTask>[];

  bool _disposed = false;

  /// Every known task, oldest first.
  List<RecordTask> get tasks => List<RecordTask>.unmodifiable(_tasks);

  /// A task as it changes. The same instance is re-emitted, so a listener reads the
  /// ledger rather than a snapshot that goes stale.
  Stream<RecordTask> get onChanged => _changed.stream;

  /// How many captures are running now.
  int get capturingCount => _running.values.where((run) => run.capture != null).length;

  /// Reads the ledger and finishes whatever a previous run left half-done.
  ///
  /// Runs before watching starts: joining a stale attempt while a new capture is
  /// writing into the same session directory would produce one file with two
  /// sessions in it.
  Future<RecoveryReport> restore() async {
    final stored = await store.loadAll();
    _tasks
      ..clear()
      ..addAll(stored);

    var joined = 0;
    var published = 0;
    var clean = 0;
    final failures = <String>[];

    for (final task in stored) {
      // A task the process owns nothing for. Anything that looked mid-capture died
      // with the previous run, and its segments are waiting to be joined.
      if (task.isBusy) {
        _set(task, status: RecordStatus.interrupted);
      }

      if (task.pendingAttempts.isNotEmpty) {
        final finished = await _finish(task, recovered: true);

        if (finished) {
          joined++;
        } else {
          failures.add(task.taskId);
        }
        continue;
      }

      if (task.mergedFile != null && task.publishedFile == null) {
        if (await _publish(task)) {
          // The join had already happened, so this is the last thing the task owed.
          _set(task, status: RecordStatus.completed, stage: ArtifactStage.published);
          await _persist(task);
          published++;
        } else {
          failures.add(task.taskId);
        }

        continue;
      }

      clean++;
    }

    stored.forEach(_emit);

    return RecoveryReport(
      restored: stored.length,
      joined: joined,
      published: published,
      nothingToFinish: clean,
      failures: failures,
    );
  }

  /// Starts watching [target], resuming its stored task when there is one.
  ///
  /// Returns immediately after the first probe; whether a capture is running by
  /// then answers a different question, and a room that is not up yet is a normal
  /// outcome rather than a failure.
  Future<RecordTask> watch(RecordTarget target) async {
    _ensureAlive();

    final existing = _tasks
        .where((task) => task.target.platform == target.platform && task.target.roomId == target.roomId)
        .firstOrNull;
    final task = existing ?? RecordTask.forTarget(target: target, paths: _pathsFor(target), now: _now());

    if (existing == null) {
      _tasks.add(task);
      await _persist(task);
    }

    _running.putIfAbsent(task.taskId, () => _Running(task)).stoppedByHost = false;

    if (!task.isBusy && task.status != RecordStatus.completed) {
      _set(task, status: RecordStatus.queued);
    }

    await _poll(task);
    return task;
  }

  /// Stops watching a room. A capture in progress is closed and its segments
  /// joined — the viewer asked to stop watching, not to lose what was recorded.
  Future<void> stopWatching(String taskId) async {
    final run = _running.remove(taskId);

    if (run == null) {
      return;
    }

    run.stoppedByHost = true;
    run.timer?.cancel();
    await _closeCapture(run, cancel: false);
    await run.guard?.release();

    final task = _find(taskId);

    if (task == null) {
      return;
    }

    if (task.pendingAttempts.isEmpty && task.mergedFile == null) {
      _set(task, status: RecordStatus.stopped);
      await _persist(task);
      return;
    }

    await _finish(task);
  }

  /// Joins and names a task's segments now, without waiting for the room to close.
  /// A viewer who wants the file while the streamer is still live gets it; the
  /// capture continues on the segments that follow.
  Future<bool> finishNow(String taskId) async {
    final task = _find(taskId);

    if (task == null || task.pendingAttempts.isEmpty) {
      return false;
    }

    return await _finish(task);
  }

  /// Stops every watcher and closes the change stream. Captures are ended, not
  /// abandoned: a segment left open behind a disposed orchestrator is a segment
  /// nobody is going to close.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    for (final taskId in _running.keys.toList()) {
      await stopWatching(taskId);
    }

    await _changed.close();
  }

  // -------------------------------------------------------------------------
  // The poll
  // -------------------------------------------------------------------------

  Future<void> _poll(RecordTask task) async {
    if (_disposed || _running[task.taskId]?.stoppedByHost == true) {
      return;
    }

    _set(task, status: RecordStatus.resolving);

    final RoomProbe probe;

    try {
      probe = await services.probe(task.target);
    } on Object catch (error) {
      await _afterProbeFailure(task, '$error');
      return;
    }

    switch (probe.outcome) {
      case ProbeOutcome.unknown:
        await _afterProbeFailure(task, probe.detail ?? 'the status endpoint did not answer');
      case ProbeOutcome.unavailable:
        await _afterRoomGone(task, probe);
      case ProbeOutcome.live:
        await _whileLive(task, probe);
      case ProbeOutcome.offline:
        await _whileOffline(task, probe);
    }
  }

  Future<void> _afterProbeFailure(RecordTask task, String reason) async {
    final run = _running.putIfAbsent(task.taskId, () => _Running(task));
    run.probeFailures++;
    _set(task, failureReason: reason, roomState: task.sawLive ? RoomState.ended : RoomState.unknown);

    if (run.probeFailures > policy.maxProbeFailures) {
      await _closeCapture(run, cancel: false);
      _set(task, status: RecordStatus.failed, failureReason: 'the status endpoint stopped answering: $reason');
      await _persist(task);
      await _announce(task, RecordNoticeKind.failed, '无法继续监听房间');
      return;
    }

    _schedule(task, policy.retryInterval);
  }

  Future<void> _afterRoomGone(RecordTask task, RoomProbe probe) async {
    final run = _running.remove(task.taskId);
    await _closeCapture(run, cancel: false);

    _set(task, status: RecordStatus.failed, roomState: RoomState.unavailable, failureReason: probe.detail ?? '房间不可用');
    await _persist(task);

    if (task.pendingAttempts.isEmpty) {
      await _announce(task, RecordNoticeKind.failed, '房间已无法访问');
      return;
    }

    await _finish(task);
  }

  Future<void> _whileLive(RecordTask task, RoomProbe probe) async {
    final run = _running.putIfAbsent(task.taskId, () => _Running(task))..probeFailures = 0;

    if (!probe.isCaptureable) {
      await _afterProbeFailure(task, 'the room says live but returned no address');
      return;
    }

    _set(task, roomState: RoomState.live, status: RecordStatus.recording, startedAt: _now());

    if (run.capture == null) {
      if (capturingCount >= policy.maxConcurrent) {
        _set(task, status: RecordStatus.queued);
        _schedule(task, policy.retryInterval);
        return;
      }

      final enough = await _hasRoomToWrite(task);

      if (!enough) {
        _set(task, status: RecordStatus.failed, failureReason: '磁盘剩余空间不足');
        await _persist(task);
        await _announce(task, RecordNoticeKind.failed, '磁盘空间不足，未能开始录制');
        return;
      }

      try {
        run
          ..guard = await services.acquireGuard(task: task)
          ..capture = await services.openCapture(task: task, streamUrl: probe.streamUrl!)
          ..lastProgress = const RecordProgress(mediaTime: Duration.zero, bytes: 0, segments: 0);
        // The listener is deliberately not held: a capture's progress stream ends
        // when the capture ends, and a subscription that outlived it would keep
        // writing into a task that has already moved on.
        run.capture!.onProgress.listen((value) => _onProgress(run, value));
        unawaited(run.capture!.ended.then((_) => _onCaptureEnded(run)));
      } on Object catch (error) {
        run.capture = null;
        await _afterCaptureFailure(task, '$error');
        return;
      }

      if (!task.sawLive) {
        _set(task, sawLive: true);
        await _announce(task, RecordNoticeKind.liveStarted, '已开始录制');
      }

      await _persist(task);
    }

    // A live room is not polled: the capture notices a dead stream first, through
    // its own timeout, and the watchdog below catches the case where it keeps
    // delivering bytes with no media in them. Polling on top of a running capture
    // would only produce two answers about the same room.
    _armStallWatchdog(run);
  }

  Future<void> _whileOffline(RecordTask task, RoomProbe probe) async {
    final run = _running.putIfAbsent(task.taskId, () => _Running(task))..probeFailures = 0;

    final endedSession = task.sawLive && task.status != RecordStatus.completed;
    _set(task, roomState: endedSession ? RoomState.ended : RoomState.waiting);

    if (run.capture != null) {
      await _closeCapture(run, cancel: false);
      _set(task, status: RecordStatus.interrupted);
      await _finish(task, announceEnded: endedSession);
      return;
    }

    if (endedSession) {
      if (task.pendingAttempts.isNotEmpty) {
        await _finish(task, announceEnded: true);
        return;
      }

      _set(task, status: RecordStatus.completed);
      await _persist(task);
      await _announce(task, RecordNoticeKind.liveEnded, '直播已结束');
    }

    _schedule(task, task.hasOutstandingWork ? policy.recheckInterval : _jitteredPoll());
  }

  /// The capture ended by itself: the stream closed, or the room went away.
  ///
  /// Nothing is concluded about the room here — that is the next probe's job. What
  /// happens is that the attempt's segments are recorded, and the room is asked
  /// again soon: still live means another capture (the CDN rotated a segment), and
  /// not live means the session ended and the files get joined.
  Future<void> _onCaptureEnded(_Running run) async {
    if (_disposed || run.stoppedByHost || run.capture == null) {
      return;
    }

    final task = run.task;
    await _closeCapture(run, cancel: false);
    _set(task, status: RecordStatus.retrying);

    if (task.failureCount + 1 > policy.maxCaptureFailures) {
      await _finish(task);
      _schedule(task, _jitteredPoll());
      return;
    }

    _set(task, failureCount: task.failureCount + 1);
    await _persist(task);
    _schedule(task, policy.recheckInterval);
  }

  void _onProgress(_Running run, RecordProgress progress) {
    final last = run.lastProgress;
    // An advance in either dimension resets the stall clock: a stream that reports
    // new bytes but no media time is exactly the case the transport timeout cannot
    // see, and a source that restarts its timeline reports the same seconds again.
    if (progress.mediaTime > last.mediaTime || progress.bytes > last.bytes) {
      run
        ..lastProgress = progress
        ..stallTicks = 0;
    }

    unawaited(run.guard?.update(progress) ?? Future<void>.value());
  }

  void _armStallWatchdog(_Running run) {
    if (run.stallTimer != null || policy.stallTimeout <= Duration.zero) {
      return;
    }

    final period = Duration(microseconds: max((policy.stallTimeout.inMicroseconds ~/ 4).clamp(200000, 10000000), 1));
    run.stallTimer = Timer.periodic(period, (_) {
      run.stallTicks++;

      if (run.stallTicks * period.inMicroseconds < policy.stallTimeout.inMicroseconds) {
        return;
      }

      run.stallTicks = 0;
      unawaited(_onStall(run));
    });
  }

  Future<void> _onStall(_Running run) async {
    final task = run.task;
    _set(task, roomState: RoomState.stalled, failureReason: '没有新的媒体写入');
    await _closeCapture(run, cancel: false);
    _set(task, status: RecordStatus.retrying);

    if (task.failureCount + 1 > policy.maxCaptureFailures) {
      await _finish(task);
      _schedule(task, _jitteredPoll());
      return;
    }

    _set(task, failureCount: task.failureCount + 1);
    await _persist(task);
    _schedule(task, policy.recheckInterval);
  }

  Future<void> _afterCaptureFailure(RecordTask task, String reason) async {
    _running.putIfAbsent(task.taskId, () => _Running(task)).capture = null;
    _set(task, status: RecordStatus.retrying, failureReason: reason, failureCount: task.failureCount + 1);
    await _persist(task);

    if (task.failureCount >= policy.maxCaptureFailures) {
      await _finish(task);
      _schedule(task, _jitteredPoll());
      return;
    }

    _schedule(task, policy.retryInterval);
  }

  // -------------------------------------------------------------------------
  // Finishing
  // -------------------------------------------------------------------------

  Future<void> _closeCapture(_Running? run, {required bool cancel}) async {
    if (run == null) {
      return;
    }

    final timer = run.stallTimer;
    timer?.cancel();

    final capture = run.capture;
    run
      ..stallTimer = null
      ..capture = null;

    if (capture == null) {
      return;
    }

    try {
      if (cancel) {
        await capture.cancel();
      } else {
        await capture.stop();
      }
    } on Object catch (_) {
      // A capture that would not close is still closed as far as this ledger is
      // concerned: its outcome is what the files say, and that is read below.
    }

    final outcome = capture.outcome;

    if (outcome.hasMedia && !cancel) {
      final attempts = <PendingAttempt>[...run.task.pendingAttempts, outcome.toPendingAttempt()];
      _set(
        run.task,
        pendingAttempts: attempts,
        stage: ArtifactStage.unmergedSegments,
        recordedFor: run.task.recordedFor + outcome.mediaTime,
        bytesWritten: run.task.bytesWritten + outcome.bytes,
        segments: run.task.segments + outcome.segments,
      );
      await _persist(run.task);
    }

    unawaited(run.guard?.release() ?? Future<void>.value());
    run.guard = null;
  }

  Future<bool> _finish(RecordTask task, {bool recovered = false, bool announceEnded = false}) async {
    if (task.pendingAttempts.isEmpty) {
      _set(task, status: statusIsTerminal(task.status) ? task.status : RecordStatus.completed);
      await _persist(task);
      return false;
    }

    if (task.pendingAttempts.any((attempt) => attempt.damaged)) {
      // Refuse the join. The segments are the evidence of what was captured, and
      // rewriting them through a damaged window is how a partial recording becomes
      // an unplayable one.
      _set(task, status: RecordStatus.completed, stage: ArtifactStage.unmergedSegments, failureReason: '分段含损坏包，未合并');
      await _persist(task);
      await _announce(task, RecordNoticeKind.failed, '分段含损坏数据包，已保留未合并');
      return false;
    }

    _set(task, status: RecordStatus.merging);
    await _persist(task);

    final MergeOutcome merged;

    try {
      merged = await services.files.merge(task: task, attempts: task.pendingAttempts);
    } on Object catch (error) {
      return _afterMergeFailure(task, '$error');
    }

    if (!merged.isSuccess) {
      return _afterMergeFailure(task, merged.failure ?? '合并失败');
    }

    _set(
      task,
      mergedFile: merged.path,
      stage: ArtifactStage.mergedFile,
      pendingAttempts: const <PendingAttempt>[],
      recordedFor: merged.mediaTime,
      bytesWritten: merged.bytes,
    );

    if (!policy.renameAfterMerge || !(await services.files.exists(merged.path))) {
      _set(task, status: RecordStatus.completed);
      await _persist(task);
      return true;
    }

    await _publish(task);
    _set(task, status: RecordStatus.completed);
    await _persist(task);

    if (announceEnded) {
      await _announce(task, RecordNoticeKind.liveEnded, '直播已结束');
    }

    await _announce(
      task,
      recovered ? RecordNoticeKind.recovered : RecordNoticeKind.recordingSaved,
      recovered ? '已补全上次未完成的录制' : '录制完成',
    );
    return true;
  }

  bool _afterMergeFailure(RecordTask task, String reason) {
    _set(task, status: RecordStatus.interrupted, stage: ArtifactStage.unmergedSegments, failureReason: reason);
    unawaited(_persist(task));
    unawaited(_announce(task, RecordNoticeKind.failed, '合并失败，分段已保留', detail: reason));

    return false;
  }

  Future<bool> _publish(RecordTask task) async {
    final source = task.mergedFile;

    if (source == null) {
      return false;
    }

    final desired = task.paths.displayPathFor(
      anchorName: task.target.anchorName,
      roomTitle: task.target.roomTitle,
      startedAt: task.startedAt ?? task.createdAt,
    );
    _set(task, desiredFile: desired);

    final RenameOutcome renamed;

    try {
      renamed = await services.files.rename(from: source, to: desired);
    } on Object catch (error) {
      _set(task, failureReason: '改名失败: $error');
      await _persist(task);
      return false;
    }

    if (!renamed.applied) {
      // The recording is kept under its capture name and the intent to rename stays
      // in the task, so the next launch tries again. Renaming is presentation; a
      // presentation failure must never be reported as a lost recording.
      _set(task, desiredFile: desired, failureReason: renamed.failure ?? '改名未生效');
      await _persist(task);
      return false;
    }

    _set(task, publishedFile: renamed.path, stage: ArtifactStage.published);
    await _persist(task);
    return true;
  }

  // -------------------------------------------------------------------------
  // Ledger helpers
  // -------------------------------------------------------------------------

  RecordTask? _find(String taskId) => _tasks.where((task) => task.taskId == taskId).firstOrNull;

  Future<bool> _hasRoomToWrite(RecordTask task) async {
    final free = await services.files.freeBytes(task.paths.sessionDirectory);

    // Unknown free space is not zero free space: a platform that cannot answer gets
    // the recording started and fails honestly at the write if there really was no
    // room.
    if (free == null) {
      return true;
    }

    return free >= policy.diskFloorBytes;
  }

  Duration _jitteredPoll() {
    if (policy.pollJitter <= Duration.zero) {
      return policy.pollInterval;
    }

    return policy.pollInterval + Duration(milliseconds: _random.nextInt(policy.pollJitter.inMilliseconds + 1));
  }

  void _set(
    RecordTask task, {
    RecordStatus? status,
    RoomState? roomState,
    ArtifactStage? stage,
    bool? sawLive,
    List<PendingAttempt>? pendingAttempts,
    String? mergedFile,
    String? publishedFile,
    String? desiredFile,
    Duration? recordedFor,
    int? bytesWritten,
    int? segments,
    String? failureReason,
    int? failureCount,
    DateTime? startedAt,
  }) {
    if (status != null) {
      task.status = status;
    }
    if (roomState != null) {
      task.roomState = roomState;
    }
    if (stage != null) {
      task.stage = stage;
    }
    if (sawLive != null) {
      task.sawLive = sawLive;
    }
    if (pendingAttempts != null) {
      task.pendingAttempts = pendingAttempts;
    }
    if (mergedFile != null) {
      task.mergedFile = mergedFile;
    }
    if (publishedFile != null) {
      task.publishedFile = publishedFile;
    }
    if (desiredFile != null) {
      task.desiredFile = desiredFile;
    }
    if (recordedFor != null) {
      task.recordedFor = recordedFor;
    }
    if (bytesWritten != null) {
      task.bytesWritten = bytesWritten;
    }
    if (segments != null) {
      task.segments = segments;
    }
    if (failureReason != null) {
      task.failureReason = failureReason;
    }
    if (failureCount != null) {
      task.failureCount = failureCount;
    }
    if (startedAt != null) {
      task.startedAt = startedAt;
    }

    _emit(task);
  }

  void _emit(RecordTask task) {
    if (!_changed.isClosed) {
      _changed.add(task);
    }
  }

  Future<void> _persist(RecordTask task) => store.save(task);

  void _schedule(RecordTask task, Duration delay) {
    final run = _running.putIfAbsent(task.taskId, () => _Running(task));
    run.timer?.cancel();
    run.timer = Timer(delay, () => unawaited(_poll(task)));
  }

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('RecordOrchestrator has been disposed.');
    }
  }

  Future<void> _announce(RecordTask task, RecordNoticeKind kind, String text, {String? detail}) async {
    final label = task.sawLive ? '正在录制' : '等待开播';

    try {
      await services.notify(
        RecordNotice(
          kind: kind,
          task: task,
          text: '$text · ${task.target.anchorName} · $label',
          detail: detail ?? task.failureReason,
        ),
      );
    } on Object catch (_) {
      // A notification that could not be shown is not a recording failure, and it is
      // never retried into the caller's face.
    }
  }

  // The paths for a room with no stored task yet: a fresh ASCII id, and the session
  // directory named by platform, anchor and day.
  RecordPaths _pathsFor(RecordTarget target) {
    return naming.paths(
      taskId: RecordNaming.newTaskId(),
      platformId: target.platform,
      anchorName: target.anchorName,
      roomId: target.roomId,
      startedAt: _now(),
    );
  }
}

/// One room's runtime, kept beside the ledger entry that outlives it.
final class _Running {
  /// Creates the runtime for [task].
  new(this.task);

  /// The task this is running for.
  final RecordTask task;

  Timer? timer;
  Timer? stallTimer;
  RecordCapture? capture;
  RecordGuard? guard;
  RecordProgress lastProgress = const RecordProgress(mediaTime: Duration.zero, bytes: 0, segments: 0);
  int stallTicks = 0;
  int probeFailures = 0;
  bool stoppedByHost = false;
}
