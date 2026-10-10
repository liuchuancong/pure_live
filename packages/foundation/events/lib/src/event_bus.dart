// Module: lib/src/event_bus.dart
// Purpose: A typed in-process event bus for facts many listeners care about, and nothing else.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/architecture/dependency-rules.md section 6 bans replacing a normal interface dependency with an
// event bus. This bus is for the cases where there genuinely is no single consumer: a session expiring,
// a source being disabled, playback state the settings screen wants to mirror. If exactly one component
// owns the reaction, that component should expose a method, not subscribe here.
//
// One stream is kept per event *type*, not per call to [on]. The first version created a fresh controller
// every time and kept it until dispose, so a widget that subscribed in build() - or a screen reopened
// twenty times - grew the bus by one retained controller each time, with no way to notice it. Bounded by
// the number of event classes in the program is the only bound that holds without a lifecycle this layer
// does not own.

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

  /// An event stamped now, for a publisher that has no better time to give it.
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
  final Map<Type, _TypeChannel> _channels = <Type, _TypeChannel>{};
  bool _disposed = false;

  /// True when anything at all is subscribed, on any type.
  ///
  /// For a specific type ask [hasListenersFor]; "does anyone care about session expiry" is a different
  /// question from "is the bus in use", and the previous getter answered the first with the second.
  bool get hasListeners => _channels.values.any((channel) => channel.controller.hasListener);

  /// True when somebody is subscribed to [T] right now.
  ///
  /// A publisher that skips work when nobody is listening is the legitimate use; deciding *whether the user
  /// should see this fact* from here is not - that is the interface dependency section 6 forbids.
  bool hasListenersFor<T extends AppEvent>() => _channels[T]?.controller.hasListener ?? false;

  /// A stream of the events that are instances of [T], including later subclasses of it.
  ///
  /// Calling it twice for the same [T] returns the same broadcast stream, so a component that forgets to
  /// cancel leaks a subscription and not a whole retained channel per call. Events emitted before
  /// subscribing are not replayed: a listener that needs current state reads it from the owning component.
  Stream<T> on<T extends AppEvent>() {
    if (_disposed) {
      // A closed bus hands out an empty stream rather than throwing: a late subscription during teardown is
      // the same benign race as a late publish, and dispose() already means "nothing more will arrive".
      return const Stream<AppEvent>.empty().cast<T>();
    }
    final channel = _channels.putIfAbsent(T, () => _TypeChannel((event) => event is T));
    return channel.controller.stream.cast<T>();
  }

  /// Publishes [event] to every matching subscriber.
  void emit(AppEvent event) {
    if (_disposed) {
      return;
    }
    for (final channel in _channels.values.toList(growable: false)) {
      if (!channel.controller.hasListener || channel.controller.isClosed) {
        continue;
      }
      if (channel.matches(event)) {
        channel.controller.add(event);
      }
    }
  }

  /// Closes every stream. After dispose, [emit] and [on] are inert rather than an error, because a late
  /// publisher or subscriber during teardown must not crash the app.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final pending = _channels.values.toList(growable: false);
    _channels.clear();
    for (final channel in pending) {
      await channel.controller.close();
    }
  }
}

/// The one channel a given declared type owns: a broadcast controller plus the test for membership.
///
/// The predicate is built where the type is still known - inside [EventBus.on] - because a
/// `StreamController<AppEvent>` cannot recover it later, and getting this wrong is what makes a base-type
/// subscription see everything or a leaf subscription see nothing.
class _TypeChannel {
  // Deliberately not sync:true. A synchronous broadcast runs each listener's callback inside add(), so one
  // throwing listener propagated its error back into emit() and stopped every later subscriber - a settings
  // page's bug could mute an auth-expiry notification. Async delivery confines the blast radius to the
  // subscription that threw, whose own error handler (or the zone that created it) receives it.
  _TypeChannel(this.matches) : controller = StreamController<AppEvent>.broadcast();

  final bool Function(AppEvent event) matches;
  final StreamController<AppEvent> controller;
}
