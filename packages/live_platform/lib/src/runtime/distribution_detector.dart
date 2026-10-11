import 'dart:io';

import 'package:live_platform/src/runtime/desktop_distribution.dart';

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
      final parts = executableRoot.absolute.path.split(Platform.pathSeparator);
      final packagesIndex = parts.indexOf('Packages');
      if (packagesIndex > 0 &&
          parts.length > packagesIndex + 1 &&
          parts[packagesIndex - 1].equalsIgnoreCase('localappdata')) {
        return DesktopDistribution.msix;
      }
    }
    return DesktopDistribution.unknown;
  }
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
