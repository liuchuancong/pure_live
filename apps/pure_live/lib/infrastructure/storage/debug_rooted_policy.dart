import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:live_platform/live_platform.dart' show PlatformRuntimeInfo;
import 'package:live_platform_path_provider/live_platform_path_provider.dart' show StorageArea, StoragePolicy;

/// A debug run keeps its data beside the debug executable — inside the
/// project's build tree — instead of the installed build's OS locations.
///
/// `flutter run` compiles to `build\windows\x64\runner\Debug\`, so the
/// debug tree lands in the project directory where a developer can find
/// and wipe it, and a debug build can never read or write an installed
/// build's data. Every area gets the exe-rooted candidate first; the
/// wrapped policy's answers follow as fallbacks (a path that fails the
/// write probe simply falls through), so nothing is lost on platforms or
/// sandboxes where the executable directory is not writable.
final class DebugRootedPolicy implements StoragePolicy {
  /// Wraps [inner] with exe-rooted debug candidates under [executableRoot].
  const DebugRootedPolicy({required this.inner, required this.executableRoot});

  /// The standard layout whose answers act as fallbacks.
  final StoragePolicy inner;

  /// The directory holding the debug executable.
  final Directory executableRoot;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) {
    if (!kDebugMode) {
      return inner.candidatesFor(area, runtime);
    }
    final debugTree = Directory('${executableRoot.path}/pure_live_debug');
    return [Directory('${debugTree.path}/${area.name}'), ...inner.candidatesFor(area, runtime)];
  }
}
