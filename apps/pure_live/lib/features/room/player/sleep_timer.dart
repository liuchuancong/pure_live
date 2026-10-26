import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the sleep timer holds: the remaining whole minutes and the moment
/// it ends (UTC), or a zero state when it is off.
typedef SleepTimerState = ({int? minutes, DateTime? endsAt});

/// The room's sleep timer: the viewer asks the room to stop in N minutes
/// (3.x's `closeTimes`: 30/60/90, a custom one, or off), the timer fires
/// and the room's playback stops.
///
/// The remaining time is exposed for the countdown chip the room shows.
final class SleepTimerController extends Notifier<SleepTimerState> {
  Timer? _ticker;
  DateTime? _endsAt;

  @override
  SleepTimerState build() {
    ref.onDispose(_cancel);
    return (minutes: null, endsAt: null);
  }

  /// The timer's remaining time, ticking once a minute (and once the
  /// minute of the end arrives, stopping the room).
  Timer? get ticker => _ticker;

  /// Starts (or restarts) the timer for [minutes], or stops it: null or
  /// zero cancels the running one.
  void start(int? minutes) {
    _cancel();
    final length = minutes;
    if (length == null || length <= 0) {
      return;
    }
    _endsAt = DateTime.now().toUtc().add(Duration(minutes: length));
    _lastWhole = length;
    state = (minutes: length, endsAt: _endsAt);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  int? _lastWhole;

  void _tick() {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final remaining = endsAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      final onFire = onFire_;
      _cancel();
      state = (minutes: null, endsAt: null);
      onFire?.call();
      return;
    }
    final whole = remaining.inMinutes;
    if (whole != _lastWhole) {
      _lastWhole = whole;
      state = (minutes: whole, endsAt: endsAt);
    }
  }

  /// The room's stop callback, set by the room page (the timer must not
  /// know the player).
  void Function()? onFire_;

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    _lastWhole = null;
  }
}

/// The open room's sleep timer (one room plays at a time; the route owns
/// the page).
final sleepTimerProvider = NotifierProvider<SleepTimerController, SleepTimerState>(SleepTimerController.new);
