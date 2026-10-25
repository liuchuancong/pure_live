import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// A stand-in for the primary window's store.
final class _FakeClient implements RemoteStorageClient {
  final Map<String, Map<String, Object?>> data = {};

  @override
  Future<StorageSnapshot> snapshot(String namespace) async => StorageSnapshot(values: Map<String, Object?>.of(data[namespace] ?? const {}));

  @override
  Future<void> put(String namespace, String key, Object? value) async {
    final store = data.putIfAbsent(namespace, () => {});
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<void> putAll(String namespace, Map<String, Object?> values) async {
    for (final entry in values.entries) {
      await put(namespace, entry.key, entry.value);
    }
  }

  @override
  Future<void> delete(String namespace, String key) => put(namespace, key, null);

  @override
  Future<void> deleteAll(String namespace, Iterable<String> keys) async {
    for (final key in keys) {
      await delete(namespace, key);
    }
  }

  @override
  Future<void> clear(String namespace) async {
    data.remove(namespace);
  }
}

void main() {
  test('a remote store reads a snapshot, writes through and applies changes', () async {
    final client = _FakeClient()
      ..data['follows'] = {
        'a': {'title': 'A'},
      };
    final store = await RemoteJsonStore.open(client, 'follows');
    final seen = <String>[];
    final subscription = store.watchKeys().listen(seen.add);
    addTearDown(subscription.cancel);

    expect(store.get('a'), {'title': 'A'});

    await store.put('b', {'title': 'B'});
    expect(client.data['follows']!['b'], {'title': 'B'});
    expect(store.get('b'), {'title': 'B'});

    store.applyChange(
      const StorageChange(
        namespace: 'follows',
        values: {
          'a': {'title': 'A2'},
          'b': null,
        },
      ),
    );
    await pumpEventQueue();

    expect(store.get('a'), {'title': 'A2'});
    expect(store.contains('b'), isFalse);
    expect(seen, containsAll(['b', 'a']));
  });
}
