import 'dart:io';

import 'package:live_platform_path_provider/src/contracts/platform_exception.dart';

/// A file the user picked through the system file-access service.
///
/// A selection may not carry a permanent absolute path (sandboxed pickers
/// return handles), so content is reached through [readBytes] and
/// [openRead]; [path] is best-effort and nullable.
final class SelectedFile {
  /// A selection produced by an access service implementation.
  const new({required this.name, required this.readBytes, required this.openRead, this.path, this.size});

  /// Display name (no directory components).
  final String name;

  /// Best-effort absolute path, or null when the platform only grants a
  /// content handle.
  final String? path;

  /// Reported size in bytes, when known upfront.
  final int? size;

  /// Reads the whole file into memory — for configs and small imports.
  final Future<List<int>> Function() readBytes;

  /// Streams the content — for large imports.
  final Stream<List<int>> Function() openRead;
}

/// User-driven file and directory access: imports, exports, backups.
///
/// Implemented by the app shell over file_selector (or TV-appropriate
/// equivalents); the platform layer only defines the contract and the
/// [UserCancelledException] semantics — a cancel is a normal outcome.
abstract interface class FileAccessService {
  /// Opens a single-file picker; null means the user cancelled.
  Future<SelectedFile?> pickOpenFile({List<String> allowedExtensions = const []});

  /// Opens a save dialog; null means the user cancelled. The returned
  /// file is NOT created — the caller writes through it.
  Future<File?> pickSaveLocation(String suggestedName);

  /// Opens a directory picker; null means cancelled. Throws
  /// [UnsupportedCapabilityException] where no directory picker exists
  /// (e.g. TV form factors).
  Future<Directory?> pickDirectory();
}
