import 'dart:io';

import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:test/test.dart';

/// `StorageConflicts.inspect` answers the split-brain question — after a
/// deployment change, do the portable tree and the legacy OS directory both
/// hold config files? — without throwing on a side it cannot read.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_platform_conflicts');
  });

  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A transient Windows lock; the temporary directory goes with the process.
    }
  });

  test('files present in both trees are reported as conflicts', () async {
    final preferred = Directory('${root.path}/preferred')..createSync();
    final legacy = Directory('${root.path}/legacy')..createSync();
    File('${preferred.path}/settings.json').writeAsStringSync('{}');
    File('${preferred.path}/unique-to-portable.json').writeAsStringSync('{}');
    File('${legacy.path}/settings.json').writeAsStringSync('{}');
    File('${legacy.path}/unique-to-legacy.json').writeAsStringSync('{}');

    final report = await StorageConflicts.inspect(preferred: preferred, legacy: legacy);

    expect(report.hasConflict, isTrue);
    expect(report.conflicts, ['settings.json']);
    expect(report.preferredFiles, contains('unique-to-portable.json'));
    expect(report.legacyFiles, contains('unique-to-legacy.json'));
  });

  test('a missing legacy side can never conflict', () async {
    final preferred = Directory('${root.path}/preferred')..createSync();
    File('${preferred.path}/settings.json').writeAsStringSync('{}');

    final report = await StorageConflicts.inspect(preferred: preferred, legacy: Directory('${root.path}/absent'));

    expect(report.hasConflict, isFalse);
    expect(report.conflicts, isEmpty);
    expect(report.legacyFiles, isEmpty);
  });

  test('disjoint trees report no conflict', () async {
    final preferred = Directory('${root.path}/preferred')..createSync();
    final legacy = Directory('${root.path}/legacy')..createSync();
    File('${preferred.path}/a.json').writeAsStringSync('{}');
    File('${legacy.path}/b.json').writeAsStringSync('{}');

    final report = await StorageConflicts.inspect(preferred: preferred, legacy: legacy);

    expect(report.hasConflict, isFalse);
  });
}
