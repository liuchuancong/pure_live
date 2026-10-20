import 'dart:ffi' as ffi;
import 'dart:ui' show Color;

import 'package:ffi/ffi.dart' show StringUtf16Pointer, calloc;

typedef _RegGetValueWNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void> key,
  ffi.Pointer<ffi.Uint16> subKey,
  ffi.Pointer<ffi.Uint16> value,
  ffi.Uint32 flags,
  ffi.Pointer<ffi.Uint32> type,
  ffi.Pointer<ffi.Void> data,
  ffi.Pointer<ffi.Uint32> size,
);

typedef _RegGetValueWDart = int Function(
  ffi.Pointer<ffi.Void> key,
  ffi.Pointer<ffi.Uint16> subKey,
  ffi.Pointer<ffi.Uint16> value,
  int flags,
  ffi.Pointer<ffi.Uint32> type,
  ffi.Pointer<ffi.Void> data,
  ffi.Pointer<ffi.Uint32> size,
);

/// The user's Windows accent colour, or null when there is nothing to read.
///
/// The system stores the accent the Settings app writes at
/// `HKCU\Software\Microsoft\Windows\DWM\ColorizationColor` as one DWORD,
/// `0xAABBGGRR` — the colour Fluent apps pick up by default. A theme with no
/// stored accent choice seeds itself from it, so an install left at its
/// defaults looks like the machine it is on. Every failure (another platform,
/// an older Windows without the value, a refused read) is an answer of null,
/// and the caller keeps its own default.
Color? readWindowsAccentColor() {
  try {
    final advapi32 = ffi.DynamicLibrary.open('Advapi32.dll');
    final regGetValue = advapi32.lookupFunction<_RegGetValueWNative, _RegGetValueWDart>('RegGetValueW');
    final subKey = r'Software\Microsoft\Windows\DWM'.toNativeUtf16().cast<ffi.Uint16>();
    final valueName = 'ColorizationColor'.toNativeUtf16().cast<ffi.Uint16>();
    final data = calloc<ffi.Uint32>();
    final size = calloc<ffi.Uint32>()..value = ffi.sizeOf<ffi.Uint32>();
    try {
      // HKEY_CURRENT_USER is a pseudo-handle with a fixed address, and
      // RRF_RT_REG_DWORD (0x10) restricts the read to REG_DWORD values.
      final status = regGetValue(
        ffi.Pointer.fromAddress(0x80000001),
        subKey,
        valueName,
        0x10,
        ffi.nullptr,
        data.cast<ffi.Void>(),
        size,
      );
      if (status != 0) {
        return null;
      }
      final dword = data.value;
      if (dword == 0) {
        return null;
      }
      return Color.fromARGB((dword >> 24) & 0xFF, dword & 0xFF, (dword >> 8) & 0xFF, (dword >> 16) & 0xFF);
    } finally {
      calloc
        ..free(subKey)
        ..free(valueName)
        ..free(data)
        ..free(size);
    }
  } on Object {
    return null;
  }
}
