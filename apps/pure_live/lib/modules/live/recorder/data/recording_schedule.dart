import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// The window arithmetic a task's schedule needs.
///
/// The window is local wall time: a viewer sets "20:00–24:00" for the clock on
/// their wall, not for UTC. [RecordingTask.startedAt] is stored in UTC, so the
/// comparison happens in local time on both sides.
extension RecordingSchedule on RecordingTask {
  /// The start of the window [now] falls inside, or null outside every window.
  ///
  /// A start later than the end is an overnight window: Monday 22:00–02:00
  /// covers Monday 22:00 through Tuesday 02:00, and its start belongs to
  /// Monday. Equal start and end is read as the whole day, so a viewer who
  /// sets 00:00–00:00 gets an always-on schedule rather than a zero-length one.
  DateTime? currentWindowStart(DateTime now) {
    if (!scheduleEnabled) return null;
    final local = now.toLocal();
    final minute = local.hour * 60 + local.minute;
    final days = scheduleDays.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : scheduleDays.toSet();
    final start = scheduleStartMinutes.clamp(0, 1439);
    final end = scheduleEndMinutes.clamp(0, 1440);
    final today = DateTime(local.year, local.month, local.day);

    DateTime at(int dayOffset) => DateTime(today.year, today.month, today.day + dayOffset, start ~/ 60, start % 60);

    bool on(int weekday) => days.contains(weekday);

    if (start == end || (start == 0 && end == 1440)) {
      return on(local.weekday) ? at(0) : null;
    }
    if (start < end) {
      return on(local.weekday) && minute >= start && minute < end ? at(0) : null;
    }
    // Overnight: the window started on the current day, or on the previous
    // one when the clock is still before the end.
    if (on(local.weekday) && minute >= start) return at(0);
    final previous = local.weekday == DateTime.monday ? DateTime.sunday : local.weekday - 1;
    if (on(previous) && minute < end) return at(-1);
    return null;
  }

  /// Whether [now] is inside an applicable window; a task without a schedule
  /// is always inside.
  bool isWithinSchedule(DateTime now) => !scheduleEnabled || currentWindowStart(now) != null;

  /// The next window start strictly after [after], within the next week.
  ///
  /// This is what lets the monitor sleep until a window opens instead of
  /// waking every minute for a schedule that may be days away. Null means the
  /// task has no window or no usable day.
  DateTime? nextWindowStart(DateTime after) {
    if (!scheduleEnabled) return null;
    final days = scheduleDays.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : scheduleDays.toSet();
    final start = scheduleStartMinutes.clamp(0, 1439);
    for (var offset = 0; offset <= 8; offset++) {
      final day = DateTime(after.year, after.month, after.day + offset);
      if (!days.contains(day.weekday)) continue;
      final candidate = DateTime(day.year, day.month, day.day, start ~/ 60, start % 60);
      if (candidate.isAfter(after)) return candidate;
    }
    return null;
  }

  /// Whether a finished task has not yet recorded in the window [now] falls
  /// inside, so a scheduled task can re-arm for the next window without
  /// restarting after a stop in the same one.
  bool canRearmAt(DateTime now) {
    final window = currentWindowStart(now);
    if (!scheduleEnabled || window == null) return false;
    return startedAt.toLocal().isBefore(window);
  }
}
