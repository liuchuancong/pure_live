import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/linux_mpv_runtime.dart';

void main() {
  test('a system library wins; only missing ones load from the bundle', () {
    const system = {'libva.so.2', 'libva-drm.so.2', 'libva-x11.so.2', 'libvdpau.so.1', 'libXv.so.1'};
    const bundledFiles = {'/app/lib/fallback/libva-wayland.so.2', '/app/lib/fallback/libunwind.so.8'};
    final opened = <String>[];
    DynamicLibrary open(String path) {
      if (system.contains(path) || bundledFiles.contains(path)) {
        opened.add(path);
        return DynamicLibrary.process();
      }
      throw ArgumentError('Failed to load dynamic library $path');
    }

    final bundled = LinuxMpvRuntime.load(open: open, fallbackDir: '/app/lib/fallback');

    expect(bundled, ['libva-wayland.so.2', 'libunwind.so.8']);
    expect(opened.indexOf('libva.so.2'), lessThan(opened.indexOf('/app/lib/fallback/libva-wayland.so.2')));
    expect(opened, isNot(contains('/app/lib/fallback/libva.so.2')));
  });

  test('the fallback list matches the CMake install list', () {
    // Kept in sync by hand; see MPV_FALLBACK_LIBRARIES in linux/CMakeLists.txt.
    expect(LinuxMpvRuntime.fallbackLibraries.first, 'libva.so.2');
    expect(LinuxMpvRuntime.fallbackLibraries.toSet().length, LinuxMpvRuntime.fallbackLibraries.length);
  });
}
