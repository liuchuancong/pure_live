import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowUtils {
  static final String _propName = "PureLive_InstanceID";

  static bool _findAndWake(int targetId) {
    final propPtr = _propName.toNativeUtf16();
    final foundPtr = calloc<Uint8>()..value = 0;
    bool isFound = false;

    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((Pointer hwndPtr, int lParam) {
      final hwnd = HWND(hwndPtr);
      final val = GetProp(hwnd, PCWSTR(propPtr));

      if (val.address == targetId) {
        if (IsIconic(hwnd)) {
          ShowWindow(hwnd, SW_RESTORE);
        }
        ShowWindow(hwnd, SW_SHOW);
        SetForegroundWindow(hwnd);

        foundPtr.value = 1;
        return 0;
      }
      return 1;
    }, exceptionalReturn: 0);

    try {
      EnumWindows(callback.nativeFunction, LPARAM(0));
    } finally {
      callback.close();
      isFound = foundPtr.value == 1;
      free(propPtr);
      free(foundPtr);
    }

    return isFound;
  }

  static void markCurrentWindow(String instanceId) {
    final int idValue = instanceId.isEmpty ? "default".hashCode : instanceId.hashCode;
    final propPtr = _propName.toNativeUtf16();
    final lpdwProcessId = calloc<Uint32>();

    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((Pointer hwndPtr, int lParam) {
      final hwnd = HWND(hwndPtr);
      GetWindowThreadProcessId(hwnd, lpdwProcessId);

      if (lpdwProcessId.value == pid && IsWindowVisible(hwnd)) {
        final handleValue = HANDLE(Pointer.fromAddress(idValue));
        SetProp(hwnd, PCWSTR(propPtr), handleValue);
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
