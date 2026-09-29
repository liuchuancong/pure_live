import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Loads the libraries libmpv links against before media_kit opens it on
/// Linux.
///
/// libmpv needs VA-API, VDPAU, libunwind, libarchive, XScrnSaver and Xv,
/// which minimal desktops do not always install (the 3.2.x notes asked users
/// to install `libva-wayland2` by hand). The bundle carries copies in
/// `lib/fallback`. Each library is opened by soname first, so an installed
/// system copy, with its own VA-API driver paths, always wins; only a missing
/// one is opened from the bundle. glibc then satisfies libmpv's `NEEDED`
/// entries with the already loaded sonames.
abstract final class LinuxMpvRuntime {
  /// Dependencies before dependents (libva before its backends). Must match
  /// `MPV_FALLBACK_LIBRARIES` in `linux/CMakeLists.txt`.
  static const List<String> fallbackLibraries = [
    'libva.so.2',
    'libva-drm.so.2',
    'libva-x11.so.2',
    'libva-wayland.so.2',
    'libvdpau.so.1',
    'libunwind.so.8',
    'libarchive.so.13',
    'libXss.so.1',
    'libXv.so.1',
  ];

  static bool _loaded = false;

  /// Idempotent; a no-op outside Linux.
  static void ensureLoaded() {
    if (_loaded || !Platform.isLinux) return;
    _loaded = true;
    final fallbackDir = '${File(Platform.resolvedExecutable).parent.path}/lib/fallback';
    final bundled = load(open: DynamicLibrary.open, fallbackDir: fallbackDir);
    if (bundled.isNotEmpty) {
      debugPrint('LinuxMpvRuntime: using bundled ${bundled.join(', ')}');
    }
  }

  /// Returns the libraries that came from [fallbackDir]. A library missing in
  /// both places is skipped; libmpv then reports the real error when opened.
  @visibleForTesting
  static List<String> load({required DynamicLibrary Function(String path) open, required String fallbackDir}) {
    final bundled = <String>[];
    for (final soname in fallbackLibraries) {
      try {
        open(soname);
        continue;
      } on ArgumentError {
        // Not installed on this system.
      }
      try {
        open('$fallbackDir/$soname');
        bundled.add(soname);
      } on ArgumentError {
        // Not bundled either (built without it); leave it to libmpv.
      }
    }
    return bundled;
  }
}
