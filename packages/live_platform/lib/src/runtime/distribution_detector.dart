import 'dart:io';

import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:path/path.dart' as p;

/// Best-effort distribution detection, used only when the app shell has
/// not declared the deployment explicitly.
///
/// Rules of engagement, in order of trust:
/// 1. The launcher or a native bridge *declares* the distribution — the
///    bootstrap's `declaredDistribution` always wins.
/// 2. MSIX can be recognised conservatively here: a Windows executable
///    running from the per-user Packages container is a strong signal.
/// 3. Portable mode is *never* inferred from a directory or file name —
///    an unknown stays unknown.
abstract final class DistributionDetector {
  /// Inspects the executable location for the MSIX container pattern
  /// (`…/AppData/Local/Packages/<package-id>/…` on Windows). Returns
  /// [DesktopDistribution.unknown] on any other layout.
  static DesktopDistribution detect(Directory executableRoot) {
    if (Platform.isWindows) {
      // Split through package:path: a Windows path may legitimately arrive with `/`
      // separators (a hand-written default, a value from a plugin or a config file),
      // and splitting only on Platform.pathSeparator turns such a path into one
      // opaque segment, so the container keyword is never found and the answer
      // silently degrades to unknown.
      final parts = p.split(executableRoot.absolute.path);
      final packagesIndex = parts.indexOf('Packages');
      // The per-user container reads `…\AppData\Local\Packages\<package-id>\…`, so the
      // two segments before `Packages` are `Local` and `AppData`. `LocalAppData` is
      // the shell *name of the root* and never appears as a path segment, which is
      // why comparing against it made this rule unreachable and every MSIX build
      // came back unknown.
      if (packagesIndex > 1 &&
          parts.length > packagesIndex + 1 &&
          parts[packagesIndex - 1].equalsIgnoreCase('local') &&
          parts[packagesIndex - 2].equalsIgnoreCase('appdata')) {
        return DesktopDistribution.msix;
      }
    }
    return DesktopDistribution.unknown;
  }
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
