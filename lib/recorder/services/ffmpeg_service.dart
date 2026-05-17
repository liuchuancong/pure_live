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
          // 根据纯文本中的关键字，为用户转换出看得懂的大白话提示
          if (code == -2 || lowerLogs.contains('no such file') || lowerLogs.contains('permission denied')) {
            userFriendlyMessage = '录制失败：保存路径不存在、包含非法字符，或软件没有存储权限。请前往设置修改下载目录。';
          } else if (lowerLogs.contains('server returned 404') || lowerLogs.contains('invalid argument')) {
            userFriendlyMessage = '参数错误,请联系开发者解决';
          } else if (lowerLogs.contains('server returned 404') || lowerLogs.contains('http error 404')) {
            userFriendlyMessage = '录制失败：当前直播源地址已失效 (404 Not Found)。';
          } else if (lowerLogs.contains('server returned 403') || lowerLogs.contains('http error 403')) {
            userFriendlyMessage = '录制失败：直播源拒绝访问 (403 Forbidden)，防盗链可能已过期。';
          } else if (lowerLogs.contains('connection timed out') || lowerLogs.contains('timed out')) {
            userFriendlyMessage = '录制失败：连接直播间服务器超时，请检查网络或代理设置。';
          } else if (lowerLogs.contains('invalid argument') || lowerLogs.contains('unable to open')) {
            userFriendlyMessage = '录制失败：输入的直播流地址格式有误，无法打开。';
          } else if (logs.trim().isNotEmpty) {
            userFriendlyMessage = '录制错误: ${logs.trim().split('\n').last}';
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
