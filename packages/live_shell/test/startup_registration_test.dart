import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// One recorded command.
typedef Call = (String executable, List<String> arguments);

void main() {
  var calls = <Call>[];

  Future<ProcessResult> fakeRun(String executable, List<String> arguments) async {
    calls.add((executable, arguments));
    return ProcessResult(1, 0, '', '');
  }

  setUp(() => calls = []);

  CommandStartupRegistration registration({
    PlatformKind platform = PlatformKind.windows,
    List<String> arguments = const [],
    Directory? autostartDirectory,
    bool Function()? systemReportsHidden,
  }) => CommandStartupRegistration(
    platform: platform,
    executablePath: platform == PlatformKind.macos
        ? '/Applications/Unit Host.app/Contents/MacOS/unit_host'
        : r'C:\app\unit_host.exe',
    registryValueName: 'unit_host',
    displayName: 'Unit Host',
    arguments: arguments,
    autostartDirectory: autostartDirectory,
    run: fakeRun,
    systemReportsHidden: systemReportsHidden,
  );

  group('Windows', () {
    test('registering writes the Run key with the hidden flag baked in', () async {
      final ok = await registration().setLaunchAtLogin(enabled: true, hidden: true);

      expect(ok, isTrue);
      expect(calls.single.$1, 'reg');
      final arguments = calls.single.$2;
      expect(
        arguments,
        containsAllInOrder(['add', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run', '/v', 'unit_host']),
      );
      expect(arguments[arguments.indexOf('/d') + 1], contains('--hidden'));
    });

    test('the query is the truth, not the saved preference', () async {
      final registered = registration();
      final missing = CommandStartupRegistration(
        platform: PlatformKind.windows,
        executablePath: r'C:\app\unit_host.exe',
        registryValueName: 'unit_host',
        displayName: 'Unit Host',
        arguments: const [],
        run: (_, _) async =>
            ProcessResult(1, 1, '', 'ERROR: The system was unable to find the specified registry key.'),
      );

      expect(await registered.isLaunchAtLogin(), isTrue);
      expect(await missing.isLaunchAtLogin(), isFalse);
      expect(calls, hasLength(1), reason: 'a query reads the key, it does not write anything');
    });

    test('a refused write is reported as a refusal, not thrown', () async {
      final blocked = CommandStartupRegistration(
        platform: PlatformKind.windows,
        executablePath: r'C:\app\unit_host.exe',
        registryValueName: 'unit_host',
        displayName: 'Unit Host',
        arguments: const [],
        run: (_, _) async => ProcessResult(1, 5, '', 'Access is denied.'),
      );

      expect(await blocked.setLaunchAtLogin(enabled: true), isFalse);
    });

    test('removing an entry that is already gone counts as success', () async {
      final gone = CommandStartupRegistration(
        platform: PlatformKind.windows,
        executablePath: r'C:\app\unit_host.exe',
        registryValueName: 'unit_host',
        displayName: 'Unit Host',
        arguments: const [],
        run: (_, _) async =>
            ProcessResult(1, 1, '', 'ERROR: The system was unable to find the specified registry key.'),
      );

      expect(await gone.setLaunchAtLogin(enabled: false), isTrue);
    });
  });

  group('Linux', () {
    test('the autostart .desktop file is both the registration and the answer', () async {
      final directory = Directory.systemTemp.createTempSync('shell-autostart');
      addTearDown(() => directory.deleteSync(recursive: true));
      final subject = registration(platform: PlatformKind.linux, autostartDirectory: directory);

      expect(await subject.isLaunchAtLogin(), isFalse);
      expect(await subject.setLaunchAtLogin(enabled: true, hidden: true), isTrue);

      // The file on disk is named by registryValueName — the host's own
      // identifier flows into the written artifact.
      final file = File(p.join(directory.path, 'unit_host.desktop'));
      expect(file.existsSync(), isTrue);
      expect(await subject.isLaunchAtLogin(), isTrue, reason: 'read from disk, not from a setting');
      final text = await file.readAsString();
      expect(text, contains('[Desktop Entry]'));
      expect(text, contains('Exec="'));
      expect(text, contains('--hidden'));
      expect(calls, isEmpty, reason: 'no shell command needed to write a file');

      expect(await subject.setLaunchAtLogin(enabled: false), isTrue);
      expect(file.existsSync(), isFalse);
    });
  });

  group('macOS', () {
    test('login items are added and removed by name', () async {
      final subject = registration(platform: PlatformKind.macos);

      expect(await subject.setLaunchAtLogin(enabled: true), isTrue);
      expect(calls.single.$1, '/usr/bin/osascript');
      expect(calls.single.$2.join(' '), contains('make login item at end'));

      await subject.setLaunchAtLogin(enabled: false);
      expect(calls.last.$2.join(' '), contains('delete login item "Unit Host"'));
    });

    test('the query matches the display name exactly among the list', () async {
      final listing = CommandStartupRegistration(
        platform: PlatformKind.macos,
        executablePath: '/Applications/Unit Host.app/Contents/MacOS/unit_host',
        registryValueName: 'unit_host',
        displayName: 'Unit Host',
        arguments: const [],
        run: (_, _) async => ProcessResult(1, 0, 'iCloud Drive, Unit Host, Steam', ''),
      );
      final absent = CommandStartupRegistration(
        platform: PlatformKind.macos,
        executablePath: '/Applications/Unit Host.app/Contents/MacOS/unit_host',
        registryValueName: 'unit_host',
        displayName: 'Unit Host',
        arguments: const [],
        run: (_, _) async => ProcessResult(1, 0, 'iCloud Drive, Steam', ''),
      );

      expect(await listing.isLaunchAtLogin(), isTrue);
      expect(await absent.isLaunchAtLogin(), isFalse);
    });
  });

  group('hidden start', () {
    test('our own flag and the system record both count', () {
      expect(registration(arguments: const ['--hidden']).wasLaunchedHidden, isTrue);
      expect(registration(systemReportsHidden: () => true).wasLaunchedHidden, isTrue);
      expect(registration(arguments: const ['--foo']).wasLaunchedHidden, isFalse);
    });

    test('a platform without a startup notion says so', () async {
      final android = registration(platform: PlatformKind.android);

      expect(android.supportsHiddenLaunch, isFalse);
      expect(await android.setLaunchAtLogin(enabled: true), isFalse);
      expect(await android.isLaunchAtLogin(), isFalse);
      expect(calls, isEmpty);
    });
  });
}
