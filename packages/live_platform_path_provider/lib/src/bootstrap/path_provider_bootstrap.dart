import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformEnvironment;
import 'package:live_platform_path_provider/src/contracts/storage_manager.dart';
import 'package:live_platform_path_provider/src/storage/default_storage_manager.dart';
import 'package:live_platform_path_provider/src/storage/storage_policy.dart';

/// Everything the path layer assembled: the storage manager business
/// modules resolve their directories through.
final class PathProviderRuntime {
  /// A completed bootstrap result.
  const new({required this.storage});

  /// Directory resolution for every storage area.
  final StorageManager storage;
}

/// The path layer's composition entry point: run once after the platform
/// runtime exists, before any storage access.
///
/// The deployment snapshot decides how the roots are used — a portable
/// build resolves its persistent areas under its own executable and never
/// into the OS directories, an installed build never writes next to the
/// executable — and neither order is ever swapped silently.
abstract final class PathProviderBootstrap {
  /// Builds the path runtime over [environment]. The directory callbacks
  /// resolve the OS roots (path_provider in a Flutter shell):
  /// [userDataDirectory] the application-support directory, [cacheDirectory]
  /// the OS cache directory, [temporaryDirectory] the system temporary
  /// directory, [downloadsDirectory] the user-visible download target —
  /// the user's own setting when one exists, the OS download directory
  /// otherwise. [policy] replaces the standard layout entirely. Without it,
  /// the default layout namespaces whatever it writes with the snapshot's
  /// `appNamespace` — the identity the host declared once at platform
  /// bootstrap — so a reused package writes under the calling application,
  /// never under this repository's own app.
  static Future<PathProviderRuntime> init({
    required PlatformEnvironment environment,
    Future<Directory?> Function()? userDataDirectory,
    Future<Directory?> Function()? cacheDirectory,
    Future<Directory?> Function()? temporaryDirectory,
    Future<Directory?> Function()? downloadsDirectory,
    StoragePolicy? policy,
  }) async {
    final runtime = environment.runtime;
    final userRoot = await userDataDirectory?.call();
    final cacheRoot = await cacheDirectory?.call();
    final tempRoot = await temporaryDirectory?.call();
    final downloadsRoot = await downloadsDirectory?.call();
    final storage = DefaultStorageManager(
      policy:
          policy ??
          DefaultStoragePolicy(
            portableRoot: runtime.executableRoot,
            userRoot: userRoot,
            cacheRoot: cacheRoot,
            tempRoot: tempRoot,
            downloadsRoot: downloadsRoot,
            // The host's identity travels from the snapshot the shell
            // bootstrapped; this layer never spells a product name itself.
            appNamespace: runtime.appNamespace,
          ),
    )..runtime = runtime;
    return PathProviderRuntime(storage: storage);
  }
}
