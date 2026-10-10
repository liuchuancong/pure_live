// Module: lib/src/sinks.dart
// Purpose: The two ways an event leaves the process for observation - a log line and a bounded recording -
// without either one becoming a subscriber that has to be remembered.
// Author: liuchuancong
// Created: 2026-10-11
//
// A bus nobody can see into is how a "spontaneous logout" incident ends with nobody knowing whether the event
// was emitted, delivered, or dropped by a cancelled subscription. Both sinks here attach through
// [EventBus.observe], so they see every emit whether or not a listener exists, and both are bounded: a
// diagnostic ring the size of the session is the problem it is meant to diagnose.

import 'package:pure_live_logging/pure_live_logging.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'event_bus.dart';

/// How loud one event name is in the log.
typedef EventLevelMap = LogLevel Function(String name);

/// Writes one log line per emitted event.
///
/// Attach it once, in the composition root. It records the *fact and the count*, not the payload: an event
/// body can carry a url with a token in it, and a log line that includes payloads is how a credential reaches
/// a support attachment.
final class EventLogSink {
  EventLogSink({required EventBus bus, required Logger log, EventLevelMap? level, Set<String>? only, int? suspendAfter})
    : _log = log,
      _level = level ?? _defaultLevel,
      _only = only,
      _limit = suspendAfter ?? 200 {
    _stop = bus.observe(_onEvent);
  }

  final Logger _log;
  final EventLevelMap _level;
  final Set<String>? _only;
  final int _limit;
  late final void Function() _stop;

  int _seen = 0;
  bool _suspended = false;

  /// True once the flood guard fired, meaning the log stopped carrying events while the bus kept passing them.
  bool get isSuspended => _suspended;

  int get observed => _seen;

  /// Stops writing. Safe to call twice; the bus also drops it on dispose.
  void detach() => _stop();

  void _onEvent(AppEvent event) {
    final wanted = _only;
    if (wanted != null && !wanted.contains(event.name)) {
      return;
    }
    _seen++;
    if (_suspended) {
      return;
    }
    if (_seen > _limit) {
      // A live-chat event bus floods by design; the guard says so once instead of filling the log and the
      // device's storage until the app is killed for it.
      _suspended = true;
      _log.warning('event log suspended', fields: <String, Object?>{'observed': _seen, 'limit': _limit});
      return;
    }
    _write(_level(event.name), event.name, <String, Object?>{
      'at': event.at.toIso8601String(),
      'type': event.runtimeType.toString(),
    });
  }

  /// Logger exposes one method per level; a map from event name to level needs the dispatch in between.
  void _write(LogLevel level, String message, Map<String, Object?> fields) {
    switch (level) {
      case LogLevel.debug:
        _log.debug(message, fields: fields);
      case LogLevel.info:
        _log.info(message, fields: fields);
      case LogLevel.warning:
        _log.warning(message, fields: fields);
      case LogLevel.error:
        _log.error(message, fields: fields);
      case LogLevel.fatal:
        _log.fatal(message, fields: fields);
    }
  }

  static LogLevel _defaultLevel(String name) => LogLevel.info;
}

/// Keeps the last [limit] events in memory for a diagnostics screen or a test.
///
/// Deliberately not a subscriber: it must see events that arrived while nothing was listening, which is
/// exactly the class of bug a "why did nothing happen" report is about.
final class EventRecorder {
  EventRecorder({required EventBus bus, this.limit = kEventLedgerLimit}) {
    _stop = bus.observe(_remember);
  }

  final int limit;
  final List<AppEvent> _events = <AppEvent>[];
  late final void Function() _stop;

  /// Oldest first.
  List<AppEvent> get events => List<AppEvent>.unmodifiable(_events);

  int get count => _events.length;

  /// The events named [name], oldest first.
  List<AppEvent> matching(String name) => _events.where((event) => event.name == name).toList(growable: false);

  bool contains(String name) => _events.any((event) => event.name == name);

  void clear() => _events.clear();

  void detach() => _stop();

  void _remember(AppEvent event) {
    _events.add(event);
    while (_events.length > limit) {
      _events.removeAt(0);
    }
  }
}

/// A publisher that stamps its own events, so a caller cannot forget the timestamp and a consumer cannot read
/// a local-time value as UTC.
final class EventPublisher {
  EventPublisher({required EventBus bus, Clock? clock}) : _bus = bus, _clock = clock ?? systemClock;

  final EventBus _bus;
  final Clock _clock;

  /// Emits a [SimpleEvent] named [name] stamped with the injected clock.
  void fire(String name, {Map<String, Object?> payload = const <String, Object?>{}}) {
    final required = requireNonBlank(name, name: 'name');
    _bus.emit(SimpleEvent(name: required, at: _clock().toUtc(), payload: payload));
  }

  /// Emits an event the caller already built, keeping its own timestamp.
  void emit(AppEvent event) => _bus.emit(event);

  bool isWatched<T extends AppEvent>() => _bus.hasListenersFor<T>();
}
