import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/consts/recorder_keys.dart';
import 'package:pure_live/recorder/services/path_helper.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

typedef RecorderConfiguredPathResolver = String? Function();
typedef RecorderDefaultDirectoryResolver = Future<Directory> Function();

/// Owns the application-managed recording directory.
///
/// A directory selected by the user is treated as a parent directory. Pure
/// Live only writes to and removes files from its [managedFolderName] child,
/// so choosing a broad directory such as Downloads never turns unrelated
/// files into recording-cache entries.
class CacheService extends GetxService {
  CacheService({
    RecorderConfiguredPathResolver? configuredPathResolver,
    RecorderDefaultDirectoryResolver? defaultDirectoryResolver,
  }) : _configuredPathResolver =
           configuredPathResolver ?? (() => HivePrefUtil.getString(RecorderKeys.recordSavePath)),
       _defaultDirectoryResolver =
           defaultDirectoryResolver ?? (() => AppPathManager().getDir(AppPathManager.dirRecords));

  static CacheService get to => Get.find();

  static const String managedFolderName = 'PureLiveRecords';
  static const String ownershipMarkerName = '.pure_live_recording_root';

  final RecorderConfiguredPathResolver _configuredPathResolver;
  final RecorderDefaultDirectoryResolver _defaultDirectoryResolver;
  final Map<String, int> _protectedDirectories = <String, int>{};

  /// Returns the only directory whose contents this service is allowed to
  /// manage. The default application RECORDS directory is already isolated;
  /// a user-selected directory receives a dedicated child directory.
  Future<Directory> getRecordDir() async {
    final defaultDir = await _defaultDirectoryResolver();
    final configuredPath = _configuredPathResolver()?.trim() ?? '';
    final Directory recordDir;

    if (configuredPath.isEmpty ||
        _samePath(configuredPath, defaultDir.path) ||
        isAndroidPrivatePath(configuredPath)) {
      recordDir = defaultDir;
    } else if (p.basename(p.normalize(configuredPath)).toLowerCase() ==
            managedFolderName.toLowerCase() &&
        await File(p.join(configuredPath, ownershipMarkerName)).exists()) {
      recordDir = Directory(configuredPath);
    } else {
      recordDir = Directory(p.join(configuredPath, managedFolderName));
    }

    await recordDir.create(recursive: true);
    await _ensureOwnershipMarker(recordDir);
    return recordDir;
  }

  bool _samePath(String left, String right) {
    final normalizedLeft = p.normalize(p.absolute(left));
    final normalizedRight = p.normalize(p.absolute(right));
    if (Platform.isWindows || Platform.isMacOS) {
      return normalizedLeft.toLowerCase() == normalizedRight.toLowerCase();
    }
    return normalizedLeft == normalizedRight;
  }

  Future<void> _ensureOwnershipMarker(Directory dir) async {
    final marker = File(p.join(dir.path, ownershipMarkerName));
    if (!await marker.exists()) {
      await marker.writeAsString('Pure Live managed recording directory.\n', flush: true);
    }
  }

  bool _isMarker(FileSystemEntity entity) => p.basename(entity.path) == ownershipMarkerName;

