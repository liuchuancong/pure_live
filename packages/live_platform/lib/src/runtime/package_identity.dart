import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// The Windows package-identity probe: does this process run with a package
/// identity, and under which family name.
///
/// The answer is evidence, not a verdict. Identity present means the MSIX
/// container rules apply to this process (that is the part that decides
/// where data may live), whether the package arrived through a store
/// install or a development registration. Identity absent proves nothing
/// about being an ordinary installed build — it only removes the MSIX
/// hypothesis. Both directions follow the official Flutter/winapp example:
/// `GetCurrentPackageFamilyName` from kernel32, two calls, first for the
/// buffer length.
abstract final class PackageIdentity {
  /// The package family name when the process has package identity on
  /// Windows, null otherwise (other platforms, no identity, or any probe
  /// failure — a broken probe must never break a startup).
  static String? windowsFamilyName() {
    if (!Platform.isWindows) {
      return null;
    }
    final length = calloc<Uint32>();
    try {
      final getCurrentPackageFamilyName = DynamicLibrary.open('kernel32.dll')
          .lookupFunction<
            Int32 Function(Pointer<Uint32>, Pointer<Uint16>),
            int Function(Pointer<Uint32>, Pointer<Uint16>)
          >('GetCurrentPackageFamilyName');
      // First call without a buffer: ERROR_INSUFFICIENT_BUFFER (122) is the
      // success path here — it reports the required length. Any other code,
      // including APPMODEL_ERROR_NO_PACKAGE, means "no identity".
      final probe = getCurrentPackageFamilyName(length, Pointer<Uint16>.fromAddress(0));
      if (probe != 122) {
        return null;
      }
      final name = calloc<Uint16>(length.value);
      try {
        if (getCurrentPackageFamilyName(length, name) != 0) {
          return null;
        }
        return name.cast<Utf16>().toDartString();
      } finally {
        calloc.free(name);
      }
    } on Object {
      // A missing symbol or a load failure is "no identity", not a crash.
      return null;
    } finally {
      calloc.free(length);
    }
  }
}
