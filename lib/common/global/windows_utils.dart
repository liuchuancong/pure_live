import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowUtils {
  static final String _propName = "PureLive_InstanceID";

  static bool _findAndWake(int targetId) {
    bool found = false;
    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((int hwnd, int lParam) {
      final propPtr = _propName.toNativeUtf16();
      final val = GetProp(hwnd, propPtr);
      free(propPtr);
      if (val == targetId) {
        // 1. 先检查是否最小化
        if (IsIconic(hwnd) != 0) {
          ShowWindow(hwnd, SW_RESTORE);
        }
        ShowWindow(hwnd, SW_SHOW);
        SetForegroundWindow(hwnd);
        found = true;
        return 0; // 停止枚举
      }
      return 1; // 继续
    }, exceptionalReturn: 0);

    try {
      EnumWindows(callback.nativeFunction, 0);
    } finally {
      callback.close();
    }

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
