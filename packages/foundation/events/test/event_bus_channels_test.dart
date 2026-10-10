// Module: test/event_bus_channels_test.dart
// Purpose: Verify the bus stays bounded per type and that a per-type listener question tells the truth.
// Author: liuchuancong
// Created: 2026-10-10
//
// The first implementation allocated a fresh controller for every call to on<T>() and kept it until
// dispose, so a widget that subscribed on each rebuild grew the bus without bound and every dropped
// subscription stayed reachable. The fix is one channel per event type: bounded by the classes in the
// program, which this layer can actually know about.

import 'dart:async';

import 'package:pure_live_events/pure_live_events.dart';
import 'package:test/test.dart';

final class PlaybackStarted implements AppEvent {
  const PlaybackStarted(this.at);

  @override
  final DateTime at;

  @override
  String get name => 'playback.started';
}

final class SourceDisabled implements AppEvent {
  const SourceDisabled(this.at);

  @override
  final DateTime at;

  @override
  String get name => 'source.disabled';
}

void main() {
  final now = DateTime.utc(2026, 10, 10, 12);

  test('test_eventBus_repeatedOnForOneTypeSharesOneChannel', () async {
    final bus = EventBus();
    // Twenty rebuilds of a screen that subscribes in build() must not retain twenty channels.
    final streams = List<Stream<PlaybackStarted>>.generate(20, (_) => bus.on<PlaybackStarted>());

    final seen = <PlaybackStarted>[];
    final subscription = streams.first.listen(seen.add);
    bus.emit(PlaybackStarted(now));
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    // Every one of those streams is the same broadcast stream, so a listener on any of them is one listener.
    expect(bus.hasListenersFor<PlaybackStarted>(), isTrue);
    await subscription.cancel();
    await bus.dispose();
  });

  test('test_eventBus_hasListenersForDistinguishesTypes', () async {
    final bus = EventBus();
    expect(bus.hasListeners, isFalse);
    expect(bus.hasListenersFor<PlaybackStarted>(), isFalse);

    final subscription = bus.on<PlaybackStarted>().listen((_) {});
    expect(bus.hasListeners, isTrue);
    expect(bus.hasListenersFor<PlaybackStarted>(), isTrue);
    expect(bus.hasListenersFor<SourceDisabled>(), isFalse, reason: 'a listener for one type is not a listener for all');

    await subscription.cancel();
    await bus.dispose();
  });

  test('test_eventBus_baseTypeStillSeesSubtypesAndLeafTypeDoesNotSeeSiblings', () async {
    final bus = EventBus();
    final any = <AppEvent>[];
    final onlyPlayback = <PlaybackStarted>[];
    final subA = bus.on<AppEvent>().listen(any.add);
    final subB = bus.on<PlaybackStarted>().listen(onlyPlayback.add);

    bus.emit(PlaybackStarted(now));
    bus.emit(SourceDisabled(now));
    await Future<void>.delayed(Duration.zero);

    expect(any, hasLength(2));
    expect(onlyPlayback, hasLength(1));
    await subA.cancel();
    await subB.cancel();
    await bus.dispose();
  });

  test('test_eventBus_disposeIsIdempotentAndLaterStreamsAreEmpty', () async {
    final bus = EventBus();
    await bus.dispose();
    await bus.dispose();

    final seen = <AppEvent>[];
    final subscription = bus.on<AppEvent>().listen(seen.add);
    bus.emit(PlaybackStarted(now));
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty);
    expect(bus.hasListeners, isFalse);
    await subscription.cancel();
  });

  test('test_eventBus_listenerThrowingDoesNotStopTheOthers', () async {
    final bus = EventBus();
    final received = <String>[];
    final zoneErrors = <Object>[];

    // A Dart stream reports a callback that throws to the zone that created the subscription, so the noisy
    // listener is created inside a guarded zone and its error is collected there.
    late StreamSubscription<AppEvent> first;
    runZonedGuarded(() {
      first = bus.on<AppEvent>().listen((event) => throw StateError('bad listener ${event.name}'));
    }, (error, _) => zoneErrors.add(error));
    final second = bus.on<AppEvent>().listen((event) => received.add(event.name));

    // The older behaviour was the real bug: with sync delivery the error was thrown straight back through
    // emit(), so the publisher crashed and the later subscriber was never reached.
    bus.emit(PlaybackStarted(now));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(received, <String>['playback.started'], reason: 'one broken listener may not mute the bus');
    expect(zoneErrors, hasLength(1), reason: 'and the bug is reported to the zone that owns it');

    // The bus keeps working after the bad listener.
    bus.emit(PlaybackStarted(now));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(received, hasLength(2));

    await first.cancel();
    await second.cancel();
    await bus.dispose();
  });

  test('test_simpleEvent_payloadIsCarriedToTheListener', () async {
    final bus = EventBus();
    final seen = <SimpleEvent>[];
    final subscription = bus.on<SimpleEvent>().listen(seen.add);

    bus.emit(SimpleEvent(name: 'sync.done', at: now, payload: <String, Object?>{'items': 3}));
    await Future<void>.delayed(Duration.zero);

    expect(seen.single.payload['items'], 3);
    await subscription.cancel();
    await bus.dispose();
  });
}
