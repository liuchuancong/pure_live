import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

class CacheController extends GetxController {
  final cacheSizeMB = 0.0.obs;
  final refreshTurns = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    getCacheSize();
  }

  Future<double> getCacheSize() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> targetDirs = [recordsDir, imageCacheDir, downloadDir, iptvCacheDir];

    double totalSizeBytes = 0;
    for (final dir in targetDirs) {
      if (!dir.existsSync()) continue;
      try {
        final files = dir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) totalSizeBytes += file.lengthSync();
        }
      } catch (_) {}
    }
    cacheSizeMB.value = totalSizeBytes / 1024 / 1024;
    return cacheSizeMB.value;
  }

  Future<void> clearCache() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> dirs = [recordsDir, imageCacheDir, downloadDir, iptvCacheDir];

    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      try {
        dir.deleteSync(recursive: true);
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    cacheSizeMB.value = 0;
  }

  Future<void> handleManualRefresh() async {
    refreshTurns.value += 1.0;
    await getCacheSize();
  }
}
