import 'dart:io' show Directory, File, Platform, Process, ProcessResult;

import 'package:live_device/src/system/startup/startup_service.dart';

/// Windows auto-start through the per-user Run key.
///
/// The executable is written as a quoted command so paths with spaces survive
/// the shell. Reading compares the registered command's target with this
/// build's executable, not just the value's presence: an entry left by an old
/// install should not make the toggle look on for a build that no longer
/// starts.
final class PlatformStartupService implements StartupService {
  /// Creates the service.
  ///
  /// [valueName] is the registry value's name and must stay stable across
  /// versions, or an upgrade orphans the old entry.
  const new({this.valueName = 'PureLive'});

  /// The Run-key value name.
  final String valueName;

  @override
  StartupCapabilities get capabilities =>
      StartupCapabilities(supported: Platform.isWindows, platformName: Platform.operatingSystem);

  static const String _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  @override
  Future<bool> isEnabled() async {
    _requireWindows();
    if (await _startupScriptMatches()) return true;
    late final ProcessResult result;
    try {
      result = await Process.run('reg.exe', ['query', _runKey, '/v', valueName]).timeout(const Duration(seconds: 3));
    } on Object {
      // The query is a read-only probe; a blocked or slow command means the
      // caller should treat the entry as absent and let the toggle try.
      return false;
    }
    if (result.exitCode != 0) return false;
    final output = '${result.stdout}${result.stderr}';
    final executable = _normalizePath(Platform.resolvedExecutable);
    return _normalizePath(output).contains(executable);
  }

  @override
  Future<void> setEnabled({required bool enabled}) async {
    _requireWindows();
    if (!enabled) {
      await _removeStartupScript();
      try {
        await Process.run('reg.exe', ['delete', _runKey, '/v', valueName, '/f']).timeout(const Duration(seconds: 3));
      } on Object {
        // The user key may be protected; the startup-folder entry is still
        // removed, and the pane reads the remaining state back.
      }
      return;
    }
    try {
      final result = await Process.run('reg.exe', [
        'add',
        _runKey,
        '/v',
        valueName,
        '/t',
        'REG_SZ',
        '/d',
        '"${Platform.resolvedExecutable}"',
        '/f',
      ]).timeout(const Duration(seconds: 3));
      if (result.exitCode == 0) {
        await _removeStartupScript();
        return;
      }
    } on Object {
      // Fall through to the Startup folder, which does not need registry
      // write access and is equally a per-user login entry.
    }
    await _writeStartupScript();
  }

  /// The Startup-folder fallback: a cmd that starts this build detached.
  Future<void> _writeStartupScript() async {
    try {
      final folder = Directory(_startupFolder());
      await folder.create(recursive: true);
      await File(_startupScriptPath())
          .writeAsString('@echo off\r\nstart "" "${Platform.resolvedExecutable}"\r\n', flush: true);
    } on Object catch (error) {
      throw StartupException(code: 'enable_failed', message: 'Could not register the app at login.', cause: error);
    }
  }

  Future<void> _removeStartupScript() async {
    try {
      final file = File(_startupScriptPath());
      if (file.existsSync()) file.deleteSync();
    } on Object {
      // A file the user cannot remove is reported by the next read, not here.
    }
  }

  Future<bool> _startupScriptMatches() async {
    try {
      final file = File(_startupScriptPath());
      if (!file.existsSync()) return false;
      final text = _normalizePath(file.readAsStringSync());
      return text.contains(_normalizePath(Platform.resolvedExecutable));
    } on Object {
      return false;
    }
  }

  static String _startupFolder() {
    final appData = Platform.environment['APPDATA'] ?? '';
    return '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';
  }

  String _startupScriptPath() => '${_startupFolder()}\\$valueName.cmd';

  static String _normalizePath(String value) => value.trim().replaceAll('/', r'\').toLowerCase();

  static void _requireWindows() {
    if (!Platform.isWindows) {
      throw const StartupException(
        code: 'unsupported_on_platform',
        message: 'Auto-start is only available on Windows.',
      );
    }
  }
}
