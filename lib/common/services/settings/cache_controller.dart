import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/plugins/cache_manager.dart';

int _measureDirectoryBytes(List<String> paths) {
  var total = 0;
  for (final path in paths.toSet()) {
    final directory = Directory(path);
    if (!directory.existsSync()) continue;
    try {
      for (final entity in directory.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += entity.lengthSync();
          } on FileSystemException {
            // A cache file may be replaced while the background scan runs.
          }
        }
      }
    } on FileSystemException {
      // A platform cache directory may disappear during an explicit clear.
    }
  }
  return total;
}

class CacheController extends GetxController {
  final cacheSizeMB = 0.0.obs;
  final refreshTurns = 0.0.obs;
  final imageCacheEpoch = 0.obs;
  Timer? _thumbnailRefreshTimer;
  Worker? _thumbnailEnabledWorker;
  Worker? _thumbnailIntervalWorker;
  bool _refreshingImages = false;
  Future<double>? _cacheSizeScan;

  @override
  void onInit() {
    super.onInit();
    final refreshConfig = Get.find<RefreshConfigController>();
    _thumbnailEnabledWorker = ever(
      refreshConfig.autoRefreshThumbnails,
      (_) => _scheduleThumbnailRefresh(),
    );
    _thumbnailIntervalWorker = ever(
      refreshConfig.thumbnailRefreshInterval,
      (_) => _scheduleThumbnailRefresh(),
    );
    _scheduleThumbnailRefresh();
  }

  void _scheduleThumbnailRefresh() {
    _thumbnailRefreshTimer?.cancel();
    final config = Get.find<RefreshConfigController>();
    if (!config.autoRefreshThumbnails.value) return;
    final minutes = config.thumbnailRefreshInterval.value.clamp(5, 360);
    _thumbnailRefreshTimer = Timer.periodic(
      Duration(minutes: minutes),
      (_) => refreshImageCache(refreshVisible: false),
    );
  }

  Future<double> getCacheSize() async {
    final active = _cacheSizeScan;
    if (active != null) return active;

    late final Future<double> operation;
    operation = _getCacheSizeInBackground().whenComplete(() {
      if (identical(_cacheSizeScan, operation)) _cacheSizeScan = null;
    });
    _cacheSizeScan = operation;
    return operation;
  }

  Future<double> _getCacheSizeInBackground() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final managedImageCacheDir = await CustomImageCacheManager.cacheDirectory();
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> targetDirs = [
      recordsDir,
      imageCacheDir,
      managedImageCacheDir,
      downloadDir,
      iptvCacheDir,
    ];

    final paths = targetDirs
        .map((directory) => directory.absolute.path)
        .toSet()
        .toList(growable: false);
    final totalSizeBytes = await compute(_measureDirectoryBytes, paths);
    if (isClosed) return totalSizeBytes / 1024 / 1024;
    cacheSizeMB.value = totalSizeBytes / 1024 / 1024;
    return cacheSizeMB.value;
  }

  Future<void> clearCache() async {
    final activeScan = _cacheSizeScan;
    if (activeScan != null) await activeScan;
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

  /// Drop encoded thumbnails. A manual action also rolls visible image
  /// providers to a new bounded cache key while retaining their old pixels.
  Future<void> refreshImageCache({bool refreshVisible = true}) async {
    if (_refreshingImages) return;
    _refreshingImages = true;
    try {
      final activeScan = _cacheSizeScan;
      if (activeScan != null) await activeScan;
      await CustomImageCacheManager.instance.emptyCache();
      // Cached entries are dropped, while live image streams keep their last
      // pixels. Cards refresh naturally on the next data/widget resolution,
      // avoiding a grid-wide placeholder and decode storm.
      PaintingBinding.instance.imageCache.clear();
      if (refreshVisible) imageCacheEpoch.value++;
      if (refreshVisible) await getCacheSize();
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
