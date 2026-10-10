// Module: lib/src/relative_time.dart
// Purpose: Turns an instant into the bucket and plural category "3 minutes ago" needs, and renders it from
// wording the host supplies.
// Author: liuchuancong
// Created: 2026-10-11
//
// Two decisions live here and neither belongs to a widget. Which bucket an instant falls in is a rule with
// published thresholds (45 seconds is still "seconds", 22 hours is still "hours"), and months and years must
// be counted on the calendar rather than by dividing by 30 and 365 days, or a feed written on the 31st shows
// "0 months ago". The wording is deliberately not here: translation assets belong to the application, so a
// host hands in a phrase table and this package only picks which cell of it to read.

import 'locale.dart';
import 'message_format.dart' show NumberRender;
import 'plural_rules.dart';

/// The bucket a timestamp is displayed as.
enum RelativeUnit { justNow, seconds, minutes, hours, days, weeks, months, years }

/// Whether the instant is before or after the reference point.
enum RelativeTense { past, future }

/// Where each bucket ends. CLDR-style defaults; a compact list view raises them to show fewer distinct units.
final class RelativeThresholds {
  const RelativeThresholds({
    this.justNow = const Duration(seconds: 15),
    this.seconds = const Duration(minutes: 1),
    this.minutes = const Duration(minutes: 45),
    this.hours = const Duration(hours: 22),
    this.days = const Duration(days: 6),
    this.weeks = const Duration(days: 30),
  });

  /// Under this the list says "just now" rather than counting seconds.
  final Duration justNow;

  /// A gap under a minute is still worth showing as seconds in a live row.
  final Duration seconds;

  /// Up to 45 minutes reads as minutes; past that it is an hour.
  final Duration minutes;

  /// 22 hours keeps "23 hours ago" instead of jumping to "yesterday" too early.
  final Duration hours;

  final Duration days;

  /// Past this the count switches to months, which are calendar months, not 30-day spans.
  final Duration weeks;

  static const RelativeThresholds standard = RelativeThresholds();
}

/// One displayable gap: which unit, how many, and which side of now.
final class RelativeSpan {
  const RelativeSpan({required this.unit, required this.count, required this.tense});

  /// [target] measured against [now], in the units [thresholds] cut at.
  ///
  /// Months and years are counted on the calendar: `2026-10-11` minus `2026-09-11` is one month even though
  /// the raw duration is 29 or 30 days depending on the month, and a naive `inDays ~/ 30` reports zero.
  factory RelativeSpan.of(
    DateTime target, {
    required DateTime now,
    RelativeThresholds thresholds = RelativeThresholds.standard,
  }) {
    final delta = target.difference(now);
    final tense = delta.isNegative ? RelativeTense.past : RelativeTense.future;
    final gap = delta.abs();
    if (gap <= thresholds.justNow) {
      return RelativeSpan(unit: RelativeUnit.justNow, count: 0, tense: tense);
    }
    if (gap < thresholds.seconds) {
      return RelativeSpan(unit: RelativeUnit.seconds, count: gap.inSeconds, tense: tense);
    }
    if (gap < thresholds.minutes) {
      return RelativeSpan(unit: RelativeUnit.minutes, count: gap.inMinutes, tense: tense);
    }
    if (gap < thresholds.hours) {
      return RelativeSpan(unit: RelativeUnit.hours, count: gap.inHours, tense: tense);
    }
    if (gap < thresholds.days) {
      return RelativeSpan(unit: RelativeUnit.days, count: gap.inDays, tense: tense);
    }
    if (gap < thresholds.weeks) {
      return RelativeSpan(unit: RelativeUnit.weeks, count: (gap.inDays / 7).round(), tense: tense);
    }
    final earlier = tense == RelativeTense.past ? target : now;
    final later = tense == RelativeTense.past ? now : target;
    final months = _monthsBetween(earlier, later);
    // A 31-day gap that crosses a month boundary is still 0 calendar months, and "0 months ago" is worse than
    // the week count it came from.
    if (months < 1) {
      return RelativeSpan(unit: RelativeUnit.weeks, count: (gap.inDays / 7).round(), tense: tense);
    }
    if (months < 12) {
      return RelativeSpan(unit: RelativeUnit.months, count: months, tense: tense);
    }
    return RelativeSpan(unit: RelativeUnit.years, count: months ~/ 12, tense: tense);
  }

  final RelativeUnit unit;
  final int count;
  final RelativeTense tense;

  bool get isJustNow => unit == RelativeUnit.justNow;

  /// The plural category the count takes in [language], so a renderer does not recompute the operands.
  PluralCategory categoryFor(String language) => pluralCategoryOf(count, language: language);

