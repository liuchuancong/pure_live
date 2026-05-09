import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:pure_live/recorder/consts/recorder_config.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_file_item.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class RecordHistoryService extends GetxService {
  static RecordHistoryService get to => Get.find();

  final records = <RecordFileItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    restore();
  }

  /// =========================
  /// 恢复历史
  /// =========================
  Future<void> restore() async {
    try {
      final list = RecorderConfig.getRecordHistory();

      records.value = list.map((e) => RecordFileItem.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      records.clear();
    }
  }

  /// =========================
  /// 保存历史
  /// =========================
  Future<void> persist() async {
    await RecorderConfig.saveRecordHistory(records);
  }

  /// =========================
  /// 添加历史
  /// =========================
  Future<void> addRecord({required LiveRecordTask task, required File file}) async {
    try {
      /// 文件不存在
      if (!file.existsSync()) {
        return;
      }

      /// 去重
      records.removeWhere((e) => e.path == file.path);

      final size = await file.length();

      final duration = await _getDuration(file.path);

      final item = RecordFileItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),

        nick: task.nick,

        platform: task.platform,

        title: task.title,

        path: file.path,

        cover: task.cover,

        size: size,

        duration: duration,

        createTime: DateTime.now(),

        fileName: basename(file.path),

        date: _dateString(),
      );

      records.insert(0, item);

      await persist();
    } catch (_) {}
  }

  /// =========================
  /// 删除历史
  /// =========================
  Future<void> removeRecord(RecordFileItem item) async {
    records.remove(item);

    await persist();
  }

  /// =========================
  /// 删除文件 + 历史
  /// =========================
  Future<void> deleteRecord(RecordFileItem item) async {
    try {
      final file = File(item.path);

      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}

    records.remove(item);

    await persist();
  }

  /// =========================
  /// 清空历史
  /// =========================
  Future<void> clear() async {
    records.clear();

    await RecorderConfig.clearRecordHistory();
  }

  /// =========================
  /// 获取视频时长
  /// =========================
  Future<int> _getDuration(String path) async {
    try {
      final session = FFprobeKit.getMediaInformation(path);

      final info = session.getMediaInformation();

      if (info == null) {
        return 0;
      }
      final duration = info.duration;
      if (duration == null) {
        return 0;
      }
      return double.tryParse(duration)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// =========================
  /// 日期字符串
  /// =========================
  String _dateString() {
    final now = DateTime.now();

    return "${now.year}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  Map<String, Map<String, List<RecordFileItem>>> grouped() {
    final result = <String, Map<String, List<RecordFileItem>>>{};

    for (final item in records) {
      result.putIfAbsent(item.platform, () => {});

      final platformMap = result[item.platform]!;

      final key = "${item.nick}_${item.date}";

      platformMap.putIfAbsent(key, () => []);

      platformMap[key]!.add(item);
    }

    return result;
  }

  /// =========================
  /// 搜索
  /// =========================
  List<RecordFileItem> search(String keyword) {
    if (keyword.isEmpty) {
      return records;
    }

    return records.where((e) {
      return e.title.contains(keyword) ||
          e.nick.contains(keyword) ||
          e.platform.contains(keyword) ||
          e.fileName.contains(keyword);
    }).toList();
  }

  /// =========================
  /// 获取主播历史
  /// =========================
  List<RecordFileItem> getByNick(String nick) {
    return records.where((e) => e.nick == nick).toList();
  }

  /// =========================
  /// 获取平台历史
  /// =========================
  List<RecordFileItem> getByPlatform(String platform) {
    return records.where((e) => e.platform == platform).toList();
  }
}
