import 'package:live_platform_path_provider/src/contracts/storage_area.dart';

/// How a resolved location answers write attempts.
enum AccessState {
  /// Probed: creating and writing succeeded.
  writable,

  /// Probed: the directory exists but writing was refused.
  readOnly,

  /// Not probed yet, or probing was skipped.
  unknown,
}

/// One resolved directory for a [StorageArea], with honest access facts.
///
/// [accessState] comes from a real probe or a capability check — never
/// assumed writable at construction. An unprobed location reports
/// [AccessState.unknown].
final class StorageLocation {
  /// A resolved location; prefer obtaining these from a StorageManager.
  const new({
    required this.area,
    required this.path,
    required this.isPersistent,
    this.accessState = AccessState.unknown,
    this.isPrivate = false,
  });

  /// Which kind of data belongs here.
  final StorageArea area;

  /// Absolute directory path.
  final String path;

  /// Whether the contents must survive updates and cleanups. Cache and
  /// temporary areas are false.
  final bool isPersistent;

  /// Probe result for writability.
  final AccessState accessState;

  /// Whether the path sits in an app-private area other apps cannot read
  /// (the Android app dirs, the iOS sandbox). A download resolved here must
  /// be offered to the user as a choice first — see `PathPrivacy`.
  final bool isPrivate;

  @override
  String toString() =>
      'StorageLocation(${area.name}, $path, '
      '${accessState.name}, persistent=$isPersistent, private=$isPrivate)';
}
