// Module: lib/src/domain/epg_window.dart
// Purpose: The EPG window for one channel: what airs now, next, and the
// remaining minutes - the three facts an IPTV surface displays.
// Author: liuchuancong
// Created: 2026-10-10

/// The current and next programme for one channel at one moment.
final class EpgWindow {
  const EpgWindow({this.nowTitle, this.nowEndsAt, this.nextTitle, this.nextStartsAt});

  final String? nowTitle;
  final DateTime? nowEndsAt;
  final String? nextTitle;
  final DateTime? nextStartsAt;

  bool get hasNow => nowTitle != null;

  /// Minutes until the current programme ends, rounded up. Null without a
  /// known end.
  int? minutesRemaining(DateTime at) {
    final endsAt = nowEndsAt;
    if (endsAt == null) {
      return null;
    }
    final remaining = endsAt.difference(at).inMinutes;
    return remaining < 0 ? 0 : remaining;
  }
}
