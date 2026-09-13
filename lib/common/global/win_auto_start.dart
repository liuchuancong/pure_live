import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowsAutoStart {
  static const _subKey = r'Software\Microsoft\Windows\CurrentVersion\Run';

  static String myAppName = 'PureLive';

  static bool commandTargetsExecutable(String? command, String executablePath) {
    final executable = _executableFromCommand(command);
    if (executable == null || executablePath.trim().isEmpty) return false;
    return _normalizeWindowsPath(executable) == _normalizeWindowsPath(executablePath);
  }

  static String? _executableFromCommand(String? command) {
    final value = command?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('"')) {
      final closingQuote = value.indexOf('"', 1);
      if (closingQuote <= 1) return null;
      return value.substring(1, closingQuote);
    }
    final separator = value.indexOf(RegExp(r'\s'));
    return separator < 0 ? value : value.substring(0, separator);
  }

  static String _normalizeWindowsPath(String value) => value.trim().replaceAll('/', r'\').toLowerCase();

  static String? _registeredCommand() {
    final keyAddress = calloc<IntPtr>();
    Pointer<Utf16>? path;
    Pointer<Utf16>? name;
    Pointer<Uint32>? type;
    Pointer<Uint32>? byteCount;
    Pointer<Uint8>? data;
    HKEY? key;
    try {
      path = _subKey.toNativeUtf16();
      name = myAppName.toNativeUtf16();
      if (RegOpenKeyEx(HKEY_CURRENT_USER, PCWSTR(path), 0, KEY_READ, keyAddress.cast()) != ERROR_SUCCESS) return null;
      key = HKEY(Pointer.fromAddress(keyAddress.value));
      type = calloc<Uint32>();
      byteCount = calloc<Uint32>();
      if (RegQueryValueEx(key, PCWSTR(name), type, null, byteCount) != ERROR_SUCCESS || byteCount.value < 2) {
        return null;
      }
      if (type.value != REG_SZ && type.value != REG_EXPAND_SZ) return null;
      data = calloc<Uint8>(byteCount.value);
      if (RegQueryValueEx(key, PCWSTR(name), type, data, byteCount) != ERROR_SUCCESS) return null;
      final units = data.cast<Uint16>().asTypedList(byteCount.value ~/ 2);
      final terminator = units.indexOf(0);
      return String.fromCharCodes(terminator < 0 ? units : units.take(terminator));
    } catch (error) {
      log('Error reading auto-start command: $error');
      return null;
    } finally {
      if (key != null) RegCloseKey(key);
      if (data != null) calloc.free(data);
      if (byteCount != null) calloc.free(byteCount);
      if (type != null) calloc.free(type);
      if (name != null) calloc.free(name);
      if (path != null) calloc.free(path);
      calloc.free(keyAddress);
    }
  }

  static bool isEnabled() => commandTargetsExecutable(_registeredCommand(), Platform.resolvedExecutable);

  static bool enable() {
    final keyAddress = calloc<IntPtr>();
    Pointer<Utf16>? path;
    Pointer<Utf16>? name;
    Pointer<Utf16>? executable;
    HKEY? key;
    try {
      path = _subKey.toNativeUtf16();
      name = myAppName.toNativeUtf16();
      executable = '"${Platform.resolvedExecutable}"'.toNativeUtf16();
      if (RegOpenKeyEx(HKEY_CURRENT_USER, PCWSTR(path), 0, KEY_SET_VALUE, keyAddress.cast()) != ERROR_SUCCESS) {
        return false;
      }
      key = HKEY(Pointer.fromAddress(keyAddress.value));
      return RegSetValueEx(key, PCWSTR(name), REG_VALUE_TYPE(REG_SZ), executable.cast(), (executable.length + 1) * 2) ==
          ERROR_SUCCESS;
    } catch (error) {
      log('Failed to enable auto-start: $error');
      return false;
    } finally {
      if (key != null) RegCloseKey(key);
      if (executable != null) calloc.free(executable);
      if (name != null) calloc.free(name);
      if (path != null) calloc.free(path);
      calloc.free(keyAddress);
    }
  }

  static bool disable() {
    final keyAddress = calloc<IntPtr>();
    Pointer<Utf16>? path;
    Pointer<Utf16>? name;
    HKEY? key;
    try {
      path = _subKey.toNativeUtf16();
      name = myAppName.toNativeUtf16();
      if (RegOpenKeyEx(HKEY_CURRENT_USER, PCWSTR(path), 0, KEY_SET_VALUE, keyAddress.cast()) != ERROR_SUCCESS) {
        return false;
      }
      key = HKEY(Pointer.fromAddress(keyAddress.value));
      final result = RegDeleteValue(key, PCWSTR(name));
      return result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND;
    } catch (error) {
      log('Failed to disable auto-start: $error');
      return false;
    } finally {
      if (key != null) RegCloseKey(key);
      if (name != null) calloc.free(name);
      if (path != null) calloc.free(path);
      calloc.free(keyAddress);
    }
  }
}
