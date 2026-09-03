import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_scheduler.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';
import 'package:pure_live/recorder/services/recording_output_metrics.dart';
import 'package:pure_live/recorder/services/recording_keep_alive_service.dart';
import 'package:pure_live/recorder/services/recorder_continuation_policy.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecorderController extends GetxService {
  RecorderController([this._outputMetrics = const RecordingOutputMetrics()]);

  static RecorderController get to => Get.find<RecorderController>();

  final RecordSettingsController settings = Get.find<RecordSettingsController>();
  final FFmpegManager ffmpeg = FFmpegManager.to;
  final FFmpegScheduler scheduler = FFmpegScheduler.instance;
  final RxList<LiveRecordTask> tasks = <LiveRecordTask>[].obs;

  final Map<String, Timer> _pollTimers = <String, Timer>{};
  final Map<String, int> _pollFailures = <String, int>{};
  final Set<String> _pollInFlight = <String>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final Map<String, Timer> _leasePrefetchTimers = <String, Timer>{};
  final Map<String, Timer> _leaseRotationTimers = <String, Timer>{};
  final Map<String, _PrefetchedRecorderLease> _prefetchedRecorderLeases =
      <String, _PrefetchedRecorderLease>{};
  final Map<String, _PendingRecorderLease> _pendingRecorderLeases =
      <String, _PendingRecorderLease>{};
  final Set<String> _startingTasks = <String>{};
  final Set<String> _rapidRecoveryTasks = <String>{};
  final Map<String, Completer<void>> _lifecycleCompleters = <String, Completer<void>>{};
  final Map<String, int> _activeSessionIds = <String, int>{};
  final Map<String, Future<void>> _finalizationFutures = <String, Future<void>>{};
  final RecordingOutputMetrics _outputMetrics;
  final Map<String, Timer> _outputMonitorTimers = <String, Timer>{};
  final Set<String> _outputMonitorBusy = <String>{};
  final Map<String, RecordingOutputTracker> _outputTrackers = <String, RecordingOutputTracker>{};
  final Map<String, ({int bytes, DateTime sampledAt})> _outputSamples =
      <String, ({int bytes, DateTime sampledAt})>{};
  final Map<String, DateTime> _outputStartedAt = <String, DateTime>{};
  final Map<String, DateTime> _lastOutputPersist = <String, DateTime>{};
  final Map<String, RecordingAttemptProgress> _attemptProgress =
      <String, RecordingAttemptProgress>{};
  bool _recordingForegroundServiceEnabled = false;
  Timer? _persistTimer;
  Timer? _resourceMonitor;
  bool _persistDirty = false;
  bool _isClosing = false;
  bool _resourceCheckRunning = false;
  Future<void>? _persistInFlight;
  late final StreamSubscription<FFmpegEvent> _ffmpegSub;

  int get runningCount => scheduler.runningCount;
  int get queuedCount => scheduler.queuedCount;

  @override
  void onInit() {
    super.onInit();
    _resourceMonitor = Timer.periodic(const Duration(minutes: 1), (_) {
      if (settings.enableCacheLimit.value) unawaited(_checkResources());
    });
    _ffmpegSub = ffmpeg.stream.listen((event) => unawaited(_handleFFmpegEvent(event)));
    unawaited(restoreAndAutoPoll());
  }

  Future<void> _handleFFmpegEvent(FFmpegEvent event) async {
    final sessionId = _sessionId(event);
    final task = tasks.firstWhereOrNull((candidate) => candidate.taskId == event.taskId);
    if (task == null) {
      if ((event.type == FFmpegEventType.error || event.type == FFmpegEventType.complete) &&
          _isCurrentSession(event.taskId, sessionId)) {
        _activeSessionIds.remove(event.taskId);
      }
      return;
    }

    switch (event.type) {
      case FFmpegEventType.startAck:
        if (sessionId == null) return;
        _activeSessionIds[event.taskId] = sessionId;
        final pendingLease = _pendingRecorderLeases.remove(event.taskId);
        if (pendingLease != null && pendingLease.sourceUrl == task.currentUrl) {
          _scheduleRecorderLeaseRefresh(task, pendingLease.stream, sessionId);
        }
        task.status = RecordStatus.preparing;
        task.lastUpdate = DateTime.now();
        task.clearFailure();
        _startOutputMonitor(task, sessionId);
        updateTask(task);
        return;
      case FFmpegEventType.started:
        if (sessionId == null) return;
        // FFmpegService permits only one native session for a task ID. A new
        // started event is therefore authoritative and replaces stale state
        // left by a task removed before its delayed terminal callback.
        if (_activeSessionIds[event.taskId] != sessionId) {
          _activeSessionIds[event.taskId] = sessionId;
          _startOutputMonitor(task, sessionId);
        }
        task.status = RecordStatus.running;
        task.lastUpdate = DateTime.now();
        task.clearFailure();
        updateTask(task);
        return;
      case FFmpegEventType.progress:
        if (!_isCurrentSession(event.taskId, sessionId)) return;
        final data = event.data;
        final recordedSeconds = ((data['time'] as num?)?.toInt() ?? 0) ~/ 1000;
        final fileSize = (data['size'] as num?)?.toInt() ?? 0;
        final bitrate = (data['bitrate'] as num?)?.toDouble() ?? 0;
        final speed = (data['speed'] as num?)?.toDouble() ?? 0;
        final fps = (data['fps'] as num?)?.toDouble() ?? 0;
        final attempt =
            _attemptProgress[event.taskId] ??
            const RecordingAttemptProgress(baseBytes: 0, baseSeconds: 0);
        final totalSeconds = attempt.totalSeconds(recordedSeconds);
        final totalBytes = attempt.totalBytes(fileSize);
        if (totalSeconds > task.recordedSeconds) task.recordedSeconds = totalSeconds;
        if (totalBytes > task.fileSize) task.fileSize = totalBytes;
        if (bitrate > 0) task.bitrate = bitrate;
        if (speed > 0) task.recordSpeed = speed;
        if (fps > 0) task.fps = fps;
        task.status = RecordStatus.running;
        task.lastUpdate = DateTime.now();
        if (recordedSeconds >= 10) {
          task.retryCount = 0;
          _rapidRecoveryTasks.remove(task.taskId);
        }
        updateTask(task, persist: _shouldPersistOutput(event.taskId));
        return;
      case FFmpegEventType.error:
      case FFmpegEventType.complete:
        if (!_isCurrentSession(event.taskId, sessionId)) return;
        await _sampleOutput(task, sessionId!, forcePersist: true);
        _stopOutputMonitor(event.taskId);
        _cancelRecorderLeaseTimers(event.taskId);
        _pendingRecorderLeases.remove(event.taskId);
        _activeSessionIds.remove(event.taskId);
        final manuallyStopped = event.data['manualStop'] == true || task.wasStoppedByUser;
        final isError = event.type == FFmpegEventType.error;
        final errorCode = (event.data['code'] as num?)?.toInt() ?? 0;
        final rawLogs = event.data['raw_logs']?.toString() ?? '';
        final failureKind = event.data['failure_kind']?.toString();
        final refreshSignedStream =
            failureKind == 'leaseRefresh' ||
            failureKind == 'unexpectedEof' ||
            failureKind == 'httpAccess';
        if (refreshSignedStream) _rapidRecoveryTasks.add(task.taskId);
        if (failureKind != 'leaseRefresh') _prefetchedRecorderLeases.remove(task.taskId);
        final fastReconnect = refreshSignedStream || _rapidRecoveryTasks.contains(task.taskId);
        final classifiedRetryable = event.data['retryable'];
        final shouldRetry =
            !isError ||
            (classifiedRetryable is bool
                ? classifiedRetryable
                : RecorderContinuationPolicy.shouldRetryFailure(
                    errorCode: errorCode,
                    rawLogs: rawLogs,
                  ));
        if (isError) {
          final message = event.data['message']?.toString();
          task.markFailure(
            stage: failureKind?.isNotEmpty == true ? 'ffmpeg.$failureKind' : 'ffmpeg',
            error: message?.isNotEmpty == true ? message! : 'FFmpeg exit code $errorCode',
          );
          final silent = event.data['silent'] == true;
          if (!silent && message?.isNotEmpty == true && (!shouldRetry || task.retryCount == 0)) {
            ToastUtil.show(message!);
          }
        }
        await _finalizeAttempt(
          task,
          manuallyStopped: manuallyStopped,
          failed: isError,
          shouldRetry: shouldRetry,
          fastReconnect: fastReconnect,
        );
        return;
      default:
        return;
    }
  }

  int? _sessionId(FFmpegEvent event) {
    final value = event.data['sessionId'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _isCurrentSession(String taskId, int? sessionId) {
    final current = _activeSessionIds[taskId];
    return current != null && sessionId != null && current == sessionId;
  }

  void _startOutputMonitor(LiveRecordTask task, int sessionId) {
    _stopOutputMonitor(task.taskId);
    final directoryPath = task.outputDir?.trim() ?? '';
    if (directoryPath.isNotEmpty) {
      _outputTrackers[task.taskId] = _outputMetrics.track(
        directoryPath: directoryPath,
        filePrefix: task.recordingFilePrefix,
      );
    }
    _outputSamples[task.taskId] = (bytes: 0, sampledAt: DateTime.now());
    unawaited(_sampleOutput(task, sessionId));
    _outputMonitorTimers[task.taskId] = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_sampleOutput(task, sessionId)),
    );
  }

  void _stopOutputMonitor(String taskId) {
    _outputMonitorTimers.remove(taskId)?.cancel();
    _outputMonitorBusy.remove(taskId);
    _outputTrackers.remove(taskId);
    _outputSamples.remove(taskId);
    _outputStartedAt.remove(taskId);
    _lastOutputPersist.remove(taskId);
  }

  bool _shouldPersistOutput(String taskId, {DateTime? now, bool force = false}) {
    final sampledAt = now ?? DateTime.now();
    final previous = _lastOutputPersist[taskId];
    if (!force && previous != null && sampledAt.difference(previous) < const Duration(seconds: 10)) {
      return false;
    }
    _lastOutputPersist[taskId] = sampledAt;
    return true;
  }

  Future<void> _sampleOutput(
    LiveRecordTask task,
    int sessionId, {
    bool forcePersist = false,
  }) async {
    if (!_isCurrentSession(task.taskId, sessionId) || !_outputMonitorBusy.add(task.taskId)) return;
    try {
      final directoryPath = task.outputDir?.trim() ?? '';
      if (directoryPath.isEmpty) return;
      final now = DateTime.now();
      final tracker = _outputTrackers.putIfAbsent(
        task.taskId,
        () => _outputMetrics.track(
          directoryPath: directoryPath,
          filePrefix: task.recordingFilePrefix,
        ),
      );
      final snapshot = await tracker.sample();
      if (!_isCurrentSession(task.taskId, sessionId)) return;

      final nativeSession = ffmpeg.getSession(task.taskId);
      final attemptBytes = math.max(snapshot.bytes, nativeSession?.fileSize ?? 0);
      final previous = _outputSamples[task.taskId];
      _outputSamples[task.taskId] = (bytes: attemptBytes, sampledAt: now);
      final mediaStarted = attemptBytes > 0 || nativeSession?.mediaStarted == true;
      if (!mediaStarted) return;

      _outputStartedAt.putIfAbsent(task.taskId, () => now);
      final attempt =
          _attemptProgress[task.taskId] ??
          const RecordingAttemptProgress(baseBytes: 0, baseSeconds: 0);
      final totalBytes = attempt.totalBytes(attemptBytes);
      if (totalBytes > task.fileSize) task.fileSize = totalBytes;
      if (previous != null && attemptBytes > previous.bytes) {
        final elapsedMs = now.difference(previous.sampledAt).inMilliseconds;
        if (elapsedMs > 0) {
          task.bitrate = (attemptBytes - previous.bytes) * 8 / elapsedMs;
        }
      }
      if (task.bitrate <= 0 && (nativeSession?.bitrate ?? 0) > 0) {
        task.bitrate = nativeSession!.bitrate;
      }
      final wallSeconds = now.difference(_outputStartedAt[task.taskId]!).inSeconds;
      final attemptSeconds = math.max(wallSeconds, nativeSession?.recordedSeconds ?? 0);
      final totalSeconds = attempt.totalSeconds(attemptSeconds);
      if (totalSeconds > task.recordedSeconds) task.recordedSeconds = totalSeconds;
      if ((nativeSession?.speed ?? 0) > 0) task.recordSpeed = nativeSession!.speed;
      if ((nativeSession?.fps ?? 0) > 0) task.fps = nativeSession!.fps;
      if (task.recordSpeed <= 0) task.recordSpeed = 1;
      task
        ..status = RecordStatus.running
        ..lastUpdate = now;
      updateTask(
        task,
        persist: _shouldPersistOutput(task.taskId, now: now, force: forcePersist),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Recorder output monitor failed: $error',
        name: 'RecorderController',
        stackTrace: stackTrace,
      );
    } finally {
      _outputMonitorBusy.remove(task.taskId);
    }
  }

  Future<void> _finalizeAttempt(
    LiveRecordTask task, {
    required bool manuallyStopped,
    required bool failed,
    required bool shouldRetry,
    bool fastReconnect = false,
  }) async {
    final existing = _finalizationFutures[task.taskId];
    if (existing != null) return existing;

    late final Future<void> operation;
    operation =
        _doFinalizeAttempt(
          task,
          manuallyStopped: manuallyStopped,
          failed: failed,
          shouldRetry: shouldRetry,
          fastReconnect: fastReconnect,
        ).whenComplete(() {
          if (identical(_finalizationFutures[task.taskId], operation)) {
            _finalizationFutures.remove(task.taskId);
          }
        });
    _finalizationFutures[task.taskId] = operation;
    return operation;
  }

  Future<void> _doFinalizeAttempt(
    LiveRecordTask task, {
    required bool manuallyStopped,
    required bool failed,
    required bool shouldRetry,
    required bool fastReconnect,
  }) async {
    try {
      await _queueCurrentAttempt(task);
      final stoppedByUser = manuallyStopped || task.wasStoppedByUser;
      final willReconnect = failed && shouldRetry && task.autoReconnect && !stoppedByUser;
      if (willReconnect) {
        // MP4 remux used to block this path for 10-20 seconds. Huya's short
        // transport lease therefore produced a real hole between attempts even
        // though the reconnect timer itself was only two seconds. Persist the
        // completed segment group and reconnect first; finalization happens
        // after the user-visible recording session ends.
        _completeLifecycle(task.taskId);
        _scheduleReconnect(task, fast: fastReconnect);
        return;
      }

      var mergeSucceeded = true;
      if (task.pendingAttempts.isNotEmpty) {
        task.status = RecordStatus.processing;
        updateTask(task);
        mergeSucceeded = await _finalizePendingAttempts(task);
        await settings.refreshCacheSize();
      }

      if (!mergeSucceeded) {
        task.markFailure(stage: 'merge', error: i18n('video_ffmpeg_failed'));
        task.status = RecordStatus.failed;
        updateTask(task);
        return;
      }

      if (stoppedByUser) {
        task.status = RecordStatus.stopped;
        updateTask(task);
        return;
      }

      if (failed) {
        task.status = RecordStatus.failed;
        task.retryCount = 0;
        updateTask(task);
        return;
      }

      if (RecorderContinuationPolicy.shouldMonitorAfterExit(
        manuallyStopped: false,
        autoReconnect: task.autoReconnect,
      )) {
        task.status = RecordStatus.waitingLive;
        updateTask(task);
        _completeLifecycle(task.taskId);
        _schedulePoll(task, delay: const Duration(seconds: 1));
      } else {
        task.status = RecordStatus.completed;
        updateTask(task);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Recorder finalization failed: $error',
        name: 'RecorderController',
        stackTrace: stackTrace,
      );
      task.markFailure(stage: 'merge', error: error);
      task.status = RecordStatus.failed;
      updateTask(task);
    } finally {
      _completeLifecycle(task.taskId);
    }
  }

  Future<void> _queueCurrentAttempt(LiveRecordTask task, {bool allowLegacy = false}) async {
    final directoryPath = task.outputDir?.trim() ?? '';
    if (directoryPath.isEmpty) return;
    final filePrefix = task.recordingFilePrefix;
    if (!await _hasRecordedSegments(
      task,
      allowLegacy: allowLegacy,
      directoryPath: directoryPath,
      filePrefix: filePrefix,
    )) {
      return;
    }
    task.queuePendingAttempt(directoryPath: directoryPath, filePrefix: filePrefix);
    updateTask(task);
  }

  Future<bool> _finalizePendingAttempts(LiveRecordTask task, {bool allowLegacy = false}) async {
    var allSucceeded = true;
    final attempts = List<PendingRecordingAttempt>.of(task.pendingAttempts);
    for (final attempt in attempts) {
      // Capture the provisional TS size before the successful converter
      // deletes those source files. Each attempt is reconciled independently
      // so a later retry never loses output committed by an earlier pass.
      final source = await _outputMetrics.measure(
        directoryPath: attempt.directoryPath,
        filePrefix: attempt.filePrefix,
      );
      final merged = await VideoProcessorService.to.convertToMp4(
        task: task,
        allowLegacySegments: allowLegacy,
        directoryPath: attempt.directoryPath,
        filePrefix: attempt.filePrefix,
      );
      if (merged) {
        final output = await _outputMetrics.measureFinalized(
          directoryPath: attempt.directoryPath,
          filePrefix: attempt.filePrefix,
        );
        if (source.bytes > 0 && output.bytes > 0) {
          task.fileSize = RecordingOutputMetrics.reconcileFinalizedBytes(
            totalBytes: task.fileSize,
            sourceBytes: source.bytes,
            finalizedBytes: output.bytes,
          );
        }
        task.removePendingAttempt(attempt);
        updateTask(task);
      } else {
        allSucceeded = false;
      }
    }
    return allSucceeded;
  }

  Future<bool> _hasRecordedSegments(
    LiveRecordTask task, {
    bool allowLegacy = false,
    String? directoryPath,
    String? filePrefix,
  }) async {
    final resolvedDirectoryPath = directoryPath ?? task.outputDir;
    final resolvedFilePrefix = filePrefix ?? task.recordingFilePrefix;
    if (resolvedDirectoryPath == null || resolvedDirectoryPath.trim().isEmpty) return false;
    final directory = Directory(resolvedDirectoryPath);
    if (!await directory.exists()) return false;
    final prefix = '${resolvedFilePrefix}_';
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.ts')) continue;
        if (!allowLegacy && !p.basename(entity.path).startsWith(prefix)) continue;
        if (await entity.length() > 0) return true;
      }
    } on FileSystemException {
      return false;
    }
    return false;
  }

  void updateTask(LiveRecordTask task, {bool persist = true}) {
    final index = tasks.indexWhere((candidate) => candidate.taskId == task.taskId);

    if (index == -1) return;

    tasks[index] = task;

    if (persist) {
      schedulePersist();
    }

    unawaited(_updateRecordingForegroundService());
  }

  bool _isRecordingLifecycleActive(LiveRecordTask task) {
    return const <RecordStatus>{
      RecordStatus.queued,
      RecordStatus.preparing,
      RecordStatus.running,
      RecordStatus.reconnecting,
      RecordStatus.processing,
    }.contains(task.status);
  }

  Future<void> _updateRecordingForegroundService() async {
    final shouldRun = tasks.any(_isRecordingLifecycleActive);

    if (shouldRun == _recordingForegroundServiceEnabled) {
      return;
    }

    _recordingForegroundServiceEnabled = shouldRun;

    if (shouldRun) {
      await RecordingKeepAliveService.start();
    } else {
      await RecordingKeepAliveService.stop();
    }
  }

  void schedulePersist() {
    _persistDirty = true;
    if (_isClosing || _persistTimer?.isActive == true) return;
    _persistTimer = Timer(const Duration(seconds: 2), () {
      _persistTimer = null;
      unawaited(_flushPersist());
    });
  }

  Future<void> _flushPersist() async {
    if (!_persistDirty) return;
    if (_persistInFlight != null) {
      schedulePersist();
      return;
    }

    _persistDirty = false;
    final pending = _persist();
    _persistInFlight = pending;
    try {
      await pending;
    } finally {
      _persistInFlight = null;
      if (_persistDirty && !_isClosing) schedulePersist();
    }
  }

  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    if (await _canWriteRecordDirectory()) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        if (await Permission.manageExternalStorage.isGranted && await _canWriteRecordDirectory()) {
          return true;
        }
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted && await _canWriteRecordDirectory()) return true;
      } else {
        if (await Permission.storage.isGranted && await _canWriteRecordDirectory()) return true;
        final status = await Permission.storage.request();
        if (status.isGranted && await _canWriteRecordDirectory()) return true;
      }
    } catch (_) {
      final status = await Permission.storage.request();
      if (status.isGranted && await _canWriteRecordDirectory()) return true;
    }

    ToastUtil.show(i18n('no_storage'));
    return false;
  }

  Future<bool> _canWriteRecordDirectory() async {
    File? probe;
    try {
      final directory = await CacheService.to.getRecordDir();
      probe = File('${directory.path}${Platform.pathSeparator}.pure_live_write_probe_$pid');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    } finally {
      if (probe != null && await probe.exists()) {
        try {
          await probe.delete();
        } on FileSystemException {
          // Best-effort cleanup after a failed storage probe.
        }
      }
    }
  }

  Future<LiveRecordTask?> addTask({required LiveRoom room, bool startImmediately = true}) async {
    if (!await requestStoragePermission()) return null;
    final existing = tasks.firstWhereOrNull(
      (task) => task.roomId == room.roomId && task.platform == room.platform,
    );
    if (existing != null) return existing;

    final task = LiveRecordTask.fromRoom(room);
    tasks.add(task);
    updateTask(task);
    // "Start now" is an explicit user intent. Do not gate it on the room card's
    // cached live state: cards can lag the player and several platforms use an
    // unknown/replay state while a valid media URL is already playing. The
    // strict stream resolver below is the authority for live/offline state.
    if (startImmediately) {
      await startTask(task);
    } else {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _schedulePoll(task);
    }
    return task;
  }

  Future<bool> startTask(LiveRecordTask task) async {
    if (!await requestStoragePermission()) return false;
    if (_startingTasks.contains(task.taskId) ||
        scheduler.isRunning(task.taskId) ||
        scheduler.isQueued(task.taskId)) {
      return true;
    }
    task.beginNewRecording();
    _attemptProgress.remove(task.taskId);
    _rapidRecoveryTasks.remove(task.taskId);
    _cancelRecorderLease(task.taskId);
    task.retryCount = 0;
    task.selectedQualityId = null;
    task.selectedLineIndex = null;
    task.wasStoppedByUser = false;
    task.autoReconnect = settings.autoReconnect.value;
    await _startTask(task);
    return true;
  }

  Future<void> forceStartTask(LiveRecordTask task) async {
    await startTask(task);
  }

  Future<void> _startTask(LiveRecordTask task) async {
    if (_startingTasks.contains(task.taskId)) {
      ToastUtil.show(i18n('recorder_task_starting'));
      return;
    }
    if (scheduler.isRunning(task.taskId) || scheduler.isQueued(task.taskId)) {
      return;
    }

    _startingTasks.add(task.taskId);
    try {
      _stopPolling(task.taskId);
      _retryTimers.remove(task.taskId)?.cancel();
      task.status = RecordStatus.queued;
      updateTask(task);
      scheduler.enqueue(taskId: task.taskId, taskRunner: (token) => _runTask(task, token));
    } catch (error, stackTrace) {
      developer.log(
        'Start recorder task failed: $error',
        name: 'RecorderController',
        stackTrace: stackTrace,
      );
      task.markFailure(stage: 'scheduler', error: error);
      task.status = RecordStatus.failed;
      updateTask(task);
    } finally {
      _startingTasks.remove(task.taskId);
    }
  }

  Future<void> _runTask(LiveRecordTask task, TaskCancelToken token) async {
    final previousUrl = task.currentUrl;
    final previousQualityId = task.selectedQualityId;
    final previousLineIndex = task.selectedLineIndex;
    _attemptProgress[task.taskId] = RecordingAttemptProgress(
      baseBytes: task.fileSize,
      baseSeconds: task.recordedSeconds,
    );
    task.beginNewAttempt();
    task.outputDir = null;
    task.status = RecordStatus.preparing;
    updateTask(task);

    final lifecycle = Completer<void>();
    _lifecycleCompleters[task.taskId] = lifecycle;
    String? protectedDirectory;
    token.onCancel = () async {
      final hadActiveSession =
          ffmpeg.isRunning(task.taskId) || VideoProcessorService.to.isProcessing(task.taskId);
      await Future.wait(<Future<void>>[
        ffmpeg.stop(task.taskId),
        VideoProcessorService.to.cancel(task.taskId),
      ]);
      if (!hadActiveSession) {
        _completeLifecycle(task.taskId);
      }
    };

    try {
      if (token.isCancelled) return;
      final renewCurrent = _rapidRecoveryTasks.contains(task.taskId);
      final prefetched = _prefetchedRecorderLeases.remove(task.taskId);
      final prefetchedStillValid =
          prefetched != null &&
          renewCurrent &&
          prefetched.sourceUrl == previousUrl &&
          (prefetched.stream.invalidAt == null ||
              prefetched.stream.invalidAt!.isAfter(DateTime.now().toUtc()));
      final resolved = prefetchedStillValid
          ? prefetched.stream
          : await StreamResolverService.to.resolveStream(
              roomId: task.roomId,
              platform: task.platform,
              preferredQuality: settings.defaultQuality.value,
              previousQualityId: previousQualityId,
              previousLineIndex: previousLineIndex,
              renewCurrent: renewCurrent,
            );
      if (token.isCancelled) return;

      final directory = await CacheService.to.getRoomDir(
        platform: task.platform,
        nick: task.nick,
        usePinyinForFolder: settings.usePinyinForFolder.value,
      );
      protectedDirectory = directory.path;
      CacheService.to.protectDirectory(directory.path);
      if (token.isCancelled) return;

      final headers = await FFmpegHeaderFactory.build(platform: task.platform, roomId: task.roomId);
      if (token.isCancelled) return;

      task
        ..currentUrl = resolved.url
        ..selectedQuality = resolved.quality.quality
        ..selectedQualityId = resolved.qualityCursorId
        ..selectedLineIndex = resolved.lineIndex
        ..selectedLine = resolved.lineLabel
        ..outputDir = directory.path;
      updateTask(task);

      final pendingLease = _PendingRecorderLease(sourceUrl: resolved.url, stream: resolved);
      _pendingRecorderLeases[task.taskId] = pendingLease;

      final arguments = FFmpegCommandBuilder.buildRecordArguments(
        headers: headers,
        url: resolved.url,
        outputDir: directory.path,
        segmentTime: settings.segmentTime.value,
        preferBestStream: settings.preferBestStream.value,
        rwTimeout: settings.rwTimeout.value,
        threadQueueSize: settings.threadQueueSize.value,
        filePrefix: task.recordingFilePrefix,
        caFile: FFmpegManager.to.caFilePath,
      );
      if (token.isCancelled) return;

      await ffmpeg.start(taskId: task.taskId, arguments: arguments, liveRecording: true);
      if (identical(_pendingRecorderLeases[task.taskId], pendingLease)) {
        _pendingRecorderLeases.remove(task.taskId);
      }
      await lifecycle.future;
    } on StreamException catch (error) {
      developer.log('Stream resolution failed: ${error.message}', name: 'RecorderController');
      if (token.isCancelled) return;
      task.markFailure(stage: _streamFailureStage(error.type), error: error.message);
      if (error.type == StreamErrorType.notLive) {
        _rapidRecoveryTasks.remove(task.taskId);
        task.clearFailure();
        task.status = RecordStatus.waitingLive;
        updateTask(task);
        _schedulePoll(task);
      } else if (!error.retryable || !task.autoReconnect) {
        task.status = RecordStatus.failed;
        updateTask(task);
        ToastUtil.show(
          i18n('recorder_resolve_failed', args: {'name': task.nick, 'error': error.message}),
        );
      } else {
        _scheduleReconnect(task, fast: _rapidRecoveryTasks.contains(task.taskId));
      }
      _completeLifecycle(task.taskId);
    } catch (error, stackTrace) {
      developer.log(
        'Recorder task failed: $error',
        name: 'RecorderController',
        stackTrace: stackTrace,
      );
      if (!token.isCancelled) {
        task.markFailure(stage: 'recorder', error: error);
        if (task.autoReconnect) {
          _scheduleReconnect(task, fast: _rapidRecoveryTasks.contains(task.taskId));
        } else {
          task.status = RecordStatus.failed;
          updateTask(task);
        }
      }
      _completeLifecycle(task.taskId);
    } finally {
      final pendingLease = _pendingRecorderLeases[task.taskId];
      if (pendingLease?.sourceUrl == task.currentUrl) {
        _pendingRecorderLeases.remove(task.taskId);
      }
      if (token.isCancelled && task.status != RecordStatus.stopped) {
        task.status = RecordStatus.stopped;
        updateTask(task);
      }
      _completeLifecycle(task.taskId);
      await lifecycle.future;
      if (identical(_lifecycleCompleters[task.taskId], lifecycle)) {
        _lifecycleCompleters.remove(task.taskId);
      }
      if (protectedDirectory != null) CacheService.to.releaseDirectory(protectedDirectory);
    }
  }

  void _scheduleRecorderLeaseRefresh(
    LiveRecordTask task,
    ResolvedRecordStream stream,
    int sessionId,
  ) {
    _cancelRecorderLeaseTimers(task.taskId);
    final refreshAt = stream.refreshAt?.toUtc();
    if (refreshAt == null || task.currentUrl?.isNotEmpty != true) return;
    final sourceUrl = task.currentUrl!;
    final now = DateTime.now().toUtc();
    developer.log(
      'Signed transport scheduled: platform=${task.platform}; '
      'refreshInMs=${math.max(0, refreshAt.difference(now).inMilliseconds)}; '
      'invalidInMs=${stream.invalidAt == null ? -1 : math.max(0, stream.invalidAt!.toUtc().difference(now).inMilliseconds)}',
      name: 'RecorderLease',
    );

    final prefetchDelay = RecorderContinuationPolicy.leasePrefetchDelay(
      now: now,
      refreshAt: refreshAt,
    );
    _leasePrefetchTimers[task.taskId] = Timer(prefetchDelay, () {
      _leasePrefetchTimers.remove(task.taskId);
      unawaited(_prefetchRecorderLease(task, sourceUrl: sourceUrl, sessionId: sessionId));
    });

    final rotationDelay = RecorderContinuationPolicy.leaseRotationDelay(
      now: now,
      refreshAt: refreshAt,
    );
    _leaseRotationTimers[task.taskId] = Timer(rotationDelay, () {
      _leaseRotationTimers.remove(task.taskId);
      if (!_isCurrentSession(task.taskId, sessionId) ||
          task.wasStoppedByUser ||
          task.currentUrl != sourceUrl ||
          ffmpeg.getSession(task.taskId)?.sessionId != sessionId) {
        return;
      }
      // The platform lease is a transport boundary, not an offline signal.
      // End the old input before the server does so the controller can consume
      // the prefetched same-quality/same-CDN URL without waiting for EOF.
      unawaited(ffmpeg.refreshLease(task.taskId));
    });
  }

  Future<void> _prefetchRecorderLease(
    LiveRecordTask task, {
    required String sourceUrl,
    required int sessionId,
  }) async {
    if (!_isCurrentSession(task.taskId, sessionId) ||
        task.wasStoppedByUser ||
        task.currentUrl != sourceUrl) {
      return;
    }
    try {
      final renewed = await StreamResolverService.to.resolveStream(
        roomId: task.roomId,
        platform: task.platform,
        preferredQuality: settings.defaultQuality.value,
        previousQualityId: task.selectedQualityId,
        previousLineIndex: task.selectedLineIndex,
        renewCurrent: true,
      );
      if (!_isCurrentSession(task.taskId, sessionId) ||
          task.wasStoppedByUser ||
          task.currentUrl != sourceUrl) {
        return;
      }
      final invalidAt = renewed.invalidAt?.toUtc();
      if (invalidAt != null && !invalidAt.isAfter(DateTime.now().toUtc())) return;
      _prefetchedRecorderLeases[task.taskId] = _PrefetchedRecorderLease(
        sourceUrl: sourceUrl,
        stream: renewed,
      );
    } catch (error, stackTrace) {
      // Prefetch is opportunistic. The scheduled rotation still performs a
      // synchronous fresh resolve, while ordinary EOF recovery remains armed.
      developer.log(
        'Recorder signed-stream prefetch failed: $error',
        name: 'RecorderController',
        stackTrace: stackTrace,
      );
    }
  }

  void _cancelRecorderLeaseTimers(String taskId) {
    _leasePrefetchTimers.remove(taskId)?.cancel();
    _leaseRotationTimers.remove(taskId)?.cancel();
  }

  void _cancelRecorderLease(String taskId) {
    _cancelRecorderLeaseTimers(taskId);
    _prefetchedRecorderLeases.remove(taskId);
    _pendingRecorderLeases.remove(taskId);
  }

  void _completeLifecycle(String taskId) {
    final lifecycle = _lifecycleCompleters[taskId];
    if (lifecycle != null && !lifecycle.isCompleted) lifecycle.complete();
  }

  String _streamFailureStage(StreamErrorType type) => switch (type) {
    StreamErrorType.roomNotFound || StreamErrorType.notLive || StreamErrorType.banned => 'room',
    StreamErrorType.noQuality => 'quality',
    StreamErrorType.cdnFailed || StreamErrorType.loginExpired => 'stream',
    StreamErrorType.networkError || StreamErrorType.unknown => 'network',
  };

  void _scheduleReconnect(LiveRecordTask task, {bool fast = false}) {
    if (task.wasStoppedByUser || !_containsTask(task.taskId)) return;
    task.retryCount = (task.retryCount + 1).clamp(0, 1000).toInt();
    if (RecorderContinuationPolicy.shouldEnterPollingAfterRetryLimit(
      retryCount: task.retryCount,
      maximumRetries: settings.maxRetryCount.value,
      unexpectedEof: fast,
    )) {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _schedulePoll(task);
      return;
    }

    task.status = RecordStatus.reconnecting;
    updateTask(task);
    _retryTimers.remove(task.taskId)?.cancel();
    final delay = RecorderContinuationPolicy.reconnectDelay(
      failureCount: task.retryCount - 1,
      // A clean EOF from a still-live HTTP stream needs a newly signed URL,
      // not FFmpeg's internal reconnect loop.  Keep this path short and
      // bounded while retaining the user-configured delay for real failures.
      configuredBaseSeconds: settings.retryDelay.value,
      configuredMaximumSeconds: settings.maxCheckInterval.value,
      enableBackoff: settings.enableBackoff.value,
      unexpectedEof: fast,
    );
    _retryTimers[task.taskId] = Timer(delay, () {
      _retryTimers.remove(task.taskId);
      if (_containsTask(task.taskId) && !task.wasStoppedByUser) unawaited(_startTask(task));
    });
  }

  Future<void> stopTask(LiveRecordTask task) async {
    task.wasStoppedByUser = true;
    _stopPolling(task.taskId);
    _retryTimers.remove(task.taskId)?.cancel();
    _cancelRecorderLease(task.taskId);
    await scheduler.cancel(task.taskId);
    final finalization = _finalizationFutures[task.taskId];
    if (finalization != null) await finalization;
    _stopOutputMonitor(task.taskId);
    _attemptProgress.remove(task.taskId);
    _rapidRecoveryTasks.remove(task.taskId);
    if (task.pendingAttempts.isNotEmpty) {
      task.status = RecordStatus.processing;
      updateTask(task);
      final merged = await _finalizePendingAttempts(task);
      await settings.refreshCacheSize();
      task.status = merged ? RecordStatus.stopped : RecordStatus.failed;
      if (!merged) task.markFailure(stage: 'merge', error: i18n('video_ffmpeg_failed'));
    } else {
      task.status = RecordStatus.stopped;
    }
    updateTask(task);
  }

  void _schedulePoll(LiveRecordTask task, {Duration? delay}) {
    if (!settings.enablePolling.value || task.wasStoppedByUser || !_containsTask(task.taskId)) {
      return;
    }
    _pollTimers.remove(task.taskId)?.cancel();
    final failureCount = _pollFailures[task.taskId] ?? 0;
    final effectiveDelay =
        delay ??
        RecorderContinuationPolicy.pollingDelay(
          failureCount: failureCount,
          baseSeconds: settings.liveCheckInterval.value,
          maximumSeconds: settings.maxCheckInterval.value,
          enableBackoff: settings.enableBackoff.value,
        );
    _pollTimers[task.taskId] = Timer(effectiveDelay, () {
      _pollTimers.remove(task.taskId);
      unawaited(_pollTask(task));
    });
  }

  Future<void> _pollTask(LiveRecordTask task) async {
    if (!_pollInFlight.add(task.taskId) || task.wasStoppedByUser || !_containsTask(task.taskId)) {
      return;
    }
    try {
      final site = Sites.of(task.platform).liveSite;
      final room = site is LiveSiteRoomRefresher
          ? await (site as LiveSiteRoomRefresher).getRoomDetailForRefresh(
              roomId: task.roomId,
              platform: task.platform,
            )
          : await site.getRoomDetail(roomId: task.roomId, platform: task.platform);
      task.updateFromRoom(room);
      updateTask(task);
      if (room.isPlayableNow) {
        _pollFailures.remove(task.taskId);
        task.retryCount = 0;
        await _startTask(task);
        return;
      }
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _pollFailures[task.taskId] = (_pollFailures[task.taskId] ?? 0) + 1;
    } catch (error) {
      _pollFailures[task.taskId] = (_pollFailures[task.taskId] ?? 0) + 1;
      task.markFailure(stage: 'status', error: error);
      updateTask(task);
      developer.log('Recorder status poll failed: $error', name: 'RecorderController');
    } finally {
      _pollInFlight.remove(task.taskId);
    }
    _schedulePoll(task);
  }

  void _stopPolling(String taskId) {
    _pollTimers.remove(taskId)?.cancel();
    _pollFailures.remove(taskId);
  }

  Future<void> refreshTaskStatus(LiveRecordTask task) async {
    _stopPolling(task.taskId);
    await _pollTask(task);
  }

  Future<void> _checkResources() async {
    if (_resourceCheckRunning || !settings.enableCacheLimit.value) return;
    _resourceCheckRunning = true;
    try {
      final cacheMB = await CacheService.to.getCacheSize();
      if (cacheMB > settings.maxCacheMB.value) {
        await CacheService.to.enforceLimit(maxMB: settings.maxCacheMB.value.toDouble());
        await settings.refreshCacheSize();
      }
    } catch (error) {
      developer.log('Recorder cache check failed: $error', name: 'RecorderController');
    } finally {
      _resourceCheckRunning = false;
    }
  }

  Future<void> unRecorder(LiveRecordTask task) async {
    await stopTask(task);
    _activeSessionIds.remove(task.taskId);
    _completeLifecycle(task.taskId);
    tasks.removeWhere((candidate) => candidate.taskId == task.taskId);
    schedulePersist();
  }

  Future<void> _persist() async {
    try {
      await HivePrefUtil.setString(
        RecorderKeys.recorderTasks,
        jsonEncode(tasks.map((task) => task.toJson()).toList()),
      );
    } catch (error) {
      developer.log('Persist recorder tasks failed: $error', name: 'RecorderController');
    }
  }

  Future<void> restoreAndAutoPoll() async {
    final raw = HivePrefUtil.getString(RecorderKeys.recorderTasks);
    if (raw == null || raw.trim().isEmpty) return;

    final restored = <LiveRecordTask>[];
    final interruptedTaskIds = <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map) continue;
          try {
            final task = LiveRecordTask.fromJson(Map<String, dynamic>.from(entry));
            if (task.roomId.trim().isEmpty || !Sites.isSupported(task.platform)) continue;
            if (const <RecordStatus>{
              RecordStatus.preparing,
              RecordStatus.running,
              RecordStatus.reconnecting,
              RecordStatus.processing,
            }.contains(task.status)) {
              interruptedTaskIds.add(task.taskId);
            }
            task
              ..status = RecordStatus.stopped
              ..wasStoppedByUser = false;
            if (restored.every((candidate) => candidate.taskId != task.taskId)) restored.add(task);
          } catch (error) {
            developer.log('Skipped malformed recorder task: $error', name: 'RecorderController');
          }
        }
      }
    } catch (error) {
      developer.log('Restore recorder task list failed: $error', name: 'RecorderController');
    }

    restored.sort((left, right) => left.status.order.compareTo(right.status.order));
    tasks.assignAll(restored);
    schedulePersist();

    // A process kill cannot run FFmpeg's completion callback. Finish only
    // tasks that were persisted in an active lifecycle; completed/manual
    // tasks are never reprocessed merely because a TS file still exists.
    for (final task in restored.where(
      (candidate) =>
          interruptedTaskIds.contains(candidate.taskId) || candidate.pendingAttempts.isNotEmpty,
    )) {
      await _recoverInterruptedRecording(task);
    }
    if (!settings.autoStartOnBoot.value || restored.isEmpty || !await requestStoragePermission()) {
      return;
    }

    for (final task in restored) {
      await refreshTaskStatus(task);
    }
  }

  Future<void> _recoverInterruptedRecording(LiveRecordTask task) async {
    final directory = task.outputDir?.trim() ?? '';
    if (directory.isNotEmpty) {
      await _queueCurrentAttempt(task, allowLegacy: true);
    }
    if (task.pendingAttempts.isEmpty) return;

    final directories = task.pendingAttempts.map((attempt) => attempt.directoryPath).toSet();
    for (final path in directories) {
      CacheService.to.protectDirectory(path);
    }
    try {
      task.status = RecordStatus.processing;
      updateTask(task);
      final merged = await _finalizePendingAttempts(task, allowLegacy: true);
      task.status = merged ? RecordStatus.stopped : RecordStatus.failed;
      updateTask(task);
      await settings.refreshCacheSize();
    } finally {
      for (final path in directories) {
        CacheService.to.releaseDirectory(path);
      }
    }
  }

  bool _containsTask(String taskId) => tasks.any((task) => task.taskId == taskId);

  Future<void> openFileDir() async {
    await FileUtils.openFileOrUrl(await CacheService.to.getDisplayPath());
  }

  @override
  void onClose() {
    _isClosing = true;
    for (final timer in _pollTimers.values) {
      timer.cancel();
    }
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    _retryTimers.clear();
    for (final timer in _leasePrefetchTimers.values) {
      timer.cancel();
    }
    for (final timer in _leaseRotationTimers.values) {
      timer.cancel();
    }
    _leasePrefetchTimers.clear();
    _leaseRotationTimers.clear();
    _prefetchedRecorderLeases.clear();
    _pendingRecorderLeases.clear();
    for (final timer in _outputMonitorTimers.values) {
      timer.cancel();
    }
    _outputMonitorTimers.clear();
    _outputMonitorBusy.clear();
    _outputTrackers.clear();
    _outputSamples.clear();
    _outputStartedAt.clear();
    _lastOutputPersist.clear();
    _attemptProgress.clear();
    _rapidRecoveryTasks.clear();
    _resourceMonitor?.cancel();
    _persistTimer?.cancel();
    _persistTimer = null;
    unawaited(scheduler.clearAll());
    unawaited(_ffmpegSub.cancel());
    if (_persistDirty) {
      _persistDirty = false;
      final pending = _persistInFlight;
      unawaited(pending == null ? _persist() : pending.whenComplete(_persist));
    }
    super.onClose();
  }
}

class _PrefetchedRecorderLease {
  const _PrefetchedRecorderLease({required this.sourceUrl, required this.stream});

  final String sourceUrl;
  final ResolvedRecordStream stream;
}

class _PendingRecorderLease {
  const _PendingRecorderLease({required this.sourceUrl, required this.stream});

  final String sourceUrl;
  final ResolvedRecordStream stream;
}
