import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowUtils {
  static final String _propName = "PureLive_InstanceID";

  /// Corrected NativeCallable for WNDENUMPROC
  static bool _findAndWake(int targetId) {
    bool found = false;

    // The function signature MUST be (int, int) -> int for WNDENUMPROC
    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((int hwnd, int lParam) {
      final propPtr = _propName.toNativeUtf16();
      final val = GetProp(hwnd, propPtr);
      free(propPtr);

      if (val == targetId && val != 0) {
        if (IsWindowVisible(hwnd) != 0) {
          ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
          found = true;
          return 0;
        }
      }
      return 1; // Continue
    }, exceptionalReturn: 0);

    EnumWindows(callback.nativeFunction, 0);
    callback.close();
    return found;
  }

  /// Mark the current window with the instance hash
  static void markCurrentWindow(String instanceId) {
    final int idValue = instanceId.isEmpty ? "default".hashCode : instanceId.hashCode;

    // Find the window belonging to the current process
    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((int hwnd, int lParam) {
      final lpdwProcessId = calloc<Uint32>();
      GetWindowThreadProcessId(hwnd, lpdwProcessId);

      // If this window belongs to our PID and is a top-level visible window
      if (lpdwProcessId.value == pid && IsWindowVisible(hwnd) != 0) {
        final propPtr = _propName.toNativeUtf16();
        SetProp(hwnd, propPtr, idValue);
        free(propPtr);
        free(lpdwProcessId);
        return 0; // Found our window, stop
      }

      free(lpdwProcessId);
      return 1;
    }, exceptionalReturn: 0);

    EnumWindows(callback.nativeFunction, 0);
    callback.close();
  }

  static bool wakeUpByProp(String instanceId) {
    final int targetId = instanceId.isEmpty ? "default".hashCode : instanceId.hashCode;
    return _findAndWake(targetId);
  }
}