  /// Prevents cache cleanup from deleting an active recording or merge.
  void protectDirectory(String directoryPath) {
    final normalized = _normalizedAbsolute(directoryPath);
    if (normalized.isNotEmpty) {
      _protectedDirectories.update(normalized, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  void releaseDirectory(String directoryPath) {
    final normalized = _normalizedAbsolute(directoryPath);
    final count = _protectedDirectories[normalized] ?? 0;
    if (count <= 1) {
      _protectedDirectories.remove(normalized);
    } else {
      _protectedDirectories[normalized] = count - 1;
    }
  }

  bool isDirectoryProtected(String directoryPath) {
    final normalized = _normalizedAbsolute(directoryPath);
    return _protectedDirectories.keys.any((root) => _sameOrWithin(root, normalized));
  }

  Future<List<File>> _managedFiles({bool excludeProtected = false}) async {
    final dir = await getRecordDir();
    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          !_isMarker(entity) &&
          (!excludeProtected || !_isProtectedPath(entity.path))) {
        files.add(entity);
      }
    }
    return files;
  }

  /// Calculates managed recording size in MiB.
  Future<double> getCacheSize() async {
    var size = 0;
    for (final file in await _managedFiles()) {
      try {
        size += await file.length();
      } on FileSystemException {
        // A recorder may rotate a segment while the size snapshot is built.
      }
    }
    return size / 1024 / 1024;
  }

  /// Clears only files owned by Pure Live and preserves the ownership marker.
  Future<void> clearAll() async {
    final dir = await getRecordDir();
    final entities = await dir.list(recursive: true, followLinks: false).toList();
    for (final entity in entities.whereType<File>()) {
      if (_isMarker(entity) || _isProtectedPath(entity.path)) continue;
      try {
        await entity.delete();
      } on FileSystemException {
        // A file may be rotated or locked by the recorder.
      }
    }

    final directories = entities.whereType<Directory>().toList()
      ..sort((left, right) => right.path.length.compareTo(left.path.length));
    for (final directory in directories) {
      if (_isProtectedPath(directory.path)) continue;
      try {
        if (await directory.list(followLinks: false).isEmpty) await directory.delete();
      } on FileSystemException {
        // Keep non-empty or concurrently used directories.
      }
    }
  }

  /// Deletes one oldest managed recording file.
  ///
  /// Returns false when no deletable file exists, allowing callers to stop
  /// rather than spinning forever on an empty/nested directory.
  Future<bool> deleteOldest() async {
    final files = await _managedFiles(excludeProtected: true);
    if (files.isEmpty) return false;
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    try {
      await files.first.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Enforces the recording limit from one recursive snapshot.
  ///
  /// This avoids repeatedly scanning the full tree and guarantees bounded
  /// work even when files disappear or become locked during rotation.
  Future<void> enforceLimit({double maxMB = 2048}) async {
    final maxBytes = (maxMB.clamp(0, double.infinity) * 1024 * 1024).round();
    final files = await _managedFiles(excludeProtected: true);
    final entries = <({File file, int size, DateTime modified})>[];
    var totalBytes = 0;
    for (final file in files) {
      try {
        final stat = await file.stat();
        totalBytes += stat.size;
        entries.add((file: file, size: stat.size, modified: stat.modified));
      } on FileSystemException {
        // File rotation between list/stat is expected.
      }
    }
    entries.sort((a, b) => a.modified.compareTo(b.modified));

    for (final entry in entries) {
      if (totalBytes <= maxBytes) break;
      try {
        await entry.file.delete();
        totalBytes -= entry.size;
      } on FileSystemException {
        // Continue with the remaining finite snapshot instead of retrying the
        // same locked file indefinitely.
      }
    }
  }

  static bool isAndroidPrivatePath(String path, {bool? androidPlatform}) {
    if (!(androidPlatform ?? Platform.isAndroid)) return false;

    final normalized = p.normalize(path).replaceAll('\\', '/').toLowerCase();

    return RegExp(r'^/data/(?:user|user_de)/\d+(?:/|$)').hasMatch(normalized) ||
        RegExp(r'^/data/data(?:/|$)').hasMatch(normalized);
  }

  String _normalizedAbsolute(String value) {
    if (value.trim().isEmpty) return '';
    var normalized = p.normalize(p.absolute(value));
    if (Platform.isWindows || Platform.isMacOS) normalized = normalized.toLowerCase();
    return normalized;
  }

  bool _isProtectedPath(String value) {
    final candidate = _normalizedAbsolute(value);
    return _protectedDirectories.keys.any((root) => _sameOrWithin(root, candidate));
  }

  bool _sameOrWithin(String root, String candidate) =>
      root == candidate || p.isWithin(root, candidate);

  Future<String> getDisplayPath() async => (await getRecordDir()).path;

  Future<Directory> createRoomDir(String roomId) async {
    final roomDir = Directory(p.join((await getRecordDir()).path, roomId));
    await roomDir.create(recursive: true);
    return roomDir;
  }

  Future<Directory> getRoomDir({
    required String platform,
    required String nick,
    bool usePinyinForFolder = false,
  }) async {
    final base = await getRecordDir();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}';
    final safePlatform = usePinyinForFolder
        ? PathHelper.toSafePinyin(platform)
        : PathHelper.toSafeComponent(platform);
    final safeNick = usePinyinForFolder
        ? PathHelper.toSafePinyin(nick)
        : PathHelper.toSafeComponent(nick);
    final dir = Directory(p.join(base.path, safePlatform, safeNick, date, time));
    await dir.create(recursive: true);
    return dir;
  }
}
