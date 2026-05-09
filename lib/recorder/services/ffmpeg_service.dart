import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

/// FFmpeg 录制会话状态
class FFmpegRecordSession {
  final String taskId;
  FFmpegSession? session;

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

    // Watchdog 防卡死逻辑
    watchdog = Timer.periodic(const Duration(seconds: 20), (_) {
      final diff = DateTime.now().difference(record.lastUpdate);
      if (diff.inSeconds > 40 && !record.hasError && !record.manualStop) {
        record.hasError = true;
        onError?.call("录制流超时");
      }
    });

    // 处理 Headers
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
      '-hide_banner',
      '-loglevel', 'info',

      // --- Enhanced Reconnect Logic ---
      '-reconnect', '1',
      '-reconnect_at_eof', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '5', // Max wait 5 seconds before giving up
      // Set a socket timeout (15 seconds) to prevent hanging
      '-rw_timeout', '15000000',

      // Add an input buffer to handle network jitter
      '-max_delay', '5000000',
      '-thread_queue_size', '1024',

      '-user_agent', '"$userAgent"',
      if (headerStr.isNotEmpty) ...['-headers', '"$headerStr"'],

      '-i', '"$url"',

      '-map', '0:v',
      '-map', '0:a',
      '-c', 'copy',

      // --- Segment Logic ---
      '-f', 'segment',
      '-segment_time', segmentTime.toString(),
      '-reset_timestamps', '1',
      '-strftime', '1',

      // Use .ts for recording (much safer against EOF errors)
      '"$outputDir/%Y%m%d_%H%M%S.ts"',
    ];

    final command = args.join(' ');
    final session = FFmpegKit.createSession(command);
    record.session = session;
    await session.executeAsync(
      logCallback: (Log log) {
        if (record.hasError || record.manualStop) return;
        final msg = log.message.toLowerCase();
        // 常见的断流或失败关键字
        if (msg.contains("failed") || msg.contains("error") || msg.contains("403") || msg.contains("404")) {
          // 这里可以视情况是否触发 onError
        }
      },
      statisticsCallback: (Statistics s) {
        record.recordedSeconds = s.time ~/ 1000;
        record.fileSize = s.size;
        record.bitrate = s.bitrate;
        record.speed = s.speed;
        record.fps = s.videoFps;
        record.lastFrame = s.videoFrameNumber;
        record.lastUpdate = DateTime.now();
        onProgress?.call(record);
      },
      completeCallback: (session) async {
        watchdog?.cancel();
        _sessions.remove(taskId);

        // 如果是手动停止，拦截所有后续逻辑
        if (record.manualStop) {
          onComplete?.call();
          return;
        }

        final code = session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          onComplete?.call();
        } else {
          if (!record.hasError) {
            onError?.call("FFmpeg退出码: $code");
          }
        }
      },
    );
  }

  /// 停止录制
  Future<void> stopRecord(String taskId) async {
    final record = _sessions[taskId];
    if (record == null) return;
    record.manualStop = true;
    try {
      final session = record.session;
      if (session != null) {
        FFmpegKit.cancel(session);
      }
      await Future.delayed(const Duration(seconds: 1));
    } catch (_) {}
    _sessions.remove(taskId);
  }

  /// 获取 Session 状态
  FFmpegRecordSession? getSession(String taskId) => _sessions[taskId];

  /// 是否录制中
  bool isRecording(String taskId) => _sessions.containsKey(taskId);
}
