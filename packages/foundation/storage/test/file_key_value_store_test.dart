// Module: test/file_key_value_store_test.dart
// Purpose: Verify the JSON-file key/value store, above all that a failed write destroys nothing.
// Author: liuchuancong
// Created: 2026-10-09
import 'dart:convert';
import 'dart:io';

import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

Directory? _dir;

String _path(String name) => '${_dir!.path}${Platform.pathSeparator}$name';

File _file(String name) => File(_path(name));

void main() {
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('file_key_value_store');
  });
  tearDown(() {
    _dir?.deleteSync(recursive: true);
    _dir = null;
  });

  group('test_fileStore_readsAndWrites', () {
    test('test_read_missingFile_returnsNullWithoutCreatingOne', () async {
      final store = FileKeyValueStore(filePath: _path('settings.json'));

      expect(await store.read('theme'), isNull);
      expect(await _file('settings.json').exists(), isFalse);
    });

    test('test_write_createsTheFileAndItsParentDirectory', () async {
      final nested = _path('data${Platform.pathSeparator}nested${Platform.pathSeparator}settings.json');
      final store = FileKeyValueStore(filePath: nested);

      await store.write('theme', 'dark');

      expect(File(nested).existsSync(), isTrue);
      expect(jsonDecode(File(nested).readAsStringSync()), <String, Object?>{'theme': 'dark'});
    });

    test('test_read_afterWrite_returnsTheValueFromASecondInstance', () async {
      await FileKeyValueStore(filePath: _path('a.json')).write('page', 12);

      // A second store over the same path is what a process restart looks like.
      expect(await FileKeyValueStore(filePath: _path('a.json')).read('page'), 12);
    });

    test('test_write_isVisibleInTheFileBeforeAnyReopen', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));
      await store.write('volume', 7);

      // Write-through, not "flush when the host feels like it": a crash must not cost the last change.
      expect(jsonDecode(_file('a.json').readAsStringSync()), <String, Object?>{'volume': 7});
    });

    test('test_write_keepsEveryJsonStorableType', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));
      await store.write('text', 'x');
      await store.write('flag', true);
      await store.write('count', 3);
      await store.write('ratio', 1.5);
      await store.write('nothing', null);
      await store.write('list', <Object?>[
        1,
        'two',
        <String, Object?>{'nested': false},
      ]);
      await store.write('map', <String, Object?>{
        'a': <String>['b'],
      });

      expect(await store.read('flag'), isTrue);
      expect(await store.read('count'), 3);
      expect(await store.read('ratio'), 1.5);
      expect(await store.read('nothing'), isNull);
      expect((await store.read('list'))! as List, hasLength(3));
      expect(((await store.read('map'))! as Map)['a'], <String>['b']);
    });

    test('test_keys_listsStoredKeys', () async {
      final store = FileKeyValueStore(filePath: _path('keys.json'));
      await store.write('one', 1);
      await store.write('two', 2);

      expect(await store.keys(), <String>['one', 'two']);
    });

    test('test_remove_dropsTheKeyFromDisk', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));
      await store.write('one', 1);
      await store.write('two', 2);
      await store.remove('one');

      expect(await store.read('one'), isNull);
      expect(jsonDecode(_file('a.json').readAsStringSync()), <String, Object?>{'two': 2});
    });

    test('test_remove_absentKey_doesNotRewriteTheFile', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));
      await store.write('one', 1);
      // Removing the file is the sharp check: a store that rewrote anyway would put it back.
      _file('a.json').deleteSync();

      await store.remove('nope');

      expect(_file('a.json').existsSync(), isFalse);
      expect(await store.read('one'), 1);
    });

    test('test_clear_emptiesTheFileAndKeepsItPresent', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));
      await store.write('one', 1);
      await store.clear();

      expect(await store.keys(), isEmpty);
      expect(jsonDecode(_file('a.json').readAsStringSync()), isEmpty);
    });

    test('test_clear_neverWritten_createsNoFile', () async {
      await FileKeyValueStore(filePath: _path('a.json')).clear();

      expect(await _file('a.json').exists(), isFalse);
    });

    test('test_indent_writesAMultiLineFile', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'), indent: true);
      await store.write('one', 1);

      expect(_file('a.json').readAsStringSync(), contains('\n'));
    });
  });

  group('test_fileStore_failuresLeavesNothingBehind', () {
    test('test_write_unencodableValue_isRejectedAndChangesNeitherMemoryNorDisk', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));
      await store.write('theme', 'dark');
      final before = _file('a.json').readAsStringSync();

      // A DateTime has no JSON form; it must fail loudly here rather than after a restart, when the row is
      // simply gone and nothing says why.
      await expectLater(store.write('when', DateTime.utc(2026, 10, 9)), throwsA(isA<ArgumentError>()));

      expect(await store.read('theme'), 'dark');
      expect(await store.read('when'), isNull);
      expect(await store.keys(), isNot(contains('when')));
      expect(_file('a.json').readAsStringSync(), before);
    });

    test('test_corruptFile_isReportedAndNeverOverwritten', () async {
      final file = _file('a.json')..writeAsStringSync('{not json');
      final store = FileKeyValueStore(filePath: file.path);

      await expectLater(store.read('x'), throwsA(isA<StoreCorruptedException>()));
      // The write path is closed too: truncating here would turn "unreadable" into "gone".
      await expectLater(store.write('x', 1), throwsA(isA<StoreCorruptedException>()));
      expect(file.readAsStringSync(), '{not json');
    });

    test('test_topLevelNotAnObject_isReportedAsCorrupt', () async {
      _file('a.json').writeAsStringSync('[1,2,3]');

      await expectLater(FileKeyValueStore(filePath: _path('a.json')).keys(), throwsA(isA<StoreCorruptedException>()));
    });

    test('test_emptyFile_isReadAsEmptyAndStillWritable', () async {
      // What a kill during the very first write leaves behind: no data existed, so nothing is lost by
      // treating it as empty.
      _file('a.json').writeAsStringSync('');
      final store = FileKeyValueStore(filePath: _path('a.json'));

      expect(await store.keys(), isEmpty);
      await store.write('one', 1);
      expect(await store.read('one'), 1);
    });
  });

  group('test_fileStore_concurrency', () {
    test('test_writes_issuedTogether_allLand', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));

      await Future.wait<void>(<Future<void>>[store.write('a', 1), store.write('b', 2), store.write('c', 3)]);

      expect(await store.keys(), containsAll(<String>['a', 'b', 'c']));
      expect(jsonDecode(_file('a.json').readAsStringSync()), <String, Object?>{'a': 1, 'b': 2, 'c': 3});
    });

    test('test_reads_duringWrites_neverSeeAHalfWrittenFile', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));
      await store.write('seed', 'value');

      final results = await Future.wait<Object?>(<Future<Object?>>[
        store.read('seed'),
        store.write('other', 2),
        store.read('seed'),
        store.write('third', 3),
        store.read('seed'),
      ]);

      // Every read saw either the whole old row or the whole new one; a torn file would have thrown.
      expect(results.where((value) => value == 'value'), hasLength(3));
      expect(jsonDecode(_file('a.json').readAsStringSync()), <String, Object?>{
        'seed': 'value',
        'other': 2,
        'third': 3,
      });
    });

    test('test_failedOperation_doesNotWedgeLaterOperations', () async {
      final store = FileKeyValueStore(filePath: _path('a.json'));

      await expectLater(store.write('when', DateTime.utc(2026)), throwsA(isA<ArgumentError>()));
      expect(await store.read('when'), isNull);
      await store.write('later', 'ok');
      expect(await store.read('later'), 'ok');
    });
  });
}
