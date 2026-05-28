import 'dart:io';
import 'dart:developer';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';

class AudioStreamLoader {
  String? _currentTaskId;
  String? _currentAudioUrl;

  Future<int> _getAvailablePort() async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      return port;
    } catch (e) {
      log('AudioStreamLoader: 获取空闲端口失败，使用保底端口: $e');
      return 8080;
    }
  }

  void startAudioStream({
    required String remoteStreamUrl,
    required String uniqueId,
    required Function(String audioUrl) onAudioReady,
    Function(FFmpegEvent event)? onFFmpegEvent,
    required String platform, // 用于构建FFmpeg请求头
  }) async {
    if (_currentTaskId != null) {
      stop();
    }

    _currentTaskId = "audio_only_$uniqueId";

    int port = await _getAvailablePort();
    _currentAudioUrl = "http://localhost:$port/live.ts";

    log('AudioStreamLoader: 分配空闲端口 -> $port, URL -> $_currentAudioUrl');

    final headers = await FFmpegHeaderFactory.build(platform: platform);

    final cmd = FFmpegCommandBuilder.buildAudioStreamCommand(
      headers: headers,
      remoteStreamUrl: remoteStreamUrl,
      port: port,
    );
    await FFmpegService.to.start(
      taskId: _currentTaskId!,
      command: cmd,
      onEvent: (event) {
        if (onFFmpegEvent != null) {
          onFFmpegEvent(event);
        }
        if (event.type == FFmpegEventType.started) {
          log('AudioStreamLoader: FFmpeg 本地服务器已在端口 $port 启动监听');
          if (_currentAudioUrl != null) {
            onAudioReady(_currentAudioUrl!);
          }
        }
      },
    );
  }

  void stop() {
    if (_currentTaskId == null) return;

    log('AudioStreamLoader: 正在停止任务 -> $_currentTaskId');

    FFmpegService.to.stop(_currentTaskId!);

    _currentTaskId = null;
    _currentAudioUrl = null;
  }

  String? get currentTaskId => _currentTaskId;
  String? get currentAudioUrl => _currentAudioUrl;
}
