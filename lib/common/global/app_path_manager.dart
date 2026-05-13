import 'dart:io';
import 'dart:developer';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppPathManager {
  static final AppPathManager _instance = AppPathManager._internal();
  factory AppPathManager() => _instance;
  AppPathManager._internal();
  static const String dirAppData = 'AppData';
  static const String softNameDir = 'PURE_LIVE';
  static const String dirIptvCache = 'IPTV_CACHE';
  static const String dirDownload = 'DOWNLOADS';
  static const String dirLogs = 'LOGS';
  static const String dirHiveDB = 'HIVE_DB';
  static const String dirImageCache = 'IMAGE_CACHE';
  static const String dirRecords = 'RECORDS';

  static const String iptvCategoryFile = 'categories.json';
  static const String iptvHotFile = 'hot.m3u';
  static const String iptvHotRemoteFile = 'https://raw.githubusercontent.com/YueChan/Live/main/GNTV.m3u';

  String? _basePath;

  Future<void> initialize({String instanceId = ''}) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    String oldRootPath = p.join(appDir.path, softNameDir);
    if (instanceId.isNotEmpty) {
      oldRootPath = p.join(oldRootPath, instanceId);
    }
    String rootPath = '';
    if (kIsWeb) {
      rootPath = softNameDir;
    } else if (Platform.isWindows) {
      final String exeDir = p.dirname(Platform.resolvedExecutable);
      if (exeDir.toLowerCase().contains('windowsapps')) {
        rootPath = p.join(appDir.path, softNameDir);
      } else {
        rootPath = p.join(exeDir, dirAppData);
      }
    } else {
      final Directory appDir = await getApplicationDocumentsDirectory();
      rootPath = p.join(appDir.path, softNameDir);
    }

    if (instanceId.isNotEmpty) {
      rootPath = p.join(rootPath, instanceId);
    }
    final bool isAlreadyMigrated = !kIsWeb && await Directory(rootPath).exists();

    if (!kIsWeb && oldRootPath != rootPath && !isAlreadyMigrated) {
      await _migrateFolder(oldRootPath, rootPath);
    }
    _basePath = rootPath;

    if (!kIsWeb && !isAlreadyMigrated) {
      await _migrateSubFolder('iptv_cache', dirIptvCache);
      await _migrateSubFolder('download', dirDownload);
      await _migrateSubFolder('logs', dirLogs);
      await _migrateSubFolder('hive_db', dirHiveDB);
      await _migrateSubFolder('image_cache', dirImageCache);
      await _migrateSubFolder('records', dirRecords);
    }
  }

  Future<void> _migrateFolder(String oldPath, String newPath) async {
    final Directory oldDir = Directory(oldPath);
    final Directory newDir = Directory(newPath);

    if (await oldDir.exists() && !await newDir.exists()) {
      try {
        await Directory(p.dirname(newPath)).create(recursive: true);
        await oldDir.rename(newPath);
        log('成功还原旧路径数据至: $newPath');
      } catch (e) {
        log('外部根数据还原失败: $e');
      }
    }
  }

  Future<void> _migrateSubFolder(String oldLowerName, String newUpperName) async {
    final String oldSubPath = p.join(basePath, oldLowerName);
    final String newSubPath = p.join(basePath, newUpperName);

    final Directory oldSubDir = Directory(oldSubPath);
    final Directory newSubDir = Directory(newSubPath);

    if (await oldSubDir.exists() && !await newSubDir.exists()) {
      try {
        await oldSubDir.rename(newSubPath);
        log('子文件夹成功转换: $oldLowerName -> $newUpperName');
      } catch (e) {
        log('子文件夹还原失败: $e');
      }
    }
  }

  Future<Directory> getDir(String segment) async {
    final String targetPath = p.join(basePath, segment);
    final Directory directory = Directory(targetPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> get iptvCacheDir => getDir(dirIptvCache);
  Future<Directory> get downloadDir => getDir(dirDownload);
  Future<Directory> get logsDir => getDir(dirLogs);
  Future<Directory> get hiveDbDir => getDir(dirHiveDB);
  Future<Directory> get imageCacheDir => getDir(dirImageCache);
  Future<Directory> get recordsDir => getDir(dirRecords);

  String get basePath => _basePath ?? (throw StateError("AppPathManager 尚未初始化"));
}
