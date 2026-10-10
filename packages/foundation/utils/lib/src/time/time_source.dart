// Module: lib/src/time/time_source.dart
// Purpose: A clock seam and duration formatting that keep time-dependent code testable without faking DateTime.
// Author: liuchuancong
// Created: 2026-10-08
//
// Why this exists: expiry checks, refresh scheduling and retry backoff all compare against now. Reading
// DateTime.now() directly makes those paths untestable and non-deterministic, so callers take a Clock.
//
// The seam is a function type rather than an interface because every consumer already stores one callable
// value; wrapping it in an abstract class would add a level of indirection that buys nothing at the call
// site. package:clock is still honoured: [systemClock] reads through its zone-overridable global, so a test
// that uses withClock() moves this default too.

import 'package:clock/clock.dart' as pkg;

/// Reads the current time. Implementations must return UTC.
typedef Clock = DateTime Function();

/// The real wall clock, read through package:clock so a zone override reaches callers that never injected
/// their own clock.
DateTime systemClock() => pkg.clock.now().toUtc();

/// A clock a test controls: it only moves when the test says so.
///
/// It is callable rather than a subtype of [Clock], which lets it be passed anywhere a Clock function is
/// expected without pretending to extend a function type.
final class FixedClock {
  FixedClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  /// The current reading, so this object can stand in for a [Clock] directly.
  DateTime call() => _now;

  /// The current reading under the package:clock spelling.
  DateTime now() => _now;

  void advance(Duration by) {
    _now = _now.add(by);
  }

  void setTo(DateTime value) {
    _now = value.toUtc();
  }
}
