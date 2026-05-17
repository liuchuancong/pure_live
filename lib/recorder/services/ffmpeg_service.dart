import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:pure_live/plugins/locale_helper.dart';
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
    ffempgSession.setCompleteCallback((completedSession) async {
      final code = completedSession.getReturnCode();
      bool isNormalExit = [
        0, // 正常结束（直播间下播）
        255, // 用户手动点击停止
        -1094995529, // 断流/无数据
        -1077350400, // 超时/网络断开
        -1005272104, // 读取中断
      ].contains(code);

      log('FFmpeg complete => taskId: $taskId; code: $code');

      String userFriendlyMessage = '录制遇到未知错误 (代码: $code)';
      Map<String, dynamic> errorData = {"code": code};
      if (!isNormalExit) {
        try {
          final String logs = completedSession.getLogs() ?? '';
          log('FFmpeg 原始错误日志:\n$logs');
          final lowerLogs = logs.toLowerCase();
          errorData["raw_logs"] = lowerLogs;
          // 1. 路径与权限错误
          if (code == -2 || lowerLogs.contains('no such file') || lowerLogs.contains('permission denied')) {
            userFriendlyMessage = i18n('path_or_permission_error');
          }
          // 2. 拦截 404 错误（原逻辑在此处有重复条件，现已优化合并）
          else if (lowerLogs.contains('server returned 404') || lowerLogs.contains('http error 404')) {
            userFriendlyMessage = i18n('url_expired_404');
          }
          // 3. 拦截 403 错误
          else if (lowerLogs.contains('server returned 403') || lowerLogs.contains('http error 403')) {
            userFriendlyMessage = i18n('url_forbidden_403');
          }
          // 4. 拦截连接超时
          else if (lowerLogs.contains('connection timed out') || lowerLogs.contains('timed out')) {
            userFriendlyMessage = i18n('timeout');
          }
          // 5. 拦截参数错误
          else if (lowerLogs.contains('invalid argument')) {
            userFriendlyMessage = i18n('param_error');
          }
          // 6. 拦截流地址格式无法打开
          else if (lowerLogs.contains('unable to open')) {
            userFriendlyMessage = i18n('invalid_stream_format');
          }
          // 7. 兜底未知错误：提取最后一行并使用具名参数传给国际化
          else if (logs.trim().isNotEmpty) {
            final lastLogLine = logs.trim().split('\n').last;
            userFriendlyMessage = i18n('unknown_error', args: {'error_log': lastLogLine});
          }
        } catch (e) {
          log('解析 FFmpeg 日志时发生异常: $e');
        }

        // 传递给 UI 层调用
        errorData["message"] = userFriendlyMessage;
      }

      onEvent(
        FFmpegEvent(
          taskId: taskId,
          type: isNormalExit ? FFmpegEventType.complete : FFmpegEventType.error,
          data: errorData,
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
