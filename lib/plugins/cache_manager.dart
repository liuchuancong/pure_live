import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomImageCacheManager {
  static CacheManager get instance => DefaultCacheManager();

  /// Covers and avatars intentionally share Flutter's proven default cache.
  /// This also gives the refresh action one cache to invalidate atomically.
  static Future<void> initialize() async {
    DefaultCacheManager();
  }

  static Future<Directory> cacheDirectory() => IOFileSystem.createDirectory(DefaultCacheManager.key);
}
