import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/interface/live_site.dart';
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
import 'package:pure_live/recorder/services/stream_resolver_service.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';

class RecorderController extends GetxService {
  static RecorderController get to => Get.find<RecorderController>();

  final RecordSettingsController settings = Get.find<RecordSettingsController>();
  final FFmpegManager ffmpeg = FFmpegManager.to;
  final FFmpegScheduler scheduler = FFmpegScheduler.instance;
  final RxList<LiveRecordTask> tasks = <LiveRecordTask>[].obs;

  final Map<String, Timer> _pollTimers = <String, Timer>{};
  final Map<String, int> _pollFailures = <String, int>{};
  final Set<String> _pollInFlight = <String>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final Set<String> _startingTasks = <String>{};
  final Map<String, Completer<void>> _lifecycleCompleters = <String, Completer<void>>{};
  final Map<String, int> _activeSessionIds = <String, int>{};
  final Map<String, Future<void>> _finalizationFutures = <String, Future<void>>{};

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
      case FFmpegEventType.started:
        if (sessionId == null) return;
        // FFmpegService permits only one native session for a task ID. A new
        // started event is therefore authoritative and replaces stale state
        // left by a task removed before its delayed terminal callback.
        _activeSessionIds[event.taskId] = sessionId;
        task.status = RecordStatus.running;
        task.lastUpdate = DateTime.now();
        updateTask(task);
        return;
      case FFmpegEventType.progress:
        if (!_isCurrentSession(event.taskId, sessionId)) return;
        final data = event.data;
        task.recordedSeconds = ((data['time'] as num?)?.toInt() ?? 0) ~/ 1000;
        task.fileSize = (data['size'] as num?)?.toInt() ?? 0;
        task.bitrate = (data['bitrate'] as num?)?.toDouble() ?? 0;
        task.recordSpeed = (data['speed'] as num?)?.toDouble() ?? 0;
        task.fps = (data['fps'] as num?)?.toDouble() ?? 0;
        task.lastUpdate = DateTime.now();
        if (task.recordedSeconds >= 10) task.retryCount = 0;
        updateTask(task, reorder: false);
        return;
      case FFmpegEventType.error:
      case FFmpegEventType.complete:
        if (!_isCurrentSession(event.taskId, sessionId)) return;
        _activeSessionIds.remove(event.taskId);
        final manuallyStopped = event.data['manualStop'] == true || task.wasStoppedByUser;
        final isError = event.type == FFmpegEventType.error;
        final errorCode = (event.data['code'] as num?)?.toInt() ?? 0;
        final rawLogs = event.data['raw_logs']?.toString() ?? '';
        final shouldRetry =
            !isError || RecorderContinuationPolicy.shouldRetryFailure(errorCode: errorCode, rawLogs: rawLogs);
        if (isError) {
          task.lastFailTime = DateTime.now();
          final message = event.data['message']?.toString();
          if (message?.isNotEmpty == true && (!shouldRetry || task.retryCount == 0)) {
            ToastUtil.show(message!);
          }
        }
        await _finalizeAttempt(task, manuallyStopped: manuallyStopped, failed: isError, shouldRetry: shouldRetry);
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

