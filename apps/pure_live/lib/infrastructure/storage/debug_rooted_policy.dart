import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:live_platform/live_platform.dart' show PlatformRuntimeInfo;
import 'package:live_platform_path_provider/live_platform_path_provider.dart' show StorageArea, StoragePolicy;
import 'package:path/path.dart' as p;

/// A debug run of a portable build keeps its data beside the executable —
/// inside the bundle's own tree — instead of the portable release's data,
/// so a developer's `flutter run` beside a portable copy never overwrites it.
///
/// Only portable deployments are re-rooted here. An installed or unknown
/// deployment follows its own policy: the OS roots the shell hands over are
/// already one `debug` segment deeper in a debug build, so those runs land
/// in `<appsupport>/debug/...` rather than beside a `flutter run`
/// executable that the next build wipes. The wrapped policy's answers stay
/// as fallbacks (a path that fails the write probe simply falls through), so
/// nothing is lost on platforms where the executable directory is not
/// writable.
final class DebugRootedPolicy implements StoragePolicy {
  /// Wraps [inner] with exe-rooted debug candidates under [executableRoot].
  const DebugRootedPolicy({required this.inner, required this.executableRoot});

  /// The standard layout whose answers act as fallbacks.
  final StoragePolicy inner;

  /// The directory holding the debug executable.
  final Directory executableRoot;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) {
    if (!kDebugMode || !runtime.isPortable) {
      return inner.candidatesFor(area, runtime);
    }
    final debugTree = Directory(p.join(executableRoot.path, 'pure_live_debug'));
    return [Directory(p.join(debugTree.path, area.name)), ...inner.candidatesFor(area, runtime)];
  }
}
