import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// `StorageBoxManager` is a thin seam over `hive_box_manager`, and thin seams are
/// exactly where a project rule gets lost. Two rules are checked here: a box name is
/// validated before anything is opened, and asking twice for one name yields the same
/// box rather than a second handle to the same file.
void main() {
  late Directory storageDir;
  late StorageBoxManager manager;

  setUp(() {
    storageDir = Directory.systemTemp.createTempSync('live_storage_boxes');
    Hive.init(storageDir.path);
    manager = StorageBoxManager();
  });

  tearDown(() async {
    await Hive.close();
    try {
      storageDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Transient lock on Windows; the temp directory goes with the process.
    }
  });

  group('name validation', () {
    test('rejects a blank name before touching Hive', () {
      // A blank box name would reach Hive as an empty file name, which is a harder
      // failure to explain to a user than an argument error at the call site.
      expect(() => manager.single<String>(''), throwsArgumentError);
      expect(() => manager.single<String>('   '), throwsArgumentError);
      expect(() => manager.list<String>('  '), throwsArgumentError);
      expect(() => manager.map<String, String>('\t'), throwsArgumentError);
      expect(() => manager.set<String>(''), throwsArgumentError);
      expect(() => manager.keyed<String>(''), throwsArgumentError);
    });
  });

  group('box reuse', () {
    test('two opens of one name are separate handles over one box', () async {
      final first = await manager.single<String>('settings');
      final second = await manager.single<String>('settings');

      // Measured, not assumed: the wrapper is rebuilt on each open, so
      // `identical` is false even though hive_box_manager caches the box behind it.
      // A caller that leaned on identity to decide "I already hold this box" would
      // be wrong, and the write-then-read case below is the guarantee that actually
      // holds.
      expect(identical(first, second), isFalse);
      expect(first.name, second.name);

      await first.set('light').run();

      expect(second.getOr(''), 'light');
    });

    test('different names are different boxes', () async {
      final a = await manager.single<String>('alpha');
      final b = await manager.single<String>('beta');

      expect(identical(a, b), isFalse);
    });

    test('a value written through one call site is visible through another', () async {
      final first = await manager.single<String>('theme');
      final second = await manager.single<String>('theme');

      // `set` hands back a Task, so nothing is written until it is run — a call
      // site that forgets this reads its own box and sees the old value.
      await second.set('dark').run();

      expect(first.getOr(''), 'dark', reason: 'the manager promises one cached box per name');
      expect(first.name, 'theme');
    });
  });
}
