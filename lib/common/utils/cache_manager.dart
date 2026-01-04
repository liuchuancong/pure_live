import 'dart:io';
import 'dart:developer';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager {
  static const String _key = 'customCacheKey';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 2000,
      repo: JsonCacheInfoRepository(databaseName: _key),
      fileSystem: IOFileSystem(_key),
      fileService: HttpFileService(),
    ),
  );

  static final _sizeController = BehaviorSubject<double>.seeded(0.0);
  static Stream<double> get cacheSizeStream => _sizeController.stream;

  static final _updateTrigger = PublishSubject<void>();

  static void init() {
    _updateTrigger
        .throttleTime(const Duration(seconds: 2), trailing: true, leading: true)
        .asyncMap((_) => _calculateSize())
        .listen((size) {
          _sizeController.add(size);
          log('缓存大小已更新: ${size.toStringAsFixed(2)} MB');
        });

    // 初始统计一次
    notifyUpdate();
  }

  static void notifyUpdate() => _updateTrigger.add(null);

  static Future<double> _calculateSize() async {
    final baseDir = await getTemporaryDirectory();
    int totalBytes = 0;

    final fileDir = Directory(p.join(baseDir.path, _key));
    if (await fileDir.exists()) {
      await for (var file in fileDir.list(recursive: true)) {
        if (file is File) totalBytes += await file.length();
      }
    }

    final dbFile = File(p.join(baseDir.path, '$_key.json'));
    if (await dbFile.exists()) {
      totalBytes += await dbFile.length();
    }

    // 转换为 MB (1024 * 1024)
    return totalBytes / (1024 * 1024);
  }

  /// 彻底清理缓存：清理数据库 + 物理删除文件夹
  static Future<void> clearCache() async {
    try {
      await instance.emptyCache();

      // 2. 物理删除残留文件夹和 JSON 数据库文件
      final baseDir = await getTemporaryDirectory();
      final dirPath = p.join(baseDir.path, _key);
      final dbPath = p.join(baseDir.path, '$_key.json');

      final dir = Directory(dirPath);
      if (await dir.exists()) await dir.delete(recursive: true);

      final db = File(dbPath);
      if (await db.exists()) await db.delete();

      log('清除缓存成功');

      // 立即重置流状态
      _sizeController.add(0.0);
    } catch (e) {
      log('清理缓存失败: $e');
    }
  }

  /// 销毁资源
  static void dispose() {
    _sizeController.close();
    _updateTrigger.close();
  }
}
