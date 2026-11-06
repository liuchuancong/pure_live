import 'dart:io';

import 'package:path/path.dart' as p;

/// The cache tree's folders.
///
/// The host passes the clearable root (`<cacheRoot>/live_cache/`); every
/// child below it belongs to this package and may be deleted.
final class CacheDirectory {
  /// Creates a layout over [root].
  const new(this.root);

  /// The clearable root.
  final Directory root;

  /// Image bytes, one folder per category and a two-character fan-out.
  Directory get images => Directory(p.join(root.path, 'images'));

  /// In-progress writes; safe to empty on startup.
  Directory get temporary => Directory(p.join(root.path, 'temporary'));

  /// The light index beside the files, not a database.
  Directory get metadata => Directory(p.join(root.path, 'metadata'));

  /// The index file.
  File get indexFile => File(p.join(metadata.path, 'index.json'));

  /// Creates the tree; false when the platform refuses the folder.
  ///
  /// A cache that cannot be created costs images their disk copy, not the
  /// application.
  Future<bool> ensure() async {
    try {
      await images.create(recursive: true);
      await temporary.create(recursive: true);
      await metadata.create(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// The file for a category and hash. [category] is already folder-safe.
  File imageFile(String category, String key) => File(p.join(images.path, category, key.substring(0, 2), '$key.img'));
}
