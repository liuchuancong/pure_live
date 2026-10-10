// Module: lib/src/domain/epg_window.dart
// Purpose: The three facts an IPTV surface shows for one channel: what airs now, what is next, and how long
// the current programme has left.
// Author: liuchuancong
// Created: 2026-10-10
//
// The guide data is somebody else's schedule, delivered late, with gaps and overlaps. So this type reports
// what it saw instead of smoothing it: a remaining time is *rounded up* (a countdown that hits zero before
// the programme ends reads as a hang), and a next programme that starts before the current one ends is
// exposed rather than silently clipped - it is the guide that is wrong, and a surface that hides that
// cannot explain why the schedule looks impossible.
//
// Two ways the builder used to contradict the model it produced: "now" was the first entry that had not
// ended, which is a programme that has not started yet whenever the guide has a gap, so the surface counted
// down a show that was not on; and "next" was searched only after the current entry's end, so an overlapping
// neighbour was skipped and [EpgWindow.isOverlappingGuide] could never be true through [windowFrom] - a flag
// that only a hand-built window could set is not a report, it is decoration.

import 'package:pure_live_utils/pure_live_utils.dart';

/// The window itself, with the consistency of the underlying guide data attached.
final class EpgWindow with ValueEquality {
  const EpgWindow({this.nowTitle, this.nowEndsAt, this.nextTitle, this.nextStartsAt, this.nowStartsAt});

  /// An empty window: no guide data for this channel at this moment.
  static const EpgWindow unknown = EpgWindow();

  final String? nowTitle;
  final DateTime? nowStartsAt;
  final DateTime? nowEndsAt;
  final String? nextTitle;
  final DateTime? nextStartsAt;

  bool get hasNow => nowTitle != null && nowTitle!.isNotEmpty;

  bool get hasNext => nextTitle != null && nextTitle!.isNotEmpty;

  /// Minutes until the current programme ends, rounded up, and never negative.
  ///
  /// Returning null when the guide gave no end is the point: a countdown shown as "0 min" tells the viewer
  /// the programme is over, which is a different statement from "this guide does not say".
  int? minutesRemaining(DateTime at) {
    final seconds = secondsRemaining(at);
    if (seconds == null) {
      return null;
    }
    // Ceil, so a programme with 10 seconds left shows "1 min" rather than "0 min".
    return (seconds / 60).ceil();
  }

  /// True when the guide's own entries disagree: the next programme starts before the current one ends.
  ///
  /// A surface can either show it as-is or hide the next row, but it should be able to choose - which is only
  /// possible if the model says so.
  bool get isOverlappingGuide {
    final endsAt = nowEndsAt;
    final startsAt = nextStartsAt;
    return endsAt != null && startsAt != null && startsAt.toUtc().isBefore(endsAt.toUtc());
  }

  /// True when there is a gap between the current programme and the next one.
  bool get hasGapBeforeNext {
    final endsAt = nowEndsAt;
    final startsAt = nextStartsAt;
    return endsAt != null && startsAt != null && startsAt.toUtc().isAfter(endsAt.toUtc());
  }

  /// How long the guide says the current programme runs; null when it does not say, or says it ends before it
  /// starts, which is a row to drop rather than a negative duration to render.
  Duration? get nowDuration {
    final startsAt = nowStartsAt;
    final endsAt = nowEndsAt;
    if (startsAt == null || endsAt == null) {
      return null;
    }
    final span = endsAt.toUtc().difference(startsAt.toUtc());
    return span.isNegative ? null : span;
  }

  /// Seconds until [at] passes [nowEndsAt], for a countdown a surface can tick against without re-deriving
  /// the rounding rule.
  int? secondsRemaining(DateTime at) {
    final endsAt = nowEndsAt;
    if (endsAt == null) {
      return null;
    }
    final remaining = endsAt.toUtc().difference(at.toUtc()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  @override
  List<Object?> get equalityFields => <Object?>[nowTitle, nowStartsAt, nowEndsAt, nextTitle, nextStartsAt];

  @override
  String toString() => 'EpgWindow(now: $nowTitle until $nowEndsAt, next: $nextTitle at $nextStartsAt)';
}

/// One guide entry, the minimum a caller has to supply.
final class EpgProgramme {
  const EpgProgramme({required this.title, required this.startsAt, required this.endsAt});

  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  bool covers(DateTime at) {
    final moment = at.toUtc();
    return !moment.isBefore(startsAt.toUtc()) && moment.isBefore(endsAt.toUtc());
  }
}

/// Builds the window for [at] out of programme triples, in whatever order the caller's guide had them.
///
/// Kept as a free function over (title, startsAt, endsAt) so the caller's guide format stays its own business;
/// nothing here assumes a source.
///
/// [onInconsistentData] fires for the three shapes real EPG files carry and a surface has to be able to name:
/// a row that ends before it starts, a moment that falls in a gap between rows, and a schedule that ran out.
EpgWindow windowFrom(
  List<EpgProgramme> programmes, {
  required DateTime at,
  void Function(DomainFailure failure)? onInconsistentData,
}) {
  if (programmes.isEmpty) {
    return EpgWindow.unknown;
  }
  final moment = at.toUtc();
  final ordered = List<EpgProgramme>.of(programmes)..sort((a, b) => a.startsAt.toUtc().compareTo(b.startsAt.toUtc()));

  EpgProgramme? now;
  for (final programme in ordered) {
    if (programme.endsAt.toUtc().isBefore(programme.startsAt.toUtc())) {
      onInconsistentData?.call(UnexpectedFailure('guide entry "${programme.title}" ends before it starts'));
      continue;
    }
    if (programme.covers(moment)) {
      // The latest-starting covering row wins: an overlapping guide usually lists a filler under the real
      // programme, and the one that began later is the one on screen.
      now = programme;
    }
  }
  final nextAfterNow = _firstStartingAfter(ordered, after: now?.startsAt ?? moment, excluding: now);

  if (now == null) {
    final ahead = nextAfterNow;
    if (ahead == null) {
      // The guide claims nothing is on air, which is a data problem rather than an empty schedule: a channel
      // that is really streaming looks dead, so say which of the two it is.
      onInconsistentData?.call(UnexpectedFailure('every guide entry had already ended at $at'));
      return EpgWindow.unknown;
    }
    // A gap: nothing is on air, but the guide knows what comes next. Reporting it is the difference between
    // "no EPG" and "the guide has a hole here", which a surface draws differently.
    onInconsistentData?.call(
      UnexpectedFailure('nothing airs at $at; the guide resumes with "${ahead.title}" at ${ahead.startsAt}'),
    );
    return EpgWindow(nextTitle: ahead.title, nextStartsAt: ahead.startsAt);
  }

  return EpgWindow(
    nowTitle: now.title,
    nowStartsAt: now.startsAt,
    nowEndsAt: now.endsAt,
    nextTitle: nextAfterNow?.title,
    nextStartsAt: nextAfterNow?.startsAt,
  );
}

/// The earliest row that starts after [after], skipping [excluding] itself.
///
/// Deliberately *not* "after the current row ends": a neighbour that starts early is the next programme the
/// viewer will see, and dropping it here would make [EpgWindow.isOverlappingGuide] unreachable through
/// [windowFrom] - the flag would only ever describe a window nobody built.
EpgProgramme? _firstStartingAfter(List<EpgProgramme> ordered, {required DateTime after, EpgProgramme? excluding}) {
  for (final programme in ordered) {
    if (identical(programme, excluding)) {
      continue;
    }
    if (programme.startsAt.toUtc().isAfter(after)) {
      return programme;
    }
  }
  return null;
}
