import 'dart:io';

import 'package:live_platform/src/contracts/platform_exception.dart';
import 'package:live_platform/src/contracts/storage_area.dart';
import 'package:live_platform/src/contracts/storage_location.dart';
import 'package:live_platform/src/contracts/storage_manager.dart';
import 'package:live_platform/src/runtime/platform_runtime_info.dart';
import 'package:live_platform/src/storage/storage_policy.dart';
import 'package:path/path.dart' as p;

/// The production StorageManager: walks the policy's candidate list,
/// probes each directory with a real write, memoises the winner per area
/// and falls back to the system temporary directory for clearable areas.
///
/// Persistent areas (data/config/extensions) never silently fall back to
/// a temp directory — if every candidate fails, resolution throws so the
/// caller can tell the user where data will live.
final class DefaultStorageManager implements StorageManager {
  /// A manager over [policy]; [systemTemp] is the last-resort directory
  /// for cache and temporary areas.
  new({required this.policy, Directory? systemTemp}) : _systemTemp = systemTemp ?? Directory.systemTemp;

  /// The active candidate policy.
  final StoragePolicy policy;

  final Directory _systemTemp;
  final Map<StorageArea, StorageLocation> _resolved = {};

  @override
  Future<StorageLocation> resolve(StorageArea area) async {
    final known = _resolved[area];
    if (known != null && known.accessState == AccessState.writable) {
      return known;
    }
    final runtime = _runtime ?? (throw StateError('bootstrap did not inject the runtime snapshot'));
    for (final candidate in policy.candidatesFor(area, runtime)) {
      final location = await _probe(area, candidate);
      if (location != null) {
        return _resolved[area] = location;
      }
    }
    // Clearable areas may degrade to the system temp dir; persistent ones
    // must fail loudly instead of hiding data where it will be wiped.
    if (area == StorageArea.cache || area == StorageArea.temporary) {
      final fallback = await _probe(area, Directory(p.join(_systemTemp.path, 'pure_live')));
      if (fallback != null) {
        return _resolved[area] = fallback;
      }
    }
    throw StorageUnavailableException(
      'no writable location for ${area.name} storage; '
      'candidates: ${policy.candidatesFor(area, runtime).map((d) => d.path).join(', ')}',
    );
  }

  @override
  Future<StorageLocation> revalidate(StorageArea area) {
    _resolved.remove(area);
    return resolve(area);
  }

  PlatformRuntimeInfo? _runtime;

  /// Injects the runtime snapshot the policy needs; called by bootstrap.
  // ignore: avoid_setters_without_getters
  set runtime(PlatformRuntimeInfo value) => _runtime = value;

  Future<StorageLocation?> _probe(StorageArea area, Directory candidate) async {
    try {
      await candidate.create(recursive: true);
      final probe = File(p.join(candidate.path, '.pure_live_probe'));
      final sink = probe.openWrite();
      await sink.close();
      await probe.delete();
      return StorageLocation(
        area: area,
        path: candidate.path,
        isPersistent: switch (area) {
          StorageArea.data ||
          StorageArea.config ||
          StorageArea.extensions ||
          StorageArea.imports ||
          StorageArea.exports => true,
          StorageArea.cache || StorageArea.temporary => false,
        },
        accessState: AccessState.writable,
      );
    } on FileSystemException {
      return null;
    }
  }
}
