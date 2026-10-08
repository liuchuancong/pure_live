// Module: lib/src/time.dart
// Purpose: A clock seam and duration formatting that keep time-dependent code testable without faking DateTime.
// Author: liuchuancong
// Created: 2026-10-08
//
// Why this exists: expiry checks, refresh scheduling and retry backoff all compare against "now". Reading
// DateTime.now() directly makes those paths untestable and non-deterministic, so callers take a Clock.

/// Reads the current time. Implementations must return UTC.
typedef Clock = DateTime Function();

/// The real wall clock.
DateTime systemClock() => DateTime.now().toUtc();

/// A clock a test controls: it only moves when the test says so.
///
/// It is callable rather than a subtype of [Clock], which lets it be passed anywhere a `Clock` function is
/// expected without pretending to extend a function type.
final class FixedClock {
  FixedClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  DateTime call() => _now;

  /// The current reading.
  DateTime get now => _now;

  void advance(Duration by) {
    _now = _now.add(by);
  }

  void setTo(DateTime value) {
    _now = value.toUtc();
  }
}

/// Formats a duration as `H:MM:SS` or `M:SS`, dropping the hour part when it is zero.
///
/// Used by progress labels and recording names where a fixed width matters more than locale.
String formatDurationHms(Duration value) {
  final total = value.abs().inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours == 0) {
    return '$minutes:$ss';
  }
  return '$hours:$mm:$ss';
}

/// A human readable short form, for example `1h 20m`, `45s` or `0s`.
String formatDurationCompact(Duration value) {
  final total = value.abs().inSeconds;
  if (total == 0) {
    return '0s';
  }
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final parts = <String>[
    if (hours > 0) '${hours}h',
    if (minutes > 0) '${minutes}m',
    if (seconds > 0 && hours == 0) '${seconds}s',
  ];
  return parts.join(' ');
}
