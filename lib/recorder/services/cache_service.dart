import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/services/path_helper.dart';

class CacheService extends GetxService {
  static CacheService get to => Get.find();

  /// =========================
  /// 📁 获取录制目录
  /// =========================

  Future<Directory> getRecordDir() async {
    final customPath = HivePrefUtil.getString(RecorderKeys.recordSavePath);

    Directory recordDir;

    /// 用户自定义目录
    if (customPath != null && customPath.isNotEmpty) {
      recordDir = Directory(customPath);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      if (Platform.isWindows) {
        recordDir = Directory(
          '${dir.path}'
          '${Platform.pathSeparator}'
          'pure_live_records',
        );
      } else {
        recordDir = Directory(
          '${dir.path}'
          '${Platform.pathSeparator}'
          'pure_live_records',
        );
      }
    }

    /// 不存在则创建
    if (!await recordDir.exists()) {
      await recordDir.create(recursive: true);
    }

    return recordDir;
  }

  /// =========================
  /// 📊 计算缓存大小（MB）
  /// =========================
  Future<double> getCacheSize() async {
    final dir = await getRecordDir();
    double size = 0;
    final files = dir.listSync(recursive: true);
    for (final file in files) {
      if (file is File) {
        size += await file.length();
      }
    }
    return size / 1024 / 1024;
  }

  Future<void> clearSystemTemp() async {
    if (!Platform.isWindows) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final systemTemp = tempDir.parent;
      if (await systemTemp.exists()) {
        final List<FileSystemEntity> entities = systemTemp.listSync();
        for (var entity in entities) {
          final String name = entity.path.split(Platform.pathSeparator).last;
          if (name.toLowerCase().startsWith('pure_live')) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// =========================
  /// 🧹 清空全部缓存
  /// =========================
  Future<void> clearAll() async {
    final dir = await getRecordDir();

    if (!await dir.exists()) {
      return;
    }

    final entities = dir.listSync(recursive: true);

    for (final entity in entities) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          if (entity.existsSync()) {
            await entity.delete(recursive: true);
          }
        }
      } catch (_) {}
    }
  }

  /// =========================
  /// 🧹 删除最旧文件
  /// =========================
  Future<void> deleteOldest() async {
    final dir = await getRecordDir();

    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    if (files.isNotEmpty) {
      await files.first.delete();
    }
  }

  /// =========================
  /// 📦 限制最大缓存（自动清理）
  /// =========================
  Future<void> enforceLimit({double maxMB = 2048}) async {
    while (await getCacheSize() > maxMB) {
      await deleteOldest();
    }
  }

  /// =========================
  /// 📌 获取路径
  /// =========================
  Future<String> getDisplayPath() async {
    final dir = await getRecordDir();
    return dir.path;
  }

  /// =========================
  /// 📂 创建房间目录
  /// =========================
  Future<Directory> createRoomDir(String roomId) async {
    final base = await getRecordDir();

    final roomDir = Directory(p.join(base.path, roomId));

    if (!await roomDir.exists()) {
      await roomDir.create(recursive: true);
    }

    return roomDir;
  }

  /// =========================
  /// 获取房间录制目录（平台 + 日期 + 主播）
  /// =========================
  Future<Directory> getRoomDir({
    required String platform,
    required String nick,
    bool usePinyinForFolder = false,
  }) async {
    final base = await getRecordDir();

    final now = DateTime.now();

    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final time =
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}';

    final safePlatform = usePinyinForFolder ? PathHelper.toSafePinyin(platform) : platform;

    final safeNick = usePinyinForFolder ? PathHelper.toSafePinyin(nick) : nick;

    final path = p.join(base.path, safePlatform, safeNick, date, time);

    final dir = Directory(path);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }
}
