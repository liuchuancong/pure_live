import 'dart:io' show Directory, File, FileSystemException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/storage_providers.dart' show storagePathsProvider;
import 'package:pure_live/app/theme/fonts/font_library.dart' show CloudFontIds, FontLibrary;
import 'package:pure_live/infrastructure/storage/storage_paths.dart' show StoragePaths;

/// The pref key of the shared download folder; empty means the platform
/// default is in use.
const String kDownloadDirectoryPref = 'storage.downloadDirectory';

/// The shared download folder: downloaded files and the cloud fonts live
/// below it. An empty custom folder means the fallback (the storage layer's
/// downloads area) is in use.
typedef DownloadDirectory = ({String custom, String fallback});

/// The platform default download root: the storage layer's downloads area,
/// or the app data tree where the platform offers none.
String defaultDownloadRoot(StoragePaths paths) => paths.downloads?.path ?? p.join(paths.data.path, 'downloads');

/// The fonts folder under a download root.
Directory fontsRootOf(String downloadRoot) => Directory(p.join(downloadRoot, 'fonts'));

/// The effective folder and the font root derived from it.
extension DownloadDirectoryPaths on DownloadDirectory {
  /// The folder downloads actually land in.
  String get effectivePath => custom.isEmpty ? fallback : custom;

  /// The cloud fonts folder under [effectivePath].
  Directory get fontsRoot => fontsRootOf(effectivePath);
}

/// Stores the viewer's shared download folder.
///
/// The reference routes app updates, downloaded files and fonts through one
/// folder; this build owns no in-app update download, so the cloud fonts are
/// the consumer that makes the choice real. A sibling window (or a restored
/// backup) re-reads the key through `settings_refresh`.
final class DownloadDirectoryController extends Notifier<DownloadDirectory> {
  @override
  DownloadDirectory build() {
    final paths = ref.watch(storagePathsProvider);
    var custom = '';
    try {
      custom = (StoragePrefs.getString(kDownloadDirectoryPref) ?? '').trim();
    } on Object {
      // A closed store answers with the default.
    }
    return (custom: custom, fallback: defaultDownloadRoot(paths));
  }

  /// Stores [path] after proving it accepts writes; false means nothing was
  /// changed and the caller shows the permission hint.
  Future<bool> setDirectory(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      await reset();
      return true;
    }
    if (!await canWriteDownloadDirectory(normalized)) return false;
    state = (custom: normalized, fallback: state.fallback);
    await _write(normalized);
    return true;
  }

  /// Returns to the platform default folder.
  Future<void> reset() async {
    state = (custom: '', fallback: state.fallback);
    await _write('');
  }

  Future<void> _write(String value) async {
    try {
      await StoragePrefs.setString(kDownloadDirectoryPref, value);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The shared download folder choice.
final downloadDirectoryProvider = NotifierProvider<DownloadDirectoryController, DownloadDirectory>(
  DownloadDirectoryController.new,
);

/// Proves [path] accepts writes. Android scoped storage can hand back a
/// folder that is readable but not writable, so the probe is a real file.
Future<bool> canWriteDownloadDirectory(String path) async {
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

/// Folds the families under the stored custom download folder into the
/// synchronous [CloudFontIds] snapshot.
///
/// The boot scan knows the default folder; a restore or another window can
/// point the folder at a tree this engine never scanned, and the theme
/// validates its stored family against that snapshot before the library is
/// built.
void refreshCloudFontSnapshot() {
  try {
    final custom = (StoragePrefs.getString(kDownloadDirectoryPref) ?? '').trim();
    if (custom.isEmpty) return;
    CloudFontIds.replace({...CloudFontIds.values, ...FontLibrary.scanInstalled(fontsRootOf(custom))});
  } on Object {
    // A store or folder that cannot answer keeps the current snapshot.
  }
}
