import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/src/instance/launch_intent.dart';
import 'package:live_shell/src/startup/startup_registration.dart';

/// Runs one external command. Injectable, so the registration can be tested
/// without touching a registry or a user's autostart folder.
typedef RunCommand = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Launch-at-sign-in through the commands each platform already ships.
///
/// No plugin is involved: Windows has a per-user `Run` key that `reg.exe` reads
/// and writes, Linux has the XDG autostart directory whose entries are plain
/// `.desktop` files, and macOS has one AppleScript verb. That matters for
/// Windows 10 in particular, where the newer per-user startup-folder APIs are
/// not all available but the `Run` key has been there since NT.
///
/// Three behaviours are deliberate:
///
/// * **[setLaunchAtLogin] answers false instead of throwing.** A managed
///   machine can forbid the registry write and a sandboxed build cannot reach
///   the autostart directory; the caller needs to put its toggle back, not
///   watch the settings screen crash.
/// * **[isLaunchAtLogin] asks the system, not the saved preference.** On Linux
///   the `.desktop` file is the truth and the viewer may delete or edit it; a
///   switch that reads the app's own setting will happily display "on" for a
///   registration that no longer exists.
/// * **A hidden start is written into the command line on Windows and Linux**,
///   because neither has a "start hidden" notion the way macOS does — the
///   argument is the only mechanism, which is why `--hidden` belongs to the
///   registration rather than to the app's own reading of its settings.
final class CommandStartupRegistration implements StartupRegistration {
  /// A registration for one app on one platform.
  ///
  /// [registryValueName] is the Windows value name and the Linux file base, so
  /// one identifier is enough to find the entry again on either.
  new({
    required this.platform,
    required this.executablePath,
    required this.registryValueName,
    required this.displayName,
    required this.arguments,
    this.autostartDirectory,
    RunCommand? run,
    bool Function()? systemReportsHidden,
  }) : _run = run ?? Process.run,
       _systemReportsHidden = systemReportsHidden ?? (() => false);

  /// The platform this instance speaks for.
  final PlatformKind platform;

  /// The executable to register. On a packaged Windows install this is the
  /// launcher, not the DLL directory.
  final String executablePath;

  /// The registry value name / autostart file base.
  final String registryValueName;

  /// The name macOS shows in its Login Items list.
  final String displayName;

  /// This process's own command line, read for [wasLaunchedHidden].
  final List<String> arguments;

  /// Where XDG autostart entries live, null to use `$HOME/.config/autostart`.
  final Directory? autostartDirectory;

  final RunCommand _run;
  final bool Function() _systemReportsHidden;

  static const String _windowsRunKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  @override
  bool get supportsHiddenLaunch =>
      platform == PlatformKind.windows || platform == PlatformKind.linux || platform == PlatformKind.macos;

  @override
  bool get wasLaunchedHidden =>
      wasRequestedHidden(arguments: arguments, openedAsHiddenBySystem: _systemReportsHidden());

  @override
  Future<bool> setLaunchAtLogin({required bool enabled, bool hidden = false}) => switch (platform) {
    PlatformKind.windows => _windowsSet(enabled: enabled, hidden: hidden),
    PlatformKind.linux => Future<bool>.value(_linuxSet(enabled: enabled, hidden: hidden)),
    PlatformKind.macos => _macosSet(enabled: enabled),
    _ => Future<bool>.value(false),
  };

  @override
  Future<bool> isLaunchAtLogin() => switch (platform) {
    PlatformKind.windows => _windowsQuery(),
    PlatformKind.linux => Future<bool>.value(_linuxFile().existsSync()),
    PlatformKind.macos => _macosQuery(),
    _ => Future<bool>.value(false),
  };

  Future<bool> _windowsSet({required bool enabled, required bool hidden}) async {
    if (!enabled) {
      final result = await _run('reg', ['delete', _windowsRunKey, '/v', registryValueName, '/f']);
      // A missing value is the state we asked for, not a failure.
      return result.exitCode == 0 || _reportsNotFound(result);
    }
    final command = '"$executablePath"${hidden ? ' ${const LaunchHiddenFlag().value}' : ''}';
    final result = await _run('reg', [
      'add',
      _windowsRunKey,
      '/v',
      registryValueName,
      '/t',
      'REG_SZ',
      '/d',
      command,
      '/f',
    ]);
    return result.exitCode == 0;
  }

  Future<bool> _windowsQuery() async {
    final result = await _run('reg', ['query', _windowsRunKey, '/v', registryValueName]);
    return result.exitCode == 0;
  }

  Future<bool> _macosSet({required bool enabled}) async {
    final script = enabled
        ? 'tell application "System Events" to make login item at end '
              'with properties {path:"$executablePath", hidden:false}'
        : 'tell application "System Events" to delete login item "$displayName"';
    final result = await _run('/usr/bin/osascript', ['-e', script]);
    return result.exitCode == 0;
  }

  Future<bool> _macosQuery() async {
    final result = await _run('/usr/bin/osascript', [
      '-e',
      'tell application "System Events" to get the name of every login item',
    ]);
    if (result.exitCode != 0) {
      return false;
    }
    return result.stdout.toString().split(',').any((name) => name.trim() == displayName);
  }

  File _linuxFile() {
    final directory =
        autostartDirectory ??
        Directory('${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/.config/autostart');
    return File('${directory.path}/$registryValueName.desktop');
  }

  /// Writes or removes the XDG autostart entry.
  ///
  /// Synchronous on purpose: this runs once, from a settings toggle, and the
  /// async `dart:io` calls would put the registration behind a microtask queue
  /// that a fast click sequence can interleave — the classic "I turned it off
  /// and it came back" report.
  bool _linuxSet({required bool enabled, required bool hidden}) {
    final file = _linuxFile();
    try {
      if (!enabled) {
        if (file.existsSync()) {
          file.deleteSync();
        }
        return true;
      }
      // The Exec line carries --hidden, so "start at sign-in" on Linux means
      // "start at sign-in in the tray" — which is what a hidden autostart is for
      // when there is no system-level flag to ask for.
      final entry = [
        '[Desktop Entry]',
        'Type=Application',
        'Version=1.0',
        'Name=$displayName',
        'Exec="$executablePath"${hidden ? ' ${const LaunchHiddenFlag().value}' : ''}',
        'Terminal=false',
        'X-GNOME-Autostart-enabled=true',
        '',
      ].join('\n');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Whether a `reg` failure means "that entry was not there".
  ///
  /// The wording matters, and it is not the wording one expects: reg.exe answers
  /// `ERROR: The system was unable to find the specified registry key.` rather
  /// than saying "not found". Treating that as a failure would report "could not
  /// turn off" for an entry that was already off, which the settings screen then
  /// leaves switched on forever.
  bool _reportsNotFound(ProcessResult result) {
    final text = '${result.stderr}${result.stdout}'.toLowerCase();
    return text.contains('unable to find') ||
        text.contains('cannot find') ||
        text.contains('not found') ||
        text.contains('找不到');
  }
}
