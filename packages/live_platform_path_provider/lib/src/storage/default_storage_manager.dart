import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformKind, PlatformRuntimeInfo;
import 'package:live_platform_path_provider/src/contracts/platform_exception.dart';
import 'package:live_platform_path_provider/src/contracts/storage_area.dart';
import 'package:live_platform_path_provider/src/contracts/storage_location.dart';
import 'package:live_platform_path_provider/src/contracts/storage_manager.dart';
import 'package:live_platform_path_provider/src/insights/path_privacy.dart';
import 'package:live_platform_path_provider/src/storage/storage_policy.dart';
import 'package:path/path.dart' as p;

/// The production StorageManager: walks the policy's candidate list,
/// probes each directory with a real write, memoises the winner per area
/// and falls back to the system temporary directory for clearable areas.
///
/// Persistent areas (data/config/extensions) never silently fall back to
/// a temp directory — if every candidate fails, resolution throws so the
/// caller can tell the user where data will live.
final class DefaultStorageManager implements StorageManager {
  /// A manager over [policy]; [runtime] feeds the portable-ordering
  /// decision (bootstrap injects it after building the snapshot),
  /// [systemTemp] is the last-resort directory for cache and temporary
  /// areas.
  new({required this.policy, this.runtime, Directory? systemTemp}) : _systemTemp = systemTemp ?? Directory.systemTemp;

  /// The active candidate policy.
  final StoragePolicy policy;

  /// The runtime snapshot the policy consults; settable so bootstrap can
  /// attach it after the manager and the snapshot are both built.
  PlatformRuntimeInfo? runtime;

  final Directory _systemTemp;
  final Map<StorageArea, StorageLocation> _resolved = {};

  /// Per-process counter keeping concurrent probes out of each other's way —
  /// the desktop shell's second window runs another isolate, and two probes
  /// sharing one fixed file name fight over its delete.
  static int _probeSequence = 0;

  @override
  Future<StorageLocation> resolve(StorageArea area) async {
    final known = _resolved[area];
    if (known != null && known.accessState == AccessState.writable) {
      return known;
    }
    final snapshot =
        runtime ?? (throw StateError('no runtime snapshot: construct with runtime or run PlatformBootstrap.init'));
    for (final candidate in policy.candidatesFor(area, snapshot)) {
      final location = await _probe(area, candidate, snapshot.kind);
      if (location != null) {
        return _resolved[area] = location;
      }
    }
    // Clearable areas may degrade to the system temp dir; persistent ones
    // must fail loudly instead of hiding data where it will be wiped.
    if (area == StorageArea.cache || area == StorageArea.temporary) {
      final fallback = await _probe(area, Directory(p.join(_systemTemp.path, 'pure_live')), snapshot.kind);
      if (fallback != null) {
        return _resolved[area] = fallback;
      }
    }
    throw StorageUnavailableException(
      'no writable location for ${area.name} storage; '
      'candidates: ${policy.candidatesFor(area, snapshot).map((d) => d.path).join(', ')}',
    );
  }

  @override
  Future<StorageLocation> revalidate(StorageArea area) {
    _resolved.remove(area);
    return resolve(area);
  }

  Future<StorageLocation?> _probe(StorageArea area, Directory candidate, PlatformKind kind) async {
    try {
      await candidate.create(recursive: true);
      final probe = File(p.join(candidate.path, '.pure_live_probe_${pid}_${++_probeSequence}'));
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
          StorageArea.exports ||
          StorageArea.downloads => true,
          StorageArea.cache || StorageArea.temporary => false,
        },
        accessState: AccessState.writable,
        isPrivate: PathPrivacy.isPrivate(candidate.path, kind: kind),
      );
    } on FileSystemException {
      return null;
    }
  }
}
