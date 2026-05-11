import 'dart:io';
import 'dart:developer' as developer;
import 'package:path/path.dart' as p;
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_isolate_manager.dart';

class VideoProcessorService {
  static final VideoProcessorService to = VideoProcessorService();

  // 记录合并任务的执行器
  final Map<String, FFmpegTaskExecutor> _mergeExecutors = {};

  Future<void> convertToMp4({
    required LiveRecordTask task,
    required Directory tsDir,
    Function(bool success, String outPath)? onFinish,
  }) async {
    final mergeId = "${task.taskId}_merge";

    // 1. 获取所有 .ts 文件并按名称排序（确保时间线正确）
    final files = tsDir
        .listSync()
        .where((e) => e.path.endsWith('.ts'))
        .where((e) => e is File && e.lengthSync() > 0) // 过滤掉损坏的 0 字节文件
        .toList();

    // 按时间顺序（文件名）排序
    files.sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      onFinish?.call(false, "");
      return;
    }

    // 2. 准备 concat 文本文件
    final listFile = File(p.join(tsDir.path, 'list.txt'));
    final buffer = StringBuffer();
    for (final f in files) {
      // FFmpeg concat 格式要求路径处理
      buffer.writeln("file '${f.path.replaceAll('\\', '/')}'");
    }
    await listFile.writeAsString(buffer.toString());

    // 3. 构建输出路径和命令
    final outPath = p.join(tsDir.path, "combined_${DateTime.now().millisecondsSinceEpoch}.mp4");

    // 使用 buildRecordCommand 类似的逻辑或直接拼 List
    final args = [
      "-f", "concat",
      "-safe", "0",
      "-i", listFile.path,
      "-c", "copy", // 仅封装，不重编码，速度极快
      outPath,
    ];

    // 4. 创建专用的合并执行器
    final executor = FFmpegTaskExecutor(taskId: mergeId);
    _mergeExecutors[mergeId] = executor;

    // 5. 监听合并任务状态
    executor.stream.listen((event) {
      if (event.type == FFmpegEventType.complete) {
        developer.log("[$mergeId] 合并完成");
        onFinish?.call(true, outPath);
        _cleanup(mergeId, listFile);
      } else if (event.type == FFmpegEventType.error) {
        developer.log("[$mergeId] 合并失败");
        onFinish?.call(false, "");
        _cleanup(mergeId, listFile);
      }
    });

    // 6. 运行 Isolate 开始合并
    await executor.run(args.join(' '));
  }

  void _cleanup(String mergeId, File listFile) {
    _mergeExecutors[mergeId]?.dispose();
    _mergeExecutors.remove(mergeId);
    if (listFile.existsSync()) listFile.deleteSync();
  }
}
