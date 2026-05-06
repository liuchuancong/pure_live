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

    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((int hwnd, int lParam) {
      // 2. 直接使用外部传入的指针
      final val = GetProp(hwnd, propPtr);
      if (val == targetId) {
        if (IsIconic(hwnd) != 0) ShowWindow(hwnd, SW_RESTORE);
        ShowWindow(hwnd, SW_SHOW);
        SetForegroundWindow(hwnd);
        found = true;
        return 0;
      }
      return 1;
    }, exceptionalReturn: 0);

    try {
      EnumWindows(callback.nativeFunction, 0);
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

    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((int hwnd, int lParam) {
      GetWindowThreadProcessId(hwnd, lpdwProcessId);

      if (lpdwProcessId.value == pid && IsWindowVisible(hwnd) != 0) {
        SetProp(hwnd, propPtr, idValue);
        return 0;
      }
      return 1;
    }, exceptionalReturn: 0);

    try {
      EnumWindows(callback.nativeFunction, 0);
    } finally {
      callback.close();
      free(propPtr);
      free(lpdwProcessId); // 确保无论如何都会释放
    }
  }

  static bool wakeUpByProp(String instanceId) {
    final int targetId = instanceId.isEmpty ? "default".hashCode : instanceId.hashCode;
    return _findAndWake(targetId);
  }
}
