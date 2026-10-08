// Module: test/event_bus_test.dart
// Purpose: Verify typed delivery, no replay, and that disposal cannot crash a late publisher.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_events/pure_live_events.dart';
import 'package:test/test.dart';

final class SessionExpired implements AppEvent {
  const SessionExpired({required this.at, required this.providerId});

  @override
  final DateTime at;

  @override
  String get name => 'auth.expired';
  final String providerId;
}

void main() {
  final now = DateTime.utc(2026, 10, 8, 12);

  test('test_eventBus_subscriberReceivesItsOwnTypeOnly', () async {
    final bus = EventBus();
    final expired = <SessionExpired>[];
    final any = <AppEvent>[];
    final subA = bus.on<SessionExpired>().listen(expired.add);
    final subB = bus.on<AppEvent>().listen(any.add);

    bus.emit(SimpleEvent(name: 'source.disabled', at: now));
    bus.emit(SessionExpired(at: now, providerId: 'douyu'));
    await Future<void>.delayed(Duration.zero);

    expect(expired, hasLength(1));
    expect(expired.single.providerId, 'douyu');
    // A subscription on the base type sees every event, including subtypes.
    expect(any, hasLength(2));
    await subA.cancel();
    await subB.cancel();
    await bus.dispose();
  });

  test('test_eventBus_eventsBeforeSubscribe_areNotReplayed', () async {
    final bus = EventBus();
    bus.emit(SimpleEvent(name: 'early', at: now));

    final seen = <SimpleEvent>[];
    final sub = bus.on<SimpleEvent>().listen(seen.add);
    bus.emit(SimpleEvent(name: 'late', at: now));
    await Future<void>.delayed(Duration.zero);

    expect(seen.map((event) => event.name), <String>['late']);
    await sub.cancel();
    await bus.dispose();
  });

  test('test_eventBus_multipleSubscribers_allReceive', () async {
    final bus = EventBus();
    final first = <AppEvent>[];
    final second = <AppEvent>[];
    final subA = bus.on<AppEvent>().listen(first.add);
    final subB = bus.on<AppEvent>().listen(second.add);

    bus.emit(SimpleEvent(name: 'one', at: now));
    await Future<void>.delayed(Duration.zero);

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(bus.hasListeners, isTrue);
    await subA.cancel();
    await subB.cancel();
    await bus.dispose();
  });

  test('test_eventBus_emitAfterDispose_isANoOp', () async {
    final bus = EventBus();
    final seen = <AppEvent>[];
    final sub = bus.on<AppEvent>().listen(seen.add);
    await sub.cancel();
    await bus.dispose();

    expect(() => bus.emit(SimpleEvent(name: 'late', at: now)), returnsNormally);
    expect(bus.hasListeners, isFalse);
  });

  test('test_simpleEvent_now_isUtcStamped', () {
    final event = SimpleEvent.now('playback.started');

    expect(event.at.isUtc, isTrue);
    expect(event.name, 'playback.started');
    expect(event.toString(), contains('playback.started'));
  });
}
