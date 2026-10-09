// Module: test/persistent_context_test.dart
// Purpose: Verify the disk-backed extension views: namespacing, TTL, and that one plugin cannot touch another's rows.
// Author: liuchuancong
// Created: 2026-10-09
import 'dart:io';

import 'package:pure_live_extension/pure_live_extension.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 9, 12);

PersistentExtensionCache _cache(KeyValueStore store, {String id = 'purelive.fake.one', DateTime? at}) {
  return PersistentExtensionCache(store: store, extensionId: id, clock: () => at ?? _t0);
}

PersistentExtensionStorage _storage(KeyValueStore store, {String id = 'purelive.fake.one'}) =>
    PersistentExtensionStorage(store: store, extensionId: id);

void main() {
  late MemoryKeyValueStore store;

  setUp(() {
    store = MemoryKeyValueStore();
  });

  group('test_persistentCache', () {
    test('test_read_afterWrite_returnsTheRowFromASecondView', () async {
      // Two views over one store is what a process restart looks like; the second one never saw the write.
      await _cache(store).write('repository', 'rows');

      expect(await _cache(store).read('repository'), 'rows');
    });

    test('test_write_landsUnderTheNamespacedKeyInTheStore', () async {
      await _cache(store, id: 'tvbox.source_001').write('repository', 'rows');

      expect(await store.read('extension.tvbox.source_001.cache.repository'), isA<Map<String, Object?>>());
    });

    test('test_read_beforeExpiry_returnsTheRow', () async {
      await _cache(store).write('page', 'fresh', ttl: const Duration(minutes: 5));

      expect(await _cache(store).read('page'), 'fresh');
    });

    test('test_read_afterExpiry_missesAndPrunesTheRow', () async {
      await _cache(store).write('page', 'fresh', ttl: const Duration(minutes: 5));

      expect(await _cache(store, at: _t0.add(const Duration(minutes: 6))).read('page'), isNull);
      expect(await store.keys(), isEmpty);
    });

    test('test_expiry_comesFromTheStoredDeadlineNotTheDuration', () async {
      // If the view re-applied "5 minutes" against its own clock, a restarted process would hand the row
      // back for another five minutes every time.
      await _cache(store).write('page', 'fresh', ttl: const Duration(minutes: 5));

      final late = _cache(store, at: _t0.add(const Duration(hours: 1)));

      expect(await late.read('page'), isNull);
    });

    test('test_read_withoutTtl_neverExpires', () async {
      await _cache(store).write('static', 'value');

      expect(await _cache(store, at: _t0.add(const Duration(days: 365))).read('static'), 'value');
    });

    test('test_keys_listsLiveRowsAndPrunesExpiredOnes', () async {
      await _cache(store).write('live', 1, ttl: const Duration(minutes: 1));
      await _cache(store).write('gone', 2, ttl: const Duration(minutes: 1));
      await _cache(store).write('noTtl', 3);

      final keys = await _cache(store, at: _t0.add(const Duration(minutes: 2))).keys();

      expect(keys, <String>['noTtl']);
      expect(await store.keys(), <String>['extension.purelive.fake.one.cache.noTtl']);
    });

    test('test_keys_keepsARowWhoseValueIsNull', () async {
      // "Stored null" and "nothing stored" are different answers, and a cache that conflates them would drop
      // a negative-result row and go re-fetch it forever.
      await _cache(store).write('absent-on-purpose', null);

      expect(await _cache(store).keys(), <String>['absent-on-purpose']);
      expect(await _cache(store).read('absent-on-purpose'), isNull);
    });

    test('test_remove_dropsOnlyThatKey', () async {
      await _cache(store).write('a', 1);
      await _cache(store).write('b', 2);
      await _cache(store).remove('a');

      expect(await _cache(store).keys(), <String>['b']);
      expect(await _cache(store).read('a'), isNull);
    });

    test('test_read_unreadableRow_missesAndDropsIt', () async {
      await store.write('extension.purelive.fake.one.cache.junk', 'not an envelope');

      expect(await _cache(store).read('junk'), isNull);
      expect(await store.keys(), isEmpty);
    });

    test('test_write_unencodableValue_isRejectedWithoutWriting', () async {
      await expectLater(_cache(store).write('when', DateTime.utc(2026)), throwsA(isA<ArgumentError>()));

      expect(await store.keys(), isEmpty);
    });
  });

  group('test_persistentStorage', () {
    test('test_settings_outliveTheCache', () async {
      // The reason the two interfaces are separate (context.dart): clearing the cache must not clear a
      // plugin's settings.
      await _cache(store).write('repository', 'rows');
      await _storage(store).write('token', 'abc');

      await _cache(store).clear();

      expect(await _cache(store).read('repository'), isNull);
      expect(await _storage(store).read('token'), 'abc');
    });

    test('test_settings_readFromASecondView', () async {
      await _storage(store).write('quality', '1080p');

      expect(await _storage(store).read('quality'), '1080p');
      expect(await _storage(store).keys(), <String>['quality']);
    });

    test('test_write_unencodableValue_isRejectedWithoutWriting', () async {
      await expectLater(_storage(store).write('when', DateTime.utc(2026)), throwsA(isA<ArgumentError>()));

      expect(await store.keys(), isEmpty);
    });
  });

  group('test_namespacesIsolateExtensions', () {
    test('test_twoExtensions_shareOneStoreWithoutSeeingEachOther', () async {
      await _cache(store, id: 'purelive.fake.one').write('repository', 'one');
      await _storage(store, id: 'purelive.fake.one').write('quality', '720p');

      expect(await _cache(store, id: 'purelive.fake.two').read('repository'), isNull);
      expect(await _storage(store, id: 'purelive.fake.two').read('quality'), isNull);
      expect(await _cache(store, id: 'purelive.fake.two').keys(), isEmpty);
    });

    test('test_clear_removesOnlyTheCallersNamespace', () async {
      await _cache(store, id: 'purelive.fake.one').write('repository', 'one');
      await _cache(store, id: 'purelive.fake.two').write('repository', 'two');

      await _cache(store, id: 'purelive.fake.one').clear();

      expect(await _cache(store, id: 'purelive.fake.two').read('repository'), 'two');
      expect(await store.keys(), <String>['extension.purelive.fake.two.cache.repository']);
    });

    test('test_aKeyNamingAnotherOwner_staysInsideTheWritersNamespace', () async {
      // Isolation is structural: the prefix is added by the view, so guessing the string is not enough to
      // reach the row - the key it produces is the attacker's own.
      await _cache(store, id: 'purelive.fake.one').write('extension.purelive.fake.two.cache.token', 'stolen');

      expect(await _storage(store, id: 'purelive.fake.two').read('token'), isNull);
      expect(await _cache(store, id: 'purelive.fake.two').read('extension.purelive.fake.two.cache.token'), isNull);
      expect(await store.keys(), <String>['extension.purelive.fake.one.cache.extension.purelive.fake.two.cache.token']);
    });
  });

  group('test_persistenceOnDisk', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('persistent_context');
    });
    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('test_cacheAndStorage_surviveAStoreReopen', () async {
      final path = '${dir.path}${Platform.pathSeparator}extensions.json';
      await _storage(FileKeyValueStore(filePath: path)).write('quality', '1080p');
      await _cache(FileKeyValueStore(filePath: path)).write('repository', 'rows', ttl: const Duration(hours: 1));

      final reopened = FileKeyValueStore(filePath: path);

      expect(await _storage(reopened).read('quality'), '1080p');
      expect(await _cache(reopened).read('repository'), 'rows');
      expect(await _cache(reopened, at: _t0.add(const Duration(days: 2))).read('repository'), isNull);
    });
  });
}
