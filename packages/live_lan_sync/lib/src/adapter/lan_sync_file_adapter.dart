import 'dart:io' show Directory, File;

import 'package:live_lan_sync/src/domain/transfer/transfer.dart' show FileManifest;

/// A file this device can send: the file itself and how to present it.
final class LocalFile {
  /// A sendable file.
  const new({required this.file, required this.fileName, this.mimeType = 'application/octet-stream'});

  /// The file on this device. Its path never leaves the device.
  final File file;

  /// The name to show the other device.
  final String fileName;

  /// The MIME type to declare.
  final String mimeType;
}

/// One category of files the host lets travel — fonts, wallpapers, covers
/// (spec §12, §13).
///
/// The adapter owns every path. It says where a file to send is read from,
/// where an incoming file stages and where it finally lands; the engine
/// never builds a path from anything a peer sent. Before a file reaches
/// [targetFor], the engine has checked every chunk and the whole-file
/// SHA-256, and the adapter's own [validate] has accepted the content.
abstract interface class LanSyncFileAdapter {
  /// The stable category name, e.g. `font`.
  String get category;

  /// The largest file of this category accepted; the transfer config's cap
  /// applies on top.
  int get maxFileBytes;

  /// The local file for [fileId], or null when this device does not have
  /// it.
  Future<LocalFile?> localFile(String fileId);

  /// Whether this device already holds [fileId] with content [sha256], in
  /// which case nothing needs to move.
  Future<bool> hasContent({required String fileId, required String sha256});

  /// Where incoming files of this category stage. It must sit on the same
  /// volume as their final location, so committing is an atomic rename.
  Future<Directory> stagingDirectory();

  /// Checks a received, hash-verified file before it is committed — real
  /// type, structure, limits. Returns a problem, or null to accept it.
  Future<String?> validate(FileManifest manifest, File staged);

  /// Where the file described by [manifest] lands. Called only after
  /// validation; the engine moves the staged file there atomically,
  /// replacing an older version. Never derive the path from
  /// [FileManifest.fileName] unescaped.
  Future<File> targetFor(FileManifest manifest);

  /// The file is committed at [file]: register it with the business module
  /// (spec §13.3 step 12).
  Future<void> committed(FileManifest manifest, File file);
}
