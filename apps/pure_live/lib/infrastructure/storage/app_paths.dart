import 'dart:io' show Directory;

import 'package:path/path.dart' as p;

import 'package:pure_live/infrastructure/storage/storage_paths.dart' show StoragePaths;

/// Every folder the app writes, named once.
///
/// [StoragePaths] answers which *area* a file belongs to — persistent data,
/// clearable cache, the viewer's download folder, exports; this class answers
/// which *folder* inside that area, so a subsystem asks for [logs] or
/// [videos] instead of joining a segment of its own and drifting from its
/// neighbours in a bug report.
///
/// The layout, for a host whose namespace is `ns`:
///
/// * data — `logs/`, `background/` with `background/thumbs/`, `fonts/`.
/// * cache — `images/` for network images, `images/covers/` for platform
///   covers, both segments of [cacheRoot] so a viewer who moves the cache
///   moves every cached picture with it.
/// * downloads — `ns/videos`, `ns/recordings`, `ns/music`, `ns/wallpapers`,
///   `ns/video_wallpapers`, `ns/lyrics`, `ns/updates` under the platform's
///   download root; the namespace keeps the product's files out of the
///   viewer's own tree in a shared folder, and a `<data>/downloads` root
///   stands in where the platform offers no download folder.
/// * exports — `backups/` for the backup files the viewer keeps.
///
/// Directories are not created here: whoever writes calls
/// `create(recursive: true)` at that point, so a folder that is never used
/// never appears on disk.
final class AppPaths {
  /// The folders over [areas].
  const AppPaths(this.areas);

  /// The resolved areas this vocabulary is built on.
  final StoragePaths areas;

  /// The identity shared roots are namespaced with, from the runtime
  /// snapshot — the same fact the storage policy names its cache tree after.
  String get namespace => areas.environment.runtime.appNamespace;

  /// The viewer-facing folder inside the download root. Null is not a case:
  /// a platform without a download folder reads the data tree's own
  /// `downloads/` segment, the fallback the download-root setting prints.
  Directory get downloads =>
      Directory(p.join(areas.downloads?.path ?? p.join(areas.data.path, 'downloads'), namespace));

  /// [folder] under the download root the viewer effectively uses: their own
  /// folder when the download setting names one, the default [downloads]
  /// tree otherwise.
  Directory downloadFolder(String folder, {String? customRoot}) =>
      Directory(p.join(customRoot == null || customRoot.isEmpty ? downloads.path : customRoot, folder));

  /// Finished videos, one folder per course of action rather than a flat
  /// pile next to the viewer's own files.
  Directory get videos => downloadFolder('videos');

  /// Finished songs.
  Directory get music => downloadFolder('music');

  /// Wallpapers the viewer saved.
  Directory get wallpapers => downloadFolder('wallpapers');

  /// Video wallpapers — the clips. They keep a folder of their own beside the
  /// pictures because the manager filters by kind and a clip is not something
  /// the viewer sets as a desktop picture by the same gesture.
  Directory get videoWallpapers => downloadFolder('video_wallpapers');

  /// Lyrics exported beside the song they belong to.
  Directory get lyrics => downloadFolder('lyrics');

  /// Installers the update check fetched.
  Directory get updates => downloadFolder('updates');

  /// Live recordings, when the viewer has no folder of their own picked:
  /// big media files, so they sit with the other downloads.
  Directory get recordings => downloadFolder('recordings');

  /// The log files and their rotation.
  Directory get logs => Directory(p.join(areas.data.path, 'logs'));

  /// Background media the viewer imported, and the thumbnails the tone
  /// sampler derives from it.
  Directory get backgrounds => Directory(p.join(areas.data.path, 'background'));

  /// The thumbnails under [backgrounds].
  Directory get backgroundThumbs => Directory(p.join(backgrounds.path, 'thumbs'));

  /// Downloaded font files.
  Directory get fonts => Directory(p.join(areas.data.path, 'fonts'));

  /// The clearable cache area: everything under it can be deleted and
  /// fetched again, so it is the one folder the viewer may point elsewhere.
  Directory get cacheRoot => Directory(areas.cache.path);

  /// Re-fetchable network images: the cover and avatar cache.
  Directory get imageCache => Directory(p.join(cacheRoot.path, 'images'));

  /// Platform covers the hongguo surfaces fetched for themselves; they live
  /// under [imageCache] so one folder holds every cached picture.
  Directory get covers => Directory(p.join(imageCache.path, 'covers'));

  /// The backup files the viewer exports and imports.
  Directory get backups => Directory(p.join(areas.exports?.path ?? p.join(areas.data.path, 'exports'), 'backups'));
}
