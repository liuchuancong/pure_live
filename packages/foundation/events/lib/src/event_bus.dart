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

import 'package:pure_live_utils/pure_live_utils.dart';

/// How many events one bus keeps for diagnostics. A ring the size of the program is a memory leak with a
/// getter on it.
const int kEventLedgerLimit = 64;

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
  final List<void Function(AppEvent event)> _observers = <void Function(AppEvent)>[];
  final List<AppEvent> _ledger = <AppEvent>[];
  final Map<String, int> _counts = <String, int>{};
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

  /// How many channels this bus has opened. Bounded by the number of event types in the program; a number
  /// that tracks the number of *screens opened* means a listener was never cancelled.
  int get channelCount => _channels.length;

  /// The events this bus passed most recently, newest last, capped at [kEventLedgerLimit].
  ///
  /// A copy, so a caller cannot append to a diagnostic ledger.
  List<AppEvent> get recentEvents => List<AppEvent>.unmodifiable(_ledger);

  /// How many times [name] was emitted, for "is this thing firing every frame" questions.
  int countOf(String name) => _counts[name] ?? 0;

  /// The per-name totals, highest first.
  Map<String, int> get emissionCounts {
    final sorted = _counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return <String, int>{for (final entry in sorted) entry.key: entry.value};
  }

  /// A stream of the events that are instances of [T], including later subclasses of it.
  ///
  /// Calling it twice for the same [T] returns the same broadcast stream, so a component that forgets to
  /// cancel leaks a subscription and not a whole retained channel per call. Events emitted before
  /// subscribing are not replayed: a listener that needs current state reads it from the owning component, or
  /// asks for [onReplaying] deliberately.
  Stream<T> on<T extends AppEvent>() {
    if (_disposed) {
      // A closed bus hands out an empty stream rather than throwing: a late subscription during teardown is
      // the same benign race as a late publish, and dispose() already means "nothing more will arrive".
      return const Stream<AppEvent>.empty().cast<T>();
    }
    final channel = _channelFor<T>();
    return channel.controller.stream.cast<T>();
  }

  /// The same, but the [length] most recent events of [T] arrive first, then the live ones.
  ///
  /// A screen that opens after `session.expired` was emitted needs to know, and "read it from the owning
  /// component" only works when a component owns it. The replay length is explicit and small; this returns a
  /// fresh single-subscription stream, so the caller must cancel it - unlike [on], which hands out a shared one.
  Stream<T> onReplaying<T extends AppEvent>(int length) {
    if (length < 1) {
      throw ArgumentError.value(length, 'length', 'must replay at least one event');
    }
    if (_disposed) {
      return const Stream<AppEvent>.empty().cast<T>();
    }
    final channel = _channelFor<T>();
    channel.replayLength = length;
    final buffered = channel.replayBuffer.cast<T>().toList(growable: false);
    if (buffered.isEmpty) {
      return on<T>();
    }
    final out = StreamController<T>();
    final link = channel.controller.stream.listen(
      (event) => out.add(event as T),
      onError: out.addError,
      onDone: out.close,
      cancelOnError: true,
    );
    for (final event in buffered) {
      out.add(event);
    }
    out.onCancel = link.cancel;
    return out.stream;
  }

  /// Subscribes [handler] and registers the handle with [into], so forgetting to cancel becomes one thing a
  /// component does at dispose rather than one per subscription.
  StreamSubscription<T> subscribe<T extends AppEvent>(
    void Function(T event) handler, {
    void Function(Object error, StackTrace stackTrace)? onError,
    Disposer? into,
  }) {
    final subscription = on<T>().listen(handler, onError: onError);
    into?.addSubscription(subscription);
    return subscription;
  }

  /// Publishes [event] to every matching subscriber.
  void emit(AppEvent event) {
    if (_disposed) {
      return;
    }
    _ledger.add(event);
    while (_ledger.length > kEventLedgerLimit) {
      _ledger.removeAt(0);
    }
    _counts[event.name] = (_counts[event.name] ?? 0) + 1;
    for (final observer in _observers.toList(growable: false)) {
      try {
        observer(event);
      } on Object {
        // A diagnostic sink that throws must not mute the event for the components that care about it.
      }
    }
    for (final channel in _channels.values.toList(growable: false)) {
      if (!channel.matches(event)) {
        continue;
      }
      channel.remember(event);
      if (!channel.controller.hasListener || channel.controller.isClosed) {
        continue;
      }
      channel.controller.add(event);
    }
  }

  /// Publishes in order, in one call, for a teardown or a batch import that produces several facts.
  void emitAll(Iterable<AppEvent> events) {
    for (final event in events) {
      emit(event);
    }
  }

  /// Watches everything the bus passes, without becoming a subscriber.
  ///
  /// For logging and dashboards. Returns the function that removes it; call it before disposing, or keep the
  /// bus itself, which drops observers when disposed.
  void Function() observe(void Function(AppEvent event) observer) {
    _observers.add(observer);
    return () => _observers.remove(observer);
  }

  /// The next event of [T], or null if [within] elapses first.
  ///
  /// A wait, not a poll: the callers that need this are waiting for a fact that has no owning component to
  /// ask, and a loop with a sleep in it hides the race instead of resolving it.
  Future<T?> expect<T extends AppEvent>(Duration within) async {
    if (_disposed || within <= Duration.zero) {
      return null;
    }
    try {
      return await on<T>().first.timeout(within);
    } on TimeoutException {
      return null;
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
    _observers.clear();
    for (final channel in pending) {
      await channel.controller.close();
    }
  }

  _TypeChannel _channelFor<T extends AppEvent>() => _channels.putIfAbsent(T, () => _TypeChannel((event) => event is T));
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

  /// Set by [EventBus.onReplaying]; zero means the buffer is not kept at all.
  int replayLength = 0;
  final List<AppEvent> _replay = <AppEvent>[];

  List<AppEvent> get replayBuffer => _replay;

  void remember(AppEvent event) {
    if (replayLength == 0) {
      return;
    }
    _replay.add(event);
    while (_replay.length > replayLength) {
      _replay.removeAt(0);
    }
  }
}
