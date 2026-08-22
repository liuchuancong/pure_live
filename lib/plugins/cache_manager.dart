import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomImageCacheManager {
  static const String key = 'pureLiveImagesV2';

  static final CacheManager instance = CacheManager(
    Config(key, stalePeriod: const Duration(minutes: 30), maxNrOfCacheObjects: 320),
  );

  /// Covers and avatars share one bounded cache. A short stale period lets a
  /// later widget resolve revalidate a reused platform URL without globally
  /// tearing down every visible image at the same instant.
  static Future<void> initialize() async {
    instance;
  }

  static Future<void> remove(String url) async {
    if (url.isEmpty) return;
    await instance.removeFile(url);
  }

  static Future<void> clear() async {
    await instance.emptyCache();
  }

  static Future<Directory> cacheDirectory() => IOFileSystem.createDirectory(key);
}
