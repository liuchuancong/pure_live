import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  var calls = <List<String>>[];

  Future<ProcessResult> record(String executable, List<String> arguments) async {
    calls.add([executable, ...arguments]);
    return ProcessResult(1, 0, '', '');
  }

  CommandProtocolRegistration windows() => CommandProtocolRegistration(
    platform: PlatformKind.windows,
    executablePath: r'C:\app\unit_host.exe',
    progIdPrefix: 'unit_host',
    displayName: 'Unit Host',
    desktopEntryName: 'unit_host',
    run: record,
  );

  CommandProtocolRegistration linux(Directory applicationsDirectory) => CommandProtocolRegistration(
    platform: PlatformKind.linux,
    executablePath: '/opt/unit_host/unit_host',
    progIdPrefix: 'unit_host',
    displayName: 'Unit Host',
    desktopEntryName: 'unit_host',
    applicationsDirectory: applicationsDirectory,
    run: record,
  );

  setUp(() => calls = []);

  group('Windows scheme', () {
    test('the key paths are built with real separators, not literal dollars', () async {
      expect(await windows().registerScheme('pureshell'), isTrue);

      expect(calls, hasLength(3));
      expect(calls[0], ['reg', 'add', r'HKCU\Software\Classes\pureshell', '/ve', '/d', 'URL:Unit Host', '/f']);
      // The empty URL Protocol value is what makes this a protocol at all.
      expect(calls[1], ['reg', 'add', r'HKCU\Software\Classes\pureshell', '/v', 'URL Protocol', '/d', '', '/f']);
      expect(calls[2], [
        'reg',
        'add',
        r'HKCU\Software\Classes\pureshell\shell\open\command',
        '/ve',
        '/d',
        r'"C:\app\unit_host.exe" "%1"',
        '/f',
      ]);
    });

    test('a step that fails stops the sequence and is reported', () async {
      final failing = CommandProtocolRegistration(
        platform: PlatformKind.windows,
        executablePath: r'C:\app\unit_host.exe',
        progIdPrefix: 'unit_host',
        displayName: 'Unit Host',
        desktopEntryName: 'unit_host',
        run: (_, _) async => ProcessResult(1, 1010, '', 'Access is denied.'),
      );

      expect(await failing.registerScheme('pureshell'), isFalse);
    });
  });

  group('Windows file types', () {
    test('a bare extension gains its dot and its own ProgID', () async {
      expect(await windows().offerFileTypes(['m3u']), isTrue);

      expect(calls[0], containsAllInOrder(['add', r'HKCU\Software\Classes\unit_hostm3u', '/ve']));
      expect(calls[1], containsAllInOrder(['add', r'HKCU\Software\Classes\unit_hostm3u\shell\open\command']));
    });

    test('offering does not rewrite the viewer’s existing default handler', () async {
      await windows().offerFileTypes(['.m3u']);

      final extensionKey = calls.last[2];
      expect(extensionKey, r'HKCU\Software\Classes\.m3u\OpenWithProgids');
      expect(calls.last, contains('/v'), reason: 'a value under OpenWithProgids, never the (default) value');
      expect(
        calls.any((call) => call.contains(r'HKCU\Software\Classes\.m3u')),
        isFalse,
        reason: 'touching the extension key itself would steal the association',
      );
    });

    test('several extensions each get their three entries', () async {
      await windows().offerFileTypes(['.m3u', '.m3u8']);

      expect(calls, hasLength(6));
    });
  });

  group('Linux', () {
    test('a scheme is claimed through x-scheme-handler in the desktop entry', () async {
      final home = Directory.systemTemp.createTempSync('shell-protocol');
      addTearDown(() => home.deleteSync(recursive: true));
      final registration = linux(home);

      expect(await registration.registerScheme('pureshell'), isTrue);

      // The entry on disk is named by desktopEntryName, not by any product
      // the package assumes.
      final text = File(p.join(home.path, 'unit_host.desktop')).readAsStringSync();
      expect(text, contains('MimeType=x-scheme-handler/pureshell;'));
      expect(text, contains('Exec="/opt/unit_host/unit_host" "%u"'));
      expect(calls.map((call) => call.first), contains('update-desktop-database'));
    });

    test('the host’s entry name, not a fixed one, titles the written file', () async {
      final home = Directory.systemTemp.createTempSync('shell-protocol-named');
      addTearDown(() => home.deleteSync(recursive: true));
      final registration = CommandProtocolRegistration(
        platform: PlatformKind.linux,
        executablePath: '/opt/unit_host/unit_host',
        progIdPrefix: 'unit_host',
        displayName: 'Unit Host',
        desktopEntryName: 'other_host',
        applicationsDirectory: home,
        run: record,
      );

      expect(await registration.registerScheme('pureshell'), isTrue);

      expect(File(p.join(home.path, 'other_host.desktop')).existsSync(), isTrue);
      expect(File(p.join(home.path, 'unit_host.desktop')).existsSync(), isFalse);
    });

    test('an extension with no known MIME type is refused, not glossed over', () async {
      final home = Directory.systemTemp.createTempSync('shell-protocol-unknown');
      addTearDown(() => home.deleteSync(recursive: true));
      final registration = linux(home);

      expect(await registration.offerFileTypes(['.weird']), isFalse);
      expect(File(p.join(home.path, 'unit_host.desktop')).existsSync(), isFalse, reason: 'nothing was claimed');
    });

    test('a known playlist extension lands in the MimeType list', () async {
      final home = Directory.systemTemp.createTempSync('shell-protocol-m3u');
      addTearDown(() => home.deleteSync(recursive: true));
      final registration = linux(home);

      expect(await registration.offerFileTypes(['.m3u', '.m3u8']), isTrue);

      final text = File(p.join(home.path, 'unit_host.desktop')).readAsStringSync();
      expect(text, contains('application/x-mpegurl;application/vnd.apple.mpegurl;'));
    });
  });

  group('platforms without a runtime notion', () {
    test('macOS says so instead of pretending', () async {
      final mac = CommandProtocolRegistration(
        platform: PlatformKind.macos,
        executablePath: '/Applications/Unit Host.app/Contents/MacOS/unit_host',
        progIdPrefix: 'unit_host',
        displayName: 'Unit Host',
        desktopEntryName: 'unit_host',
        run: record,
      );

      expect(mac.supportsRuntimeRegistration, isFalse);
      expect(await mac.registerScheme('pureshell'), isFalse);
      expect(await mac.offerFileTypes(['.m3u']), isFalse);
      expect(calls, isEmpty, reason: 'the Info.plist is written at build time, not by us');
    });
  });
}
