import 'dart:async' show unawaited;
import 'dart:io' show Directory, File, FileSystemException;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

import 'package:pure_live/infrastructure/infrastructure.dart' show AppPaths;

/// A folder the viewer may move to a directory of their own.
///
/// Everything except the data tree: the database of settings, accounts and
/// history follows the deployment and never moves, while media, exports, the
/// log files, the recordings and the clearable cover cache are the viewer's
/// call. The default for each one comes from the storage layout, so "reset" is
/// always the device's answer.
enum StorageFolder {
  /// Finished videos.
  videos(DsIcons.film),

  /// Live recordings the app took.
  recordings(DsIcons.folderVideo),

  /// Finished songs.
  music(DsIcons.music),

  /// Saved wallpapers.
  wallpapers(DsIcons.image),

  /// Saved video wallpapers — the clips.
  videoWallpapers(DsIcons.video),

  /// Exported lyrics.
  lyrics(DsIcons.captions),

  /// Installers the update check fetched.
  updates(DsIcons.download),

  /// Background media the viewer imported, still and video alike.
  backgrounds(DsIcons.wallpaper),

  /// Downloaded font files.
  fonts(DsIcons.type),

  /// The rotating log files.
  logs(DsIcons.terminal),

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
///
/// Two of these folders had their own row and their own key before they joined
/// the list; the first read of a folder with nothing stored here takes over
/// that choice and retires the old keys, so a viewer who moved their logs or
/// their recordings keeps them moved without a file being touched.
Map<StorageFolder, String> readStorageFolderOverrides() {
  final overrides = <StorageFolder, String>{};
  for (final folder in StorageFolder.values) {
    try {
      final stored = (StoragePrefs.getString(folder.prefKey) ?? '').trim();
      if (stored.isNotEmpty) {
        overrides[folder] = stored;
        continue;
      }
      final legacy = _legacyChoiceFor(folder);
      if (legacy == null) continue;
      overrides[folder] = legacy.path;
      unawaited(_adoptLegacyChoice(folder, legacy));
    } on Object {
      // A closed store answers with the defaults.
    }
  }
  return overrides;
}

/// The choice [folder] stored under its own key before it belonged here, with
/// the keys that held it; null when the old row never wrote one. The keys are
/// read literally — the prefs gate resolves a call site only from the text.
({String path, List<String> keys})? _legacyChoiceFor(StorageFolder folder) {
  try {
    return switch (folder) {
      StorageFolder.logs => _legacy((StoragePrefs.getString('log.directory') ?? '').trim(), const ['log.directory']),
      // The old row named a parent and the app owned a `PureLiveRecords`
      // child of it — the takes live in that child, so adopting that child as
      // the folder keeps every file exactly where it is.
      StorageFolder.recordings => _legacyParentedRecordings(
        (StoragePrefs.getString('recorder.dir') ?? '').trim(),
        (StoragePrefs.getString('recorder.saveDir') ?? '').trim(),
      ),
      _ => null,
    };
  } on Object {
    return null;
  }
}

/// The legacy answer for [path] and the [keys] that held it; null when the old
/// row never wrote one.
({String path, List<String> keys})? _legacy(String path, List<String> keys) =>
    path.isEmpty ? null : (path: path, keys: keys);

/// The recordings folder the recorder's own keys implied: `PureLiveRecords`
/// under the first parent the viewer typed — `recorder.dir`, or the
/// `recorder.saveDir` an older build wrote.
({String path, List<String> keys})? _legacyParentedRecordings(String directory, String saved) {
  final parent = directory.isNotEmpty ? directory : saved;
  if (parent.isEmpty) return null;
  return (path: p.join(parent, 'PureLiveRecords'), keys: const ['recorder.dir', 'recorder.saveDir']);
}

/// Moves [legacy] under [folder]'s own key and drops the keys it came from, so
/// the choice is read from one place from the next start on.
Future<void> _adoptLegacyChoice(StorageFolder folder, ({String path, List<String> keys}) legacy) async {
  try {
    await StoragePrefs.setString(folder.prefKey, legacy.path);
    for (final key in legacy.keys) {
      await StoragePrefs.remove(key);
    }
  } on Object {
    // A closed store leaves the legacy read to do the same thing next start.
  }
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

  /// Live recordings.
  Directory get recordings => _pick(StorageFolder.recordings, paths.recordings);

  /// Finished songs.
  Directory get music => _pick(StorageFolder.music, paths.music);

  /// Saved wallpapers.
  Directory get wallpapers => _pick(StorageFolder.wallpapers, paths.wallpapers);

  /// Saved video wallpapers — the clips.
  Directory get videoWallpapers => _pick(StorageFolder.videoWallpapers, paths.videoWallpapers);

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

  /// The rotating log files.
  Directory get logs => _pick(StorageFolder.logs, paths.logs);

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
