import 'package:pure_live/core/interface/live_quality_discovery.dart';
import 'package:pure_live/recorder/services/recording_bitrate_window.dart';
import 'package:pure_live/recorder/services/live_input_recording_binding.dart';
import 'package:pure_live/common/utils/play_quality_label.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/huya/huya_transport_policy.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_scheduler.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/recorder_continuation_policy.dart';
import 'package:pure_live/recorder/services/recorder_background_service.dart';
import 'package:pure_live/recorder/services/recording_danmaku_service.dart';
import 'package:pure_live/recorder/services/recording_output_metrics.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';

class RecorderController extends GetxService {
  RecorderController([this._outputMetrics = const RecordingOutputMetrics()])
    : settings = Get.find<RecordSettingsController>(),
      _background = RecorderBackgroundService.shared,
      _persistTasks = _defaultPersistTasks,
      ffmpeg = FFmpegManager.to,
      scheduler = FFmpegScheduler.instance,
      _siteResolver = _defaultSiteResolver,
      _inputRecordingBinder = bindLiveInputForRecording,
      _pollTimeout = const Duration(seconds: 20),
      _outputSampleInterval = const Duration(seconds: 1);

  @visibleForTesting
  RecorderController.forTesting({
    required this.settings,
    required this.ffmpeg,
    required this.scheduler,
    this._siteResolver = _defaultSiteResolver,
    this._inputRecordingBinder = bindLiveInputForRecording,
    this._pollTimeout = const Duration(seconds: 20),
    this._outputMetrics = const RecordingOutputMetrics(),
    this._outputSampleInterval = const Duration(seconds: 1),
    RecorderBackgroundService? background,
    Future<void> Function(String)? persistTasks,
  }) : _background = background ?? RecorderBackgroundService(supported: false),
       _persistTasks = persistTasks ?? _defaultPersistTasks;

  static RecorderController get to => Get.find<RecorderController>();

  final RecordSettingsController settings;
  final FFmpegManager ffmpeg;
  final FFmpegScheduler scheduler;
  final RecorderLiveSiteResolver _siteResolver;
  final LiveInputRecordingBinder _inputRecordingBinder;
  final Duration _pollTimeout;
  static LiveSite _defaultSiteResolver(String platform) => Sites.of(platform).liveSite;
  final Duration _outputSampleInterval;
  final Future<void> Function(String) _persistTasks;
  static Future<void> _defaultPersistTasks(String snapshot) async {
    await HivePrefUtil.setString(RecorderKeys.recorderTasks, snapshot);
  }

  final RecorderBackgroundService _background;
  final Map<String, _RecorderBackgroundTaskLease> _backgroundLeases = {};
  late final Future<void> Function(String) _backgroundInterruptionListener;
  final RxList<LiveRecordTask> tasks = <LiveRecordTask>[].obs;

