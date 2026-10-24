import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The app's one disk cache for network images: covers, avatars, logos.
///
/// Every image the app draws from the network goes through [cachedImage],
/// which hands the [CachedNetworkImageProvider] this manager — so the bytes
/// live in one folder, age out after the manager's stale period, and can be
/// measured, cleared and capped from the settings surface. (Before this,
/// images used `Image.network`: memory only, nothing on disk to manage.)
final DefaultCacheManager appImageCache = DefaultCacheManager(
  stalePeriod: const Duration(days: 30),
  maxNrOfCacheObjects: 320,
);

/// The folder the manager keeps its image files in, under the temporary
/// directory. Its `hive` subfolder is metadata and is never counted or
/// pruned — deleting it would corrupt the manager's bookkeeping.
const String _cacheFolder = 'cached_network_image_ce';
const String _metadataFolder = 'hive';

/// The extensions the manager writes (webp included); only these are
/// counted and pruned.
const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'tga', 'cur', 'ico'};

/// A network image through [appImageCache]; [width]/[height] ask for a
/// decode box and, where the server can, a fitting copy.
ImageProvider cachedImage(String url, {int? width, int? height, String? cacheKey}) =>
    CachedNetworkImageProvider(url, cacheManager: appImageCache, maxWidth: width, maxHeight: height, cacheKey: cacheKey);

/// The cache's image folder, when the platform has a temporary directory.
Future<Directory?> _cacheDirectory() async {
  try {
    final temp = await getTemporaryDirectory();
    return Directory(p.join(temp.path, _cacheFolder));
  } on Object {
    return null;
  }
}

/// The image files under [root], skipping the metadata folder.
List<(File, DateTime, int)> _imageFiles(Directory root) {
  final files = <(File, DateTime, int)>[];
  try {
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final parts = p.split(p.relative(entity.path, from: root.path));
      if (parts.contains(_metadataFolder)) {
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
  final directory = await _cacheDirectory();
  if (directory == null || !directory.existsSync()) {
    return 0;
  }
  return _imageFiles(directory).fold<int>(0, (sum, entry) => sum + entry.$3);
}

/// Deletes every cached image (the manager's own bookkeeping goes with it).
Future<void> clearImageCache() => appImageCache.emptyCache();

/// Deletes the oldest cached images until the images fit [maxBytes]; a
/// limit of zero or less means no pruning. Answers the bytes left.
Future<int> enforceImageCacheLimit(int maxBytes) async {
  if (maxBytes <= 0) {
    return await imageCacheBytes();
  }
  final directory = await _cacheDirectory();
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
