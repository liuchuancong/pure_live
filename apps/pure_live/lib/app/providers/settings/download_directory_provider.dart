import 'dart:io' show Directory, File, FileSystemException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

import 'package:pure_live/app/providers/boot/storage_providers.dart' show storagePathsProvider;
import 'package:pure_live/infrastructure/infrastructure.dart';

/// The pref key of the shared download folder; empty means the platform
/// default is in use.
const String kDownloadDirectoryPref = 'storage.downloadDirectory';

/// The shared download folder: downloaded files (recordings and the like)
/// live below it. An empty custom folder means the fallback (the storage
/// layer's downloads area) is in use.
typedef DownloadDirectory = ({String custom, String fallback});

/// The platform default download root: the storage layer's downloads area,
/// or the app data tree where the platform offers none.
String defaultDownloadRoot(StoragePaths paths) => paths.downloads?.path ?? p.join(paths.data.path, 'downloads');

/// The effective folder.
extension DownloadDirectoryPaths on DownloadDirectory {
  /// The folder downloads actually land in.
  String get effectivePath => custom.isEmpty ? fallback : custom;
}

/// Stores the viewer's shared download folder.
///
/// The reference routes app updates and downloaded files through one folder;
/// this build owns no in-app update download, so recordings are the consumer
/// that makes the choice real. A sibling window (or a restored backup)
/// re-reads the key through `settings_refresh`.
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
