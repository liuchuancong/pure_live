import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:pure_live/desktop_tray_icons.dart';

/// Checks the shipped tray artwork by reading the bytes, because a tray icon is
/// one of the few assets where "the file is there" and "the file works" are very
/// different claims: an .ico the shell cannot parse leaves the icon absent with
/// nothing on screen to say why, and a container holding only one size looks
/// fine at 100% scaling and turns to mush at 150%.
///
/// The artwork belongs to the application now, so this guard lives with the app
/// that declares `assets/tray/` in its pubspec.
void main() {
  Directory assetsDirectory() {
    // `flutter test` runs from the app root, which is also where the declared
    // asset directory sits.
    final dir = Directory('assets/tray');
    if (!dir.existsSync()) {
      throw StateError('expected to run from the app root; found ${Directory.current.path}');
    }
    return dir;
  }

  File assetFor(String key) {
    // The keys are the app's own asset paths, so each source file sits at the
    // same path relative to the app root — the working directory of the test.
    return File(key.replaceAll('/', Platform.pathSeparator));
  }

  final advertisedKeys = {
    windowsTrayIcon,
    macOSMenuIcon,
    macOSMenuIconRetina,
    ...trayIconAssets(PlatformKind.windows).values,
    ...trayIconAssets(PlatformKind.macos).values,
  };

  test('every advertised asset exists in the app', () {
    for (final key in advertisedKeys) {
      final file = assetFor(key);
      expect(file.existsSync(), isTrue, reason: '$key is advertised but not shipped');
      // A zero-length file satisfies existsSync() and produces a tray with no
      // icon and no error, which is the failure a build never mentions out loud.
      expect(file.lengthSync(), greaterThan(0), reason: '$key is empty');
    }
  });

  test('nothing sits in the directory that is not advertised', () {
    // Catches the residue of a renamed or abandoned export: an orphan file gets
    // bundled, and nobody knows what it is for afterwards.
    final advertised = advertisedKeys.map((key) => key.split('/').last).toList();
    final onDisk = assetsDirectory().listSync().whereType<File>().map((file) => file.uri.pathSegments.last).toList();

    expect(onDisk, unorderedEquals(advertised));
  });

  test('the .ico is a container, not a renamed PNG, and covers the sizes the shell asks for', () {
    final bytes = assetFor(windowsTrayIcon).readAsBytesSync();

    expect(bytes[2], 1, reason: 'resource type must be icon (1), not cursor (2)');
    final count = bytes[4] | (bytes[5] << 8);
    final sizes = <int>[];
    for (var i = 0; i < count; i++) {
      final entry = 6 + 16 * i;
      // A zero byte in these fields means 256, which no tray icon should claim.
      expect(bytes[entry], isNonZero);
      sizes.add(bytes[entry]);
      expect(bytes[entry + 6] | (bytes[entry + 7] << 8), 32, reason: 'entries must carry a 32-bit alpha channel');
    }

    expect(sizes, contains(16), reason: 'the notification area draws at 16px at 100% scaling');
    expect(sizes, contains(32), reason: 'the same slot is 32px at 200% scaling');
    expect(sizes.length, greaterThanOrEqualTo(4));
  });

  test('the icon entries describe the image plus its mask, not truncated data', () {
    final bytes = assetFor(windowsTrayIcon).readAsBytesSync();
    final count = bytes[4] | (bytes[5] << 8);

    for (var i = 0; i < count; i++) {
      final entry = 6 + 16 * i;
      final side = bytes[entry];
      final declared =
          bytes[entry + 8] | (bytes[entry + 9] << 8) | (bytes[entry + 10] << 16) | (bytes[entry + 11] << 24);
      final offset =
          bytes[entry + 12] | (bytes[entry + 13] << 8) | (bytes[entry + 14] << 16) | (bytes[entry + 15] << 24);
      // BITMAPINFOHEADER (40) + BGRA, and the AND mask rounded up to a 4-byte row.
      final maskRow = ((side + 31) ~/ 32) * 4;
      final expected = 40 + side * side * 4 + maskRow * side;

      expect(declared, expected, reason: 'the $side px entry promises $declared and needs $expected');
      expect(offset + declared, lessThanOrEqualTo(bytes.length), reason: 'the $side px entry runs past the file');
    }
  });

  test('the menu bar PNGs are square and carry transparency', () {
    for (final key in [macOSMenuIcon, macOSMenuIconRetina]) {
      final bytes = assetFor(key).readAsBytesSync();

      expect(bytes.sublist(1, 4), [0x50, 0x4e, 0x47], reason: '$key is not a PNG');
      // IHDR width and height, big-endian at offsets 16 and 20.
      final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect(width, height, reason: '$key must be square for the menu bar slot');
      expect(bytes[25], isNot(2), reason: '$key must not be an indexed palette without alpha');
    }
  });
}
