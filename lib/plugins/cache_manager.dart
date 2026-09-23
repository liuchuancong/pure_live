import 'dart:io';

import 'package:http/io_client.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomImageCacheManager {
  static const String key = 'pureLiveImagesV2';
  static String Function()? _proxyDirectiveProvider;

  static final CacheManager instance = _createManager();

  static CacheManager _createManager() {
    final client = HttpClient()
      ..idleTimeout = const Duration(seconds: 30)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Ignore all HTTPS certificate validation errors.
        return true;
      };

    client.findProxy = (_) {
      try {
        return _proxyDirectiveProvider?.call() ?? 'DIRECT';
      } catch (_) {
        return 'DIRECT';
      }
    };

    return CacheManager(
      Config(
        key,
        stalePeriod: const Duration(minutes: 30),
        maxNrOfCacheObjects: 320,
        fileService: HttpFileService(httpClient: IOClient(client)),
      ),
    );
  }

  static Future<void> initialize({String Function()? proxyDirectiveProvider}) async {
    _proxyDirectiveProvider = proxyDirectiveProvider;
    instance;
  }

  static Future<void> remove(String url) async {
    final fileInfo = await instance.getFileFromCache(url);

    if (fileInfo == null) {
      return;
    }

    final file = fileInfo.file;

    for (var i = 0; i < 5; i++) {
      try {
        if (!await file.exists()) {
          return;
        }

        await file.delete();
        return;
      } on PathAccessException catch (_) {
        if (i == 4) {
          return;
        }

        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      } catch (_) {
        return;
      }
    }
  }

  static Future<void> clear() async {
    await instance.emptyCache();
  }

  static Future<Directory> cacheDirectory() {
    return IOFileSystem.createDirectory(key);
  }
}
