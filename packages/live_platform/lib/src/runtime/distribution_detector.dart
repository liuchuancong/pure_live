import 'dart:io';

import 'package:live_platform/src/runtime/desktop_distribution.dart';
import 'package:path/path.dart' as p;

/// Best-effort distribution detection, used only when the app shell has
/// not declared the deployment explicitly.
///
/// Rules of engagement, in order of trust:
/// 1. The launcher or a native bridge *declares* the distribution — the
///    bootstrap's `declaredDistribution` always wins.
/// 2. The user *declares* portable mode by placing a marker next to the
///    executable (`detectMarkers`): a `data/` tree or a `portable.marker`
///    file. Reading those is not guessing — whoever put them there meant
///    them.
/// 3. MSIX can be recognised conservatively here: a Windows executable
///    running from the per-user Packages container is a strong signal.
/// 4. Everything else stays `unknown`; portable mode is never inferred
///    from a directory or file *name* — an unknown stays unknown.
abstract final class DistributionDetector {
  /// Recognises the user-declared portable markers: a `data/` directory or a
  /// `portable.marker` file directly inside [executableRoot]. Returns null
  /// when neither is present, so the caller falls through to the shape
  /// checks. This is what keeps a portable build's data on its own medium —
  /// without a marker (or a launcher declaration) there is no honest way to
  /// know, and the path provider will keep such a build out of the
  /// executable's directory.
  static DesktopDistribution? detectMarkers(Directory executableRoot) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dataTree = Directory(p.join(executableRoot.path, 'data'));
      final marker = File(p.join(executableRoot.path, 'portable.marker'));
      if (dataTree.existsSync() || marker.existsSync()) {
        return DesktopDistribution.portable;
      }
    }
    return null;
  }

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
