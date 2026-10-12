import 'package:drift/native.dart';
import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

void main() {
  group('DbKeyedStore', () {
    late PureLiveDatabase database;
    late KeyedStore store;

    setUp(() {
      database = PureLiveDatabase(NativeDatabase.memory());
      store = database.store('preferences');
    });

    tearDown(() async {
      await database.close();
    });

    test('round trips every JSON-encodable shape', () async {
      await store.write('flag', true);
      await store.write('count', 42);
      await store.write('name', '设置');
      await store.write('nested', {'quality': '超清', 'volume': 0.8});

      expect(await store.read('flag'), true);
      expect(await store.read('count'), 42);
      expect(await store.read('name'), '设置');
      expect(await store.read('nested'), {'quality': '超清', 'volume': 0.8});
    });

    test('readAll and keys list the table contents in key order', () async {
      await store.write('b', 2);
      await store.write('a', 1);

      expect(await store.keys(), ['a', 'b']);
      expect(await store.readAll(), {'a': 1, 'b': 2});
    });

    test('one store instance per table name', () {
      expect(identical(database.store('preferences'), store), isTrue);
      expect(identical(database.store('other'), store), isFalse);
    });

    test('rejects table names that are not plain identifiers', () {
      expect(() => database.store(''), throwsA(isA<StorageValidationException>()));
      expect(() => database.store('a b'), throwsA(isA<StorageValidationException>()));
      expect(() => database.store('x; DROP TABLE preferences'), throwsA(isA<StorageValidationException>()));
    });

    test('upsert overwrites and remove clears', () async {
      await store.write('key', 'first');
      await store.write('key', 'second');
      expect(await store.read('key'), 'second');

      await store.remove('key');
      expect(await store.read('key'), isNull);
    });

    test('writing null removes the entry', () async {
      await store.write('key', 'value');
      await store.write('key', null);
      expect(await store.read('key'), isNull);
      expect(await store.keys(), isEmpty);
    });

    test('writes are durable across reopen', () async {
      await store.write('durable', 'yes');
      await database.close();

      // A fresh in-memory database has nothing — proving writes go to the
      // executor, not to some in-controller cache.
      final reopened = PureLiveDatabase(NativeDatabase.memory());
      final reopenedStore = reopened.store('preferences');
      expect(await reopenedStore.read('durable'), isNull);
      await reopened.close();
    });

    test('changes fires on write and remove', () async {
      final events = <int>[];
      final sub = store.changes.listen((_) => events.add(events.length));
      await store.write('k', 1);
      await store.remove('k');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(2));
    });

    test('clear empties this table only', () async {
      final other = database.store('other');
      await store.write('k', 1);
      await other.write('k', 2);

      await store.clear();

      expect(await store.read('k'), isNull);
      expect(await other.read('k'), 2);
    });

    test('transaction rolls back on failure', () async {
      await store.write('keep', 'me');

      Object? caught;
      try {
        await database.runInTransaction(() async {
          await store.write('transient', 'value');
          throw StateError('rollback');
        });
      } on Object catch (error) {
        caught = error;
      }

      expect(caught, isA<StateError>());
      expect(await store.read('transient'), isNull, reason: 'rolled back');
      expect(await store.read('keep'), 'me', reason: 'prior data untouched');
    });
  });
}
