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
  FFmpegSession? session;
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
    onEvent(FFmpegEvent(taskId: taskId, type: FFmpegEventType.started));

    final ffempgSession = FFmpegKit.createSession(command);

    final session = FFmpegRecordSession(taskId: taskId);
    _sessions[taskId] = session;
    session.session = ffempgSession;
    session.sessionId = ffempgSession.getSessionId();
    ffempgSession.setStatisticsCallback((s) {
      session
        ..recordedSeconds = s.time ~/ 1000
        ..fileSize = s.size
        ..bitrate = s.bitrate
        ..speed = s.speed
        ..fps = s.videoFps
        ..lastUpdate = DateTime.now();

      onEvent(
        FFmpegEvent(
          taskId: taskId,
          type: FFmpegEventType.progress,
          data: {"time": s.time, "size": s.size, "bitrate": s.bitrate, "speed": s.speed, "fps": s.videoFps},
        ),
      );
    });
    ffempgSession.setCompleteCallback((completedSession) {
      final code = completedSession.getReturnCode();
      final success = ReturnCode.isSuccess(code);
      log('FFmpeg complete => taskId: $taskId;successCode: $code ');
      onEvent(
        FFmpegEvent(
          taskId: taskId,
          type: success ? FFmpegEventType.complete : FFmpegEventType.error,
          data: {"code": code},
        ),
      );
      _sessions.remove(taskId);
    });
    await ffempgSession.executeAsync();
  }

  Future<void> stop(String taskId) async {
    final session = _sessions[taskId];
    if (session == null) return;
    session.manualStop = true;
    final ffempgSession = session.session;
    if (ffempgSession == null) {
      return;
    }
    log('FFmpeg stop => $taskId');
    FFmpegKit.cancel(ffempgSession);
  }

  FFmpegRecordSession? getSession(String taskId) => _sessions[taskId];
  bool isRunning(String taskId) => _sessions.containsKey(taskId);
}
