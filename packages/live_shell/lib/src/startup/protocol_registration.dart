import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/src/startup/command_startup_registration.dart' show RunCommand;
import 'package:path/path.dart' as p;

/// Claiming a URL scheme and file types for this build of the app.
abstract interface class ProtocolRegistration {
  /// Whether the platform lets a running app register handlers at all.
  ///
  /// macOS does not: schemes and document types live in the bundle's
  /// `Info.plist` and are read by Launch Services when the bundle is placed, and
  /// a sandboxed app editing its own bundle breaks its code signature. A mac
  /// build declares them at build time and reports false here, rather than
  /// pretending a toggle did something it cannot do.
  bool get supportsRuntimeRegistration;

  /// Points a scheme (`pureshell`) at this executable, so a browser link or
  /// another app's "open in" can reach the running instance.
  Future<bool> registerScheme(String scheme);

  /// Offers the app as a program able to open [extensions] (`.m3u`, `.xml`).
  ///
  /// Offering is not taking: nothing here rewrites the viewer's existing default
  /// handler, because stealing `.m3u` to save one click is the change they
  /// discover a week later, when their other player stopped opening it.
  Future<bool> offerFileTypes(List<String> extensions);
}

/// Handler registration through the tools each platform already ships.
///
/// On Windows everything is written under `HKCU\Software\Classes`, which needs
/// no administrator and has been the per-user mechanism since the earliest
/// registry — the point for Windows 10, where the packaged-app (sparse package)
/// routes either need an MSIX identity or are not available at all.
final class CommandProtocolRegistration implements ProtocolRegistration {
  /// A registration for one executable on one platform.
  const new({
    required this.platform,
    required this.executablePath,
    required this.progIdPrefix,
    required this.displayName,
    required this.run,
    required this.desktopEntryName,
    this.applicationsDirectory,
  });

  /// The platform spoken for.
  final PlatformKind platform;

  /// The executable a handler invokes.
  final String executablePath;

  /// The base of the ProgIDs this build creates, e.g. the host's app id.
  final String progIdPrefix;

  /// The name shown in the shell's picker.
  final String displayName;

  /// The host application's name; a desktop entry is written as
  /// `<desktopEntryName>.desktop`. Required because this package serves any
  /// host app and must not assume any particular one's identity.
  final String desktopEntryName;

  /// Where desktop entries live, null to use the profile's own.
  ///
  /// Injectable because a registration test that writes into the real
  /// `~/.local/share/applications` would leave a entry behind on the developer's
  /// machine that their file manager then offers to open playlists with.
  final Directory? applicationsDirectory;

  /// The command runner used for `reg` and the desktop database tools.
  final RunCommand run;

  /// The registry path where per-user classes live.
  static const String _classesRoot = r'HKCU\Software\Classes';

  /// The MIME types this build can actually open, by extension.
  static const Map<String, String> _mimeByExtension = {
    '.m3u': 'application/x-mpegurl',
    '.m3u8': 'application/vnd.apple.mpegurl',
    '.xml': 'application/xml',
    '.txt': 'text/plain',
  };

  @override
  bool get supportsRuntimeRegistration => platform == PlatformKind.windows || platform == PlatformKind.linux;

  @override
  Future<bool> registerScheme(String scheme) => switch (platform) {
    PlatformKind.windows => _windowsScheme(scheme),
    PlatformKind.linux => _linuxEntry(mimeType: 'x-scheme-handler/$scheme', argument: '%u'),
    _ => Future<bool>.value(false),
  };

  @override
  Future<bool> offerFileTypes(List<String> extensions) => switch (platform) {
    PlatformKind.windows => _windowsFileTypes(extensions),
    PlatformKind.linux => _linuxFileTypes(extensions),
    _ => Future<bool>.value(false),
  };

  /// The value a handler is registered with: this executable, one argument.
  String get _commandValue => '"$executablePath" "%1"';

  /// The registry path separator.
  static const String _sep = r'\';

