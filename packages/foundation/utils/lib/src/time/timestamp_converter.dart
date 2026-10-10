// Module: lib/src/time/timestamp_converter.dart
// Purpose: Conversions between the epoch units the protocols use and Dart DateTime.
// Author: liuchuancong
// Created: 2026-10-10
//
// Sources mix seconds, milliseconds and microsecond epochs in the same response, and a value read in the
// wrong unit is off by three or six orders of magnitude - which looks like an expiry far in the future
// rather than a bug. The unit is therefore always named at the call site, never inferred.

/// Epoch conversions with the unit stated in the method name.
final class Timestamps {
  const Timestamps._();

  /// A UTC instant from whole seconds since the epoch; zero and negatives are accepted as-is.
  static DateTime fromSeconds(int secondsSinceEpoch) =>
      DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000, isUtc: true);

  /// A UTC instant from milliseconds since the epoch.
  static DateTime fromMilliseconds(int millisecondsSinceEpoch) =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch, isUtc: true);

  /// A UTC instant from microseconds since the epoch, the unit media_core uses for ticket expiry.
  static DateTime fromMicroseconds(int microsecondsSinceEpoch) =>
      DateTime.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch, isUtc: true);

  /// Whole seconds since the epoch, for the wire formats that carry second resolution.
  static int toSeconds(DateTime value) => value.toUtc().millisecondsSinceEpoch ~/ 1000;

  /// Microseconds since the epoch, matching the media_core timestamp unit.
  static int toMicroseconds(DateTime value) => value.toUtc().microsecondsSinceEpoch;

  /// Parses [value] as seconds or milliseconds by magnitude, returning null when it is not a number.
  ///
  /// The heuristic is deliberate and bounded: any epoch after 1973 and before 2286 is at least five digits
  /// in seconds, so a value below that threshold cannot be seconds and must be a smaller unit. Callers that
  /// know the unit use [fromSeconds] or [fromMilliseconds] instead - this is only for sources that report
  /// both in the same field across versions.
  static DateTime? parseAmbiguous(Object? value) {
    final number = switch (value) {
      final int number => number,
      final String text => int.tryParse(text) ?? double.tryParse(text)?.round(),
      _ => null,
    };
    if (number == null) {
      return null;
    }
    return number.abs() < 100000000000 ? fromSeconds(number) : fromMilliseconds(number);
  }
}
