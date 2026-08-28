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
    final inFlight = _initializeFuture;
    if (inFlight != null) return inFlight;

    late final Future<void> initialization;
    initialization = _ffmpeg.initialize().catchError((Object error, StackTrace stackTrace) {
      // A transient native-library or filesystem failure must not poison the
      // singleton for the remainder of the process. A later recording action
      // gets one fresh attempt while concurrent callers still share this one.
      if (identical(_initializeFuture, initialization)) {
        _initializeFuture = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _initializeFuture = initialization;
    return initialization;
  }

  Future<void> start({required String taskId, required List<String> arguments, bool liveRecording = false}) async {
    await initialize();

    await _ffmpeg.start(
      taskId: taskId,
      arguments: arguments,
      liveRecording: liveRecording,
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
