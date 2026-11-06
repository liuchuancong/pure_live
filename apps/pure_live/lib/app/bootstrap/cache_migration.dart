import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart' show AppFolders;

/// Carries the pre-`live_cache` layout into the new one, once.
///
/// The old tree was `<cacheRoot>/images/`, with `flutter_cache_manager`'s
/// files, its metadata and the hongguo renditions inside. None of it is worth
/// migrating — it is re-fetchable — except the recording frames, which the
/// library regenerates from local files and would otherwise lose until the
/// next scan. Those move to `<cacheRoot>/recording_covers/`; the rest of the
/// old tree is deleted.
///
/// A failure here costs cache bytes, never the boot.
Future<void> migrateLegacyImageCache(AppFolders folders) async {
  final log = appLog.forCategory('cache');
  final legacy = Directory(p.join(folders.cacheRoot.path, 'images'));
  try {
    if (legacy.existsSync()) {
      final legacyCovers = Directory(p.join(legacy.path, 'recording_covers'));
      if (legacyCovers.existsSync()) {
        await _moveTree(legacyCovers, folders.recordingCovers);
      }
      await legacy.delete(recursive: true);
    }
  } on Object catch (error) {
    log.warning('legacy image cache could not be removed', fields: {'error': '$error'});
  }
  try {
    final temp = await getTemporaryDirectory();
    for (final name in const ['pure_live_image_cache', 'pure_live_hongguo_covers']) {
      final folder = Directory(p.join(temp.path, name));
      if (folder.existsSync()) {
        await folder.delete(recursive: true);
      }
    }
  } on Object catch (error) {
    log.warning('legacy temporary cache could not be removed', fields: {'error': '$error'});
  }
}

Future<void> _moveTree(Directory source, Directory target) async {
  await target.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final destination = File(p.join(target.path, p.relative(entity.path, from: source.path)));
    await destination.parent.create(recursive: true);
    if (destination.existsSync()) {
      continue;
    }
    try {
      await entity.rename(destination.path);
    } on FileSystemException {
      // A folder the viewer moved across volumes cannot rename; copy the
      // bytes instead and let the old tree be deleted.
      await entity.copy(destination.path);
    }
  }
}
