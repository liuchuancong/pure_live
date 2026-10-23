import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_platform/live_platform.dart' show PlatformEnvironment;
import 'package:live_platform_path_provider/live_platform_path_provider.dart'
    show DefaultStoragePolicy, PathProviderBootstrap, StorageArea, StorageLocation, StorageManager;
import 'package:pure_live/infrastructure/platform/os_roots.dart' show OsRoots;
import 'package:pure_live/infrastructure/storage/debug_rooted_policy.dart' show DebugRootedPolicy;

/// The app's storage paths, resolved from the deployment facts.
///
/// `live_platform` answers *what this deployment is* — the trust chain is
/// portable marker, then build claim, then package identity (an MSIX
/// install), then shape — and `live_platform_path_provider` turns that
/// answer into directories. The policy owns every branch; this class owns
/// none:
///
/// * **portable** — data lives on the bundle's own medium:
///   `<exe>/data/pure_live` (the `data/` segment is namespaced because
///   Flutter's own Windows bundle occupies `data/` next to the
///   executable), cache at `<exe>/cache`, temp at `<exe>/temp`,
///   downloads at `<exe>/downloads` with the OS folder as fallback.
/// * **installed / MSIX** — data under the OS application-support root
///   (`<appsupport>/data`), cache under `<cacheroot>/pure_live`, temp
///   under `<temproot>/pure_temp`, downloads = the OS download folder.
///   Neither deployment style ever writes next to the executable.
///
/// The OS roots come from [OsRoots.measure] — the one place that touches
/// `path_provider` — and are only the *installed* case's answers; whether
/// they are offered at all is the policy's call, made from the runtime
/// snapshot, never from here.
final class StoragePaths {
  StoragePaths._({
    required this.environment,
    required this.manager,
    required this.roots,
    required this.data,
    required this.config,
    required this.cache,
  });

  /// The platform runtime snapshot (OS family, form factor, distribution).
  final PlatformEnvironment environment;

  /// The OS roots this layout was built over, kept for the diagnostics and
  /// the split-brain checks that must name them.
  final OsRoots roots;

  /// Directory resolution for every storage area, memoised per area.
  final StorageManager manager;

  /// The persistent data area — settings, databases, history.
  final StorageLocation data;

  /// The user-editable configuration area.
  final StorageLocation config;

  /// The clearable cache area.
  final StorageLocation cache;

  /// Resolves the layout for [environment] once at boot; every later
  /// reader takes the resolved locations from here instead of asking the
  /// OS again.
  static Future<StoragePaths> resolve({
    required PlatformEnvironment environment,
    LiveLog? log,
    String? dataDirOverride,
  }) async {
    final roots = await OsRoots.measure();
    final exeRoot = environment.runtime.executableRoot;
    // In a debug run the data tree is rooted beside the debug executable —
    // inside the project's build tree — so `flutter run` never touches an
    // installed build's data and the developer finds every file in the
    // project. Release builds keep the standard policy untouched.
    final policy = kDebugMode
        ? DebugRootedPolicy(
            inner: DefaultStoragePolicy(
              portableRoot: exeRoot,
              userRoot: roots.userRoot,
              cacheRoot: roots.cacheRoot,
              tempRoot: roots.temporaryRoot,
              downloadsRoot: roots.downloadsRoot,
            ),
            executableRoot: Directory(exeRoot.path),
          )
        : DefaultStoragePolicy(portableRoot: exeRoot);
    final pathRuntime = await PathProviderBootstrap.init(environment: environment, policy: policy);
    final manager = pathRuntime.storage;
    // A build-time data-root override (PURE_LIVE_DATA_DIR) pins the data
    // area wherever the diagnostic run wants it; the write probe in the
    // resolver does not run for a hand-pinned location.
    final data = dataDirOverride == null
        ? await manager.resolve(StorageArea.data)
        : StorageLocation(area: StorageArea.data, path: dataDirOverride, isPersistent: true);
    final config = await manager.resolve(StorageArea.config);
    final cache = await manager.resolve(StorageArea.cache);
    log
        ?.forCategory('paths')
        .info(
          'storage layout resolved',
          fields: {
            'distribution': environment.runtime.distribution.name,
            'portable': '${environment.runtime.isPortable}',
            'data': data.path,
            'config': config.path,
            'cache': cache.path,
          },
        );
    return StoragePaths._(
      environment: environment,
      manager: manager,
      roots: roots,
      data: data,
      config: config,
      cache: cache,
    );
  }

  /// Resolves any other area (temporary, downloads, extensions, imports,
  /// exports) through the same policy.
  Future<StorageLocation> resolveArea(StorageArea area) => manager.resolve(area);
}
