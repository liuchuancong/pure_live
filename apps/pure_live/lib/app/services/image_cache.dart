import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';

/// The picture cache's own answers — the reference's 当前缓存大小 and
/// 清除本地缓存 rows.
///
/// The thumbnails every room card draws go through `cached_network_image`,
/// which keeps them in one disk folder; that folder *is* the app's cache in
/// the reference's sense of the word (its "clear local cache" empties the
/// same images), so size and clear are measured on the cache manager itself
/// rather than on a bookkeeping of our own. The automatic clear is the same
/// folder, emptied when the stored ceiling is crossed — checked after each
/// app resume, the moment a browsing session has just filled it.
abstract final class ImageCache {
  /// The cache directory's byte total; null when it cannot be measured (a
  /// cache not yet created is empty, and an error reading it is unknown).
  static Future<int?> sizeBytes() async {
    final directory = await _directory();
    return await _walk(directory);
  }

  /// The cache folder the default manager was configured with — the same
  /// `flutter_image_cache` store name, resolved the way the package resolves
  /// it (`<base>/flutter_image_cache/<store>`).
  static Future<Directory?> _directory() async {
    try {
      final base = await getTemporaryDirectory();
      return Directory(p.join(base.path, DefaultCacheManager().config.cacheKey));
    } on Object {
      return null;
    }
  }

  static Future<int?> _walk(Directory? directory) async {
    if (directory == null || !directory.existsSync()) {
      return 0;
    }
    var total = 0;
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on Object {
          // A file that vanished mid-count is counted as nothing.
        }
      }
    }
    return total;
  }

  /// Empties the picture cache; the count of bytes it held, null when the
  /// cache could not be read or cleared.
  static Future<int?> clear() async {
    try {
      final size = await sizeBytes();
      await DefaultCacheManager().emptyCache();
      return size;
    } on Object {
      return null;
    }
  }

  /// The stored ceiling's prune, run once per app resume by the shell's
  /// watcher. Returns whether a prune happened.
  static Future<bool> enforceLimit(Ref ref) async {
    final preferences = ref.read(appPreferencesProvider);
    if (!preferences.cacheAutoClear || preferences.cacheMaxMB <= 0) {
      return false;
    }
    final bytes = await sizeBytes();
    if (bytes == null || bytes <= preferences.cacheMaxMB * 1024 * 1024) {
      return false;
    }
    await clear();
    return true;
  }

  /// Cover-refresh sweeping: with 自动刷新封面 on and 保存旧的缩略图 off, the
  /// superseded bucket's pictures are dropped so the cache does not stack a
  /// window of every room's face. The package's own prune is age/count based
  /// and does not know the refresh was a re-pull, so this deletes what the
  /// cache folder has held past two intervals — the walk is confined to the
  /// manager's own `cacheKey` directory.
  static Future<int> sweepSupersededBuckets(Ref ref) async {
    final preferences = ref.read(appPreferencesProvider);
    if (!preferences.autoRefreshThumbnails || preferences.thumbnailKeepOldFiles) {
      return 0;
    }
    final directory = await _directory();
    if (directory == null || !directory.existsSync()) {
      return 0;
    }
    final window = preferences.thumbnailRefreshMinutes.clamp(5, 360);
    var removed = 0;
    // The stored pictures age out of their bucket one window at a time; a
    // file older than two windows is a face some room has already outlived.
    final cutoff = DateTime.now().subtract(Duration(minutes: window * 2));
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      try {
        if (!entity.statSync().modified.isAfter(cutoff)) {
          await entity.delete();
          removed += 1;
        }
      } on Object {
        // A locked or vanished file is the next sweep's problem.
      }
    }
    return removed;
  }
}

/// The resume-time prune of the stored cap; the shell runs it while it is up,
/// the same lifecycle the clipboard watcher rides.
final class CacheAutoClearWatcher {
  /// The watcher over the app's provider graph.
  new(this._ref);

  final Ref _ref;
  AppLifecycleListener? _listener;
  bool _busy = false;

  /// Starts watching; idempotent.
  void start() {
    _listener ??= AppLifecycleListener(
      onResume: () async {
        if (_busy) {
          return;
        }
        _busy = true;
        try {
          await ImageCache.sweepSupersededBuckets(_ref);
          await ImageCache.enforceLimit(_ref);
        } finally {
          _busy = false;
        }
      },
    );
  }

  /// Stops watching.
  void dispose() {
    _listener?.dispose();
    _listener = null;
  }
}

/// One watcher per process; the shell starts it and stops it with itself.
///
/// riverpod's provider type is not exported by flutter_riverpod, so the
/// variable annotation the lint asks for cannot be written.
// ignore: specify_nonobvious_property_types
final cacheAutoClearWatcherProvider = Provider.autoDispose<CacheAutoClearWatcher>((ref) {
  final watcher = CacheAutoClearWatcher(ref);
  ref.onDispose(watcher.dispose);
  return watcher;
});
