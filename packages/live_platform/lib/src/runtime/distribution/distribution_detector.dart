import 'dart:io';

import 'package:live_platform/src/runtime/distribution/desktop_distribution.dart';
import 'package:path/path.dart' as p;

/// Best-effort distribution detection, used only when the app shell has
/// not declared the deployment explicitly.
///
/// Rules of engagement, in order of trust:
/// 1. The launcher or a native bridge *declares* the distribution — the
///    bootstrap's `declaredDistribution` always wins.
/// 2. The user *declares* portable mode by placing a `portable.marker` file
///    next to the executable. Reading it is not guessing — whoever put it
///    there meant it. A `data/` directory is deliberately NOT a marker: on
///    a Flutter Windows build that name is the runtime's own bundle
///    (`data/flutter_assets`, `data/icudtl.dat`), so the directory sits
///    next to every Windows executable ever built and would call every
///    single build portable.
/// 3. MSIX can be recognised conservatively here: a Windows executable
///    running from the per-user Packages container is a strong signal.
/// 4. Everything else stays `unknown`; portable mode is never inferred
///    from a directory or file *name* — an unknown stays unknown.
abstract final class DistributionDetector {
  /// Recognises the user-declared portable marker: a `portable.marker` file
  /// directly inside [executableRoot]. Returns null when it is absent, so
  /// the caller falls through to the shape checks. This is what keeps a
  /// portable build's data on its own medium — without the marker (or a
  /// launcher declaration) there is no honest way to know, and the path
  /// provider will keep such a build out of the executable's directory.
  static DesktopDistribution? detectMarkers(Directory executableRoot) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final marker = File(p.join(executableRoot.path, 'portable.marker'));
      if (marker.existsSync()) {
        return DesktopDistribution.portable;
      }
    }
    return null;
  }

  /// Inspects the executable location for the MSIX container pattern
  /// (`…/AppData/Local/Packages/<package-id>/…` on Windows). Returns
  /// [DesktopDistribution.unknown] on any other layout.
  ///
  /// A standard MSIX install actually runs from
  /// `…\Program Files\WindowsApps\…`, which the native package-identity
  /// probe already covers — this shape check is a defensive fallback for
  /// the rare package that runs from its per-user data container, never
  /// the primary rule.
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
