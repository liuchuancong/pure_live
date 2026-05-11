import 'dart:async';
import 'dart:isolate';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class FFmpegTaskExecutor {
  final String taskId;
  Isolate? _isolate;
  SendPort? _sendPort;

  final _eventController = StreamController<FFmpegEvent>.broadcast();
  Stream<FFmpegEvent> get stream => _eventController.stream;

  FFmpegTaskExecutor({required this.taskId});

  /// 启动并运行任务
  Future<void> run(String command) async {
    if (_isolate != null) await forceKill();

    final receivePort = ReceivePort();
    final token = RootIsolateToken.instance!;

    _isolate = await Isolate.spawn(_entry, {
      "port": receivePort.sendPort,
      "token": token,
      "taskId": taskId,
      "command": command,
    });

    // 监听子 Isolate 发回的消息
    receivePort.listen((data) {
      if (data is SendPort) {
        _sendPort = data;
      } else if (data is Map) {
        _eventController.add(FFmpegEvent.fromMap(data));
      }
    });
  }

  /// 尝试正常停止 (调用 FFmpegKit.cancel)
  Future<void> stop() async {
    _sendPort?.send({"cmd": "stop"});
  }

  /// 强行结束任务 (Kill Isolate)
  /// 这会立即切断该任务的所有原生联系，不影响其他 Executor 实例
  Future<void> forceKill() async {
    if (_isolate != null) {
      _sendPort?.send({"cmd": "stop"});

      await Future.delayed(const Duration(milliseconds: 500));

      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
      _sendPort = null;

      await Future.delayed(const Duration(milliseconds: 200));
      log("[$taskId] 线程安全关闭");
    }
  }

  /// 释放资源
  void dispose() {
    forceKill();
    _eventController.close();
  }

  /// Isolate 入口点 (静态方法)
  static void _entry(Map<String, dynamic> context) async {
    final SendPort mainSendPort = context["port"];
    final RootIsolateToken token = context["token"];
    final String taskId = context["taskId"];
    final String command = context["command"];

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    try {
      await FFmpegKitExtended.initialize();
    } catch (e) {
      log("FFmpegKit initialization failed: $e");
    }

    final port = ReceivePort();
    mainSendPort.send(port.sendPort);

    // 自动开始录制
    FFmpegService.to.start(taskId: taskId, command: command, onEvent: (event) => mainSendPort.send(event.toMap()));

    port.listen((msg) async {
      if (msg["cmd"] == "stop") {
        await FFmpegService.to.stop(taskId);
      }
    });
  }
}