  Future<void> _finalizeAttempt(
    LiveRecordTask task, {
    required bool manuallyStopped,
    required bool failed,
    required bool shouldRetry,
  }) async {
    final existing = _finalizationFutures[task.taskId];
    if (existing != null) return existing;

    late final Future<void> operation;
    operation = _doFinalizeAttempt(task, manuallyStopped: manuallyStopped, failed: failed, shouldRetry: shouldRetry)
        .whenComplete(() {
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
  }) async {
    var mergeSucceeded = true;
    try {
      if (await _hasRecordedSegments(task)) {
        task.status = RecordStatus.processing;
        updateTask(task);
        mergeSucceeded = await VideoProcessorService.to.convertToMp4(task: task);
        await settings.refreshCacheSize();
      }

      final stoppedByUser = manuallyStopped || task.wasStoppedByUser;
      if (stoppedByUser) {
        task.status = RecordStatus.stopped;
        updateTask(task);
        return;
      }

      if (failed) {
        if (!shouldRetry || !task.autoReconnect) {
          task.status = RecordStatus.failed;
          task.retryCount = 0;
          updateTask(task);
          return;
        }
        _completeLifecycle(task.taskId);
        _scheduleReconnect(task);
        return;
      }

      if (!mergeSucceeded) {
        task.status = RecordStatus.failed;
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
      task.status = RecordStatus.failed;
      updateTask(task);
    } finally {
      _completeLifecycle(task.taskId);
    }
  }

  Future<bool> _hasRecordedSegments(LiveRecordTask task, {bool allowLegacy = false}) async {
    final directoryPath = task.outputDir;
    if (directoryPath == null || directoryPath.trim().isEmpty) return false;
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return false;
    final prefix = '${task.recordingFilePrefix}_';
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

  void updateTask(LiveRecordTask task, {bool reorder = true}) {
    final index = tasks.indexWhere((candidate) => candidate.taskId == task.taskId);
    if (index == -1) return;

    if (reorder) {
      final updated = [...tasks]..sort((left, right) => left.status.order.compareTo(right.status.order));
      tasks.assignAll(updated);
    } else {
      tasks[index] = task;
    }
    schedulePersist();
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

  Future<void> addTask({required LiveRoom room}) async {
    if (!await requestStoragePermission()) return;
    if (tasks.any((task) => task.roomId == room.roomId && task.platform == room.platform)) return;

    final task = LiveRecordTask.fromRoom(room);
    tasks.add(task);
    updateTask(task);
    if (room.liveStatus == LiveStatus.live) {
      await startTask(task);
    } else {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _schedulePoll(task);
    }
  }

  Future<bool> startTask(LiveRecordTask task) async {
    if (!await requestStoragePermission()) return false;
    task.retryCount = 0;
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
      developer.log('Start recorder task failed: $error', name: 'RecorderController', stackTrace: stackTrace);
      task.status = RecordStatus.failed;
      updateTask(task);
    } finally {
      _startingTasks.remove(task.taskId);
    }
  }

  Future<void> _runTask(LiveRecordTask task, TaskCancelToken token) async {
    final previousUrl = task.currentUrl;
    task.beginNewRecording();
    task.outputDir = null;
    task.status = RecordStatus.preparing;
    updateTask(task);

    final lifecycle = Completer<void>();
    _lifecycleCompleters[task.taskId] = lifecycle;
    String? protectedDirectory;
    token.onCancel = () async {
      final hadActiveSession = ffmpeg.isRunning(task.taskId) || VideoProcessorService.to.isProcessing(task.taskId);
      await Future.wait(<Future<void>>[ffmpeg.stop(task.taskId), VideoProcessorService.to.cancel(task.taskId)]);
      if (!hadActiveSession) {
        _completeLifecycle(task.taskId);
      }
    };

    try {
      if (token.isCancelled) return;
      final resolved = await StreamResolverService.to.resolveStream(
        roomId: task.roomId,
        platform: task.platform,
        preferredQuality: settings.defaultQuality.value,
        previousUrl: previousUrl,
        lineOffset: task.retryCount,
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
        ..selectedLine = resolved.lineLabel
        ..outputDir = directory.path;
      updateTask(task);

      final command = FFmpegCommandBuilder.buildRecordCommand(
        headers: headers,
        url: resolved.url,
        outputDir: directory.path,
        segmentTime: settings.segmentTime.value,
        preferBestStream: settings.preferBestStream.value,
        rwTimeout: settings.rwTimeout.value,
        threadQueueSize: settings.threadQueueSize.value,
        filePrefix: task.recordingFilePrefix,
      );
      if (token.isCancelled) return;

      await ffmpeg.start(taskId: task.taskId, command: command);
      await lifecycle.future;
    } on StreamException catch (error) {
      developer.log('Stream resolution failed: ${error.message}', name: 'RecorderController');
      if (token.isCancelled) return;
      task.lastFailTime = DateTime.now();
      if (error.type == StreamErrorType.notLive) {
        task.status = RecordStatus.waitingLive;
        updateTask(task);
        _schedulePoll(task);
      } else if (!error.retryable || !task.autoReconnect) {
        task.status = RecordStatus.failed;
        updateTask(task);
        ToastUtil.show(i18n('recorder_resolve_failed', args: {'name': task.nick, 'error': error.message}));
      } else {
        _scheduleReconnect(task);
      }
      _completeLifecycle(task.taskId);
    } catch (error, stackTrace) {
      developer.log('Recorder task failed: $error', name: 'RecorderController', stackTrace: stackTrace);
      if (!token.isCancelled) {
        task.lastFailTime = DateTime.now();
        if (task.autoReconnect) {
          _scheduleReconnect(task);
        } else {
          task.status = RecordStatus.failed;
          updateTask(task);
        }
      }
      _completeLifecycle(task.taskId);
    } finally {
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

  void _completeLifecycle(String taskId) {
    final lifecycle = _lifecycleCompleters[taskId];
    if (lifecycle != null && !lifecycle.isCompleted) lifecycle.complete();
  }

  void _scheduleReconnect(LiveRecordTask task) {
    if (task.wasStoppedByUser || !_containsTask(task.taskId)) return;
    task.retryCount++;
    if (task.retryCount >= settings.maxRetryCount.value.clamp(1, 100)) {
      task.status = RecordStatus.waitingLive;
      updateTask(task);
      _schedulePoll(task);
      return;
    }

    task.status = RecordStatus.reconnecting;
    updateTask(task);
    _retryTimers.remove(task.taskId)?.cancel();
    final delay = RecorderContinuationPolicy.pollingDelay(
      failureCount: task.retryCount - 1,
      baseSeconds: settings.retryDelay.value,
      maximumSeconds: settings.maxCheckInterval.value,
      enableBackoff: settings.enableBackoff.value,
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
    await scheduler.cancel(task.taskId);
    task.status = RecordStatus.stopped;
    updateTask(task);
  }

  void _schedulePoll(LiveRecordTask task, {Duration? delay}) {
    if (!settings.enablePolling.value || task.wasStoppedByUser || !_containsTask(task.taskId)) return;
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
    if (!_pollInFlight.add(task.taskId) || task.wasStoppedByUser || !_containsTask(task.taskId)) return;
    try {
      final site = Sites.of(task.platform).liveSite;
      final room = site is LiveSiteRoomRefresher
          ? await (site as LiveSiteRoomRefresher).getRoomDetailForRefresh(roomId: task.roomId, platform: task.platform)
          : await site.getRoomDetail(roomId: task.roomId, platform: task.platform);
      task.updateFromRoom(room);
      updateTask(task);
      if (room.liveStatus == LiveStatus.live || room.isRecord == true) {
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
    task.wasStoppedByUser = true;
    _stopPolling(task.taskId);
    _retryTimers.remove(task.taskId)?.cancel();
    await scheduler.cancel(task.taskId);
    _activeSessionIds.remove(task.taskId);
    _completeLifecycle(task.taskId);
    tasks.removeWhere((candidate) => candidate.taskId == task.taskId);
    schedulePersist();
  }

  Future<void> _persist() async {
    try {
      await HivePrefUtil.setString(RecorderKeys.recorderTasks, jsonEncode(tasks.map((task) => task.toJson()).toList()));
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
    for (final task in restored.where((candidate) => interruptedTaskIds.contains(candidate.taskId))) {
      await _recoverInterruptedRecording(task);
    }
    if (!settings.autoStartOnBoot.value || restored.isEmpty || !await requestStoragePermission()) return;

    for (final task in restored) {
      await refreshTaskStatus(task);
    }
  }

  Future<void> _recoverInterruptedRecording(LiveRecordTask task) async {
    final directory = task.outputDir?.trim() ?? '';
    if (directory.isEmpty || !await _hasRecordedSegments(task, allowLegacy: true)) return;

    CacheService.to.protectDirectory(directory);
    try {
      task.status = RecordStatus.processing;
      updateTask(task);
      final merged = await VideoProcessorService.to.convertToMp4(task: task, allowLegacySegments: true);
      task.status = merged ? RecordStatus.stopped : RecordStatus.failed;
      updateTask(task);
      await settings.refreshCacheSize();
    } finally {
      CacheService.to.releaseDirectory(directory);
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
