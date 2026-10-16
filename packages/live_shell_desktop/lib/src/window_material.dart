import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// The material a window ended up with, or [none] when nothing was applied
/// and the surface must stay opaque.
enum AppliedWindowMaterial {
  /// Windows 11's compositor-hosted Mica, via `DWMWA_SYSTEMBACKDROP_TYPE`.
  mica,

  /// Windows 10's accent-policy acrylic blur, via the undocumented
  /// `SetWindowCompositionAttribute`. Known to drop frames while the window
  /// is dragged; it is the best Win10 offers without a UI toolkit blur.
  acrylic,

  /// Nothing was applied: the window keeps its opaque background.
  none,
}

/// Signature of the material applier, so callers and tests can substitute
/// their own.
typedef WindowMaterialApplier = AppliedWindowMaterial Function({required bool dark});

/// Applies the strongest translucent material the running Windows supports
/// behind the process's main window.
///
/// The dispatch is the industry three-step: build 22000+ asks the DWM for
/// Mica and verifies the attribute took by reading it back; older builds ask
/// user32's accent policy for acrylic and trust its boolean. A failure at
/// any step — missing export, failed call, unsupported attribute — falls
/// through to [AppliedWindowMaterial.none], and the caller must keep the
/// opaque surface: a transparent clear colour with no material behind it
/// shows the desktop through on Windows 10, which is the artefact this
/// contract exists to prevent.
AppliedWindowMaterial applyWindowMaterial({required bool dark}) {
  if (!Platform.isWindows) {
    return AppliedWindowMaterial.none;
  }
  final hwnd = _findMainWindowHandle();
  if (hwnd == 0) {
    return AppliedWindowMaterial.none;
  }
  // The backdrop attribute exists from build 22000; asking earlier builds
  // fails outright, so the version gate spares them the call.
  if (_windowsBuildNumber() >= 22000 && _applyMica(hwnd, dark: dark)) {
    return AppliedWindowMaterial.mica;
  }
  if (_applyAccentAcrylic(hwnd, dark: dark)) {
    return AppliedWindowMaterial.acrylic;
  }
  return AppliedWindowMaterial.none;
}

const int _hwndOwnerNone = 0;
const int _windowClassNameCapacity = 256;

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

bool _applyMica(int hwnd, {required bool dark}) {
  final dwmapi = ffi.DynamicLibrary.open('dwmapi.dll');
  final setAttribute = dwmapi
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Uint32, ffi.Pointer<ffi.Void>, ffi.Uint32),
        int Function(int, int, ffi.Pointer<ffi.Void>, int)
      >('DwmSetWindowAttribute');
  final getAttribute = dwmapi
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Uint32, ffi.Pointer<ffi.Void>, ffi.Uint32),
        int Function(int, int, ffi.Pointer<ffi.Void>, int)
      >('DwmGetWindowAttribute');
  const backdropAttribute = 38; // DWMWA_SYSTEMBACKDROP_TYPE
  const mainWindowMica = 2; // DWMSBT_MAINWINDOW
  final backdrop = calloc<ffi.Int32>()..value = mainWindowMica;
  final readback = calloc<ffi.Int32>();
  try {
    // The backdrop paints behind the extended frame region; without the
    // sheet-of-glass margins the attribute succeeds and shows nothing.
    _extendFrame(dwmapi, hwnd);
    final darkMode = calloc<ffi.Int32>()..value = dark ? 1 : 0;
    try {
      // Attribute 20, DWMWA_USE_IMMERSIVE_DARK_MODE: tints the material.
      setAttribute(hwnd, 20, darkMode.cast<ffi.Void>(), ffi.sizeOf<ffi.Int32>());
    } finally {
      calloc.free(darkMode);
    }
    final applied = setAttribute(hwnd, backdropAttribute, backdrop.cast<ffi.Void>(), ffi.sizeOf<ffi.Int32>()) == 0;
    if (!applied) {
      return false;
    }
    return getAttribute(hwnd, backdropAttribute, readback.cast<ffi.Void>(), ffi.sizeOf<ffi.Int32>()) == 0 &&
        readback.value == mainWindowMica;
  } finally {
    calloc
      ..free(backdrop)
      ..free(readback);
  }
}

void _extendFrame(ffi.DynamicLibrary dwmapi, int hwnd) {
  final extendFrame = dwmapi
      .lookupFunction<ffi.Int32 Function(ffi.IntPtr, ffi.Pointer<_Margins>), int Function(int, ffi.Pointer<_Margins>)>(
        'DwmExtendFrameIntoClientArea',
      );
  final margins = calloc<_Margins>()
    ..ref.left = -1
    ..ref.right = -1
    ..ref.top = -1
    ..ref.bottom = -1;
  try {
    extendFrame(hwnd, margins);
  } finally {
    calloc.free(margins);
  }
}

final class _Margins extends ffi.Struct {
  @ffi.Int32()
  external int left;

  @ffi.Int32()
  external int right;

  @ffi.Int32()
  external int top;

  @ffi.Int32()
  external int bottom;
}

bool _applyAccentAcrylic(int hwnd, {required bool dark}) {
  final user32 = ffi.DynamicLibrary.open('user32.dll');
  final setCompositionAttribute = user32
      .lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Pointer<_CompositionAttribData>),
        int Function(int, ffi.Pointer<_CompositionAttribData>)
      >('SetWindowCompositionAttribute');
  final accent = calloc<_AccentPolicy>()
    ..ref.state =
        4 // ACCENT_ENABLE_ACRYLICBLURBEHIND
    ..ref.flags = 2
    // ABGR: a mostly-opaque tint so the blur has something to work with.
    ..ref.gradientColor = dark ? 0xB4000000 : 0x8CFFFFFF
    ..ref.animationId = 0;
  final data = calloc<_CompositionAttribData>()
    ..ref.attribute =
        19 // WCA_ACCENT_POLICY
    ..ref.data = accent.cast<ffi.Void>()
    ..ref.size = ffi.sizeOf<_AccentPolicy>();
  try {
    return setCompositionAttribute(hwnd, data) != 0;
  } finally {
    calloc
      ..free(accent)
      ..free(data);
  }
}

final class _AccentPolicy extends ffi.Struct {
  @ffi.Uint32()
  external int state;

  @ffi.Uint32()
  external int flags;

  @ffi.Uint32()
  external int gradientColor;

  @ffi.Uint32()
  external int animationId;
}

final class _CompositionAttribData extends ffi.Struct {
  @ffi.Uint32()
  external int attribute;

  external ffi.Pointer<ffi.Void> data;

  @ffi.IntPtr()
  external int size;
}
