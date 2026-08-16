import 'dart:async';
import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/plugins/cache_manager.dart';

class CacheController extends GetxController {
  final cacheSizeMB = 0.0.obs;
  final refreshTurns = 0.0.obs;
  final imageCacheEpoch = 0.obs;
  Timer? _thumbnailRefreshTimer;
  Worker? _thumbnailEnabledWorker;
  Worker? _thumbnailIntervalWorker;
  bool _refreshingImages = false;

  @override
  void onInit() {
    super.onInit();
    getCacheSize();
    final refreshConfig = Get.find<RefreshConfigController>();
    _thumbnailEnabledWorker = ever(refreshConfig.autoRefreshThumbnails, (_) => _scheduleThumbnailRefresh());
    _thumbnailIntervalWorker = ever(refreshConfig.thumbnailRefreshInterval, (_) => _scheduleThumbnailRefresh());
    _scheduleThumbnailRefresh();
  }

  void _scheduleThumbnailRefresh() {
    _thumbnailRefreshTimer?.cancel();
    final config = Get.find<RefreshConfigController>();
    if (!config.autoRefreshThumbnails.value) return;
    final minutes = config.thumbnailRefreshInterval.value.clamp(5, 360);
    _thumbnailRefreshTimer = Timer.periodic(Duration(minutes: minutes), (_) => refreshImageCache());
  }

  Future<double> getCacheSize() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final managedImageCacheDir = await CustomImageCacheManager.cacheDirectory();
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> targetDirs = [recordsDir, imageCacheDir, managedImageCacheDir, downloadDir, iptvCacheDir];

    double totalSizeBytes = 0;
    for (final dir in targetDirs) {
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) totalSizeBytes += await entity.length();
        }
      } catch (error) {
        debugPrint('Failed to inspect cache directory ${dir.path}: $error');
      }
    }
    cacheSizeMB.value = totalSizeBytes / 1024 / 1024;
    return cacheSizeMB.value;
  }

  Future<void> clearCache() async {
    await CustomImageCacheManager.instance.emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> dirs = [recordsDir, imageCacheDir, downloadDir, iptvCacheDir];

    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      try {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      } catch (error) {
        debugPrint('Failed to clear cache directory ${dir.path}: $error');
      }
    }
    cacheSizeMB.value = 0;
    imageCacheEpoch.value++;
  }

  /// Drop only thumbnails and force visible cards to request fresh images.
  Future<void> refreshImageCache() async {
    if (_refreshingImages) return;
    _refreshingImages = true;
    try {
      await CustomImageCacheManager.instance.emptyCache();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      imageCacheEpoch.value++;
      await getCacheSize();
    } finally {
      _refreshingImages = false;
    }
  }

  Future<void> handleManualRefresh() async {
    refreshTurns.value += 1.0;
    await getCacheSize();
  }

  @override
  void onClose() {
    _thumbnailRefreshTimer?.cancel();
    _thumbnailEnabledWorker?.dispose();
    _thumbnailIntervalWorker?.dispose();
    super.onClose();
  }
}
