import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/release_model.dart';
import 'package:pure_live/modules/about/version_history.dart';

void main() {
  group('release history feed contract', () {
    test('history follows the maintained update repository', () {
      final source = File('lib/modules/about/version_history.dart').readAsStringSync();

      expect(source, contains('VersionUtil.mirror'));
      expect(source, isNot(contains("owner: 'liuchuancong'")));
    });

    test('numeric strings in external release data are normalized', () {
      final release = ReleaseModel.fromJson({
        'version': 3.2,
        'title': 320,
        'date': '2026-09-11',
        'author': {'name': 123},
        'files': [
          {'name': 'PureLive.apk', 'size': 2048, 'downloads': '17', 'url': 'https://example.test/PureLive.apk'},
        ],
      });

      expect(release.version, '3.2');
      expect(release.title, '320');
      expect(release.author.name, '123');
      expect(release.files.single.size, '2048');
      expect(release.files.single.downloads, 17);
    });

    test('malformed nested entries are isolated instead of breaking the complete history', () {
      final release = ReleaseModel.fromJson({
        'version': '3.2.0',
        'author': 'invalid author',
        'files': [
          null,
          'invalid file',
          {'name': 'portable.zip', 'downloads': 'invalid'},
        ],
      });

      expect(release.author.name, isEmpty);
      expect(release.files, hasLength(1));
      expect(release.files.single.name, 'portable.zip');
      expect(release.files.single.downloads, 0);
    });

    test('payload parser filters unusable rows and sorts the retained releases', () {
      final releases = parseReleaseHistoryPayload({
        'releases': [
          {'version': '3.1.9', 'date': '2026-09-10'},
          'invalid row',
          {'title': 'missing version'},
          {'version': '3.2.0', 'date': '2026-09-11'},
        ],
      });

      expect(releases.map((release) => release.version), ['3.2.0', '3.1.9']);
      expect(() => parseReleaseHistoryPayload({'releases': 'invalid'}), throwsFormatException);
    });

    test('bundled maintained release history is completely parseable', () {
      final raw = jsonDecode(File('assets/releases.json').readAsStringSync()) as List<dynamic>;
      final releases = parseReleaseHistoryPayload(raw);

      expect(releases, hasLength(raw.length));
      expect(releases.first.version, '3.2.9');
      expect(releases.every((release) => release.version.isNotEmpty), isTrue);
    });

    test('release actions share the normalized complete HTTP target contract', () {
      expect(
        releaseHistoryWebUri(' HTTPS://Example.TEST:8443/release?q=a%2Fb ')?.toString(),
        'https://example.test:8443/release?q=a%2Fb',
      );
      for (final value in <String>[
        'prefix https://example.test/release',
        'https://user:token@example.test/release',
        'https://example.test:70000/release',
        'javascript:alert(1)',
        '/relative/release',
        '',
      ]) {
        expect(releaseHistoryWebUri(value), isNull, reason: value);
      }
    });
  });
}
