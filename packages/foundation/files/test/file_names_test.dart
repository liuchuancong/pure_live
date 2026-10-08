// Module: test/file_names_test.dart
// Purpose: Verify name sanitizing, collision naming, the directory escape guard and atomic writes.
// Author: liuchuancong
// Created: 2026-10-08
import 'dart:io';

import 'package:pure_live_files/pure_live_files.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeFileName', () {
    test('test_sanitizeFileName_illegalCharacters_areRemoved', () {
      expect(sanitizeFileName('a<b>c:d"e/f\\g|h?i*j'), 'abcdefghij');
    });

    test('test_sanitizeFileName_controlCharacters_areRemoved', () {
      expect(sanitizeFileName('name\x00\x1F.txt'), 'name.txt');
    });

    test('test_sanitizeFileName_blankOrDotOnly_fallsBack', () {
      expect(sanitizeFileName('   '), 'untitled');
      expect(sanitizeFileName('...'), 'untitled');
      expect(sanitizeFileName(''), 'untitled');
    });

    test('test_sanitizeFileName_trailingDotOrSpace_isTrimmed', () {
      // Windows drops these silently, which would make two different names collide.
      expect(sanitizeFileName('video.  '), 'video');
    });

    test('test_sanitizeFileName_reservedWindowsName_isPrefixedKeepingExtension', () {
      expect(sanitizeFileName('nul.txt'), '_nul.txt');
      expect(sanitizeFileName('CON'), '_CON');
      expect(sanitizeFileName('normal.txt'), 'normal.txt');
    });

    test('test_sanitizeFileName_tooLong_keepsTheExtensionAndCapsTheLength', () {
      final long = '${'x' * 300}.mp4';

      final safe = sanitizeFileName(long, maxLength: 40);

      expect(safe.length, lessThanOrEqualTo(40));
      expect(safe.endsWith('.mp4'), isTrue);
    });

    test('test_sanitizeFileName_tinyBudget_stillReturnsSomethingUsable', () {
      expect(sanitizeFileName('${'x' * 50}.mp4', maxLength: 2), hasLength(2));
    });

    test('test_sanitizeFileName_dotfileIsNotTreatedAsExtension', () {
      expect(sanitizeFileName('.gitignore'), 'gitignore');
    });
  });

  group('disambiguateName', () {
    test('test_disambiguateName_freeName_isReturnedUnchanged', () {
      expect(disambiguateName('a.mp4', (_) => false), 'a.mp4');
    });

    test('test_disambiguateName_takenNames_appendNumberBeforeTheExtension', () {
      final taken = <String>{'a.mp4', 'a (1).mp4'};

      expect(disambiguateName('a.mp4', taken.contains), 'a (2).mp4');
    });

    test('test_disambiguateName_extensionlessName_stillGetsASuffix', () {
      expect(disambiguateName('playlist', (_) => true), startsWith('playlist ('));
    });
  });

  group('resolveWithin', () {
    test('test_resolveWithin_relativePath_staysInside', () {
      expect(resolveWithin('/data/app', 'sub/file.txt'), '/data/app/sub/file.txt');
    });

    test('test_resolveWithin_dotSegments_areCollapsed', () {
      expect(resolveWithin('/data/app', './a/../b.txt'), '/data/app/b.txt');
    });

    test('test_resolveWithin_parentEscape_isRejected', () {
      expect(() => resolveWithin('/data/app', '../other.txt'), throwsA(isA<StateError>()));
      expect(() => resolveWithin('/data/app', 'a/../../other.txt'), throwsA(isA<StateError>()));
    });

    test('test_resolveWithin_absoluteEscape_isRejected', () {
      expect(() => resolveWithin('/data/app', '/etc/passwd'), throwsA(isA<StateError>()));
    });

    test('test_resolveWithin_windowsSeparators_areUnderstood', () {
      expect(resolveWithin(r'C:\data\app', r'sub\file.txt'), r'C:/data/app/sub/file.txt');
      expect(() => resolveWithin(r'C:\data\app', r'..\..\windows\x.txt'), throwsA(isA<StateError>()));
    });

    test('test_resolveWithin_sameDirectoryIsAllowed', () {
      expect(resolveWithin('/data/app', '.'), '/data/app');
    });
  });

  group('mimeTypeFor', () {
    test('test_mimeTypeFor_knownExtensions_match', () {
      expect(mimeTypeFor('list.m3u8'), 'application/vnd.apple.mpegurl');
      expect(mimeTypeFor('list.M3U8'.toLowerCase()), 'application/vnd.apple.mpegurl');
      expect(mimeTypeFor('a/b/c.srt'), 'application/x-subrip');
    });

    test('test_mimeTypeFor_unknownOrMissingExtension_isOctetStream', () {
      expect(mimeTypeFor('archive.qq'), 'application/octet-stream');
      expect(mimeTypeFor('noextension'), 'application/octet-stream');
      expect(mimeTypeFor('trailing.'), 'application/octet-stream');
    });
  });

  group('writeTextAtomically', () {
    late Directory workdir;

    setUp(() => workdir = Directory.systemTemp.createTempSync('pl_files_'));
    tearDown(() => workdir.deleteSync(recursive: true));

    test('test_writeTextAtomically_createsTheFileAndItsDirectory', () async {
      final target = File('${workdir.path}/nested/deep/out.txt');

      await writeTextAtomically(target, 'content');

      expect(target.readAsStringSync(), 'content');
    });

    test('test_writeTextAtomically_overwritesExistingFile', () async {
      final target = File('${workdir.path}/out.txt');
      await writeTextAtomically(target, 'first');

      await writeTextAtomically(target, 'second');

      expect(target.readAsStringSync(), 'second');
    });

    test('test_writeTextAtomically_leavesNoTempFileBehind', () async {
      final target = File('${workdir.path}/out.txt');

      await writeTextAtomically(target, 'x');

      expect(
        workdir.listSync().whereType<File>().where((file) => file.path.endsWith('.tmp')),
        isEmpty,
      );
    });
  });
}
