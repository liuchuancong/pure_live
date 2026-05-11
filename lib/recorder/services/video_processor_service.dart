import 'dart:io';
import 'dart:developer';
import 'cache_service.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import '../models/live_record_task.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class VideoProcessorService extends GetxService {
  static VideoProcessorService get to => Get.find();

  /// =========================
  /// 🎬 TS → MP4
  /// =========================
  Future<String?> convertToMp4({
    required LiveRecordTask task,
    required Directory tsDir,
    Function(bool success, String outPath)? onFinish,
  }) async {
    try {
      final files = tsDir.listSync().where((e) => e.path.endsWith('.ts')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      if (files.isEmpty) return null;

      // 1. 预先计算输出路径并准备配置文件
      final String listFileName = '${task.platform}_${task.roomId}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final listFile = File(p.join(tsDir.path, listFileName));
      final buffer = StringBuffer();
      for (final f in files) {
        String safePath = f.path.replaceAll('\\', '/');
        buffer.writeln("file '$safePath'");
      }
      await listFile.writeAsString(buffer.toString());

      // 生成唯一的输出路径
      final outputName = '${task.taskId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputPath = '${tsDir.path}${Platform.pathSeparator}$outputName';

      // 4. 处理 FFmpeg 命令路径（统一为正斜杠并用引号包裹）
      final safeListPath = listFile.path.replaceAll('\\', '/');
      final safeOutPath = outputPath.replaceAll('\\', '/');
      final cmd = '-f concat -safe 0 -i "file:$safeListPath" -c copy "$safeOutPath"';

      // 2. 触发异步执行（不 await）
      FFmpegKit.executeAsync(
        cmd,
        onComplete: (session) async {
          await Future.delayed(const Duration(milliseconds: 1000));
          final code = session.getReturnCode();
          bool isSuccess = ReturnCode.isSuccess(code);
          if (listFile.existsSync()) await listFile.delete();
          await Future.delayed(const Duration(milliseconds: 500));
          if (isSuccess) {
            for (var f in files) {
              if (f.existsSync()) await f.delete();
            }
          }
          await CacheService.to.enforceLimit();
          if (onFinish != null) onFinish(isSuccess, outputPath);
        },
        onLog: (msg) => log("[ffmpeg]: ${msg.message}"),
      );
      return outputPath;
    } catch (e) {
      log("VideoProcessor Error: $e");
      return null;
    }
  }
}
