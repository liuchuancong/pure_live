import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryKeyedStore', () {
    late KeyedStore store;

    setUp(() => store = InMemoryKeyedStore());

    test('write, read, overwrite and remove', () async {
      await store.write('theme', 'dark');
      expect(await store.read('theme'), 'dark');

      await store.write('theme', 'light');
      expect(await store.read('theme'), 'light');

      await store.remove('theme');
      expect(await store.read('theme'), isNull);
      expect(await store.read('never-written'), isNull);
    });

    test('supports every JSON-encodable shape', () async {
      await store.write('flag', true);
      await store.write('count', 42);
      await store.write('ratio', 0.5);
      await store.write('name', '纯直播');
      await store.write('tags', ['a', 'b']);
      await store.write('nested', {
        'a': 1,
        'b': [2, 3],
      });

      expect(await store.read('flag'), true);
      expect(await store.read('count'), 42);
      expect(await store.read('ratio'), 0.5);
      expect(await store.read('name'), '纯直播');
      expect(await store.read('tags'), ['a', 'b']);
      expect(await store.read('nested'), {
        'a': 1,
        'b': [2, 3],
      });

      expect(await store.keys(), ['count', 'flag', 'name', 'nested', 'ratio', 'tags']);
      expect((await store.readAll())['nested'], {
        'a': 1,
        'b': [2, 3],
      });
    });

    test('clear removes everything', () async {
      await store.write('a', 1);
      await store.write('b', 2);
      await store.clear();

      expect(await store.read('a'), isNull);
      expect(await store.read('b'), isNull);
      expect(await store.keys(), isEmpty);
    });

    test('changes fires per committed mutation', () async {
      final events = <int>[];
      final sub = store.changes.listen((_) => events.add(events.length));
      await store.write('k', 1);
      await store.remove('k');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(2));
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
