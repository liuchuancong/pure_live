import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// The namespaced JSON store every feature repository sits on: synchronous
/// reads from a snapshot, persisted writes, insertion order and the two
/// change streams.
void main() {
  late StorageStores stores;
  late JsonStore subject;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    subject = await stores.openStore('follows');
  });

  tearDown(() => stores.close());

  test('put, read and contains round-trip a JSON document', () async {
    await subject.put('douyu:1', {
      'title': 'A',
      'tags': ['x', 'y'],
    });

    expect(subject.get('douyu:1'), {
      'title': 'A',
      'tags': ['x', 'y'],
    });
    expect(subject.contains('douyu:1'), isTrue);
    expect(subject.contains('missing'), isFalse);
    expect(subject.keys, ['douyu:1']);
  });

  test('entries keep insertion order across updates', () async {
    await subject.put('b', {'n': 2});
    await subject.put('a', {'n': 1});
    await subject.put('b', {'n': 3});

    expect(subject.keys, ['b', 'a']);
    expect(subject.values, [
      {'n': 3},
      {'n': 1},
    ]);
  });

  test('putAll writes one batch and keeps the first insertion stamp', () async {
    await subject.put('a', 1);
    await subject.putAll({'a': 2, 'b': 3});

    expect(subject.entries, {'a': 2, 'b': 3});
    expect(subject.keys, ['a', 'b']);
  });

  test('putAll keeps the caller order for new entries in one tick', () async {
    await subject.putAll({'z': 1, 'a': 2, 'm': 3});

    expect(subject.keys, ['z', 'a', 'm']);
  });

  test('delete, deleteAll and clear update the snapshot', () async {
    await subject.putAll({'a': 1, 'b': 2, 'c': 3});

    await subject.delete('b');
    expect(subject.keys, ['a', 'c']);

    await subject.deleteAll(['a', 'missing']);
    expect(subject.keys, ['c']);

    await subject.clear();
    expect(subject.isEmpty, isTrue);
  });

  test('watch and watchKeys report the committed changes', () async {
    final changes = <void>[];
    final keys = <String>[];
    final all = subject.watch().listen(changes.add);
    final named = subject.watchKeys().listen(keys.add);
    addTearDown(all.cancel);
    addTearDown(named.cancel);

    await subject.put('a', 1);
    await subject.delete('a');
    await pumpEventQueue();

    expect(changes, hasLength(2));
    expect(keys, ['a', 'a']);
  });

  test('a namespace is isolated from its siblings', () async {
    final other = await stores.openStore('history');
    await subject.put('same', 'follows');
    await other.put('same', 'history');

    expect(subject.get('same'), 'follows');
    expect(other.get('same'), 'history');
  });
}
