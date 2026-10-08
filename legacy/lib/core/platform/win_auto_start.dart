import 'dart:developer';
import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

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
    try {
      final key = CURRENT_USER.open(_subKey);
      try {
        final value = key.getValue(myAppName);
        return switch (value) {
          StringValue(:final value) => value,
          _ => null,
        };
      } finally {
        key.close();
      }
    } catch (error) {
      log('Error reading auto-start command: $error');
      return null;
    }
  }

  static bool isEnabled() => commandTargetsExecutable(_registeredCommand(), Platform.resolvedExecutable);

  static bool enable() {
    try {
      final key = CURRENT_USER.open(_subKey, config: RegistryOpenConfig(access: RegistryAccess.write));
      try {
        key.setValue(myAppName, RegistryValue.string('"${Platform.resolvedExecutable}"'));
        return true;
      } finally {
        key.close();
      }
    } catch (error) {
      log('Failed to enable auto-start: $error');
      return false;
    }
  }

  static bool disable() {
    try {
      final key = CURRENT_USER.open(_subKey, config: RegistryOpenConfig(access: RegistryAccess.write));
      try {
        try {
          key.removeValue(myAppName);
        } on Exception catch (_) {
          // Already absent.
        }
        return true;
      } finally {
        key.close();
      }
    } catch (error) {
      log('Failed to disable auto-start: $error');
      return false;
    }
  }
}
