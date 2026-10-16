import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;

/// The material a window ended up with, or [none] when nothing was applied
/// and the surface must stay opaque.
enum AppliedWindowMaterial {
  /// Windows 11's compositor-hosted Mica, applied through flutter_acrylic.
  mica,

  /// Nothing was applied: the window keeps its opaque background. Windows 10
  /// deliberately lands here — its acrylic path drops frames while the window
  /// is dragged, and the package's transparent effects show the desktop
  /// through, so the solid colour is the stable choice.
  none,
}

/// Signature of the material applier, so callers and tests can substitute
/// their own.
typedef WindowMaterialApplier = Future<AppliedWindowMaterial> Function({required bool dark});

/// Applies the strongest translucent material the running Windows supports
/// behind the process's main window.
///
/// The dispatch is deliberate: build 22000+ asks flutter_acrylic for Mica and
/// verifies the DWM attribute took by reading it back; older builds are given
/// the solid surface without an attempt. A failure at any step — failed
/// initialisation, unsupported attribute, mismatched readback — falls through
/// to [AppliedWindowMaterial.none], and the caller must keep the opaque
/// surface: a transparent clear colour with no material behind it shows the
/// desktop through on Windows 10, which is the artefact this contract exists
/// to prevent.
Future<AppliedWindowMaterial> applyWindowMaterial({required bool dark}) async {
  if (!Platform.isWindows) {
    return AppliedWindowMaterial.none;
  }
  if (!_initialised) {
    try {
      await acrylic.Window.initialize();
      _initialised = true;
    } on Object {
      return AppliedWindowMaterial.none;
    }
  }
  final hwnd = _findMainWindowHandle();
  if (hwnd == 0) {
    return AppliedWindowMaterial.none;
  }
  // The backdrop attribute exists from build 22000; asking earlier builds
  // fails outright, so the version gate spares them the call.
  if (_windowsBuildNumber() >= 22000) {
    try {
      await acrylic.Window.setEffect(effect: acrylic.WindowEffect.mica, dark: dark);
    } on Object {
      return AppliedWindowMaterial.none;
    }
    if (_backdropIsMica(hwnd)) {
      return AppliedWindowMaterial.mica;
    }
  }
  return AppliedWindowMaterial.none;
}

bool _initialised = false;

const int _windowClassNameCapacity = 256;
const int _hwndOwnerNone = 0;

/// Finds the process's main top-level window by class name — the runner
/// registers `FLUTTER_RUNNER_WIN32_WINDOW` — current process id and having
/// no owner. Visibility is not required: at the point a caller runs this,
/// the runner is still holding the window hidden until the first frame.
int _findMainWindowHandle() {
  final user32 = ffi.DynamicLibrary.open('user32.dll');
  final kernel32 = ffi.DynamicLibrary.open('kernel32.dll');
  final getCurrentProcessId = kernel32.lookupFunction<ffi.Uint32 Function(), int Function()>('GetCurrentProcessId');
  final pid = getCurrentProcessId();
  _candidates
    ..found = 0
    ..pid = pid
    ..user32 = user32;
  final enumWindows = user32
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.NativeFunction<ffi.Int32 Function(ffi.IntPtr, ffi.IntPtr)>>, ffi.IntPtr),
        int Function(ffi.Pointer<ffi.NativeFunction<ffi.Int32 Function(ffi.IntPtr, ffi.IntPtr)>>, int)
      >('EnumWindows');
  enumWindows(ffi.Pointer.fromFunction<ffi.Int32 Function(ffi.IntPtr, ffi.IntPtr)>(_onWindow, 1), 0);
  return _candidates.found;
}

final class _MainWindowCandidates {
  int pid = 0;
  int found = 0;
  ffi.DynamicLibrary? user32;
}

final _MainWindowCandidates _candidates = _MainWindowCandidates();

int _onWindow(int hwnd, int _) {
  final user32 = _candidates.user32;
  if (user32 == null) {
    return 1;
  }
  final getWindowThreadProcessId = user32
      .lookupFunction<
        ffi.Uint32 Function(ffi.IntPtr, ffi.Pointer<ffi.Uint32>),
        int Function(int, ffi.Pointer<ffi.Uint32>)
      >('GetWindowThreadProcessId');
  if (getWindowThreadProcessId(hwnd, ffi.nullptr) != _candidates.pid) {
    return 1;
  }
  final getWindow = user32.lookupFunction<ffi.IntPtr Function(ffi.IntPtr, ffi.Uint32), int Function(int, int)>(
    'GetWindow',
  );
  // GW_OWNER: a window owned by another (a dialog the runner put up) is not
  // the main window, whatever its class says.
  if (getWindow(hwnd, 4) != _hwndOwnerNone) {
    return 1;
  }
  final getClassName = user32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Pointer<ffi.Uint16>, ffi.Int32),
        int Function(int, ffi.Pointer<ffi.Uint16>, int)
      >('GetClassNameW');
  final name = calloc<ffi.Uint16>(_windowClassNameCapacity);
  try {
    getClassName(hwnd, name, _windowClassNameCapacity);
    if (name.cast<Utf16>().toDartString() != 'FLUTTER_RUNNER_WIN32_WINDOW') {
      return 1;
    }
  } finally {
    calloc.free(name);
  }
  _candidates.found = hwnd;
  return 0;
}

int _windowsBuildNumber() {
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

/// Reads the window's `DWMWA_SYSTEMBACKDROP_TYPE` back: a Mica request only
/// counts as applied when the DWM answers 2 (`DWMSBT_MAINWINDOW`).
bool _backdropIsMica(int hwnd) {
  final dwmapi = ffi.DynamicLibrary.open('dwmapi.dll');
  final getAttribute = dwmapi
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Uint32, ffi.Pointer<ffi.Void>, ffi.Uint32),
        int Function(int, int, ffi.Pointer<ffi.Void>, int)
      >('DwmGetWindowAttribute');
  const backdropAttribute = 38; // DWMWA_SYSTEMBACKDROP_TYPE
  const mainWindowMica = 2; // DWMSBT_MAINWINDOW
  final readback = calloc<ffi.Int32>();
  try {
    return getAttribute(hwnd, backdropAttribute, readback.cast<ffi.Void>(), ffi.sizeOf<ffi.Int32>()) == 0 &&
        readback.value == mainWindowMica;
  } finally {
    calloc.free(readback);
  }
}
