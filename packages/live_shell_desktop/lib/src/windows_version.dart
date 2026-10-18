import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' show calloc;

/// The Windows build number the process is running on, or 0 when it cannot be
/// read.
///
/// `RtlGetVersion` rather than `GetVersionEx` or `Platform.operativeSystemVersion`:
/// the former reports the build the OS actually is, while the latter two are
/// gated by the application manifest and answer 6.2 (Windows 8) to anything that
/// has not declared itself compatible. A policy that decides who owns the window
/// frame cannot be built on a number that lies depending on a resource file.
int windowsBuildNumber() {
  final ntdll = ffi.DynamicLibrary.open('ntdll.dll');
  final rtlGetVersion = ntdll
      .lookupFunction<ffi.Int32 Function(ffi.Pointer<_OsVersionInfo>), int Function(ffi.Pointer<_OsVersionInfo>)>(
        'RtlGetVersion',
      );
  final info = calloc<_OsVersionInfo>();
  try {
    info.ref.size = ffi.sizeOf<_OsVersionInfo>();
    if (rtlGetVersion(info) != 0) {
      return 0;
    }
    return info.ref.build;
  } finally {
    calloc.free(info);
  }
}

/// The first Windows build that composes a window's rounded corners and frame
/// border itself, so an app that takes the non-client area over still reads as a
/// window with an edge.
///
/// The same threshold the Mica backdrop uses, for the same reason: it is where
/// Windows 11's compositor begins.
const int kWindowsRoundedFrameBuild = 22000;

/// Whether this Windows gives an app-drawn frame its edge for free.
///
/// False on Windows 10, where a custom frame loses the system-drawn border and
/// the corners were square anyway — the window ends up as a rectangle with no
/// visible edge against the desktop. That is why the default title-bar mode is
/// chosen from this rather than fixed for every build.
bool windowsDrawsFrameEdgeItself() => windowsBuildNumber() >= kWindowsRoundedFrameBuild;

final class _OsVersionInfo extends ffi.Struct {
  @ffi.Uint32()
  external int size;

  @ffi.Uint32()
  external int major;

  @ffi.Uint32()
  external int minor;

  @ffi.Uint32()
  external int build;

  @ffi.Uint32()
  external int platformId;

  @ffi.Array(128)
  external ffi.Array<ffi.Uint16> servicePack;
}
