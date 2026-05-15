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
    final sanitizedInstanceId = instanceId.replaceAll(RegExp(r'[\\/]'), '');

    final Directory appDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();
    final List<String> extraOldBasePaths = [
      p.join(appDir.path, softNameDir),
      p.join(supportDir.path, softNameDir),
      p.join(appDir.path, softNameDir.toLowerCase()),
      p.join(supportDir.path, softNameDir.toLowerCase()),
    ];
    String oldBaseRoot = p.join(appDir.path, softNameDir);
    for (final path in extraOldBasePaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        oldBaseRoot = path;
        break;
      }
    }
    String oldRootPath = oldBaseRoot;
    if (sanitizedInstanceId.isNotEmpty) {
      oldRootPath = p.join(oldBaseRoot, sanitizedInstanceId);
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
      rootPath = p.join(appDir.path, softNameDir);
    }
    if (sanitizedInstanceId.isNotEmpty) {
      rootPath = p.join(rootPath, sanitizedInstanceId);
    }
    final dir = Directory(rootPath);
    final bool isAlreadyMigrated = !kIsWeb && await dir.exists() && await dir.list().isEmpty == false;

    if (!kIsWeb && oldRootPath != rootPath && !isAlreadyMigrated) {
      await _migrateHiveFiles(oldRootPath, rootPath);
    }
    _basePath = rootPath;
  }

  Future<void> _migrateHiveFiles(String oldRoot, String rootPath) async {
    final oldDir = Directory(oldRoot);
    if (!await oldDir.exists()) return;

    final newDir = Directory(p.join(rootPath, dirHiveDB));
    await newDir.create(recursive: true);

    final files = ['app_settings.hive', 'app_instance.lock', 'app_settings.lock'];

    for (final name in files) {
      final oldFile = File(p.join(oldRoot, name));
      final newFile = File(p.join(newDir.path, name));

      if (await oldFile.exists()) {
        try {
          await oldFile.copy(newFile.path);
          await oldFile.delete();
        } catch (e) {
          log('迁移失败: $name -> $e');
        }
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
