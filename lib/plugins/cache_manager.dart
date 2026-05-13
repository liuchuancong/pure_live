import 'dart:io';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomImageCacheManager {
  static const _cacheKey = 'customImageCacheKey';
  static CacheManager? _instance;
  static CacheManager get instance {
    if (_instance == null) {
      throw StateError("CustomImageCacheManager 尚未初始化，请先在 main 中调用 initialize()");
    }
    return _instance!;
  }

  static Future<void> initialize() async {
    if (_instance != null) return;
    final Directory imageCacheDir = await AppPathManager().getDir(AppPathManager.dirImageCache);
    final customFileSystem = IOFileSystem(imageCacheDir.path);

    _instance = CacheManager(
      Config(
        _cacheKey,
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        fileSystem: customFileSystem,
        fileService: HttpFileServiceWithRetry(),
      ),
    );
  }
}

class HttpFileServiceWithRetry extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    int retryCount = 0;
    const int maxRetries = 3;

    while (true) {
      try {
        return await super.get(url, headers: headers);
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries || e.toString().contains('404')) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }
}
