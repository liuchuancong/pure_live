import 'dart:async';
import 'dart:developer';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart' hide Log;
import 'package:flutter/services.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';

enum FFmpegFailureKind { outputPath, command, httpAccess, transport, inputOpen, inputFormat, decoder, native }

class FFmpegFailureDiagnosis {
  const FFmpegFailureDiagnosis({required this.kind, required this.retryable});

  final FFmpegFailureKind kind;
  final bool retryable;
}

class FFmpegFailureClassifier {
  const FFmpegFailureClassifier._();

  static FFmpegFailureDiagnosis classify({required int code, required String logs}) {
    final value = logs.toLowerCase();
    if (_containsAny(value, const <String>[
      'error opening output',
      'unable to open output',
      'could not open output',
      'failed to open segment',
      'error writing trailer',
      'av_interleaved_write_frame',
      'no space left on device',
      'read-only file system',
      'permission denied',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.outputPath, retryable: false);
    }
    if (_containsAny(value, const <String>[
      'invalid argument',
      'option not found',
      'unrecognized option',
      'unknown protocol',
      'protocol not found',
      'muxer not found',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.command, retryable: false);
    }
    if (_containsAny(value, const <String>[
      'server returned 401',
      'server returned 403',
      'server returned 404',
      'http error 401',
      'http error 403',
      'http error 404',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.httpAccess, retryable: true);
    }
    if (_containsAny(value, const <String>[
      'connection timed out',
      'timed out',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'host is unreachable',
      'failed to resolve',
      'name or service not known',
      'tls handshake',
      'ssl handshake',
      'certificate verify failed',
      'input/output error',
      'i/o error',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.transport, retryable: true);
    }
    if (_containsAny(value, const <String>[
      'error opening input',
      'unable to open input',
      'failed to open input',
      'could not open input',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.inputOpen, retryable: true);
    }
    if (_containsAny(value, const <String>[
      'invalid data found when processing input',
      'could not find codec parameters',
      'no streams found',
      'moov atom not found',
    ])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.inputFormat, retryable: true);
    }
    if (_containsAny(value, const <String>['decoder', 'decode', 'codec', 'invalid nal'])) {
      return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.decoder, retryable: true);
    }
    return const FFmpegFailureDiagnosis(kind: FFmpegFailureKind.native, retryable: true);
  }

  static bool _containsAny(String value, List<String> markers) => markers.any(value.contains);
}

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
        final diagnosis = FFmpegFailureClassifier.classify(code: code, logs: diagnosticLogs);
        final errorData = <String, dynamic>{
          'sessionId': session.sessionId,
          'code': code,
          'manualStop': manuallyStopped,
          if (!isNormalExit) 'raw_logs': diagnosticLogs,
          if (!isNormalExit) 'failure_kind': diagnosis.kind.name,
          if (!isNormalExit) 'retryable': diagnosis.retryable,
        };
        if (!isNormalExit) {
          errorData['message'] = _friendlyError(code, diagnosticLogs, diagnosis);
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
        final diagnosticLogs = _sanitizeLogs(error.toString()).toLowerCase();
        final diagnosis = FFmpegFailureClassifier.classify(code: -1, logs: diagnosticLogs);
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
              'raw_logs': diagnosticLogs,
              'failure_kind': diagnosis.kind.name,
              'retryable': diagnosis.retryable,
              'message': _friendlyError(-1, diagnosticLogs, diagnosis),
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

  static String _friendlyError(int code, String logs, FFmpegFailureDiagnosis diagnosis) {
    switch (diagnosis.kind) {
      case FFmpegFailureKind.outputPath:
        return i18n('path_or_permission_error');
      case FFmpegFailureKind.command:
        return i18n('param_error');
      case FFmpegFailureKind.httpAccess:
        if (logs.contains('404')) return i18n('url_expired_404');
        if (logs.contains('403')) return i18n('url_forbidden_403');
        return i18n('recorder_input_open_failed');
      case FFmpegFailureKind.transport:
        if (logs.contains('timed out')) return i18n('timeout');
        return i18n('recorder_transport_failed');
      case FFmpegFailureKind.inputOpen:
        return i18n('recorder_input_open_failed');
      case FFmpegFailureKind.inputFormat:
        return i18n('recorder_input_format_failed');
      case FFmpegFailureKind.decoder:
        return i18n('recorder_decoder_failed');
      case FFmpegFailureKind.native:
        break;
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
