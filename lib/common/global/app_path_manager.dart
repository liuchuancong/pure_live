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

    // 3. 规范化 Windows 的物理路径字符串（消除 pure_live 和 PURE_LIVE 的大小写异同带来的冲突）
    final String canonicalOldRoot = p.canonicalize(oldRootPath);
    final String canonicalNewRoot = p.canonicalize(rootPath);

    // 4. 迁移保险锁文件
    final lockFile = File(p.join(rootPath, 'migrated.lock'));
    final bool isAlreadyMigrated = !kIsWeb && await lockFile.exists();

    // 只有在“新旧物理路径不同”且“历史上从未成功迁移过”时才复制文件
    if (!kIsWeb && canonicalOldRoot != canonicalNewRoot && !isAlreadyMigrated) {
      await _migrateHiveFiles(oldRootPath, rootPath, lockFile);
    }

    _basePath = rootPath;
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
          // 只复制，不执行旧文件的 delete 操作，确保原始数据 100% 完好留存
          await oldFile.copy(newFile.path);
          log('数据迁移成功 (原文件已保留): $name');
        } catch (e) {
          log('数据迁移失败: $name -> $e');
        }
      }
    }

    // 迁移成功后生成锁文件，下次打开应用直接跳过此段逻辑
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
