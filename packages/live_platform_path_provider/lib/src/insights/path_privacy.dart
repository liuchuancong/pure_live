import 'package:live_platform/live_platform.dart' show PlatformKind;

/// Answers "can apps outside ours open files under this path".
///
/// A heuristic on the path shape, because the honest test — opening the
/// file through another app — is not available to a library: on Android the
/// app-private and app-specific-external trees are unreachable to other
/// apps (and to most file managers since Android 11); on iOS the whole
/// sandbox is; on the desktop nothing is. An unknown platform answers
/// conservatively.
///
/// The download flow consults this before planning a default: a private
/// default must reach the user as a choice ("the file would land where
/// your gallery and file manager cannot see it — pick another folder?"),
/// never as a silent write.
abstract final class PathPrivacy {
  /// Whether [path] sits in an app-private area other apps cannot read.
  static bool isPrivate(String path, {required PlatformKind kind}) {
    return switch (kind) {
      PlatformKind.android => _isPrivateAndroidPath(path),
      // The iOS sandbox is private by construction; only paths the user
      // picked through the file-access service escape it, and those arrive
      // as picked destinations, never as planned defaults.
      PlatformKind.ios => true,
      // Nothing to consult — answer as if private so the caller warns.
      PlatformKind.unknown => true,
      PlatformKind.windows || PlatformKind.macos || PlatformKind.linux => false,
    };
  }

  static bool _isPrivateAndroidPath(String path) {
    final normalized = path.replaceAll(r'\', '/').toLowerCase();
    return normalized.contains('/data/data/') ||
        normalized.contains('/data/user/') ||
        normalized.contains('/android/data/') ||
        normalized.contains('/android/obb/');
  }
}
