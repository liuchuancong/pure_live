import 'package:live_record_core/live_record_core.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  final naming = RecordNaming(rootDirectory: '/rec');

  RecordOrchestrator build({required FakeServices services, required RecordStore store, RecordPolicy? policy}) {
    final orchestrator = RecordOrchestrator(
      services: services,
      store: store,
      naming: naming,
      policy: policy ?? fastPolicy(),
    );
    addTearDown(orchestrator.dispose);

    return orchestrator;
  }

  group('the polling switch', () {
    test('off: a room waiting for its first broadcast is asked once, then sleeps', () async {
      final services = FakeServices(script: <RoomProbe>[offline]);
      final policy = fastPolicy()..enablePolling = false;
      final task = await build(services: services, store: RecordJsonStore(MemorySlots()), policy: policy).watch(target);
      await pump(80);

      expect(task.roomState, RoomState.waiting);
      expect(
        services.probeCount,
        1,
        reason: 'the first answer comes from watch itself; nothing re-arms the check while polling is off',
      );
    });

    test('the switch applies live: a re-arm already scheduled answers once more, then stops', () async {
      final services = FakeServices(script: <RoomProbe>[offline]);
      final policy = fastPolicy();
      final orchestrator = build(services: services, store: RecordJsonStore(MemorySlots()), policy: policy);
      await orchestrator.watch(target);
      policy.enablePolling = false;
      await pump(80);
      final settled = services.probeCount;
      await pump(120);

      expect(
        services.probeCount,
        settled,
        reason: 'the timer armed before the edit still fires once; its answer schedules no new one',
      );
    });

    test('on (the default): waiting rooms keep being checked', () async {
      final services = FakeServices(script: <RoomProbe>[offline]);
      await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump(80);

      expect(services.probeCount, greaterThan(1));
    });
  });

  group('poll backoff', () {
    test('the wait between checks of an offline room doubles, capped', () async {
      final services = FakeServices(script: <RoomProbe>[offline]);
      final policy = fastPolicy()
        ..pollBackoff = true
        ..maxPollInterval = const Duration(milliseconds: 80);
      await build(services: services, store: RecordJsonStore(MemorySlots()), policy: policy).watch(target);
      await pump(200);

      // Without backoff the 10 ms interval answers ~20 times in this window;
      // doubling to an 80 ms ceiling lands in the single digits.
      expect(services.probeCount, lessThanOrEqualTo(10));
      expect(services.probeCount, greaterThan(2));
    });

    test('backoff off (the default): the wait stays the ordinary interval', () async {
      final services = FakeServices(script: <RoomProbe>[offline]);
      await build(services: services, store: RecordJsonStore(MemorySlots())).watch(target);
      await pump(200);

      expect(services.probeCount, greaterThan(10));
    });
  });
}
