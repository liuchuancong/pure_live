import 'package:drift/native.dart';
import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

void main() {
  group('DbKeyedStore', () {
    late PureLiveDatabase database;
    late KeyedStore store;

    setUp(() async {
      database = PureLiveDatabase(NativeDatabase.memory());
      store = await database.openStore('preferences');
    });

    tearDown(() async {
      await database.close();
    });

    test('round trips every JSON-encodable shape', () async {
      await store.put('flag', true);
      await store.put('count', 42);
      await store.put('name', '设置');
      await store.put('nested', {'quality': '超清', 'volume': 0.8});

      expect(store.get<bool>('flag'), true);
      expect(store.get<int>('count'), 42);
      expect(store.get<String>('name'), '设置');
      expect(store.get<Map<String, Object?>>('nested'), {'quality': '超清', 'volume': 0.8});
    });

    test('typed reads apply default values', () async {
      expect(store.get<String>('absent'), isNull);
      expect(store.get<String>('absent', defaultValue: 'fallback'), 'fallback');

      await store.put('count', 42);
      expect(store.get<int>('count', defaultValue: 0), 42);
    });

    test('keys and containsKey reflect the table', () async {
      expect(store.containsKey('a'), isFalse);

      await store.put('b', 2);
      await store.put('a', 1);

      expect(store.containsKey('a'), isTrue);
      expect(store.keys, containsAll(['a', 'b']));
    });

    test('openStore reuses one store per table name', () async {
      expect(identical(await database.openStore('preferences'), store), isTrue);
      expect(identical(await database.openStore('other'), store), isFalse);
    });

    test('rejects table names that are not plain identifiers', () {
      expect(() => database.openStore(''), throwsA(isA<StorageValidationException>()));
      expect(() => database.openStore('a b'), throwsA(isA<StorageValidationException>()));
      expect(() => database.openStore('x; DROP TABLE preferences'), throwsA(isA<StorageValidationException>()));
    });

    test('put overwrites and delete clears', () async {
      await store.put('key', 'first');
      await store.put('key', 'second');
      expect(store.get<String>('key'), 'second');

      await store.delete('key');
      expect(store.get<String>('key'), isNull);
      expect(store.containsKey('key'), isFalse);
    });

    test('putting null removes the entry', () async {
      await store.put('key', 'value');
      await store.put('key', null);

      expect(store.get<String>('key'), isNull);
      expect(store.keys, isEmpty);
    });

    test('writes are durable across reopen', () async {
      await store.put('durable', 'yes');
      await database.close();

      // A fresh in-memory database has nothing — proving writes go to the
      // executor, not to the in-memory mirror.
      final reopened = PureLiveDatabase(NativeDatabase.memory());
      final reopenedStore = await reopened.openStore('preferences');
      expect(reopenedStore.get<String>('durable'), isNull);
      await reopened.close();
    });

    test('watch reports committed changes', () async {
      final events = <KeyedEvent>[];
      final sub = store.watch(key: 'k').listen(events.add);
      await store.put('k', 1);
      await store.put('other', 2);
      await store.delete('k');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(2));
      expect(events[0].key, 'k');
      expect(events[0].value, 1);
      expect(events[0].deleted, isFalse);
      expect(events[1].key, 'k');
      expect(events[1].deleted, isTrue);
    });

    test('clear empties this table only', () async {
      final other = await database.openStore('other');
      await store.put('k', 1);
      await other.put('k', 2);

      await store.clear();

      expect(store.get<int>('k'), isNull);
      expect(other.get<int>('k'), 2);
    });
  });
}
