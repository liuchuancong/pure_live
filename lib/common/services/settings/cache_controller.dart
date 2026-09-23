import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/plugins/cache_manager.dart';

typedef CacheDirectoryResolver = Future<List<Directory>> Function();
typedef CacheDirectoryPurger = Future<bool> Function(Directory directory);
typedef EncodedImageCacheClearer = Future<void> Function();
typedef DownloadDirectoryPathProvider = Future<String> Function();

int _measureDirectoryBytes(List<String> paths) {
  var total = 0;
  for (final path in paths.toSet()) {
    final directory = Directory(path);
    if (!directory.existsSync()) continue;
    try {
      for (final entity in directory.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += entity.lengthSync();
          } on FileSystemException {
            // A cache file may be replaced while the background scan runs.
          }
        }
      }
    } on FileSystemException {
      // A platform cache directory may disappear during an explicit clear.
    }
  }
  return total;
}

/// Defines the app-owned temporary directories shown by Cache & Data.
///
/// Recordings, downloads (including fonts and update packages), and IPTV data
/// are persistent user data and deliberately never enter this list.
abstract final class CacheStoragePolicy {
  static const localDirectoryNames = <String>[AppPathManager.dirImageCache, AppPathManager.dirEmojiCache];
}

/// Platform fallback used when the user has not selected a download directory.
Future<String> _platformDefaultDownloadPath() async {
  if (Platform.isAndroid) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return p.join(downloads.path, 'pure_live');
  }
  return (await AppPathManager().downloadDir).path;
}

Future<bool> _directoryExists(String path) async {
  if (path.isEmpty) return false;
  try {
    return await Directory(path).exists();
  } on FileSystemException {
    return false;
  }
}

class CacheClearResult {
  const CacheClearResult({required this.remainingSizeMB, required this.failedOperations});

  final double remainingSizeMB;
  final int failedOperations;

  bool get succeeded => failedOperations == 0;
}

class CacheController extends GetxController {
  CacheController({
    CacheDirectoryResolver? cacheDirectoryResolver,
    CacheDirectoryPurger? cacheDirectoryPurger,
    EncodedImageCacheClearer? encodedImageCacheClearer,
    DownloadDirectoryPathProvider? defaultDownloadDirectoryPathProvider,
  }) : _cacheDirectoryResolver = cacheDirectoryResolver ?? _defaultCacheDirectories,
       _cacheDirectoryPurger = cacheDirectoryPurger ?? _purgeDirectory,
       _encodedImageCacheClearer = encodedImageCacheClearer ?? _clearDefaultEncodedImageCache,
       _defaultDownloadDirectoryPathProvider = defaultDownloadDirectoryPathProvider ?? _platformDefaultDownloadPath;

  final CacheDirectoryResolver _cacheDirectoryResolver;
  final CacheDirectoryPurger _cacheDirectoryPurger;
  final EncodedImageCacheClearer _encodedImageCacheClearer;
  final DownloadDirectoryPathProvider _defaultDownloadDirectoryPathProvider;

  final cacheSizeMB = 0.0.obs;
  final refreshTurns = 0.0.obs;
  final imageCacheEpoch = 0.obs;
  final isScanning = false.obs;
  final isClearing = false.obs;
  final isRefreshingImages = false.obs;

  Timer? _thumbnailRefreshTimer;
  Worker? _thumbnailEnabledWorker;
  Worker? _thumbnailIntervalWorker;
  Future<double>? _cacheSizeScan;
  Future<CacheClearResult>? _cacheClearOperation;
  Future<void>? _imageRefreshOperation;

  bool get isBusy => isScanning.value || isClearing.value || isRefreshingImages.value;

  /// Persisted custom download directory. An empty value means the platform
  /// default directory is used.
  static const downloadDirectoryPrefKey = 'downloadDirectoryPath';

  /// True once the user answered the download-directory prompt, so a later
  /// update does not ask again after the default directory was chosen.
  static const downloadDirectoryDecisionPrefKey = 'downloadDirectoryDecisionMade';

  /// User-selected download directory for update packages, downloaded files and
  /// font bundles. Empty means the platform default is in use.
  final RxString downloadDirectory = RxString(readDownloadDirectoryPreference());

  /// Mirrors [downloadDirectoryDecisionPrefKey] for the settings UI.
  final RxBool downloadDirectoryDecided = RxBool(readDownloadDirectoryDecisionMade());

  bool get hasCustomDownloadDirectory => downloadDirectory.v.trim().isNotEmpty;

