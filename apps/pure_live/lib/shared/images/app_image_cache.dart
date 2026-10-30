import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart' show CachedNetworkImageProvider;
import 'package:file/file.dart' as file;
import 'package:file/local.dart' as file_local;
import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The app's one disk cache for network images: covers, avatars, logos.
///
/// Every image the app draws from the network goes through [cachedImage],
/// which hands the [CachedNetworkImageProvider] this manager — so the bytes
/// live in one folder, age out after the manager's stale period, and can be
/// measured, cleared and capped from the settings surface.
Directory? _appCacheRoot;
CacheManager? _appCache;

/// The app-wide manager. Built on first use, so the boot can point it at the
/// storage layout's cache folder ([installImageCacheRoot]) before any image
/// asks for it.
CacheManager get appImageCache => _appCache ??= CacheManager(_config());

/// The folder the app-wide manager keeps its images in, once the boot has
/// installed one. A module that caches derived files of its own — a converted
/// cover, say — writes them under here so the settings page's one cache folder
/// shows, measures and caps everything.
Directory? get installedImageCacheDirectory => _appCacheRoot;

/// Points the shared cache at [directory] — the storage layout's cache
/// folder, moved by the viewer or not. A different folder drops the manager
/// so the next image rebuilds it against the new one.
void installImageCacheRoot(Directory directory) {
  if (_appCacheRoot?.path == directory.path) return;
  _appCacheRoot = directory;
  _appCache = null;
}

Config _config() {
  final root = _appCacheRoot;
  return Config(
    _cacheFolder,
    fileSystem: root == null ? IOFileSystem(_cacheFolder) : _RootedFileSystem(root),
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 320,
  );
}

/// Keeps the cache's files under a folder the app chose, with the same
/// layout `flutter_cache_manager` gives its own temporary tree.
final class _RootedFileSystem implements FileSystem {
  const _RootedFileSystem(this.root);

  final Directory root;

  @override
  Future<file.File> createFile(String name) async {
    final target = const file_local.LocalFileSystem().file(p.join(root.path, name));
    await target.parent.create(recursive: true);
    return target;
  }
}

/// The room windows' image cache, when one is installed. A room window
/// gets a folder and a JSON metadata file of its own, so two engines never
/// share cache bookkeeping.
CacheManager? _roomWindowImageCache;

/// The room window's cache folder, when one is installed: its settings
/// surface measures and prunes that folder, not the app-wide one this
/// engine never draws.
Directory? _roomWindowCacheDirectory;

/// Points the shared image cache at [directory] for this engine. Call it
/// from a room window's boot, before the first image is asked for.
Future<void> installWindowImageCache(Directory directory) async {
  await directory.create(recursive: true);
  _roomWindowCacheDirectory = directory;
  // The default file system for [CacheManager] puts files under the temp
  // directory under the cache key; the key therefore carries the room's
  // folder. The metadata goes beside them instead of a shared database.
  final key = p.join('pure_live_window_cache', p.basename(directory.path));
  _roomWindowImageCache = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 120,
      repo: JsonCacheInfoRepository.withFile(File(p.join(directory.path, 'metadata.json'))),
    ),
  );
}

/// The folder the default manager keeps its image files in, under the
/// temporary directory.
const String _cacheFolder = 'pure_live_image_cache';

/// Creates the default cache folder before the first image asks for it.
///
/// `flutter_cache_manager`'s file system creates the folder lazily on each
/// `createFile`; on Windows several image loads in one frame can race that
/// creation and surface a `PathAccessException`. The boot owns the folder
/// first, so the per-file path only ever sees an existing directory.
Future<void> prepareImageCache() async {
  final directory = await _cacheDirectory();
  if (directory == null) return;
  try {
    await directory.create(recursive: true);
  } on Object {
    // A cache that cannot be created costs images their disk copy, not the app.
  }
}

/// The extensions the manager writes (webp included); only these are
/// counted and pruned.
const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'tga', 'cur', 'ico'};

/// A network image through the engine's own cache — the room window's
/// when one is installed, the app's otherwise; [width]/[height] ask for a
/// decode box and, where the server can, a fitting copy.
ImageProvider cachedImage(String url, {int? width, int? height, String? cacheKey}) => CachedNetworkImageProvider(
  url,
  cacheManager: _roomWindowImageCache ?? appImageCache,
  maxWidth: width,
  maxHeight: height,
  cacheKey: cacheKey,
);

