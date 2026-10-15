import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformRuntimeInfo;
import 'package:live_platform_path_provider/src/contracts/storage_area.dart';

/// Ordered candidate directories per storage area.
///
/// The resolver tries candidates in order and keeps the first one that
/// passes a real write probe. Implementations decide fallback order from
/// the deployment snapshot — a portable build keeps its data on its own
/// medium, an installed build never writes next to the executable.
abstract interface class StoragePolicy {
  /// The candidate directories for [area], best first. May be empty; an
  /// empty list means "no acceptable location was planned" and the
  /// resolver reports it as such.
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime);
}

/// The standard PureLive layout.
///
/// Root directories come from the app shell (path_provider results):
/// `portableRoot` is the executable's own directory, under which portable
/// layouts put the per-area trees (`data/`, `cache/`, …); `userRoot` the OS
/// application-support directory, `cacheRoot` the OS cache directory,
/// `tempRoot` the system temporary directory, `downloadsRoot` the
/// user-visible OS download folder.
///
/// The one hard rule: a portable build never resolves a persistent area
/// into `userRoot`/`cacheRoot` — user data follows the executable, which is
/// the entire point of the distribution. The OS temporary directory stays
/// reachable for clearable scratch only, through the manager's fallback.
final class DefaultStoragePolicy implements StoragePolicy {
  /// A policy over the five roots. Null roots are simply never offered
  /// as candidates.
  const new({this.portableRoot, this.userRoot, this.cacheRoot, this.tempRoot, this.downloadsRoot});

  /// The executable's directory (portable layouts only); the per-area
  /// segments (`data/`, `cache/`, …) are appended beneath it.
  final Directory? portableRoot;

  /// The OS per-user application-data directory. Never offered to a
  /// portable build.
  final Directory? userRoot;

  /// The OS cache directory (installed builds only, same rule as [userRoot]).
  final Directory? cacheRoot;

  /// The system temporary directory (installed builds only).
  final Directory? tempRoot;

  /// The user-visible OS download folder. For an installed or packaged
  /// build it is the first download target; a portable build keeps its
  /// downloads in its own tree and falls back to this folder when that
  /// tree cannot host them (a read-only medium).
  final Directory? downloadsRoot;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) {
    final portable = runtime.isPortable;
    if (area == StorageArea.downloads) {
      // A portable build keeps its downloads in the bundle — the medium is
      // the point — and degrades to the user-visible OS folder only when the
      // bundle's tree cannot host them. An installed or packaged build never
      // writes next to its executable (Program Files, the MSIX WindowsApps
      // root), so there the OS download folder stays first and the user's
      // application-data tree is the last resort.
      final bundleTree = portable ? (portableRoot == null ? null : Directory('${portableRoot!.path}/downloads')) : null;
      final osTree = portable || userRoot == null ? null : Directory('${userRoot!.path}/downloads');
      return portable ? [?bundleTree, ?downloadsRoot] : [?downloadsRoot, ?osTree];
    }
    final persistent = switch (area) {
      StorageArea.data ||
      StorageArea.config ||
      StorageArea.extensions ||
      StorageArea.imports ||
      StorageArea.exports ||
      StorageArea.downloads => true,
      StorageArea.cache || StorageArea.temporary => false,
    };
    if (persistent) {
      return [
        if (portable && portableRoot != null) Directory('${portableRoot!.path}/${_segment(area)}'),
        if (!portable && userRoot != null) Directory('${userRoot!.path}/${_segment(area)}'),
      ];
    }
    return switch (area) {
      StorageArea.cache => [
        if (portable && portableRoot != null) Directory('${portableRoot!.path}/cache'),
        if (!portable && cacheRoot != null) Directory('${cacheRoot!.path}/pure_live'),
        if (!portable && tempRoot != null) Directory('${tempRoot!.path}/pure_live_cache'),
      ],
      StorageArea.temporary => [
        if (portable && portableRoot != null) Directory('${portableRoot!.path}/temp'),
        if (!portable && tempRoot != null) Directory('${tempRoot!.path}/pure_live_temp'),
      ],
      _ => const [],
    };
  }

  static String _segment(StorageArea area) => switch (area) {
    StorageArea.data => 'data',
    StorageArea.config => 'config',
    StorageArea.extensions => 'extensions',
    StorageArea.imports => 'imports',
    StorageArea.exports => 'exports',
    StorageArea.downloads => 'downloads',
    StorageArea.cache => 'cache',
    StorageArea.temporary => 'temp',
  };
}