  /// One registry path under the per-user classes root.
  ///
  /// Assembled from parts with an explicit separator instead of backslash
  /// escapes: `'a\$b'` means a literal `$b` and `r'a\$b'` means no interpolation
  /// at all, so both plausible-looking spellings of a registry path produce a
  /// key the shell will never look at. Writing the separators as a constant makes
  /// the mistake impossible to make silently.
  static String _key(List<String> parts) => [_classesRoot, ...parts].join(_sep);

  Future<bool> _windowsScheme(String scheme) {
    final key = _key([scheme]);
    final steps = [
      ['add', key, '/ve', '/d', 'URL:$displayName', '/f'],
      // The empty `URL Protocol` value is what marks the key as a protocol
      // rather than a folder; without it the browser never offers the app.
      ['add', key, '/v', 'URL Protocol', '/d', '', '/f'],
      [
        'add',
        _key([scheme, 'shell', 'open', 'command']),
        '/ve',
        '/d',
        _commandValue,
        '/f',
      ],
    ];
    return _runAll(steps);
  }

  Future<bool> _windowsFileTypes(List<String> extensions) {
    final steps = <List<String>>[];
    for (final extension in extensions) {
      final dotted = extension.startsWith('.') ? extension : '.$extension';
      final progId = '$progIdPrefix${dotted.substring(1)}';
      steps
        ..add([
          'add',
          _key([progId]),
          '/ve',
          '/d',
          '$displayName ${dotted.substring(1)} file',
          '/f',
        ])
        ..add([
          'add',
          _key([progId, 'shell', 'open', 'command']),
          '/ve',
          '/d',
          _commandValue,
          '/f',
        ])
        // `OpenWithProgids` only offers us. The viewer's current default handler
        // for the extension is left exactly where it was.
        ..add([
          'add',
          _key([dotted, 'OpenWithProgids']),
          '/v',
          progId,
          '/f',
        ]);
    }
    return _runAll(steps);
  }

  Future<bool> _linuxFileTypes(List<String> extensions) async {
    final types = <String>[];
    for (final extension in extensions) {
      final dotted = extension.startsWith('.') ? extension : '.$extension';
      final mime = _mimeByExtension[dotted];
      if (mime == null) {
        // Unknown extension: reporting success here would let the settings
        // screen claim a registration that never happened.
        return false;
      }
      types.add(mime);
    }
    if (types.isEmpty) {
      return true;
    }
    return await _linuxEntry(mimeType: types.join(';'), argument: '%f');
  }

  Future<bool> _runAll(List<List<String>> steps) async {
    for (final step in steps) {
      final result = await run('reg', step);
      if (result.exitCode != 0) {
        return false;
      }
    }
    return true;
  }

  /// Writes one desktop entry claiming [mimeType] and refreshes the database.
  ///
  /// The file itself is written synchronously, and a failed
  /// `update-desktop-database` is not reported as a failure: some distributions
  /// rescan on their own and some do not ship the tool at all, so the entry
  /// being on disk is the fact worth answering for.
  Future<bool> _linuxEntry({required String mimeType, required String argument}) async {
    final directory = applicationsDirectory ?? Directory(_defaultApplicationsDirectory);
    final file = File(p.join(directory.path, '$desktopEntryName.desktop'));
    final entry = [
      '[Desktop Entry]',
      'Type=Application',
      'Version=1.0',
      'Name=$displayName',
      'Exec="$executablePath" "$argument"',
      'NoDisplay=true',
      'MimeType=$mimeType;',
      '',
    ].join('\n');
    try {
      directory.createSync(recursive: true);
      file.writeAsStringSync(entry);
    } on FileSystemException {
      return false;
    }
    await run('update-desktop-database', [directory.path]);
    return true;
  }

  /// The per-user applications directory, where a desktop entry is discovered.
  static String get _defaultApplicationsDirectory =>
      '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']}/.local/share/applications';
}