  /// Reads the persisted download directory without requiring an initialized
  /// Hive box, so startup-time font resolution can rely on it too.
  static String readDownloadDirectoryPreference() {
    try {
      return HivePrefUtil.getString(downloadDirectoryPrefKey)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool readDownloadDirectoryDecisionMade() {
    try {
      return HivePrefUtil.getBool(downloadDirectoryDecisionPrefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Platform default directory, used when the user keeps the default.
  static Future<Directory> defaultDownloadDirectory() async => Directory(await _platformDefaultDownloadPath());

  /// Resolves the effective download directory: the user-selected path when
  /// configured, otherwise the platform default.
  static Future<Directory> resolveDownloadDirectory() async {
    final custom = readDownloadDirectoryPreference();
    if (custom.isNotEmpty) return Directory(custom);
    return defaultDownloadDirectory();
  }

  /// Resolves the effective download directory and creates it when missing.
  static Future<Directory> ensureDownloadDirectory() async {
    final directory = await resolveDownloadDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// Proves the stored custom directory accepts writes.
  ///
  /// Android scoped storage can leave a previously selected folder readable
  /// but not writable; the update flow checks this before transferring bytes.
  /// An unset custom directory reports `true` so the platform default path is
  /// handled by the download dialog itself.
  static Future<bool> isCustomDownloadDirectoryUsable() async {
    final custom = readDownloadDirectoryPreference();
    if (custom.isEmpty) return true;
    try {
      final directory = Directory(custom);
      await directory.create(recursive: true);
      final probe = File(p.join(custom, '.pure_live_write_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether the app-update flow must ask the user where downloads go.
  ///
  /// The prompt appears when no usable directory exists yet: a stored custom
  /// directory disappeared, or the user has never answered and the default
  /// directory is not present either.
  Future<bool> needsDownloadDirectoryPrompt() async {
    final custom = downloadDirectory.v.trim();
    if (custom.isNotEmpty) return !await _directoryExists(custom);
    if (downloadDirectoryDecided.v) return false;
    return !await _directoryExists(await _defaultDownloadDirectoryPathProvider());
  }

  /// Stores a user-selected download directory and marks the prompt answered.
  Future<void> setDownloadDirectory(String directory) async {
    final normalized = directory.trim();
    if (normalized.isEmpty) return useDefaultDownloadDirectory();
    downloadDirectory.v = normalized;
    downloadDirectoryDecided.v = true;
    await HivePrefUtil.setPrefs({downloadDirectoryPrefKey: normalized, downloadDirectoryDecisionPrefKey: true});
    await HivePrefUtil.flush();
  }

  /// Keeps the platform default directory and remembers that choice.
  Future<void> useDefaultDownloadDirectory() async {
    downloadDirectory.v = '';
    downloadDirectoryDecided.v = true;
    await HivePrefUtil.setPrefs({downloadDirectoryPrefKey: '', downloadDirectoryDecisionPrefKey: true});
    await HivePrefUtil.flush();
  }

  static Future<List<Directory>> _defaultCacheDirectories() async {
    final manager = AppPathManager();
    return [
      for (final name in CacheStoragePolicy.localDirectoryNames) await manager.getDir(name),
      await CustomImageCacheManager.cacheDirectory(),
    ];
  }

  static Future<void> _clearDefaultEncodedImageCache() => CustomImageCacheManager.instance.emptyCache();

  static Future<bool> _purgeDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    final refreshConfig = Get.find<RefreshConfigController>();
    _thumbnailEnabledWorker = ever(refreshConfig.autoRefreshThumbnails, (_) => _scheduleThumbnailRefresh());
    _thumbnailIntervalWorker = ever(refreshConfig.thumbnailRefreshInterval, (_) => _scheduleThumbnailRefresh());
    _scheduleThumbnailRefresh();
  }

  void _scheduleThumbnailRefresh() {
    _thumbnailRefreshTimer?.cancel();
    final config = Get.find<RefreshConfigController>();
    if (!config.autoRefreshThumbnails.value) return;
    final minutes = config.thumbnailRefreshInterval.value.clamp(5, 360);
    _thumbnailRefreshTimer = Timer.periodic(Duration(minutes: minutes), (_) => unawaited(_refreshImagesInBackground()));
  }

  Future<void> _refreshImagesInBackground() async {
    try {
      await refreshImageCache(refreshVisible: false);
    } catch (error) {
      debugPrint('Scheduled thumbnail cache refresh failed: $error');
    }
  }

  Future<double> getCacheSize() async {
    final clearing = _cacheClearOperation;
    if (clearing != null) {
      await clearing;
      return cacheSizeMB.value;
    }
    final refreshing = _imageRefreshOperation;
    if (refreshing != null) {
      await refreshing;
      return cacheSizeMB.value;
    }

    final active = _cacheSizeScan;
    if (active != null) return active;

    late final Future<double> operation;
    if (!isClosed) isScanning.value = true;
    operation = _scanCacheSize().whenComplete(() {
      if (identical(_cacheSizeScan, operation)) {
        _cacheSizeScan = null;
        if (!isClosed) isScanning.value = false;
      }
    });
    _cacheSizeScan = operation;
    return operation;
  }

  Future<double> _scanCacheSize({List<Directory>? directories}) async {
    final roots = _uniqueDirectories(directories ?? await _cacheDirectoryResolver());
    final totalSizeBytes = await compute(
      _measureDirectoryBytes,
      roots.map((directory) => directory.absolute.path).toList(growable: false),
    );
    final size = totalSizeBytes / 1024 / 1024;
    if (!isClosed) cacheSizeMB.value = size;
    return size;
  }

  Future<CacheClearResult> clearCache() {
    final active = _cacheClearOperation;
    if (active != null) return active;

    late final Future<CacheClearResult> operation;
    if (!isClosed) isClearing.value = true;
    operation = _clearCache().whenComplete(() {
      if (identical(_cacheClearOperation, operation)) {
        _cacheClearOperation = null;
        if (!isClosed) isClearing.value = false;
      }
    });
    _cacheClearOperation = operation;
    return operation;
  }

  Future<CacheClearResult> _clearCache() async {
    final refreshing = _imageRefreshOperation;
    if (refreshing != null) {
      try {
        await refreshing;
      } catch (error) {
        debugPrint('Previous thumbnail cache refresh failed before clear: $error');
      }
    }
    final activeScan = _cacheSizeScan;
    if (activeScan != null) {
      try {
        await activeScan;
      } catch (error) {
        debugPrint('Previous cache size scan failed before clear: $error');
      }
    }

    var failedOperations = 0;
    try {
      await _encodedImageCacheClearer();
    } catch (error) {
      failedOperations++;
      debugPrint('Failed to clear the encoded image cache: $error');
    }

    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    } catch (error) {
      failedOperations++;
      debugPrint('Failed to clear the in-memory image cache: $error');
    }

    List<Directory>? directories;
    try {
      directories = _uniqueDirectories(await _cacheDirectoryResolver());
    } catch (error) {
      failedOperations++;
      debugPrint('Failed to resolve local cache directories: $error');
    }

    for (final directory in directories ?? const <Directory>[]) {
      var cleared = false;
      try {
        cleared = await _cacheDirectoryPurger(directory);
      } catch (error) {
        debugPrint('Failed to clear cache directory ${directory.path}: $error');
      }
      if (!cleared) {
        failedOperations++;
        debugPrint('Failed to clear cache directory ${directory.path}');
      }
    }

    var remainingSizeMB = cacheSizeMB.value;
    if (directories != null) {
      try {
        remainingSizeMB = await _scanCacheSize(directories: directories);
      } catch (error) {
        failedOperations++;
        debugPrint('Failed to refresh cache size after clearing: $error');
      }
    }
    if (!isClosed) imageCacheEpoch.value++;
    return CacheClearResult(remainingSizeMB: remainingSizeMB, failedOperations: failedOperations);
  }

  /// Drop encoded thumbnails. A manual action also rolls visible image
  /// providers to a new bounded cache key while retaining their old pixels.
  Future<void> refreshImageCache({bool refreshVisible = true}) {
    final active = _imageRefreshOperation;
    if (active != null) return active;

    late final Future<void> operation;
    if (!isClosed) isRefreshingImages.value = true;
    operation = _refreshImageCache(refreshVisible: refreshVisible).whenComplete(() {
      if (identical(_imageRefreshOperation, operation)) {
        _imageRefreshOperation = null;
        if (!isClosed) isRefreshingImages.value = false;
      }
    });
    _imageRefreshOperation = operation;
    return operation;
  }

  Future<void> _refreshImageCache({required bool refreshVisible}) async {
    final clearing = _cacheClearOperation;
    if (clearing != null) await clearing;
    final activeScan = _cacheSizeScan;
    if (activeScan != null) {
      try {
        await activeScan;
      } catch (error) {
        debugPrint('Previous cache size scan failed before thumbnail refresh: $error');
      }
    }

    await _encodedImageCacheClearer();
    // Live streams retain their current pixels so a manual refresh does not
    // produce a grid-wide placeholder and decode storm.
    PaintingBinding.instance.imageCache.clear();
    if (!refreshVisible || isClosed) return;
    imageCacheEpoch.value++;
    await _scanCacheSize();
  }

  Future<void> handleManualRefresh() async {
    refreshTurns.value += 1.0;
    await getCacheSize();
  }

  List<Directory> _uniqueDirectories(Iterable<Directory> directories) {
    final unique = <String, Directory>{};
    for (final directory in directories) {
      var key = directory.absolute.path.replaceAll('\\', '/');
      if (Platform.isWindows || Platform.isMacOS) key = key.toLowerCase();
      unique.putIfAbsent(key, () => directory);
    }
    return unique.values.toList(growable: false);
  }

  @override
  void onClose() {
    _thumbnailRefreshTimer?.cancel();
    _thumbnailEnabledWorker?.dispose();
    _thumbnailIntervalWorker?.dispose();
    super.onClose();
  }
}
