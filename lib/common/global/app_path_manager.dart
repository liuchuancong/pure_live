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
    final Directory supportDir = await getApplicationSupportDirectory();

    bool isRunningOnCDrive = false;
    if (!kIsWeb && Platform.isWindows) {
      final String exeDir = p.dirname(Platform.resolvedExecutable);
      if (exeDir.startsWith(RegExp(r'^[cC]:'))) {
        isRunningOnCDrive = true;
        log('检测到当前程序运行在 C 盘，将强制跳过历史数据迁移。');
      }
    }

    final List<String> extraOldBasePaths = [
      p.join(appDir.path, softNameDir),
      p.join(supportDir.path, softNameDir),
      p.join(appDir.path, softNameDir.toLowerCase()),
      p.join(supportDir.path, softNameDir.toLowerCase()),
    ];

    String oldBaseRoot = p.join(appDir.path, softNameDir.toLowerCase());
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
      final String exeDirLower = exeDir.toLowerCase();
      if (exeDirLower.contains('windowsapps') || exeDirLower.contains('program files')) {
        rootPath = p.join(supportDir.path, softNameDir);
      } else {
        final testDir = Directory(p.join(exeDir, dirAppData));
        try {
          await testDir.create(recursive: true);
          rootPath = testDir.path;
        } catch (e) {
          log('Windows 运行目录无写入权限，安全切换至应用支持目录: $e');
          rootPath = p.join(supportDir.path, softNameDir);
        }
      }
    } else {
      rootPath = p.join(appDir.path, softNameDir);
    }

    if (sanitizedInstanceId.isNotEmpty) {
      rootPath = p.join(rootPath, sanitizedInstanceId);
    }

    // 3. 规范化 Windows 的物理路径字符串
    final String canonicalOldRoot = p.canonicalize(oldRootPath);
    final String canonicalNewRoot = p.canonicalize(rootPath);

    // 4. 迁移保险锁文件
    final lockFile = File(p.join(rootPath, 'migrated.lock'));
    final bool isAlreadyMigrated = !kIsWeb && await lockFile.exists();

    // 核心修改：非 Web 平台 + 新旧路径不同 + 未迁移过 +【非 C 盘运行】时才触发迁移
    if (!kIsWeb && canonicalOldRoot != canonicalNewRoot && !isAlreadyMigrated && !isRunningOnCDrive) {
      // 验证目标目录是否有写入权限
      final bool hasWritePermission = await _checkDirectoryWritable(rootPath);
      if (hasWritePermission) {
        await _migrateHiveFiles(oldRootPath, rootPath, lockFile);
      } else {
        log('迁移终止：目标新目录 $rootPath 没有写入权限！');
      }
    }

    _basePath = rootPath;
  }

  /// 新增：测试目标目录是否真正具备物理写入权限
  Future<bool> _checkDirectoryWritable(String path) async {
    try {
      final testDir = Directory(path);
      if (!await testDir.exists()) {
        await testDir.create(recursive: true);
      }
      // 创建一个临时测试文件
      final testFile = File(p.join(path, '.permission_test_${DateTime.now().millisecondsSinceEpoch}'));
      await testFile.writeAsString('test');
      await testFile.delete(); // 成功写入后立即删除
      return true;
    } catch (e) {
      log('目录写入权限检测失败 ($path): $e');
      return false;
    }
  }

  Future<void> _migrateHiveFiles(String oldRoot, String rootPath, File lockFile) async {
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
          log('数据迁移成功 (原文件已保留): $name');
        } catch (e) {
          log('数据迁移失败: $name -> $e');
        }
      }
    }

    try {
      await lockFile.create(recursive: true);
      await lockFile.writeAsString('Migrated on ${DateTime.now()}');
    } catch (e) {
      log('创建迁移锁文件失败: $e');
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
