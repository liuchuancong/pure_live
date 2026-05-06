import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowUtils {
  static final String _propName = "PureLive_InstanceID";

  static bool _findAndWake(int targetId) {
    bool found = false;
    // 1. 在回调外部分配指针，只分配一次
    final propPtr = _propName.toNativeUtf16();

    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((Pointer hwndPtr, int lParam) {
      final hwnd = HWND(hwndPtr.cast<NativeType>());

      // 2. Pass the HWND object (not the address) to Win32 functions
      final val = GetProp(hwnd, PCWSTR(propPtr));

      if (val.address == targetId) {
        if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
        ShowWindow(hwnd, SW_SHOW);
        SetForegroundWindow(hwnd);
        return 0; // Stop enumeration (FALSE)
      }
      return 1; // Continue enumeration (TRUE)
    }, exceptionalReturn: 0);
    try {
      EnumWindows(callback.nativeFunction, LPARAM(0));
    } finally {
      callback.close();
      free(propPtr); // 3. 结束后统一释放
    }
    return found;
  }

  static void markCurrentWindow(String instanceId) {
    final int idValue = instanceId.isEmpty ? "default".hashCode : instanceId.hashCode;
    final propPtr = _propName.toNativeUtf16();
    final lpdwProcessId = calloc<Uint32>();

    // 1. Signature must match (Pointer, int)
    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((Pointer hwndPtr, int lParam) {
      final hwnd = HWND(hwndPtr.cast<NativeType>());

      GetWindowThreadProcessId(hwnd, lpdwProcessId);

      if (lpdwProcessId.value == pid && IsWindowVisible(hwnd)) {
        // Correctly wrap the int as a Pointer-based HANDLE
        SetProp(hwnd, PCWSTR(propPtr), HANDLE(Pointer.fromAddress(idValue)));
        return 0;
      }
      return 1;
    }, exceptionalReturn: 0);

    try {
      EnumWindows(callback.nativeFunction, LPARAM(0));
    } finally {
      callback.close();
      free(propPtr);
      free(lpdwProcessId);
    }
  }

  static bool wakeUpByProp(String instanceId) {
    final int targetId = instanceId.isEmpty ? "default".hashCode : instanceId.hashCode;
    return _findAndWake(targetId);
  }
}
