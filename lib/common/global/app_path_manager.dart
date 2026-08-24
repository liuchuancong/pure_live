import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/common/utils/windows_multi_instance_launcher.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:win32_registry/win32_registry.dart';

import 'windows_portable_path_provider.dart';

class AppPathManager {
  static final AppPathManager _instance = AppPathManager._internal();
  factory AppPathManager() => _instance;
  AppPathManager._internal();

  static const String dirAppData = 'AppData';
  static const String softNameDir = 'PURE_LIVE';
  static const String dirIptvCache = 'IPTV_CACHE';
  static const String iptvTable = 'pure_live_tv';
  static const String dirDownload = 'DOWNLOADS';
  static const String dirLogs = 'LOGS';
  static const String dirHiveDB = 'HIVE_DB';
  static const String dirImageCache = 'IMAGE_CACHE';
  static const String dirRecords = 'RECORDS';
  static const String dirEmojiCache = 'EMOJI_CACHE';
  static const String dirMigrationBackup = 'MIGRATION_BACKUP';

  /// Canonical directory used by [FontDownloadManager] for downloaded fonts.
  /// Keep this in one place so the manager page and downloader never drift to
  /// different folders (the old `fontsDir` value broke multi-file font packs).
  static const String fontDirectoryName = 'fonts';
  // Compatibility alias retained for upstream call sites introduced in
  // 5aa1a40a. Both names intentionally resolve to the same canonical folder.
  static const String fontCacheDir = fontDirectoryName;
  static const String iptvCategoryFile = 'categories.json';
  static const String iptvHotFile = 'hot.m3u';
  static const String iptvHotRemoteFile = 'https://raw.githubusercontent.com/YueChan/Live/main/GNTV.m3u';

  String? _basePath;
  List<String> _legacyHiveFiles = const [];

  List<String> get legacyHiveFiles => List.unmodifiable(_legacyHiveFiles);

  Future<void> initialize({String instanceId = ''}) async {
    // Treat the command line as untrusted even if it normally comes from our
    // launcher. A path segment such as `..` must never escape the portable
    // AppData root.
    final sanitizedInstanceId = WindowsMultiInstanceLauncher.sanitizeInstanceId(instanceId);

    final originalPathProvider = PathProviderPlatform.instance;
    final appDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();
    final cacheDir = await getApplicationCacheDirectory();

    var rootPath = '';
    if (kIsWeb) {
      rootPath = softNameDir;
    } else if (Platform.isWindows) {
      rootPath = await _selectWindowsDataRoot(supportDir);
    } else {
      rootPath = p.join(appDir.path, softNameDir);
    }

    if (sanitizedInstanceId.isNotEmpty) {
      rootPath = p.join(rootPath, sanitizedInstanceId);
    }
    await Directory(rootPath).create(recursive: true);
    _basePath = rootPath;

    if (!kIsWeb && Platform.isWindows) {
      final legacyRoots = await _discoverWindowsLegacyRoots(
        appDir: appDir,
        supportDir: supportDir,
        cacheDir: cacheDir,
        instanceId: sanitizedInstanceId,
      );
      _legacyHiveFiles = await _findLegacyHiveFiles(roots: legacyRoots, targetRoot: rootPath);
      await _createMigrationBackups(_legacyHiveFiles);
      await _recoverMissingPersistentData(legacyRoots);
      await _recoverLegacyPluginPreferences(supportDir);

      // Portable/EXE builds keep plugin support, cache and temporary state
      // beside the executable. MSIX already receives a writable package data
      // root from the system path provider and must retain that provider.
      if (!_isWindowsMsix) {
        PathProviderPlatform.instance = WindowsPortablePathProvider(delegate: originalPathProvider, dataRoot: rootPath);
        configureWindowsPortableSharedPreferences(rootPath);
      }
    }
  }

  Future<String> _selectWindowsDataRoot(Directory supportDir) async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final localRoot = p.join(exeDir, dirAppData);
    if (await _checkDirectoryWritable(localRoot)) return localRoot;

