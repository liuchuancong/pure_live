import 'dart:async';
import 'dart:developer';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart' hide Log;
import 'package:flutter/services.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';

class FFmpegRecordSession {
  FFmpegRecordSession({required this.taskId, required this.sessionId, required this.session});

  final String taskId;
  final int sessionId;
  final FFmpegSession session;
  final Completer<void> completion = Completer<void>();

  bool manualStop = false;
  int recordedSeconds = 0;
  int fileSize = 0;
  double bitrate = 0;
  double speed = 0;
  double fps = 0;
  DateTime lastUpdate = DateTime.now();
}

class FFmpegService {
  FFmpegService._internal();

  static final FFmpegService _instance = FFmpegService._internal();
  static FFmpegService get to => _instance;

  final Map<String, FFmpegRecordSession> _sessions = {};
  Future<void>? _initializing;
  bool _initialized = false;

  static void initInIsolate(RootIsolateToken token) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }

  Future<void> initialize() async {
    await _ensureInitialized();
  }

  Future<void> start({
    required String taskId,
    required List<String> arguments,
    required void Function(FFmpegEvent event) onEvent,
  }) async {
    await _ensureInitialized();
    if (_sessions.containsKey(taskId)) {
      throw StateError('FFmpeg task is already active: $taskId');
    }

    if (arguments.isEmpty) throw ArgumentError.value(arguments, 'arguments', 'FFmpeg arguments must not be empty');
    // Pass the exact argument vector to FFI. Re-parsing a shell-like command
    // string was platform-dependent and could corrupt signed URLs, header CRLF
    // blocks or Android storage paths before FFmpeg saw them.
    final nativeSession = FFmpegKit.createSessionFromArguments(List<String>.of(arguments));
    final session = FFmpegRecordSession(
      taskId: taskId,
      sessionId: nativeSession.getSessionId(),
      session: nativeSession,
    );
    _sessions[taskId] = session;

    nativeSession.setStatisticsCallback((statistics) {
      if (!identical(_sessions[taskId], session)) return;
      session
        ..recordedSeconds = statistics.time ~/ 1000
        ..fileSize = statistics.size
        ..bitrate = statistics.bitrate
        ..speed = statistics.speed
        ..fps = statistics.videoFps
        ..lastUpdate = DateTime.now();

      _safeEmit(
        onEvent,
        FFmpegEvent(
          taskId: taskId,
          type: FFmpegEventType.progress,
          data: {
            'sessionId': session.sessionId,
            'time': statistics.time,
            'size': statistics.size,
            'bitrate': statistics.bitrate,
            'speed': statistics.speed,
            'fps': statistics.videoFps,
          },
        ),
      );
    });

    nativeSession.setCompleteCallback((completedSession) {
      try {
        final code = completedSession.getReturnCode();
        final manuallyStopped = session.manualStop;
        final isNormalExit = manuallyStopped || code == 0 || code == -541478725;
        Log.i('FFmpeg complete => taskId: $taskId; sessionId: ${session.sessionId}; code: $code');

        final rawLogs = completedSession.getLogs() ?? '';
        final diagnosticLogs = _sanitizeLogs(rawLogs).toLowerCase();
        final errorData = <String, dynamic>{
          'sessionId': session.sessionId,
          'code': code,
          'manualStop': manuallyStopped,
          if (!isNormalExit) 'raw_logs': diagnosticLogs,
        };
        if (!isNormalExit) {
          errorData['message'] = _friendlyError(code, diagnosticLogs);
        }

        _safeEmit(
          onEvent,
          FFmpegEvent(
            taskId: taskId,
            type: isNormalExit ? FFmpegEventType.complete : FFmpegEventType.error,
            data: errorData,
          ),
        );
      } finally {
        if (identical(_sessions[taskId], session)) _sessions.remove(taskId);
        if (!session.completion.isCompleted) session.completion.complete();
      }
    });

    _safeEmit(
      onEvent,
      FFmpegEvent(taskId: taskId, type: FFmpegEventType.started, data: {'sessionId': session.sessionId}),
    );

    try {
      await nativeSession.executeAsync();
    } catch (error, stackTrace) {
      Log.e('FFmpeg execution failed before native completion: $error', stackTrace);
      if (identical(_sessions[taskId], session)) {
        _sessions.remove(taskId);
        _safeEmit(
          onEvent,
          FFmpegEvent(
            taskId: taskId,
            type: FFmpegEventType.error,
            data: {
              'sessionId': session.sessionId,
              'code': -1,
              'manualStop': session.manualStop,
              'raw_logs': _sanitizeLogs(error.toString()).toLowerCase(),
              'message': i18n('unknown_error', args: {'error_log': _sanitizeLogs(error.toString())}),
            },
          ),
        );
      }
    } finally {
      if (identical(_sessions[taskId], session)) _sessions.remove(taskId);
      if (!session.completion.isCompleted) session.completion.complete();
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;

    final future = FFmpegKitExtended.initialize();
    _initializing = future;
    try {
      await future;
      _initialized = true;
    } finally {
      if (identical(_initializing, future)) _initializing = null;
    }
  }

  Future<void> stop(String taskId) async {
    final session = _sessions[taskId];
    if (session == null) return;
    session.manualStop = true;
    log('FFmpeg stop => $taskId (${session.sessionId})');
    FFmpegKit.cancel(session.session);
    try {
      await session.completion.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      Log.w('FFmpeg stop timeout => taskId: $taskId; sessionId: ${session.sessionId}');
    }
  }

  FFmpegRecordSession? getSession(String taskId) => _sessions[taskId];
  bool isRunning(String taskId) => _sessions.containsKey(taskId);

  static void _safeEmit(void Function(FFmpegEvent event) onEvent, FFmpegEvent event) {
    try {
      onEvent(event);
    } catch (error, stackTrace) {
      Log.e('FFmpeg event listener failed: $error', stackTrace);
    }
  }

  static String _friendlyError(int code, String logs) {
    if (code == -2 || logs.contains('no such file') || logs.contains('permission denied')) {
      return i18n('path_or_permission_error');
    }
    if (logs.contains('server returned 404') || logs.contains('http error 404')) {
      return i18n('url_expired_404');
    }
    if (logs.contains('server returned 403') || logs.contains('http error 403')) {
      return i18n('url_forbidden_403');
    }
    if (logs.contains('connection timed out') || logs.contains('timed out')) {
      return i18n('timeout');
    }
    if (logs.contains('invalid argument') || logs.contains('option not found')) {
      return i18n('param_error');
    }
    if (logs.contains('unable to open') || logs.contains('error opening input')) {
      return i18n('invalid_stream_format');
    }
    final lines = logs.trim().split('\n');
    final lastLine = lines.isEmpty ? '' : lines.last.trim();
    return i18n('unknown_error', args: {'error_log': lastLine.isEmpty ? 'code $code' : lastLine});
  }

  static String _sanitizeLogs(String logs) {
    return logs
        .replaceAll(RegExp(r'(?:https?|rtmps?|rtsp|srt|udp|rtp)://[^\s]+', caseSensitive: false), '[stream-url]')
        .replaceAllMapped(
          RegExp(r'^(cookie|authorization):.*$', caseSensitive: false, multiLine: true),
          (match) => '${match.group(1)}: [redacted]',
        )
        .replaceAllMapped(
          RegExp(r'((?:access_)?token|sign|auth|key|wssecret|txsecret)=([^&\s]+)', caseSensitive: false),
          (match) => '${match.group(1)}=[redacted]',
        );
  }
}
