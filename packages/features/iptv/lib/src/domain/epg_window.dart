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
    final endsAt = nowEndsAt;
    if (endsAt == null) {
      return null;
    }
    final remaining = endsAt.toUtc().difference(at.toUtc());
    if (remaining.isNegative) {
      return 0;
    }
    // Ceil, so a programme with 10 seconds left shows "1 min" rather than "0 min".
    return (remaining.inSeconds / 60).ceil();
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

/// Builds the window for [at] out of a chronologically sorted list of programme titles and ends.
///
/// Kept as a free function over (title, startsAt, endsAt) triples so the caller's guide format stays its own
/// business; nothing here assumes a source.
EpgWindow windowFrom(
  List<EpgProgramme> programmes, {
  required DateTime at,
  void Function(DomainFailure failure)? onInconsistentData,
}) {
  if (programmes.isEmpty) {
    return EpgWindow.unknown;
  }
  final moment = at.toUtc();
  final now = programmes.where((programme) => programme.endsAt.toUtc().isAfter(moment)).head;
  if (now == null) {
    // The guide claims nothing is on air, which is a data problem rather than an empty schedule: a channel
    // that is really streaming looks dead, so say which of the two it is.
    onInconsistentData?.call(UnexpectedFailure('every guide entry had already ended at $at'));
    return EpgWindow.unknown;
  }
  final following = programmes.where((programme) => programme.startsAt.toUtc().isAfter(now.endsAt.toUtc()));
  final next = following.head;
  return EpgWindow(
    nowTitle: now.title,
    nowStartsAt: now.startsAt,
    nowEndsAt: now.endsAt,
    nextTitle: next?.title,
    nextStartsAt: next?.startsAt,
  );
}

/// One guide entry, the minimum a caller has to supply.
final class EpgProgramme {
  const EpgProgramme({required this.title, required this.startsAt, required this.endsAt});

  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
}