    // Store/MSIX and protected enterprise directories can be read-only. Keep
    // a deterministic fallback so startup still succeeds.
    final fallback = p.join(supportDir.path, softNameDir);
    await Directory(fallback).create(recursive: true);
    log('Windows 安装目录只读，数据目录回退至 $fallback');
    return fallback;
  }

  Future<List<String>> _discoverWindowsLegacyRoots({
    required Directory appDir,
    required Directory supportDir,
    required Directory cacheDir,
    required String instanceId,
  }) async {
    final roots = <String>{
      p.join(appDir.path, softNameDir),
      p.join(appDir.path, softNameDir.toLowerCase()),
      supportDir.path,
      cacheDir.path,
      p.join(supportDir.path, softNameDir),
      p.join(supportDir.path, softNameDir.toLowerCase()),
    };

    final exeDir = Directory(p.dirname(Platform.resolvedExecutable));
    final parent = exeDir.parent;
    if (await parent.exists()) {
      try {
        await for (final entity in parent.list(followLinks: false)) {
          if (entity is! Directory) continue;
          final normalized = p.basename(entity.path).toLowerCase().replaceAll(RegExp(r'[_ -]'), '');
          if (normalized == 'purelive') {
            roots.add(p.join(entity.path, dirAppData));
          }
        }
      } catch (_) {}
    }

    roots.addAll(_readWindowsInstallLocations().map((location) => p.join(location, dirAppData)));
    await _expandWindowsInstallHistory(roots);

    if (instanceId.isEmpty) return roots.toList();
    return roots.map((root) => p.join(root, instanceId)).toList();
  }

  /// Installer relocation overwrites the current AppId's registry location.
  /// Keep following the small relocation ledger stored with the data so a
  /// user can move from C: to another drive without orphaning the latest
  /// follows/settings database. The queue is bounded and existing data is
  /// only read; source directories are never deleted or rewritten.
  Future<void> _expandWindowsInstallHistory(Set<String> roots) async {
    final pending = <String>[...roots];
    final inspected = <String>{};
    while (pending.isNotEmpty && inspected.length < 32) {
      final root = pending.removeAt(0);
      final normalized = p.normalize(p.absolute(root)).toLowerCase();
      if (!inspected.add(normalized)) continue;

      final ledger = File(p.join(root, 'previous_install_locations.txt'));
      if (!await ledger.exists()) continue;
      try {
        final lines = await ledger.readAsLines();
        for (final raw in lines) {
          final installDirectory = raw.trim().replaceAll(RegExp(r'[\\/]+$'), '');
          if (installDirectory.isEmpty || !p.isAbsolute(installDirectory)) continue;
          final previousRoot = p.join(installDirectory, dirAppData);
          if (roots.add(previousRoot)) pending.add(previousRoot);
        }
      } catch (error) {
        log('旧安装位置记录读取失败 ($root): $error');
      }
    }
  }

  List<String> _readWindowsInstallLocations() {
    final locations = <String>{};
    const uninstallPaths = [
      r'Software\Microsoft\Windows\CurrentVersion\Uninstall',
      r'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    ];

    for (final root in [CURRENT_USER, LOCAL_MACHINE]) {
      for (final uninstallPath in uninstallPaths) {
        RegistryKey? uninstallKey;
        try {
          uninstallKey = root.open(uninstallPath);
          for (final childName in uninstallKey.keys) {
            RegistryKey? child;
            try {
              child = uninstallKey.open(childName);
              final displayName = child.getString('DisplayName') ?? '';
              if (!RegExp(r'纯粹直播|pure[ _-]?live', caseSensitive: false).hasMatch(displayName)) {
                continue;
              }
              var location = (child.getString('InstallLocation') ?? '').trim();
              if (location.isEmpty) {
                final uninstall = child.getString('UninstallString') ?? '';
                final match = RegExp(r'^"?([^\"]+\\)unins\d*\.exe', caseSensitive: false).firstMatch(uninstall);
                location = match?.group(1) ?? '';
              }
              if (location.isNotEmpty) {
                locations.add(location.replaceAll(RegExp(r'[\\/]+$'), ''));
              }
            } catch (_) {
              // Ignore stale or access-restricted uninstall entries.
            } finally {
              child?.close();
            }
          }
        } catch (_) {
          // A registry view may not exist on every Windows architecture.
        } finally {
          uninstallKey?.close();
        }
      }
    }
    return locations.toList();
  }

  Future<List<String>> _findLegacyHiveFiles({required Iterable<String> roots, required String targetRoot}) async {
    final targetFile = File(p.join(targetRoot, dirHiveDB, 'app_settings.hive'));
    final candidates = <String, String>{};
    for (final root in roots) {
      for (final path in [p.join(root, 'app_settings.hive'), p.join(root, dirHiveDB, 'app_settings.hive')]) {
        final file = File(path);
        if (!await file.exists()) continue;
        if (await _sameFile(file, targetFile)) continue;
        final absolutePath = file.absolute.path;
        // Windows paths are case-insensitive even when the spelling returned
        // by Documents/registry discovery differs (PURE_LIVE vs pure_live).
        candidates.putIfAbsent(p.normalize(absolutePath).toLowerCase(), () => absolutePath);
      }
    }
    return candidates.values.toList();
  }

  Future<bool> _sameFile(File a, File b) async {
    if (!await a.exists() || !await b.exists()) {
      return a.absolute.path == b.absolute.path;
    }
    try {
      return await FileSystemEntity.identical(a.path, b.path);
    } catch (_) {
      return a.absolute.path == b.absolute.path;
    }
  }

  Future<void> _createMigrationBackups(List<String> sources) async {
    final backupDir = Directory(p.join(basePath, dirMigrationBackup, 'settings-v4'));
    final marker = File(p.join(backupDir.path, 'backup_manifest.json'));
    if (await marker.exists()) return;
    await backupDir.create(recursive: true);

    final paths = <String>[p.join(basePath, dirHiveDB, 'app_settings.hive'), ...sources];
    final manifest = <Map<String, dynamic>>[];
    var index = 0;
    for (final sourcePath in paths.toSet()) {
      final source = File(sourcePath);
      if (!await source.exists()) continue;
      final destination = File(p.join(backupDir.path, 'settings_before_upgrade_$index.hive'));
      await source.copy(destination.path);
      final stat = await source.stat();
      manifest.add({
        'source': source.absolute.path,
        'backup': destination.path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
      });
      index++;
    }
    await marker.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest), flush: true);
  }

  Future<void> _recoverMissingPersistentData(Iterable<String> roots) async {
    final marker = File(p.join(basePath, 'persistent_data_migration_v4.lock'));
    if (await marker.exists()) return;

    // IPTV contains user-added providers, favorites, EPG mappings and timers.
    // Prefer the richest existing database, then copy only absent files; a
    // database already used by the new installation always wins.
    final sources = <Directory>[];
    for (final root in roots) {
      final source = Directory(p.join(root, dirIptvCache));
      if (!await source.exists()) continue;
      final target = Directory(p.join(basePath, dirIptvCache));
      if (await _sameDirectory(source, target)) continue;
      sources.add(source);
    }
    sources.sort((a, b) => _iptvDatabaseSize(b).compareTo(_iptvDatabaseSize(a)));
    final target = Directory(p.join(basePath, dirIptvCache));
    for (final source in sources) {
      await _copyMissingTree(source, target);
    }
    await marker.writeAsString(DateTime.now().toIso8601String(), flush: true);
  }

  int _iptvDatabaseSize(Directory root) {
    final file = File(p.join(root.path, iptvTable, '$iptvTable.db'));
    try {
      return file.existsSync() ? file.lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> _sameDirectory(Directory a, Directory b) async {
    if (!await a.exists() || !await b.exists()) {
      return a.absolute.path == b.absolute.path;
    }
    try {
      return await FileSystemEntity.identical(a.path, b.path);
    } catch (_) {
      return a.absolute.path == b.absolute.path;
    }
  }

  Future<void> _recoverLegacyPluginPreferences(Directory supportDir) async {
    final source = File(p.join(supportDir.path, 'shared_preferences.json'));
    if (!await source.exists()) return;
    final target = File(p.join(basePath, 'PLUGIN_SUPPORT', 'shared_preferences.json'));
    if (await target.exists()) return;
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }

  Future<void> _copyMissingTree(Directory source, Directory target) async {
    await target.create(recursive: true);
    try {
      await for (final entity in source.list(recursive: true, followLinks: false)) {
        final relative = p.relative(entity.path, from: source.path);
        final destination = p.join(target.path, relative);
        if (entity is Directory) {
          await Directory(destination).create(recursive: true);
        } else if (entity is File && !await File(destination).exists()) {
          await File(destination).parent.create(recursive: true);
          await entity.copy(destination);
        }
      }
    } catch (error) {
      log('旧数据目录读取失败 (${source.path}): $error');
    }
  }

  Future<bool> _checkDirectoryWritable(String path) async {
    try {
      final testDir = Directory(path);
      await testDir.create(recursive: true);
      final testFile = File(p.join(path, '.permission_test_${DateTime.now().microsecondsSinceEpoch}'));
      await testFile.writeAsString('test', flush: true);
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> getDir(String segment) async {
    final targetPath = p.join(basePath, segment);
    final directory = Directory(targetPath);
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> get iptvCacheDir => getDir(dirIptvCache);
  Future<Directory> get downloadDir => getDir(dirDownload);
  Future<Directory> get logsDir => getDir(dirLogs);
  Future<Directory> get hiveDbDir => getDir(dirHiveDB);
  Future<Directory> get imageCacheDir => getDir(dirImageCache);
  Future<Directory> get recordsDir => getDir(dirRecords);
  Future<Directory> get emojiCacheDir => getDir(dirEmojiCache);
  Future<Directory> get migrationWorkingDir => getDir(p.join(dirMigrationBackup, 'working'));

  String get basePath => _basePath ?? (throw StateError('AppPathManager 尚未初始化'));

  Future<String> getFontFamilyFolderPath(String id) async {
    final downloadDir = await getDir(dirDownload);
    return fontFamilyFolderPath(downloadDir.path, id);
  }

  bool get _isWindowsMsix {
    if (!Platform.isWindows) return false;
    return isWindowsMsixExecutablePath(Platform.resolvedExecutable);
  }

  @visibleForTesting
  static bool isWindowsMsixExecutablePath(String path) {
    final normalized = path.replaceAll('/', r'\').toLowerCase();
    return normalized.contains(r'\windowsapps\');
  }

  @visibleForTesting
  static String fontFamilyFolderPath(String downloadPath, String id) {
    return p.join(downloadPath, fontDirectoryName, id);
  }
}
