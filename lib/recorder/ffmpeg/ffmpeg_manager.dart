import 'dart:async';

import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';

class FFmpegManager {
  FFmpegManager._internal();

  static final FFmpegManager _instance = FFmpegManager._internal();

  static FFmpegManager get to => _instance;

  final StreamController<FFmpegEvent> _eventController = StreamController<FFmpegEvent>.broadcast();

  Stream<FFmpegEvent> get stream => _eventController.stream;

  final FFmpegService _ffmpeg = FFmpegService.to;

  Future<void>? _initializeFuture;

  Future<void> initialize() {
    return _initializeFuture ??= _ffmpeg.initialize();
  }

  Future<void> start({required String taskId, required String command}) async {
    await initialize();

    await _ffmpeg.start(
      taskId: taskId,
      command: command,
      onEvent: (event) {
        if (!_eventController.isClosed) {
          _eventController.add(event);
        }
      },
    );
  }

  Future<void> stop(String taskId) async {
    await initialize();
    await _ffmpeg.stop(taskId);
  }

  bool isRunning(String taskId) {
    return _ffmpeg.isRunning(taskId);
  }

  FFmpegRecordSession? getSession(String taskId) {
    return _ffmpeg.getSession(taskId);
  }
}
