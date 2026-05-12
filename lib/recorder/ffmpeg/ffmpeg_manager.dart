import 'dart:async';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';

class FFmpegManager {
  FFmpegManager._internal();
  static final FFmpegManager _instance = FFmpegManager._internal();
  static FFmpegManager get to => _instance;

  // 事件流（页面/控制器监听）
  final StreamController<FFmpegEvent> _eventController = StreamController.broadcast();
  Stream<FFmpegEvent> get stream => _eventController.stream;

  final FFmpegService _ffmpeg = FFmpegService.to;

  /// 启动录制
  Future<void> start({required String taskId, required String command}) async {
    await _ffmpeg.start(
      taskId: taskId,
      command: command,
      onEvent: (event) {
        _eventController.add(event);
      },
    );
  }

  /// 停止录制
  Future<void> stop(String taskId) async {
    await _ffmpeg.stop(taskId);
  }

  /// 是否正在运行
  bool isRunning(String taskId) {
    return _ffmpeg.isRunning(taskId);
  }

  /// 获取会话信息
  FFmpegRecordSession? getSession(String taskId) {
    return _ffmpeg.getSession(taskId);
  }
}
