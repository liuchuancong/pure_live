import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryKeyedStore', () {
    late KeyedStore store;

    setUp(() => store = InMemoryKeyedStore());

    test('put, get, overwrite and delete', () async {
      await store.put('theme', 'dark');
      expect(store.get<String>('theme'), 'dark');

      await store.put('theme', 'light');
      expect(store.get<String>('theme'), 'light');

      await store.delete('theme');
      expect(store.get<String>('theme'), isNull);
      expect(store.get<String>('never-written'), isNull);
    });

    test('supports every JSON-encodable shape', () async {
      await store.put('flag', true);
      await store.put('count', 42);
      await store.put('ratio', 0.5);
      await store.put('name', '纯直播');
      await store.put('tags', ['a', 'b']);
      await store.put('nested', {
        'a': 1,
        'b': [2, 3],
      });

      expect(store.get<bool>('flag'), true);
      expect(store.get<int>('count'), 42);
      expect(store.get<double>('ratio'), 0.5);
      expect(store.get<String>('name'), '纯直播');
      expect(store.get<List<dynamic>>('tags'), ['a', 'b']);
      expect(store.get<Map<String, Object?>>('nested'), {
        'a': 1,
        'b': [2, 3],
      });
      expect(store.containsKey('count'), isTrue);
      expect(store.containsKey('missing'), isFalse);
      expect(store.keys, containsAll(['flag', 'count', 'ratio', 'name', 'tags', 'nested']));
    });

    test('typed reads apply default values', () async {
      expect(store.get<String>('absent'), isNull);
      expect(store.get<String>('absent', defaultValue: 'fallback'), 'fallback');
    });

    test('clear removes everything', () async {
      await store.put('a', 1);
      await store.put('b', 2);
      await store.clear();

      expect(store.get<int>('a'), isNull);
      expect(store.get<int>('b'), isNull);
      expect(store.keys, isEmpty);
    });

    test('watch reports committed changes', () async {
      final events = <KeyedEvent>[];
      final sub = store.watch().listen(events.add);
      await store.put('k', 1);
      await store.delete('k');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(2));
      expect(events[0].deleted, isFalse);
      expect(events[1].deleted, isTrue);
    });
  });

  group('InMemorySecureStore', () {
    late SecureStore store;

    setUp(() => store = InMemorySecureStore());

    test('write, read, contains, delete, clear', () async {
      expect(await store.contains('token'), isFalse);

      await store.write('token', 'secret-value');
      expect(await store.read('token'), 'secret-value');
      expect(await store.contains('token'), isTrue);

      await store.delete('token');
      expect(await store.contains('token'), isFalse);

      await store.write('token2', 'v');
      await store.clear();
      expect(await store.read('token2'), isNull);
    });
  });
}
