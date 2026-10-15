import 'package:live_platform_path_provider/src/contracts/storage_area.dart';
import 'package:live_platform_path_provider/src/contracts/storage_manager.dart';

/// Reports the resolved storage layout for diagnostics screens and bug
/// reports: one line per area with path, persistence and access state.
///
/// Resolution failures are captured per area, never thrown — a
/// diagnostics view must render even when storage is broken.
abstract final class StorageDiagnostics {
  /// Resolves every [areas] location and renders a stable report.
  static Future<List<String>> report(StorageManager storage, {List<StorageArea> areas = StorageArea.values}) async {
    final lines = <String>[];
    for (final area in areas) {
      try {
        final location = await storage.resolve(area);
        lines.add(
          '${area.name}: ${location.path} '
          '(${location.accessState.name}, persistent=${location.isPersistent})',
        );
      } on Object catch (error) {
        lines.add('${area.name}: UNAVAILABLE ($error)');
      }
    }
    return lines;
  }
}
