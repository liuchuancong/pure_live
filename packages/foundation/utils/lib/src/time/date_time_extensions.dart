// Module: lib/src/time/date_time_extensions.dart
// Purpose: Formatting and comparing dates the way the player and the history list actually need them.
// Author: liuchuancong
// Created: 2026-10-10

extension DurationFormatting on Duration {
  /// The duration as `H:MM:SS`, or `M:SS` when there is no hour.
  ///
  /// Used by progress labels and recording names, where a fixed shape matters more than locale.
  String get asHms {
    final total = abs().inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours == 0 ? '$minutes:$ss' : '$hours:$mm:$ss';
  }

  /// A short human form: `1h 20m`, `45s`, `0s`. Hours suppress the seconds so a long video does not read
  /// like a stopwatch.
  String get asCompact {
    final total = abs().inSeconds;
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
}

extension DateTimeComparison on DateTime {
  /// Whether both instants fall on the same calendar day in the same zone.
  ///
  /// History grouping asks "today or earlier", which is a calendar question; comparing [day] of a UTC
  /// instant against a local one puts the boundary at the wrong hour for every viewer east of Greenwich.
  bool sameDayAs(DateTime other) {
    final left = toLocal();
    final right = other.toLocal();
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  /// The start of this instant's local day.
  DateTime get startOfDay {
    final local = toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
