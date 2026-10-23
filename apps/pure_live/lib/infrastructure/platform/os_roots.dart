import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';

/// The four operating-system directories the app's layout is built from.
///
/// Resolved here and only here: `live_platform_path_provider` is deliberately
/// Flutter-free and takes its roots from the host, so a business module that
/// reached for `path_provider` itself would silently opt out of the
/// portable-versus-installed decision this layer makes.
///
/// A null root is not an error — it means that candidate is simply never
/// offered, and the policy falls through to the next one. `downloadsDirectory`
/// is the usual case: it answers null on iOS and on the web.
final class OsRoots {
  /// The roots as measured on this device.
  const OsRoots({
    required this.userRoot,
    required this.cacheRoot,
    required this.temporaryRoot,
    required this.downloadsRoot,
  });

  /// The app-support directory: `%APPDATA%\<App>` on Windows,
  /// `~/Library/Application Support/<App>` on macOS, `~/.local/share/<App>` on
  /// Linux. The home of every persistent area on an installed build, and the
  /// writable metadata home the distribution claim cache needs.
  final Directory? userRoot;

  /// The OS cache directory, for data the app may lose without breaking
  /// anything (the clearable areas).
  final Directory? cacheRoot;

  /// The system temporary directory: scratch that may vanish at any time.
  final Directory? temporaryRoot;

  /// The user's own visible download folder, when this platform has one.
  final Directory? downloadsRoot;

  /// Measured through `path_provider`. A platform-channel failure counts as
  /// "no such root" rather than a crash: the layout has a fallback for every
  /// area, and refusing to start over a missing download folder is worse than
  /// not offering one.
  ///
  /// A debug build roots its persistent and clearable trees one segment
  /// deeper (`.../debug`): a `flutter run` must never read or write an
  /// installed build's data, and nothing below this layer can tell the two
  /// builds apart. The user's real download folder is deliberately not
  /// remapped — it is the user's own folder, not the app's.
  static Future<OsRoots> measure() async {
    return OsRoots(
      userRoot: (await _nullOnFailure(getApplicationSupportDirectory))?._debugSegment(),
      cacheRoot: (await _nullOnFailure(getApplicationCacheDirectory))?._debugSegment(),
      temporaryRoot: (await _nullOnFailure(getTemporaryDirectory))?._debugSegment(),
      downloadsRoot: await _nullOnFailure(getDownloadsDirectory),
    );
  }

  static Future<Directory?> _nullOnFailure(Future<Directory?> Function() read) async {
    try {
      return await read();
    } on Object {
      return null;
    }
  }
}

/// The debug profile: one `debug` segment deeper, debug builds only.
extension _DebugProfile on Directory {
  Directory? _debugSegment() {
    if (!kDebugMode) {
      return this;
    }
    return Directory('$path/debug');
  }
}
