import 'dart:async' show unawaited;

import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// The settings facade's two backings: the SQLite rows the process owns,
/// whose changes the window bridge follows, and the seeded memory a
/// secondary engine serves its reads from.
void main() {
  setUp(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(StorageStores.closeInstance);

  test('watch reports the key a write and a delete touch', () async {
    final events = <Set<String>>[];
    final subscription = StoragePrefs.watch().listen(events.add);
    addTearDown(subscription.cancel);

    await StoragePrefs.setString('theme.mode', 'dark');
    await StoragePrefs.remove('theme.mode');
    await pumpEventQueue();

    expect(events, [
      {'theme.mode'},
      {'theme.mode'},
    ]);
  });

  test('typed getters keep their types and lists copy', () async {
    await StoragePrefs.setBool('flag', true);
    await StoragePrefs.setInt('count', 3);
    await StoragePrefs.setDouble('ratio', 0.5);
    await StoragePrefs.setString('name', 'Pure Live');
    await StoragePrefs.setStringList('tags', ['a', 'b']);

    expect(StoragePrefs.getBool('flag'), isTrue);
    expect(StoragePrefs.getInt('count'), 3);
    expect(StoragePrefs.getDouble('ratio'), 0.5);
    expect(StoragePrefs.getString('name'), 'Pure Live');
    expect(StoragePrefs.getStringList('tags'), ['a', 'b']);
    expect(StoragePrefs.getString('missing'), isNull);
  });

  test('persistBatch commits every collected key', () async {
    await StoragePrefs.persistBatch(() {
      unawaited(StoragePrefs.setBool('danmaku', true));
      unawaited(StoragePrefs.setInt('size', 18));
    });

    expect(StoragePrefs.getBool('danmaku'), isTrue);
    expect(StoragePrefs.getInt('size'), 18);
  });

  test('a seeded backing reads the seed and keeps writes in memory', () async {
    await StoragePrefs.setString('theme.mode', 'light');
    await StoragePrefs.initSeeded({'theme.mode': 'dark', 'app.locale': 'zh-CN'});

    expect(StoragePrefs.getString('theme.mode'), 'dark');
    expect(StoragePrefs.snapshot(), containsPair('app.locale', 'zh-CN'));

    var emitted = false;
    final subscription = StoragePrefs.watch().listen((_) => emitted = true);
    addTearDown(subscription.cancel);

    await StoragePrefs.setString('theme.mode', 'system');
    await pumpEventQueue();

    expect(StoragePrefs.getString('theme.mode'), 'system');
    expect(emitted, isFalse, reason: 'the seeded engine never writes the shared database');
  });

  test('a seeded backing does not leak into the database it replaced', () async {
    await StoragePrefs.initSeeded({'theme.mode': 'dark'});
    await StoragePrefs.setString('theme.mode', 'light');

    await StoragePrefs.init();

    expect(StoragePrefs.getString('theme.mode'), isNull, reason: 'the memory copy must not reach the settings rows');
  });
}
