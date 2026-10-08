// Module: lib/src/event_bus.dart
// Purpose: A typed in-process event bus for facts many listeners care about, and nothing else.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/architecture/dependency-rules.md section 6 bans replacing a normal interface dependency with an
// event bus. This bus is for the cases where there genuinely is no single consumer: a session expiring,
// a source being disabled, playback state the settings screen wants to mirror. If exactly one component
// owns the reaction, that component should expose a method, not subscribe here.

import 'dart:async';

/// Anything that can travel on the bus. Events describe a fact that already happened.
abstract interface class AppEvent {
  /// When the fact occurred, in UTC.
  DateTime get at;

  /// A stable dotted name for logs and dashboards, for example `auth.expired`.
  String get name;
}

/// A base event carrying a timestamp and a name, so a concrete event is one subclass.
class SimpleEvent implements AppEvent {
  const SimpleEvent({required this.name, required this.at, this.payload = const <String, Object?>{}});

  factory SimpleEvent.now(String name, {Map<String, Object?> payload = const <String, Object?>{}}) =>
      SimpleEvent(name: name, at: DateTime.now().toUtc(), payload: payload);

  @override
  final String name;
  @override
  final DateTime at;

  /// Extra context. Keep it small: listeners may hold the event while processing.
  final Map<String, Object?> payload;

  @override
  String toString() => 'SimpleEvent($name at=$at)';
}

/// Delivers events to subscribers by declared type.
final class EventBus {
  final List<_Subscription> _subscriptions = <_Subscription>[];

  /// Whether any listener currently subscribes to [T].
  bool get hasListeners => _subscriptions.any((item) => !item.controller.isClosed);

  /// A stream of events that are instances of [T], including later subclasses.
  ///
  /// Events emitted before subscribing are not replayed; a listener that needs the current state must
  /// read it from the owning component, which is the interface dependency this bus must not replace.
  Stream<T> on<T extends AppEvent>() {
    final controller = StreamController<T>.broadcast(sync: true);
    final subscription = _Subscription(
      matches: (event) => event is T,
      deliver: (event) => controller.add(event as T),
      controller: controller,
    );
    _subscriptions.add(subscription);
    return controller.stream;
  }

  /// Publishes [event] to every matching subscriber.
  void emit(AppEvent event) {
    for (final subscription in _subscriptions.toList(growable: false)) {
      if (subscription.controller.isClosed) {
        _subscriptions.remove(subscription);
        continue;
      }
      if (subscription.matches(event)) {
        subscription.deliver(event);
      }
    }
  }

  /// Closes every stream. After dispose, [emit] is a no-op rather than an error, because a late publisher
  /// during teardown must not crash the app.
  Future<void> dispose() async {
    final pending = _subscriptions.toList(growable: false);
    _subscriptions.clear();
    for (final subscription in pending) {
      await subscription.controller.close();
    }
  }
}

class _Subscription {
  _Subscription({required this.matches, required this.deliver, required this.controller});

  final bool Function(AppEvent event) matches;
  final void Function(AppEvent event) deliver;
  final StreamController<Object?> controller;
}
