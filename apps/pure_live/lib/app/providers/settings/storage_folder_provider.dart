import 'dart:io' show Directory, File, FileSystemException;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

import 'package:pure_live/infrastructure/infrastructure.dart' show AppPaths;

/// A folder the viewer may move to a directory of their own.
///
/// Everything except the data tree: the database of settings, accounts and
/// history follows the deployment and never moves, while media, exports and
/// the clearable cover cache are the viewer's call. The default for each one
/// comes from the storage layout, so "reset" is always the device's answer.
enum StorageFolder {
  /// Finished videos.
  videos(DsIcons.film),

  /// Finished songs.
  music(DsIcons.music),

  /// Saved wallpapers.
  wallpapers(DsIcons.image),

  /// Exported lyrics.
  lyrics(DsIcons.captions),

  /// Installers the update check fetched.
  updates(DsIcons.download),

  /// Background media the viewer imported.
  backgrounds(DsIcons.wallpaper),

  /// Downloaded font files.
  fonts(DsIcons.type),

  /// The clearable cover and avatar cache.
  cache(DsIcons.database);

  StorageFolder(this.icon);

  /// The folder's glyph in the settings row.
  final DsIconData icon;

  /// The preference key holding the viewer's choice; absent means the
  /// device default.
  String get prefKey => 'storage.folder.$name';

  /// Whether a new location lands only on the next start: the cover cache is
  /// rebuilt by the boot, so it cannot move under a running cache manager.
  bool get needsRestart => this == cache;
}

/// The viewer's chosen folders, keyed by [StorageFolder]. A folder that is
/// absent follows the device default, so a reset is a removal, not a copy of
/// the default path.
final class StorageFolderOverrides extends Notifier<Map<StorageFolder, String>> {
  @override
  Map<StorageFolder, String> build() => readStorageFolderOverrides();

  /// Stores [path] for [folder] after proving it accepts writes; false means
  /// nothing changed and the caller offers the permission hint.
  Future<bool> set(StorageFolder folder, String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) return false;
    if (!await canWriteFolder(normalized)) return false;
    state = {...state, folder: normalized};
    try {
      await StoragePrefs.setString(folder.prefKey, normalized);
    } on Object {
      // A preference; a closed store loses it.
    }
    return true;
  }

  /// Drops the choice so the folder follows the device again.
  Future<void> reset(StorageFolder folder) async {
    state = {...state}..remove(folder);
    try {
      await StoragePrefs.remove(folder.prefKey);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The stored choices, read straight from the preferences: the notifier's
/// first answer and the boot's cache root both come from here, so a folder
/// moved in settings and a folder moved across a restart agree.
Map<StorageFolder, String> readStorageFolderOverrides() {
  final overrides = <StorageFolder, String>{};
  for (final folder in StorageFolder.values) {
    try {
      final stored = (StoragePrefs.getString(folder.prefKey) ?? '').trim();
      if (stored.isNotEmpty) overrides[folder] = stored;
    } on Object {
      // A closed store answers with the defaults.
    }
  }
  return overrides;
}

/// Proves [path] accepts writes. Android scoped storage can hand back a
/// folder that is readable but not writable, so the probe is a real file.
Future<bool> canWriteFolder(String path) async {
  try {
    final directory = Directory(path);
    await directory.create(recursive: true);
    final probe = File(p.join(directory.path, '.pure_live_write_probe'));
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// The folders in force: the storage layout's defaults with the viewer's
/// choices laid over them.
final class AppFolders {
  /// The folders over [paths], with [overrides] winning where present.
  const AppFolders(this.paths, this.overrides);

  /// The device default layout.
  final AppPaths paths;

  /// The viewer's chosen folders.
  final Map<StorageFolder, String> overrides;

  Directory _pick(StorageFolder folder, Directory fallback) {
    final custom = overrides[folder];
    return custom == null || custom.isEmpty ? fallback : Directory(custom);
  }

  /// The persistent data area: settings, databases, history.
  Directory get data => Directory(paths.areas.data.path);

  /// The viewer-facing product folder inside the download root.
  Directory get downloads => paths.downloads;

  /// Finished videos.
  Directory get videos => _pick(StorageFolder.videos, paths.videos);

  /// Finished songs.
  Directory get music => _pick(StorageFolder.music, paths.music);

  /// Saved wallpapers.
  Directory get wallpapers => _pick(StorageFolder.wallpapers, paths.wallpapers);

  /// Exported lyrics.
  Directory get lyrics => _pick(StorageFolder.lyrics, paths.lyrics);

  /// Installers the update check fetched.
  Directory get updates => _pick(StorageFolder.updates, paths.updates);

  /// Background media, and the thumbnails sampled from it.
  Directory get backgrounds => _pick(StorageFolder.backgrounds, paths.backgrounds);

  /// The thumbnails under [backgrounds].
  Directory get backgroundThumbs => Directory(p.join(backgrounds.path, 'thumbs'));

  /// Downloaded fonts.
  Directory get fonts => _pick(StorageFolder.fonts, paths.fonts);

  /// Live recordings, when the viewer has no folder of their own picked.
  Directory get recordings => paths.recordings;

  /// The clearable cache area: the device default unless the viewer moved it.
  Directory get cacheRoot => _pick(StorageFolder.cache, paths.cacheRoot);

  /// The clearable cover and avatar cache.
  Directory get imageCache => Directory(p.join(cacheRoot.path, 'images'));

  /// The HEIC cover cache; it sits under [imageCache], so one folder holds
  /// every cached picture and the cap prunes them together.
  Directory get covers => Directory(p.join(imageCache.path, 'covers'));

  /// The backup files the viewer exports and imports.
  Directory get backups => paths.backups;
}
