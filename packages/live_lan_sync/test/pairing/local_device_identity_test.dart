import 'dart:math' show Random;

import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';

void main() {
  group('LocalDeviceIdentity', () {
    test('generates a dashed hex id', () {
      final id = LocalDeviceIdentity.generate(_CountingRandom());
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
    });

    test('persists on first boot and reuses afterwards', () async {
      final store = MemoryLanSyncStore();
      final first = await LocalDeviceIdentity.ensure(store);
      final second = await LocalDeviceIdentity.ensure(store);
      expect(first, second);
      expect(await store.loadLocalDeviceId(), first);
    });

    test('a pre-existing id wins over generation', () async {
      final store = MemoryLanSyncStore();
      await store.saveLocalDeviceId('existing-id');
      expect(await LocalDeviceIdentity.ensure(store), 'existing-id');
    });
  });
}

class _CountingRandom implements Random {
  int _next = 0;

  @override
  bool nextBool() => _next.isEven;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => _next++ % max;
}
