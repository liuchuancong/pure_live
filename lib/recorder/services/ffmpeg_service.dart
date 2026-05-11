import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class FFmpegRecordSession {
  final String taskId;
  int? sessionId;

  int recordedSeconds = 0;
  int fileSize = 0;
  double bitrate = 0;
  double speed = 0;
  double fps = 0;
  int lastFrame = 0;

  DateTime lastUpdate = DateTime.now();

  bool manualStop = false;
  bool hasError = false;

  FFmpegRecordSession({required this.taskId});
}

class FFmpegService extends GetxService {
  static FFmpegService get to => Get.find();
  final RecordSettingsController settings = Get.find<RecordSettingsController>();
  final Map<String, FFmpegRecordSession> _sessions = {};

  /// 开始录制
  Future<void> startRecord({
    required String taskId,
    required String url,
    required String outputDir,
    Map<String, String>? headers,
    int segmentTime = 300,
    Function(FFmpegRecordSession stats)? onProgress,
    VoidCallback? onComplete,
    Function(String error)? onError,
  }) async {
    // 启动前先尝试停止旧的
    await stopRecord(taskId);

    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final record = FFmpegRecordSession(taskId: taskId);
    _sessions[taskId] = record;

    Timer? watchdog;

    watchdog = Timer.periodic(const Duration(seconds: 20), (_) {
      final diff = DateTime.now().difference(record.lastUpdate);
      if (diff.inSeconds > 40 && !record.hasError && !record.manualStop) {
        record.hasError = true;
        onError?.call("录制流超时");
      }
    });

    final userAgent =
        headers?['user-agent'] ??
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

    final headerLines = <String>[];
    headers?.forEach((key, value) {
      if (key.toLowerCase() != 'user-agent') {
        headerLines.add("$key: $value");
      }
    });
    final headerStr = headerLines.isNotEmpty ? "${headerLines.join('\r\n')}\r\n" : "";

    final List<String> args = [
      '-y',
      '-hide_banner',
      '-loglevel', 'info',
      '-protocol_whitelist', 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto',
      // --- Enhanced Reconnect Logic ---
      '-reconnect', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '2',
      // Set a socket timeout (15 seconds) to prevent hanging
      '-rw_timeout', '${settings.rwTimeout.value * 1000000}',

      // Add an input buffer to handle network jitter
      '-max_delay', '5000000',
      '-thread_queue_size', '${settings.threadQueueSize.value}',

      '-user_agent', userAgent, // 直接传变量，不要加引号
      if (headerStr.isNotEmpty) ...['-headers', "'$headerStr'"], // 直接传变量
      // --- 2. 输入 ---
      '-i', url,
      // --- 3. 输出配置 ---
      '-map', settings.preferBestStream.value ? '0:v:0' : '0:v',
      '-map', settings.preferBestStream.value ? '0:a:0' : '0:a',
      '-c', 'copy',

      // --- Segment Logic ---
      '-f', 'segment',
      '-segment_time', segmentTime.toString(),
      '-reset_timestamps', '1',
      '-strftime', '1',

      // Use .ts for recording (much safer against EOF errors)
      '$outputDir${Platform.pathSeparator}%Y%m%d_%H%M%S.ts',
    ];

    final command = args.join(' ');
    FFmpegKit.executeAsync(
      command,
      onLog: (Log log) {
        record.sessionId ??= log.sessionId;
      },
      onStatistics: (Statistics s) {
        record.recordedSeconds = s.time ~/ 1000;
        record.fileSize = s.size;
        record.bitrate = s.bitrate;
        record.speed = s.speed;
        record.fps = s.videoFps;
        record.lastFrame = s.videoFrameNumber;
        record.lastUpdate = DateTime.now();
        record.sessionId = s.sessionId;
        onProgress?.call(record);
      },
      onComplete: (session) async {
        record.sessionId = session.sessionId;
        watchdog?.cancel();
        try {
          final code = session.getReturnCode();
          if (record.manualStop) {
            onComplete?.call();
            return;
          }
          if (ReturnCode.isSuccess(code)) {
            onComplete?.call();
          } else {
            onError?.call("FFmpeg退出码: $code");
          }
        } finally {
          _sessions.remove(taskId);
        }
      },
    );
  }

  /// 停止录制
  Future<void> stopRecord(String taskId) async {
    final record = _sessions[taskId];
    if (record == null) return;
    record.manualStop = true;
    final sessionId = record.sessionId;
    if (sessionId != null) {
      final sessions = FFmpegKit.getFFmpegSessions();
      for (final s in sessions) {
        if (s.getSessionId() == sessionId) {
          log('stopRecord before $taskId');
          FFmpegKit.cancel(s);
          log('stopRecord $taskId');
          break;
        }
      }
    }
  }

  FFmpegRecordSession? getSession(String taskId) => _sessions[taskId];

  bool isRecording(String taskId) => _sessions.containsKey(taskId);
}
