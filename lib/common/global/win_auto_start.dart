import 'dart:io';
import 'dart:ffi';
import 'dart:developer';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowsAutoStart {
  static const _subKey = r'Software\Microsoft\Windows\CurrentVersion\Run';

  static String myAppName = "PureLive";

  static bool isEnabled() {
    final lpKey = calloc<IntPtr>();
    final lpData = calloc<BYTE>(MAX_PATH);
    final lpcbData = calloc<DWORD>()..value = MAX_PATH;

    bool enabled = false;

    try {
      final pathPtr = _subKey.toNativeUtf16();
      final namePtr = myAppName.toNativeUtf16();

      if (RegOpenKeyEx(HKEY_CURRENT_USER, PCWSTR(pathPtr), 0, KEY_READ, lpKey.cast()) == ERROR_SUCCESS) {
        final hKey = HKEY(Pointer.fromAddress(lpKey.value));
        if (RegQueryValueEx(hKey, PCWSTR(namePtr), nullptr, lpData.cast(), lpcbData) == ERROR_SUCCESS) {
          enabled = true;
        }
        RegCloseKey(hKey);
      }

      free(pathPtr);
      free(namePtr);
    } catch (e) {
      log("Error checking auto-start status: $e");
    } finally {
      free(lpKey);
      free(lpData);
      free(lpcbData);
    }
    return enabled;
  }

  static bool enable() {
    final lpKey = calloc<IntPtr>();
    bool success = false;

    try {
      final pathPtr = _subKey.toNativeUtf16();
      final namePtr = myAppName.toNativeUtf16();
      final exePath = '"${Platform.resolvedExecutable}"'.toNativeUtf16();

      if (RegOpenKeyEx(HKEY_CURRENT_USER, PCWSTR(pathPtr), 0, KEY_SET_VALUE, lpKey.cast()) == ERROR_SUCCESS) {
        final hKey = HKEY(Pointer.fromAddress(lpKey.value));
        final result = RegSetValueEx(
          hKey,
          PCWSTR(namePtr),
          REG_VALUE_TYPE(REG_SZ),
          exePath.cast(),
          (exePath.length + 1) * 2,
        );
        success = (result == ERROR_SUCCESS);
        RegCloseKey(hKey);
      }

      free(pathPtr);
      free(namePtr);
      free(exePath);
    } catch (e) {
      log("Failed to enable auto-start: $e");
    } finally {
      free(lpKey);
    }
    return success;
  }

  static bool disable() {
    final lpKey = calloc<IntPtr>();
    bool success = false;

    try {
      final pathPtr = _subKey.toNativeUtf16();
      final namePtr = myAppName.toNativeUtf16();

      if (RegOpenKeyEx(HKEY_CURRENT_USER, PCWSTR(pathPtr), 0, KEY_SET_VALUE, lpKey.cast()) == ERROR_SUCCESS) {
        final hKey = HKEY(Pointer.fromAddress(lpKey.value));
        final result = RegDeleteValue(hKey, PCWSTR(namePtr));
        success = (result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND);
        RegCloseKey(hKey);
      }

      free(pathPtr);
      free(namePtr);
    } catch (e) {
      log("Failed to disable auto-start: $e");
    } finally {
      free(lpKey);
    }
    return success;
  }
}