  final Map<String, Timer> _pollTimers = <String, Timer>{};
  final Map<String, int> _pollFailures = <String, int>{};
  final Map<String, _RecorderPollRequest> _pollInFlight = <String, _RecorderPollRequest>{};
  Worker? _pollingWorker;
  Future<void>? _restoreInFlight;
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final Map<String, Timer> _leasePrefetchTimers = <String, Timer>{};
  final Map<String, Timer> _leaseRotationTimers = <String, Timer>{};
  final Map<String, _RecorderLeasePrefetch> _leasePrefetchRequests = {};
  final Map<String, _PrefetchedRecorderLease> _prefetchedRecorderLeases = <String, _PrefetchedRecorderLease>{};
  final Map<String, _PendingRecorderLease> _pendingRecorderLeases = <String, _PendingRecorderLease>{};
  final Set<String> _startingTasks = <String>{};
  final Map<String, _RecorderStartRequest> _startRequests = {};
  final Map<String, _RecorderStopRequest> _stopRequests = {};
  final Map<String, Completer<void>> _interruptedRecoveries = {};
  final Set<LiveRecordTask> _removingTasks = {};
  final Set<String> _rapidRecoveryTasks = <String>{};
  final Map<String, Completer<void>> _lifecycleCompleters = <String, Completer<void>>{};
  final Map<String, int> _activeSessionIds = <String, int>{};
  final Map<String, Future<void>> _finalizationFutures = <String, Future<void>>{};
  final RecordingOutputMetrics _outputMetrics;
  final Map<String, _RecorderOutputMonitor> _outputMonitors = <String, _RecorderOutputMonitor>{};
  final Map<String, DateTime> _lastOutputPersist = <String, DateTime>{};
  final Map<String, RecordingAttemptProgress> _attemptProgress = <String, RecordingAttemptProgress>{};

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
    _backgroundInterruptionListener = _onBackgroundInterrupted;
    _background.addInterruptionListener(_backgroundInterruptionListener);
    _resourceMonitor = Timer.periodic(const Duration(minutes: 1), (_) {
      if (settings.enableCacheLimit.value) unawaited(_checkResources());
    });
    _ffmpegSub = ffmpeg.stream.listen((event) => unawaited(_handleFFmpegEvent(event)));
    _pollingWorker = ever<bool>(settings.enablePolling, _onPollingChanged);
    _danmakuTasksWorker = ever<List<LiveRecordTask>>(tasks, _danmakuRecorder.sync);
    _danmakuSettingWorker = ever<bool>(settings.recordDanmaku, (_) => _danmakuRecorder.sync(tasks));
    unawaited(restoreAndAutoPoll());
  }

  /// Opt-in chat capture beside each attempt's video. It only observes task
  /// snapshots, so chat failures never reach stream or FFmpeg handling.
  late final RecordingDanmakuService _danmakuRecorder = RecordingDanmakuService(
    enabled: () => settings.recordDanmaku.value,
    connect: _connectRecordingDanmaku,
  );
  Worker? _danmakuTasksWorker;
  Worker? _danmakuSettingWorker;

  Future<RecordingDanmakuConnection?> _connectRecordingDanmaku(
    LiveRecordTask task,
    void Function(LiveMessage message) onMessage,
  ) async {
    if (!Sites.isSupported(task.platform)) return null;
    final site = _siteResolver(task.platform);
    final engine = site.getDanmaku();
    if (engine is EmptyDanmaku) return null;
    final room = await site.getRoomDetail(roomId: task.roomId, platform: task.platform);
    engine.onMessage = onMessage;
    try {
      await engine.start(room.danmakuData).timeout(const Duration(seconds: 20));
    } catch (_) {
      engine.onMessage = null;
      await engine.stop().catchError((Object _) {});
      rethrow;
    }
    return RecordingDanmakuConnection(
      stop: () async {
        engine.onMessage = null;
        await engine.stop();
      },
    );
  }

  Future<void> _handleFFmpegEvent(FFmpegEvent event) async {
    if (_isClosing) return;
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
        final attempt = _attemptProgress[event.taskId] ?? const RecordingAttemptProgress(baseBytes: 0, baseSeconds: 0);
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
      case FFmpegEventType.inputCoverage:
        if (!_isCurrentSession(event.taskId, sessionId) || event.data['inputCoverageIncomplete'] != true) return;
        if (!task.inputCoverageIncomplete) {
          task.inputCoverageIncomplete = true;
          // Input evidence is not media start/progress, a stop, or a retry.
          updateTask(task);
        }
        return;
      case FFmpegEventType.error:
      case FFmpegEventType.complete:
        if (!_isCurrentSession(event.taskId, sessionId)) return;
        final monitor = _outputMonitors[event.taskId];
        if (monitor?.finishing == true) return;
        if (monitor != null) {
          monitor.finishing = true;
          monitor.timer?.cancel();
        }
        await _sampleOutput(task, sessionId!, forcePersist: true);
        // Native events are dispatched without awaiting this handler. A new
        // attempt can own the task while the old terminal snapshot is reading.
        if (_isClosing ||
            !_isCurrentSession(event.taskId, sessionId) ||
            !identical(_outputMonitors[event.taskId], monitor) ||
            !tasks.any((candidate) => identical(candidate, task))) {
          return;
        }
        _stopOutputMonitor(event.taskId);
        _cancelRecorderLeaseTimers(event.taskId);
        _pendingRecorderLeases.remove(event.taskId);
        _activeSessionIds.remove(event.taskId);
        // Only a current terminal session may enrich the recording verdict.
        // Keep it through successful remux/reconnection; missing input is not
        // equivalent to damaged packets and does not block healthy segment use.
        task.inputTailDiscarded = task.inputTailDiscarded || event.data['inputTailDiscarded'] == true;
        task.inputCoverageIncomplete = task.inputCoverageIncomplete || event.data['inputCoverageIncomplete'] == true;
        final manuallyStopped = event.data['manualStop'] == true || task.wasStoppedByUser;
        final isError = event.type == FFmpegEventType.error;
        final errorCode = (event.data['code'] as num?)?.toInt() ?? 0;
        final rawLogs = event.data['raw_logs']?.toString() ?? '';
        final failureKind = event.data['failure_kind']?.toString();
        final refreshSignedStream =
            failureKind == 'leaseRefresh' || failureKind == 'unexpectedEof' || failureKind == 'httpAccess';
        if (refreshSignedStream) _rapidRecoveryTasks.add(task.taskId);
        final fastReconnect = refreshSignedStream || _rapidRecoveryTasks.contains(task.taskId);
        final classifiedRetryable = event.data['retryable'];
        final shouldRetry =
            !isError ||
            (classifiedRetryable is bool
                ? classifiedRetryable
                : RecorderContinuationPolicy.shouldRetryFailure(errorCode: errorCode, rawLogs: rawLogs));
        // A native FLV credential is prefetched without rotating its healthy
        // transport. Keep it for actual EOF/access recovery, not just for the
        // old timer-driven cancellation path. _runTask rechecks URL and expiry.
        if (manuallyStopped || !refreshSignedStream || !shouldRetry) {
          _prefetchedRecorderLeases.remove(task.taskId);
        }
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
          inputIntegrityError: event.data['inputIntegrityError'] == true,
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
    final monitor = _RecorderOutputMonitor(
      task: task,
      sessionId: sessionId,
      tracker: _outputMetrics.track(directoryPath: directoryPath, filePrefix: task.recordingFilePrefix),
    );
    _outputMonitors[task.taskId] = monitor;
    unawaited(_sampleOutput(task, sessionId));
    monitor.timer = Timer.periodic(_outputSampleInterval, (_) => unawaited(_sampleOutput(task, sessionId)));
  }

  void _stopOutputMonitor(String taskId) {
    _outputMonitors.remove(taskId)?.timer?.cancel();
    _lastOutputPersist.remove(taskId);
  }

  bool _shouldPersistOutput(String taskId, {DateTime? now, bool force = false}) {
    final sampledAt = now ?? DateTime.now();
    final previous = _lastOutputPersist[taskId];
    if (!force && previous != null && sampledAt.difference(previous) < const Duration(seconds: 10)) return false;
    _lastOutputPersist[taskId] = sampledAt;
    return true;
  }

  Future<void> _sampleOutput(LiveRecordTask task, int sessionId, {bool forcePersist = false}) async {
    final monitor = _outputMonitors[task.taskId];
    if (monitor == null || monitor.sessionId != sessionId || !_ownsOutputMonitor(monitor)) return;
    final pending = monitor.sampling;
    if (pending != null) {
      if (!forcePersist) return;
      // Finishing cancels periodic sampling first. Join its in-flight read,
      // then take a fresh snapshot after native shutdown, without overlapping
      // the stateful sequential segment tracker or dropping final bytes.
      await pending.future;
      if (!_ownsOutputMonitor(monitor)) return;
    }
    if (monitor.finishing && !forcePersist) return;
    final sampling = Completer<void>();
    monitor.sampling = sampling;
    try {
      final directoryPath = task.outputDir?.trim() ?? '';
      if (directoryPath.isEmpty) return;
      final snapshot = await monitor.tracker.sample();
      if (!_ownsOutputMonitor(monitor)) return;
      final now = DateTime.now();
      final activeNative = ffmpeg.getSession(task.taskId);
      final nativeSession = activeNative?.sessionId == sessionId ? activeNative : null;
      final attemptBytes = math.max(snapshot.bytes, nativeSession?.fileSize ?? 0);
      final mediaStarted = attemptBytes > 0 || nativeSession?.mediaStarted == true;
      if (!mediaStarted) return;

      monitor.startedAt ??= now;
      final attempt = _attemptProgress[task.taskId] ?? const RecordingAttemptProgress(baseBytes: 0, baseSeconds: 0);
      final totalBytes = attempt.totalBytes(attemptBytes);
      if (totalBytes > task.fileSize) task.fileSize = totalBytes;
      final windowBitrate = monitor.bitrate.add(attemptBytes, now);
      if (windowBitrate != null) task.bitrate = windowBitrate;
      if (task.bitrate <= 0 && (nativeSession?.bitrate ?? 0) > 0) task.bitrate = nativeSession!.bitrate;
      final wallSeconds = now.difference(monitor.startedAt!).inSeconds;
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
      developer.log('Recorder output monitor failed: $error', name: 'RecorderController', stackTrace: stackTrace);
    } finally {
      // This owner can be detached while its IO completes. Never release a
      // lock by task ID here: that ID may already belong to another attempt.
      if (identical(monitor.sampling, sampling)) monitor.sampling = null;
      sampling.complete();
    }
  }

  bool _ownsOutputMonitor(_RecorderOutputMonitor monitor) =>
      !_isClosing &&
      identical(_outputMonitors[monitor.task.taskId], monitor) &&
      _isCurrentSession(monitor.task.taskId, monitor.sessionId) &&
      tasks.any((candidate) => identical(candidate, monitor.task));

  Future<void> _finalizeAttempt(
    LiveRecordTask task, {
    required bool manuallyStopped,
    required bool failed,
    required bool shouldRetry,
    bool fastReconnect = false,
    bool inputIntegrityError = false,
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
          inputIntegrityError: inputIntegrityError,
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
    required bool inputIntegrityError,
  }) async {
    try {
      await _queueCurrentAttempt(task, inputIntegrityError: inputIntegrityError);
      if (_isClosing) return;
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
        if (_isClosing) return;
        await settings.refreshCacheSize();
        if (_isClosing) return;
      }

      if (!mergeSucceeded) {
        _markFinalizationFailure(task);
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
      developer.log('Recorder finalization failed: $error', name: 'RecorderController', stackTrace: stackTrace);
      if (_isClosing) return;
      task.markFailure(stage: 'merge', error: error);
      task.status = RecordStatus.failed;
      updateTask(task);
    } finally {
      _completeLifecycle(task.taskId);
    }
  }

  void _markFinalizationFailure(LiveRecordTask task) {
    final damaged = task.pendingAttempts.any((attempt) => attempt.inputIntegrityError);
    task.markFailure(
      stage: damaged ? 'ffmpeg.inputIntegrity' : 'merge',
      error: i18n(damaged ? 'recorder_input_integrity_failed' : 'video_ffmpeg_failed'),
    );
  }

  Future<void> _queueCurrentAttempt(
    LiveRecordTask task, {
    bool allowLegacy = false,
    bool inputIntegrityError = false,
  }) async {
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
    if (_isClosing || !_ownsTask(task)) return;
    task.queuePendingAttempt(
      directoryPath: directoryPath,
      filePrefix: filePrefix,
      inputIntegrityError: inputIntegrityError,
    );
    updateTask(task);
  }

  Future<bool> _finalizePendingAttempts(LiveRecordTask task, {bool allowLegacy = false}) async {
    var allSucceeded = true;
    final attempts = List<PendingRecordingAttempt>.of(task.pendingAttempts);
    for (final attempt in attempts) {
      if (_isClosing || !_ownsTask(task)) return false;
      // Capture the provisional TS size before the successful converter
      // deletes those source files. Each attempt is reconciled independently
      // so a later retry never loses output committed by an earlier pass.
      final source = await _outputMetrics.measure(directoryPath: attempt.directoryPath, filePrefix: attempt.filePrefix);
      if (_isClosing || !_ownsTask(task)) return false;
      final merged = await VideoProcessorService.to.convertToMp4(
        task: task,
        allowLegacySegments: allowLegacy,
        directoryPath: attempt.directoryPath,
        filePrefix: attempt.filePrefix,
      );
      if (_isClosing || !_ownsTask(task)) return false;
      if (merged) {
        final output = await _outputMetrics.measureFinalized(
          directoryPath: attempt.directoryPath,
          filePrefix: attempt.filePrefix,
        );
        if (_isClosing || !_ownsTask(task)) return false;
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
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.ts')) continue;
        if (VideoProcessorService.selectAttemptSegments(
          candidates: [entity],
          filePrefix: resolvedFilePrefix,
          allowLegacySegments: allowLegacy,
        ).isEmpty) {
          continue;
        }
        if (await entity.length() > 0) return true;
      }
    } on FileSystemException {
      return false;
    }
    return false;
  }

  void updateTask(LiveRecordTask task, {bool persist = true}) {
    final index = tasks.indexWhere((candidate) => candidate.taskId == task.taskId);
    if (_isClosing || index == -1 || !identical(tasks[index], task)) return;
    // Preserve the user's spatial context. Sorting on every status/progress
    // transition made recorder cards jump between rows while they were being
    // read or operated. Tabs already expose status-specific views; the all tab
    // therefore keeps insertion/restoration order stable.
    tasks[index] = task;
    if (persist) schedulePersist();
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
    // Every caller joins the actual write and any newer dirty snapshot. A
    // scheduled retry is insufficient when the last engine owner is leaving.
    while (true) {
      final inFlight = _persistInFlight;
      if (inFlight != null) {
        await inFlight;
        continue;
      }
      if (!_persistDirty) return;
      _persistDirty = false;
      final pending = _persist();
      _persistInFlight = pending;
      try {
        await pending;
      } finally {
        if (identical(_persistInFlight, pending)) _persistInFlight = null;
      }
    }
  }

  Future<bool> requestStoragePermission({bool requestIfMissing = true}) async {
    if (!Platform.isAndroid) return true;
    if (await _canWriteRecordDirectory()) return true;
    // Automatic resume runs during controller initialization rather than a
    // direct user gesture. Leave the task stopped when access disappeared;
    // the next explicit start can present the system permission surface.
    if (!requestIfMissing) return false;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        if (await Permission.manageExternalStorage.isGranted && await _canWriteRecordDirectory()) return true;
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

  Future<bool> _canWriteRecordDirectory() => CacheService.to.canWriteRecordDir();

  Future<LiveRecordTask?> addTask({required LiveRoom room, bool startImmediately = true}) async {
    if (_isClosing || !await requestStoragePermission() || _isClosing) return null;
    final existing = tasks.firstWhereOrNull((task) => task.roomId == room.roomId && task.platform == room.platform);
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
    return !_isClosing && _ownsTask(task) && !_removingTasks.contains(task) ? task : null;
  }

  Future<bool> startTask(LiveRecordTask task) {
    if (_isClosing || !_ownsTask(task) || _removingTasks.contains(task)) return Future.value(false);
    final existing = _startRequests[task.taskId];
    if (existing != null && identical(existing.task, task)) return existing.done.future;
    existing?.complete(false);
    final request = _RecorderStartRequest(task);
    _startRequests[task.taskId] = request;
    unawaited(_performUserStart(request));
    return request.done.future;
  }

  bool _ownsStart(_RecorderStartRequest request) =>
      !_isClosing &&
      _ownsTask(request.task) &&
      !_removingTasks.contains(request.task) &&
      identical(_startRequests[request.task.taskId], request);

  void _cancelUserStart(String taskId) => _startRequests.remove(taskId)?.complete(false);

  Future<void> _performUserStart(_RecorderStartRequest request) async {
    final task = request.task;
    try {
      if (!await requestStoragePermission() || !_ownsStart(request)) return;
      // Permission is not a recording intent. Wait for the old writer/file
      // transaction to drain before resetting this mutable task's counters.
      await _stopRequests[task.taskId]?.done.future;
      if (!_ownsStart(request)) return;
      await _interruptedRecoveries[task.taskId]?.future;
      if (!_ownsStart(request)) return;
      await _finalizationFutures[task.taskId];
      if (!_ownsStart(request)) return;
      if (_startingTasks.contains(task.taskId) || scheduler.isRunning(task.taskId) || scheduler.isQueued(task.taskId)) {
        request.complete(true);
        return;
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
      _background.allowUserRetry();
      await _startTask(task);
      request.complete(_ownsStart(request) && task.status != RecordStatus.failed);
    } catch (error, stack) {
      if (_ownsStart(request) && !request.done.isCompleted) request.done.completeError(error, stack);
    } finally {
      if (identical(_startRequests[task.taskId], request)) _startRequests.remove(task.taskId);
      request.complete(false);
    }
  }

  Future<void> forceStartTask(LiveRecordTask task) async {
    await startTask(task);
  }

  Future<void> _startTask(LiveRecordTask task) async {
    if (_isClosing || task.wasStoppedByUser || !_ownsTask(task) || _removingTasks.contains(task)) return;
    await _interruptedRecoveries[task.taskId]?.future;
    await _stopRequests[task.taskId]?.done.future;
    if (_isClosing || task.wasStoppedByUser || !_ownsTask(task) || _removingTasks.contains(task)) return;
    if (_startingTasks.contains(task.taskId)) {
      ToastUtil.show(i18n('recorder_task_starting'));
      return;
    }
    if (scheduler.isRunning(task.taskId) || scheduler.isQueued(task.taskId)) {
      return;
    }

    _startingTasks.add(task.taskId);
    _RecorderBackgroundTaskLease? backgroundLease;
    try {
      backgroundLease = await _acquireBackgroundLease(task);
      if (_isClosing || task.wasStoppedByUser || !_ownsTask(task) || _removingTasks.contains(task)) {
        await _releaseBackgroundLease(backgroundLease);
        return;
      }
      _stopPolling(task.taskId);
      _retryTimers.remove(task.taskId)?.cancel();
      task.status = RecordStatus.queued;
      updateTask(task);
      final lease = backgroundLease;
      scheduler.enqueue(taskId: task.taskId, taskRunner: (token) => _runTask(task, token, lease));
    } on RecorderBackgroundException catch (error) {
      if (_ownsTask(task) && !task.wasStoppedByUser && !_isClosing) {
        task.markFailure(stage: 'background', error: _backgroundFailureText(error.reason));
        task.status = RecordStatus.failed;
        updateTask(task);
      }
    } catch (error, stackTrace) {
      developer.log('Start recorder task failed: $error', name: 'RecorderController', stackTrace: stackTrace);
      task.markFailure(stage: 'scheduler', error: error);
      task.status = RecordStatus.failed;
      updateTask(task);
    } finally {
      _startingTasks.remove(task.taskId);
      if (backgroundLease != null && !scheduler.isRunning(task.taskId) && !scheduler.isQueued(task.taskId)) {
        await _releaseBackgroundLease(backgroundLease);
      }
    }
  }

  Future<void> _runTask(
    LiveRecordTask task,
    TaskCancelToken token,
    _RecorderBackgroundTaskLease backgroundLease,
  ) async {
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
    CacheService? directoryOwner;
    final discovery = LiveQualityDiscoveryScope();
    token.onCancel = () async {
      discovery.cancel();
      final hadActiveSession = ffmpeg.isRunning(task.taskId) || VideoProcessorService.to.isProcessing(task.taskId);
      await Future.wait(<Future<void>>[
        discovery.close(),
        ffmpeg.stop(task.taskId),
        VideoProcessorService.to.cancel(task.taskId),
      ]);
      // A finished native writer can still have a terminal sample or a
      // dispatched finalizer. Cancellation must not release its directory
      // and scheduler slot before those phases have drained.
      if (!hadActiveSession &&
          !_activeSessionIds.containsKey(task.taskId) &&
          !_finalizationFutures.containsKey(task.taskId)) {
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
          (prefetched.stream.invalidAt == null || prefetched.stream.invalidAt!.isAfter(DateTime.now().toUtc()));
      final resolved = prefetchedStillValid
          ? prefetched.stream
          : await StreamResolverService.to.resolveStream(
              roomId: task.roomId,
              platform: task.platform,
              preferredQuality: settings.defaultQuality.value,
              previousQualityId: previousQualityId,
              previousLineIndex: previousLineIndex,
              renewCurrent: renewCurrent,
              discoveryScope: discovery,
            );
      if (token.isCancelled) return;

      directoryOwner = CacheService.to;
      final directory = await directoryOwner.getRoomDir(
        platform: task.platform,
        nick: task.nick,
        usePinyinForFolder: settings.usePinyinForFolder.value,
      );
      protectedDirectory = directory.path;
      directoryOwner.protectDirectory(directory.path);
      if (token.isCancelled) return;

      final recipe = resolved.inputRecipe;
      final ownedSource = recipe == null ? null : _inputRecordingBinder(recipe);
      final headers = ownedSource == null
          ? await FFmpegHeaderFactory.build(
              platform: task.platform,
              roomId: task.roomId,
              roomHeaders: resolved.httpHeaders,
            )
          : const <String, String>{};
      if (token.isCancelled) return;

      task
        ..currentUrl = ownedSource == null ? resolved.url : null
        ..selectedQuality = resolved.quality.playbackLabel
        ..selectedQualityId = resolved.qualityCursorId
        ..selectedLineIndex = resolved.lineIndex
        ..selectedLine = resolved.lineLabel
        ..outputDir = directory.path;
      updateTask(task);

      final pendingLease = ownedSource == null
          ? _PendingRecorderLease(sourceUrl: resolved.url, stream: resolved)
          : null;
      if (pendingLease != null) _pendingRecorderLeases[task.taskId] = pendingLease;

      // Freeze output settings before remote acquisition. The deferred builder
      // owns values, not a mutable route/task or a fabricated input URL.
      final outputDir = directory.path;
      final segmentTime = settings.segmentTime.value;
      final preferBestStream = settings.preferBestStream.value;
      final rwTimeout = settings.rwTimeout.value;
      final threadQueueSize = settings.threadQueueSize.value;
      final filePrefix = task.recordingFilePrefix;
      List<String> buildArguments(String url) => FFmpegCommandBuilder.buildRecordArguments(
        headers: headers,
        url: url,
        outputDir: outputDir,
        segmentTime: segmentTime,
        preferBestStream: preferBestStream,
        rwTimeout: rwTimeout,
        threadQueueSize: threadQueueSize,
        filePrefix: filePrefix,
      );
      if (token.isCancelled) return;

      if (ownedSource != null) {
        await ffmpeg.startOwned(
          taskId: task.taskId,
          source: ownedSource,
          buildArguments: (input) => buildArguments(input.toString()),
        );
      } else {
        await ffmpeg.start(
          taskId: task.taskId,
          arguments: buildArguments(resolved.url),
          liveRecording: true,
          // Every live URL attempt uses bounded HLS retention when the feeds
          // can be admitted atomically; owned inputs bring their own relay.
          hlsPrefetch: true,
          sourceQueryPolicy: resolved.sourceQueryPolicy,
        );
      }
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
        ToastUtil.show(i18n('recorder_resolve_failed', args: {'name': task.nick, 'error': error.message}));
      } else {
        _scheduleReconnect(task, fast: _rapidRecoveryTasks.contains(task.taskId));
      }
      _completeLifecycle(task.taskId);
    } catch (error, stackTrace) {
      developer.log('Recorder task failed: $error', name: 'RecorderController', stackTrace: stackTrace);
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
      await discovery.close();
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
      if (protectedDirectory != null) directoryOwner?.releaseDirectory(protectedDirectory);
      // Preserve the same lease over signed-source rotation and short retries.
      // A user stop keeps it through any remaining pending-attempt merge.
      if (!identical(_stopRequests[task.taskId]?.task, task) &&
          (_isClosing || !_ownsTask(task) || task.status != RecordStatus.reconnecting)) {
        await _releaseBackgroundLease(backgroundLease);
      }
    }
  }

  Future<_RecorderBackgroundTaskLease> _acquireBackgroundLease(LiveRecordTask task) async {
    final current = _backgroundLeases[task.taskId];
    if (current != null && identical(current.task, task)) return current;
    final lease = _RecorderBackgroundTaskLease(task);
    _backgroundLeases[task.taskId] = lease;
    try {
      await _background.acquire(lease);
      return lease;
    } catch (_) {
      if (identical(_backgroundLeases[task.taskId], lease)) _backgroundLeases.remove(task.taskId);
      rethrow;
    }
  }

  Future<void> _releaseBackgroundLease(_RecorderBackgroundTaskLease lease) async {
    if (identical(_backgroundLeases[lease.task.taskId], lease)) _backgroundLeases.remove(lease.task.taskId);
    // Unbinding the last native owner may destroy a detached cached engine.
    // Persist final file/status metadata before allowing that destruction.
    await _flushPersist();
    await _background.release(lease);
  }

  String _backgroundFailureText(String reason) =>
      i18n(reason == 'timeout' ? 'recorder_background_time_limit' : 'recorder_background_unavailable');

  Future<void> _onBackgroundInterrupted(String reason) async {
    if (_isClosing) return;
    final cleanup = Object();
    _background.retainForCleanup(cleanup);
    try {
      final affected = _backgroundLeases.values.map((lease) => lease.task).toSet().toList();
      await Future.wait(
        affected.map((task) async {
          await stopTask(task);
          if (_isClosing || !_ownsTask(task)) return;
          task.markFailure(stage: 'background', error: _backgroundFailureText(reason));
          task.status = RecordStatus.failed;
          updateTask(task);
        }),
      );
      await _flushPersist();
    } finally {
      await _background.release(cleanup);
    }
  }

  void _scheduleRecorderLeaseRefresh(LiveRecordTask task, ResolvedRecordStream stream, int sessionId) {
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

    final prefetchDelay = RecorderContinuationPolicy.leasePrefetchDelay(now: now, refreshAt: refreshAt);
    _scheduleRecorderCredentialPrefetch(task, sourceUrl: sourceUrl, sessionId: sessionId, delay: prefetchDelay);

    // Native WUP FLV has demonstrated a connection lifetime longer than its
    // open credential. Keep capturing packets; only prepare the next URL.
    // Web/HLS leases and other adapters retain their existing rotation policy.
    if (HuyaTransportPolicy.hasNativeFlvCredential(sourceUrl)) return;

    final rotationDelay = RecorderContinuationPolicy.leaseRotationDelay(now: now, refreshAt: refreshAt);
    _leaseRotationTimers[task.taskId] = Timer(rotationDelay, () {
      _leaseRotationTimers.remove(task.taskId);
      if (!_ownsRecorderLease(task, sourceUrl: sourceUrl, sessionId: sessionId)) return;
      unawaited(ffmpeg.refreshLease(task.taskId));
    });
  }

  bool _ownsRecorderLease(LiveRecordTask task, {required String sourceUrl, required int sessionId}) =>
      !_isClosing &&
      _ownsTask(task) &&
      !task.wasStoppedByUser &&
      task.currentUrl == sourceUrl &&
      _isCurrentSession(task.taskId, sessionId) &&
      ffmpeg.getSession(task.taskId)?.sessionId == sessionId;

  void _scheduleRecorderCredentialPrefetch(
    LiveRecordTask task, {
    required String sourceUrl,
    required int sessionId,
    required Duration delay,
  }) {
    _leasePrefetchTimers.remove(task.taskId)?.cancel();
    if (!_ownsRecorderLease(task, sourceUrl: sourceUrl, sessionId: sessionId)) return;
    _leasePrefetchTimers[task.taskId] = Timer(delay, () {
      _leasePrefetchTimers.remove(task.taskId);
      unawaited(_prefetchRecorderLease(task, sourceUrl: sourceUrl, sessionId: sessionId));
    });
  }

  Future<void> _prefetchRecorderLease(LiveRecordTask task, {required String sourceUrl, required int sessionId}) async {
    if (!_ownsRecorderLease(task, sourceUrl: sourceUrl, sessionId: sessionId) ||
        _leasePrefetchRequests.containsKey(task.taskId)) {
      return;
    }
    final request = _RecorderLeasePrefetch();
    _leasePrefetchRequests[task.taskId] = request;
    DateTime? nextRefreshAt;
    try {
      final renewed = await StreamResolverService.to.resolveStream(
        roomId: task.roomId,
        platform: task.platform,
        preferredQuality: settings.defaultQuality.value,
        previousQualityId: task.selectedQualityId,
        previousLineIndex: task.selectedLineIndex,
        renewCurrent: true,
        discoveryScope: request.discovery,
      );
      if (!identical(_leasePrefetchRequests[task.taskId], request) ||
          !_ownsRecorderLease(task, sourceUrl: sourceUrl, sessionId: sessionId)) {
        return;
      }
      final invalidAt = renewed.invalidAt?.toUtc();
      if (invalidAt != null && !invalidAt.isAfter(DateTime.now().toUtc())) return;
      _prefetchedRecorderLeases[task.taskId] = _PrefetchedRecorderLease(sourceUrl: sourceUrl, stream: renewed);
      nextRefreshAt = renewed.refreshAt;
    } catch (error, stackTrace) {
      // Prefetch is opportunistic; its failure never cancels healthy native
      // FLV. Genuine EOF recovery still resolves a URL when no valid cache exists.
      developer.log(
        'Recorder signed-stream prefetch failed: $error',
        name: 'RecorderController',
        stackTrace: stackTrace,
      );
    } finally {
      await request.discovery.close();
      if (identical(_leasePrefetchRequests[task.taskId], request)) {
        _leasePrefetchRequests.remove(task.taskId);
        if (HuyaTransportPolicy.hasNativeFlvCredential(sourceUrl)) {
          _scheduleRecorderCredentialPrefetch(
            task,
            sourceUrl: sourceUrl,
            sessionId: sessionId,
            delay: RecorderContinuationPolicy.leaseMaintenanceDelay(
              now: DateTime.now().toUtc(),
              refreshAt: nextRefreshAt,
            ),
          );
        }
      }
    }
  }

  void _cancelRecorderLeaseTimers(String taskId) {
    _leasePrefetchTimers.remove(taskId)?.cancel();
    _leaseRotationTimers.remove(taskId)?.cancel();
    final request = _leasePrefetchRequests.remove(taskId);
    if (request != null) _retirePrefetchDiscovery(taskId, request.discovery);
  }

  final Map<String, Set<Future<void>>> _retiringPrefetchDiscoveries = {};

  void _retirePrefetchDiscovery(String taskId, LiveQualityDiscoveryScope discovery) {
    final pending = _retiringPrefetchDiscoveries.putIfAbsent(taskId, () => {});
    late final Future<void> work;
    work = discovery.close().whenComplete(() {
      pending.remove(work);
      if (pending.isEmpty && identical(_retiringPrefetchDiscoveries[taskId], pending)) {
        _retiringPrefetchDiscoveries.remove(taskId);
      }
    });
    pending.add(work);
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
    if (_isClosing || task.wasStoppedByUser || !_containsTask(task.taskId)) return;
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

  Future<void> stopTask(LiveRecordTask task) {
    if (_isClosing || !_ownsTask(task)) return Future.value();
    _cancelUserStart(task.taskId);
    task.wasStoppedByUser = true;
    _stopPolling(task.taskId);
    _retryTimers.remove(task.taskId)?.cancel();
    _cancelRecorderLease(task.taskId);
    final existing = _stopRequests[task.taskId];
    if (existing != null && identical(existing.task, task)) return existing.done.future;
    final request = _RecorderStopRequest(task);
    _stopRequests[task.taskId] = request;
    unawaited(_performUserStop(request, previous: existing));
    return request.done.future;
  }

  Future<void> _performUserStop(_RecorderStopRequest request, {_RecorderStopRequest? previous}) async {
    try {
      await previous?.done.future;
      await _stopTask(request.task);
      final lease = _backgroundLeases[request.task.taskId];
      if (lease != null && identical(lease.task, request.task)) await _releaseBackgroundLease(lease);
      request.done.complete();
    } catch (error, stack) {
      request.done.completeError(error, stack);
    } finally {
      if (identical(_stopRequests[request.task.taskId], request)) _stopRequests.remove(request.task.taskId);
    }
  }

  Future<void> _stopTask(LiveRecordTask task) async {
    if (_isClosing || !_ownsTask(task)) return;
    await scheduler.cancel(task.taskId);
    // cancel has a bounded wait and may return while a native writer is still
    // draining. Do not clear monitoring or allow a new start on that signal.
    await scheduler.waitForTask(task.taskId);
    await Future.wait(_retiringPrefetchDiscoveries[task.taskId]?.toList() ?? <Future<void>>[]);
    if (_isClosing || !_ownsTask(task)) return;
    await _interruptedRecoveries[task.taskId]?.future;
    if (_isClosing || !_ownsTask(task)) return;
    final finalization = _finalizationFutures[task.taskId];
    if (finalization != null) await finalization;
    if (_isClosing || !_ownsTask(task)) return;
    _stopOutputMonitor(task.taskId);
    _attemptProgress.remove(task.taskId);
    _rapidRecoveryTasks.remove(task.taskId);
    if (task.pendingAttempts.isNotEmpty) {
      task.status = RecordStatus.processing;
      updateTask(task);
      final merged = await _finalizePendingAttempts(task);
      if (_isClosing || !_ownsTask(task)) return;
      await settings.refreshCacheSize();
      if (_isClosing || !_ownsTask(task)) return;
      task.status = merged ? RecordStatus.stopped : RecordStatus.failed;
      if (!merged) _markFinalizationFailure(task);
    } else {
      task.status = RecordStatus.stopped;
    }
    updateTask(task);
  }

  void _schedulePoll(LiveRecordTask task, {Duration? delay}) {
    if (!settings.enablePolling.value || !_canPoll(task)) return;
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
    late final Timer timer;
    timer = Timer(effectiveDelay, () {
      if (!identical(_pollTimers[task.taskId], timer)) return;
      _pollTimers.remove(task.taskId);
      unawaited(_pollTask(task, automatic: true));
    });
    _pollTimers[task.taskId] = timer;
  }

  bool _ownsTask(LiveRecordTask task) => tasks.any((candidate) => identical(candidate, task));

  bool _canPoll(LiveRecordTask task) =>
      !_isClosing &&
      !task.wasStoppedByUser &&
      _ownsTask(task) &&
      !_startingTasks.contains(task.taskId) &&
      !_startRequests.containsKey(task.taskId) &&
      !_stopRequests.containsKey(task.taskId) &&
      !_interruptedRecoveries.containsKey(task.taskId) &&
      !_removingTasks.contains(task) &&
      !scheduler.isRunning(task.taskId) &&
      !scheduler.isQueued(task.taskId) &&
      !_finalizationFutures.containsKey(task.taskId);

  bool _ownsPoll(_RecorderPollRequest request) =>
      identical(_pollInFlight[request.task.taskId], request) &&
      _canPoll(request.task) &&
      (!request.automatic || settings.enablePolling.value);

  Future<void> _pollTask(LiveRecordTask task, {bool automatic = false}) {
    // Validate before claiming ownership: a skipped task must not leave a
    // permanent busy flag. Explicit refreshes coalesce until this request ends.
    if (!_canPoll(task) || (automatic && !settings.enablePolling.value)) return Future<void>.value();
    final existing = _pollInFlight[task.taskId];
    if (existing != null && identical(existing.task, task)) return existing.done.future;
    existing?.complete();
    final request = _RecorderPollRequest(task: task, automatic: automatic);
    _pollInFlight[task.taskId] = request;
    unawaited(_performPoll(request));
    return request.done.future;
  }

  Future<void> _performPoll(_RecorderPollRequest request) async {
    final task = request.task;
    try {
      final site = _siteResolver(task.platform);
      final response = site is LiveSiteRoomRefresher
          ? (site as LiveSiteRoomRefresher).getRoomDetailForRefresh(roomId: task.roomId, platform: task.platform)
          : site.getRoomDetail(roomId: task.roomId, platform: task.platform);
      // This bounds controller waiting, not the adapter's underlying socket.
      // A late success/error remains isolated by request ownership.
      final room = await response.timeout(_pollTimeout);
      if (!_ownsPoll(request)) return;
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
      if (!_ownsPoll(request)) return;
      _pollFailures[task.taskId] = (_pollFailures[task.taskId] ?? 0) + 1;
      task.markFailure(stage: 'status', error: error);
      updateTask(task);
      developer.log('Recorder status poll failed: $error', name: 'RecorderController');
    } finally {
      if (identical(_pollInFlight[task.taskId], request)) {
        _pollInFlight.remove(task.taskId);
        _schedulePoll(task);
      }
      request.complete();
    }
  }

  void _stopPolling(String taskId) {
    _pollTimers.remove(taskId)?.cancel();
    _pollFailures.remove(taskId);
    _pollInFlight.remove(taskId)?.complete();
  }

  Future<void> refreshTaskStatus(LiveRecordTask task) async {
    if (!_canPoll(task)) return;
    _pollTimers.remove(task.taskId)?.cancel();
    _pollFailures.remove(task.taskId);
    await _pollTask(task);
  }

  void _onPollingChanged(bool enabled) {
    if (_isClosing) return;
    if (!enabled) {
      for (final timer in _pollTimers.values) {
        timer.cancel();
      }
      _pollTimers.clear();
      for (final request in _pollInFlight.values.where((request) => request.automatic).toList()) {
        if (identical(_pollInFlight[request.task.taskId], request)) {
          _pollInFlight.remove(request.task.taskId);
          request.complete();
        }
      }
      return;
    }
    for (final task in tasks) {
      if (task.status == RecordStatus.waitingLive) _schedulePoll(task, delay: Duration.zero);
    }
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
    if (_isClosing || !_ownsTask(task)) return;
    _removingTasks.add(task);
    try {
      await stopTask(task);
      if (_isClosing || !_ownsTask(task)) return;
      _activeSessionIds.remove(task.taskId);
      _completeLifecycle(task.taskId);
      tasks.removeWhere((candidate) => identical(candidate, task));
      schedulePersist();
    } finally {
      _removingTasks.remove(task);
    }
  }

  Future<void> _persist() async {
    try {
      await _persistTasks(jsonEncode(tasks.map((task) => task.toJson()).toList()));
    } catch (error) {
      developer.log('Persist recorder tasks failed: $error', name: 'RecorderController');
    }
  }

  Future<void> restoreAndAutoPoll() {
    if (_isClosing) return Future<void>.value();
    final existing = _restoreInFlight;
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = _restoreAndAutoPoll().whenComplete(() {
      if (identical(_restoreInFlight, operation)) _restoreInFlight = null;
    });
    _restoreInFlight = operation;
    return operation;
  }

  Future<void> _restoreAndAutoPoll() async {
    final raw = HivePrefUtil.getString(RecorderKeys.recorderTasks);
    if (raw == null || raw.trim().isEmpty) return;

    final restored = <LiveRecordTask>[];
    final interruptedTaskIds = <String>{};
    final resumeTaskIds = <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map) continue;
          try {
            final task = LiveRecordTask.fromJson(Map<String, dynamic>.from(entry));
            if (task.roomId.trim().isEmpty || !Sites.isSupported(task.platform)) continue;
            if (restored.any((candidate) => candidate.taskId == task.taskId)) continue;
            if (const <RecordStatus>{
              RecordStatus.preparing,
              RecordStatus.running,
              RecordStatus.reconnecting,
              RecordStatus.processing,
            }.contains(task.status)) {
              interruptedTaskIds.add(task.taskId);
            }
            if (!task.wasStoppedByUser &&
                const <RecordStatus>{
                  RecordStatus.queued,
                  RecordStatus.preparing,
                  RecordStatus.running,
                  RecordStatus.reconnecting,
                  RecordStatus.waitingLive,
                }.contains(task.status)) {
              resumeTaskIds.add(task.taskId);
            }
            if (!task.status.isFinished) task.status = RecordStatus.stopped;
            restored.add(task);
          } catch (error) {
            developer.log('Skipped malformed recorder task: $error', name: 'RecorderController');
          }
        }
      }
    } catch (error) {
      developer.log('Restore recorder task list failed: $error', name: 'RecorderController');
    }

    restored.sort((left, right) => left.status.order.compareTo(right.status.order));
    // Reserve every interrupted output before publishing the cards: a user
    // can start the second task while recovery of the first one is awaiting IO.
    final recovering = {
      for (final task in restored)
        if (interruptedTaskIds.contains(task.taskId) || task.pendingAttempts.isNotEmpty) task: Completer<void>(),
    };
    for (final entry in recovering.entries) {
      _interruptedRecoveries[entry.key.taskId] = entry.value;
    }
    tasks.assignAll(restored);
    schedulePersist();

    // A process kill cannot run FFmpeg's completion callback. Finish only
    // tasks that were persisted in an active lifecycle; completed/manual
    // tasks are never reprocessed merely because a TS file still exists.
    for (final entry in recovering.entries) {
      final task = entry.key;
      try {
        if (!_isClosing && _ownsTask(task)) await _recoverInterruptedRecording(task);
      } catch (error, stack) {
        developer.log('Interrupted recording recovery failed', error: error, stackTrace: stack);
        if (!_isClosing && _ownsTask(task)) {
          task.markFailure(stage: 'merge', error: error);
          task.status = RecordStatus.failed;
          updateTask(task);
        }
      } finally {
        if (identical(_interruptedRecoveries[task.taskId], entry.value)) _interruptedRecoveries.remove(task.taskId);
        entry.value.complete();
      }
    }
    if (_isClosing || !settings.autoStartOnBoot.value || resumeTaskIds.isEmpty) return;
    if (!await requestStoragePermission(requestIfMissing: false) || _isClosing || !settings.autoStartOnBoot.value) {
      return;
    }

    final candidates = restored.where((task) => resumeTaskIds.contains(task.taskId)).toList();
    var next = 0;
    Future<void> worker() async {
      while (!_isClosing && settings.autoStartOnBoot.value && next < candidates.length) {
        final task = candidates[next++];
        if (!_canPoll(task)) continue;
        task.status = RecordStatus.waitingLive;
        updateTask(task);
        await refreshTaskStatus(task);
      }
    }

    // Bound startup request fan-out. One slow platform should not delay every
    // other recorder card, while native recording concurrency stays scheduler-owned.
    await Future.wait(List.generate(math.min(3, candidates.length), (_) => worker()));
  }

  Future<void> _recoverInterruptedRecording(LiveRecordTask task) async {
    final directory = task.outputDir?.trim() ?? '';
    if (directory.isNotEmpty) {
      await _queueCurrentAttempt(task, allowLegacy: true);
    }
    if (_isClosing || !_ownsTask(task) || task.pendingAttempts.isEmpty) return;

    final directories = task.pendingAttempts.map((attempt) => attempt.directoryPath).toSet();
    final directoryOwner = CacheService.to;
    for (final path in directories) {
      directoryOwner.protectDirectory(path);
    }
    try {
      task.status = RecordStatus.processing;
      updateTask(task);
      final merged = await _finalizePendingAttempts(task, allowLegacy: true);
      if (_isClosing || !_ownsTask(task)) return;
      task.status = merged ? RecordStatus.stopped : RecordStatus.failed;
      if (!merged) _markFinalizationFailure(task);
      updateTask(task);
      await settings.refreshCacheSize();
    } finally {
      for (final path in directories) {
        directoryOwner.releaseDirectory(path);
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
    for (final request in _startRequests.values) {
      request.complete(false);
    }
    _startRequests.clear();
    _pollingWorker?.dispose();
    _pollingWorker = null;
    _danmakuTasksWorker?.dispose();
    _danmakuSettingWorker?.dispose();
    unawaited(_danmakuRecorder.dispose());
    for (final request in _pollInFlight.values) {
      request.complete();
    }
    _pollInFlight.clear();
    _pollFailures.clear();
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
    for (final entry in _leasePrefetchRequests.entries) {
      _retirePrefetchDiscovery(entry.key, entry.value.discovery);
    }
    _leasePrefetchRequests.clear();
    _prefetchedRecorderLeases.clear();
    _pendingRecorderLeases.clear();
    for (final monitor in _outputMonitors.values) {
      monitor.timer?.cancel();
    }
    _outputMonitors.clear();
    _lastOutputPersist.clear();
    _attemptProgress.clear();
    _rapidRecoveryTasks.clear();
    _resourceMonitor?.cancel();
    _persistTimer?.cancel();
    _persistTimer = null;
    final backgroundLeases = _backgroundLeases.values.toList();
    final shutdown = scheduler.clearAll();
    unawaited(() async {
      try {
        await shutdown;
        // clearAll has a bounded cancel wait, not a native completion guarantee.
        await Future.wait(backgroundLeases.map((lease) => scheduler.waitForTask(lease.task.taskId)));
        await Future.wait(_finalizationFutures.values.toList());
        await Future.wait(_retiringPrefetchDiscoveries.values.expand((pending) => pending).toList());
        for (final lease in backgroundLeases) {
          await _releaseBackgroundLease(lease);
        }
      } catch (error, stack) {
        developer.log('Recorder background shutdown failed', error: error, stackTrace: stack);
      } finally {
        _background.removeInterruptionListener(_backgroundInterruptionListener);
      }
    }());
    unawaited(_ffmpegSub.cancel());
    _activeSessionIds.clear();
    // The subscription is gone, so a later native terminal event cannot
    // release these fences. A runner still awaits ffmpeg.start before its
    // lifecycle fence: completing the fence never releases a live writer.
    // An already-dispatched finalizer must drain first, retaining its cache
    // protection and task slot until it has stopped touching the output.
    for (final entry in _lifecycleCompleters.entries.toList()) {
      final finalization = _finalizationFutures[entry.key];
      void complete() {
        if (!entry.value.isCompleted) entry.value.complete();
      }

      if (finalization == null) {
        complete();
      } else {
        unawaited(
          finalization.then<void>(
            (_) => complete(),
            onError: (Object error, StackTrace stack) {
              developer.log('Recorder shutdown finalization failed', error: error, stackTrace: stack);
              complete();
            },
          ),
        );
      }
    }
    // Shutdown must use the same tracked barrier as the final background
    // release, rather than starting an untracked write after clearing dirty.
    unawaited(_flushPersist());
    super.onClose();
  }
}

class _RecorderBackgroundTaskLease {
  _RecorderBackgroundTaskLease(this.task);
  final LiveRecordTask task;
}

class _RecorderStartRequest {
  _RecorderStartRequest(this.task);
  final LiveRecordTask task;
  final Completer<bool> done = Completer<bool>();
  void complete(bool value) {
    if (!done.isCompleted) done.complete(value);
  }
}

class _RecorderStopRequest {
  _RecorderStopRequest(this.task);
  final LiveRecordTask task;
  final Completer<void> done = Completer<void>();
}

class _RecorderPollRequest {
  _RecorderPollRequest({required this.task, required this.automatic});
  final LiveRecordTask task;
  final bool automatic;
  final Completer<void> done = Completer<void>();
  void complete() {
    if (!done.isCompleted) done.complete();
  }
}

class _RecorderOutputMonitor {
  _RecorderOutputMonitor({required this.task, required this.sessionId, required this.tracker});

  final LiveRecordTask task;
  final int sessionId;
  final RecordingOutputTracker tracker;
  Timer? timer;
  Completer<void>? sampling;
  bool finishing = false;
  final bitrate = RecordingBitrateWindow();
  DateTime? startedAt;
}

class _PrefetchedRecorderLease {
  const _PrefetchedRecorderLease({required this.sourceUrl, required this.stream});

  final String sourceUrl;
  final ResolvedRecordStream stream;
}

class _RecorderLeasePrefetch {
  final discovery = LiveQualityDiscoveryScope();
}

class _PendingRecorderLease {
  const _PendingRecorderLease({required this.sourceUrl, required this.stream});

  final String sourceUrl;
  final ResolvedRecordStream stream;
}
