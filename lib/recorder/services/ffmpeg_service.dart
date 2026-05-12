import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class FFmpegRecordSession {
  final String taskId;
  int? sessionId;
  bool manualStop = false;
  int recordedSeconds = 0;
  int fileSize = 0;
  double bitrate = 0;
  double speed = 0;
  double fps = 0;
  DateTime lastUpdate = DateTime.now();

  FFmpegRecordSession({required this.taskId});
}

class FFmpegService {
  FFmpegService._internal();
  static final FFmpegService _instance = FFmpegService._internal();
  static FFmpegService get to => _instance;

  final Map<String, FFmpegRecordSession> _sessions = {};

  static void initInIsolate(RootIsolateToken token) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }

  Future<void> start({
    required String taskId,
    required String command,
    required void Function(FFmpegEvent event) onEvent,
  }) async {
    final session = FFmpegRecordSession(taskId: taskId);
    _sessions[taskId] = session;

    onEvent(FFmpegEvent(taskId: taskId, type: FFmpegEventType.started));

    FFmpegKit.executeAsync(
      command,
      onComplete: (s) {
        session.sessionId = s.sessionId;
        final code = s.getReturnCode();
        final success = ReturnCode.isSuccess(code);
        onEvent(
          FFmpegEvent(
            taskId: taskId,
            type: success ? FFmpegEventType.complete : FFmpegEventType.error,
            data: {"code": code},
          ),
        );
        _sessions.remove(taskId);
      },
      onLog: (log) {
        session.sessionId = log.sessionId;
      },
      onStatistics: (s) {
        session
          ..recordedSeconds = s.time ~/ 1000
          ..fileSize = s.size
          ..bitrate = s.bitrate
          ..speed = s.speed
          ..fps = s.videoFps
          ..lastUpdate = DateTime.now()
          ..sessionId = s.sessionId;

        onEvent(
          FFmpegEvent(
            taskId: taskId,
            type: FFmpegEventType.progress,
            data: {"time": s.time, "size": s.size, "bitrate": s.bitrate, "speed": s.speed, "fps": s.videoFps},
          ),
        );
      },
    );
  }

  Future<void> stop(String taskId) async {
    final session = _sessions[taskId];
    if (session == null) return;
    session.manualStop = true;
    final sessionId = session.sessionId;
    if (sessionId == null) return;
    final sessions = FFmpegKit.getFFmpegSessions();
    for (final s in sessions) {
      if (s.getSessionId() == sessionId) {
        log('FFmpeg stop => $taskId');
        FFmpegKit.cancel(s);
        break;
      }
    }
  }

  FFmpegRecordSession? getSession(String taskId) => _sessions[taskId];
  bool isRunning(String taskId) => _sessions.containsKey(taskId);
}