/// The cache's image folder, when the platform has a temporary directory.
Future<Directory?> _cacheDirectory() async {
  final root = _appCacheRoot;
  if (root != null) return root;
  try {
    final temp = await getTemporaryDirectory();
    return Directory(p.join(temp.path, _cacheFolder));
  } on Object {
    return null;
  }
}

/// The folder this engine's images actually live in: the room window's own
/// when one is installed, the app-wide one otherwise.
Future<Directory?> _activeCacheDirectory() async => _roomWindowCacheDirectory ?? await _cacheDirectory();

/// The image files under [root].
List<(File, DateTime, int)> _imageFiles(Directory root) {
  final files = <(File, DateTime, int)>[];
  try {
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      if (!_imageExtensions.contains(p.extension(entity.path).replaceFirst('.', '').toLowerCase())) {
        continue;
      }
      files.add((entity, entity.lastModifiedSync(), entity.lengthSync()));
    }
  } on Object {
    // A file vanishing mid-walk just means it is not counted.
  }
  return files;
}

/// The bytes the image cache occupies on disk.
Future<int> imageCacheBytes() async {
  final directory = await _activeCacheDirectory();
  if (directory == null || !directory.existsSync()) {
    return 0;
  }
  return _imageFiles(directory).fold<int>(0, (sum, entry) => sum + entry.$3);
}

/// Deletes every cached image (the manager's own bookkeeping goes with it).
///
/// A room window installs its own manager; clearing there must empty that
/// engine's cache too, otherwise the scheduled cover refresh would keep the
/// only images that window actually draws.
Future<void> clearImageCache() async {
  await appImageCache.emptyCache();
  final roomWindow = _roomWindowImageCache;
  if (roomWindow != null) await roomWindow.emptyCache();
  // The manager only knows the bytes it fetched, and the folder it shares has
  // derived files too — a converted HEIC cover, for one. The settings page
  // measures this folder, so clearing it has to empty it.
  final directory = await _activeCacheDirectory();
  if (directory == null) return;
  for (final (image, _, _) in _imageFiles(directory)) {
    try {
      image.deleteSync();
    } on Object {
      // An image still on screen keeps its file; the next clear tries again.
    }
  }
}

/// Deletes the oldest cached images until the images fit [maxBytes]; a
/// limit of zero or less means no pruning. Answers the bytes left.
Future<int> enforceImageCacheLimit(int maxBytes) async {
  if (maxBytes <= 0) {
    return await imageCacheBytes();
  }
  final directory = await _activeCacheDirectory();
  if (directory == null || !directory.existsSync()) {
    return 0;
  }
  final files = _imageFiles(directory);
  var total = files.fold<int>(0, (sum, entry) => sum + entry.$3);
  if (total <= maxBytes) {
    return total;
  }
  files.sort((a, b) => a.$2.compareTo(b.$2));
  for (final (file, _, size) in files) {
    if (total <= maxBytes) {
      break;
    }
    try {
      file.deleteSync();
      total -= size;
    } on Object {
      // A locked file keeps its share; the next start tries again.
    }
  }
  return total;
}

/// The configured automatic limit in megabytes; 0 means off.
int imageCacheLimitMb() {
  try {
    return StoragePrefs.getInt('cache.maxMB') ?? 0;
  } on Object {
    return 0;
  }
}

/// Stores the automatic limit (megabytes, 0 = off).
Future<void> storeImageCacheLimitMb(int megabytes) async {
  try {
    if (megabytes <= 0) {
      await StoragePrefs.remove('cache.maxMB');
    } else {
      await StoragePrefs.setInt('cache.maxMB', megabytes);
    }
  } on Object {
    // A preference; a closed store loses it.
  }
}

/// Prunes to the configured limit; the boot runs this once.
Future<void> enforceConfiguredImageCacheLimit() async {
  final limit = imageCacheLimitMb();
  if (limit > 0) {
    await enforceImageCacheLimit(limit * 1024 * 1024);
  }
}

/// A byte count in the settings surface's words: B, KB or MB, one decimal.
String formatCacheSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
