import 'dart:io';
import 'dart:ffi';
import 'dart:developer';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowsAutoStart {
  // Registry path for current user startup items
  static const _subKey = r'Software\Microsoft\Windows\CurrentVersion\Run';

  static String myAppName = "PureLive";

  /// Checks if the app is already set to auto-start
  static bool isEnabled() {
    final lpKey = calloc<HKEY>();
    final lpData = calloc<BYTE>(MAX_PATH);
    final lpcbData = calloc<DWORD>()..value = MAX_PATH;

    bool enabled = false;

    try {
      final pathPtr = _subKey.toNativeUtf16();
      final namePtr = myAppName.toNativeUtf16();

      // Open the registry key
      if (RegOpenKeyEx(HKEY_CURRENT_USER, pathPtr, 0, KEY_READ, lpKey) == ERROR_SUCCESS) {
        // Try to query the value
        if (RegQueryValueEx(lpKey.value, namePtr, nullptr, nullptr, lpData, lpcbData) == ERROR_SUCCESS) {
          enabled = true;
        }
        RegCloseKey(lpKey.value);
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

  /// Enables auto-start by writing to the registry
  static bool enable() {
    final lpKey = calloc<HKEY>();
    bool success = false;

    try {
      final pathPtr = _subKey.toNativeUtf16();
      final namePtr = myAppName.toNativeUtf16();
      // Get the current executable path and wrap in quotes to handle spaces safely
      final exePath = '"${Platform.resolvedExecutable}"'.toNativeUtf16();

      if (RegOpenKeyEx(HKEY_CURRENT_USER, pathPtr, 0, KEY_SET_VALUE, lpKey) == ERROR_SUCCESS) {
        final result = RegSetValueEx(lpKey.value, namePtr, 0, REG_SZ, exePath.cast(), (exePath.length + 1) * 2);
        success = (result == ERROR_SUCCESS);
        RegCloseKey(lpKey.value);
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

  /// Disables auto-start by removing the registry value
  static bool disable() {
    final lpKey = calloc<HKEY>();
    bool success = false;

    try {
      final pathPtr = _subKey.toNativeUtf16();
      final namePtr = myAppName.toNativeUtf16();

      if (RegOpenKeyEx(HKEY_CURRENT_USER, pathPtr, 0, KEY_SET_VALUE, lpKey) == ERROR_SUCCESS) {
        final result = RegDeleteValue(lpKey.value, namePtr);
        success = (result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND);
        RegCloseKey(lpKey.value);
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
