import 'package:live_platform/src/contracts/platform_exception.dart';
import 'package:live_platform/src/contracts/storage_area.dart';
import 'package:live_platform/src/contracts/storage_location.dart';

/// Unified directory resolution for every storage area.
///
/// Implementations walk an ordered candidate list per area (from the
/// active StoragePolicy), probe writability for real, and fall back
/// deterministically. Results are memoised per area: resolution happens
/// once, callers get the same location afterwards.
abstract interface class StorageManager {
  /// Resolves [area] to a usable, writable location. Throws
  /// [StorageUnavailableException] when every candidate failed and the
  /// area has no acceptable fallback.
  Future<StorageLocation> resolve(StorageArea area);

  /// Re-runs probing for [area], e.g. after the user moved the data
  /// directory or a disk came back. Returns the fresh location.
  Future<StorageLocation> revalidate(StorageArea area);
}