  @override
  String toString() => 'RelativeSpan(${tense.name} ${count} ${unit.name})';

  @override
  bool operator ==(Object other) =>
      other is RelativeSpan && other.unit == unit && other.count == count && other.tense == tense;

  @override
  int get hashCode => Object.hash(unit, count, tense);
}

/// The wording one language needs.
///
/// An interface rather than a map because an app already has its strings in a catalog with its own lookup
/// rules; implementing this over that catalog costs one method and keeps a second copy of the assets out.
abstract interface class RelativePhrases {
  String justNow(String language);

  /// One cell of the table. [countText] is already locale-formatted; the pattern's own placeholder is not
  /// substituted here, so a table can use `{count}`, `%d` or its catalog's argument syntax.
  String unit({
    required RelativeUnit unit,
    required RelativeTense tense,
    required int count,
    required PluralCategory category,
    required String countText,
    required String language,
  });
}

/// A phrase table as nested maps, for a host that ships its wording as data rather than code.
final class RelativePhraseTable implements RelativePhrases {
  const RelativePhraseTable({required this.justNowText, required this.units, this.missingUnitText});

  final String justNowText;

  /// unit -> tense -> plural category -> pattern.
  final Map<RelativeUnit, Map<RelativeTense, Map<PluralCategory, String>>> units;

  /// Shown when the table has no cell for a bucket at all. Null falls back to the bare count, which is
  /// readable but obviously incomplete; a host that would rather see the gap sets a marker string.
  final String? missingUnitText;

  @override
  String justNow(String language) => justNowText;

  @override
  String unit({
    required RelativeUnit unit,
    required RelativeTense tense,
    required int count,
    required PluralCategory category,
    required String countText,
    required String language,
  }) {
    final byCategory = units[unit]?[tense];
    final pattern = byCategory == null ? null : _pick(byCategory, category);
    if (pattern == null) {
      return missingUnitText ?? countText;
    }
    return pattern.replaceAll('{count}', countText);
  }

  /// Every bucket the table cannot render, for a check that runs at startup rather than on a user's screen.
  List<String> missingCells({
    List<RelativeUnit> units = const <RelativeUnit>[
      RelativeUnit.seconds,
      RelativeUnit.minutes,
      RelativeUnit.hours,
      RelativeUnit.days,
      RelativeUnit.weeks,
      RelativeUnit.months,
      RelativeUnit.years,
    ],
    List<RelativeTense> tenses = RelativeTense.values,
  }) {
    final out = <String>[];
    for (final unit in units) {
      for (final tense in tenses) {
        final byCategory = this.units[unit]?[tense];
        if (byCategory == null || byCategory.isEmpty) {
          out.add('${unit.name}.${tense.name}');
        }
      }
    }
    out.sort();
    return out;
  }

  static String? _pick(Map<PluralCategory, String> byCategory, PluralCategory category) =>
      byCategory[category] ?? byCategory[PluralCategory.other] ?? (byCategory.isEmpty ? null : byCategory.values.first);
}

/// Renders an instant as relative time.
final class RelativeTimeFormatter {
  const RelativeTimeFormatter({
    required this.language,
    required this.phrases,
    this.thresholds = RelativeThresholds.standard,
    this.number,
    this.now,
  });

  final String language;
  final RelativePhrases phrases;
  final RelativeThresholds thresholds;

  /// How the count is written. Null formats it as an integer, which is right for English and wrong for a
  /// locale whose separator the app cares about - a catalog-backed host passes its own renderer.
  final NumberRender? number;

  /// A fixed reference instant, for replaying a recorded feed: without it the same row renders differently
  /// every time the list rebuilds.
  final DateTime? now;

  RelativeSpan spanOf(DateTime target, {DateTime? now}) {
    final reference = now ?? this.now ?? DateTime.now();
    return RelativeSpan.of(target, now: reference, thresholds: thresholds);
  }

  String format(DateTime target, {DateTime? now}) {
    final span = spanOf(target, now: now);
    if (span.isJustNow) {
      return phrases.justNow(language);
    }
    final countText = number == null ? '${span.count}' : number!(span.count, 0);
    return phrases.unit(
      unit: span.unit,
      tense: span.tense,
      count: span.count,
      category: span.categoryFor(language),
      countText: countText,
      language: language,
    );
  }
}

/// Whole calendar months between two local dates, ignoring the day-of-month overshoot.
int _monthsBetween(DateTime earlier, DateTime later) {
  var months = (later.year - earlier.year) * 12 + (later.month - earlier.month);
  if (months > 0 && later.day < earlier.day) {
    months--;
  }
  if (months < 0 && later.day > earlier.day) {
    months++;
  }
  return months < 0 ? 0 : months;
}
