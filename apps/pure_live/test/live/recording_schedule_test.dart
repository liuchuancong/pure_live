import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/recorder/data/recording_schedule.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

RecordingTask task({
  required DateTime startedAt,
  RecordingTaskState state = RecordingTaskState.stopped,
  bool scheduleEnabled = true,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  int start = 1200,
  int end = 1440,
}) {
  // The defaults are written out at the call sites on purpose — a schedule test
  // that says `start: 1200, end: 1440` states the window it means.
  // ignore_for_file: avoid_redundant_argument_values
  return RecordingTask(
    id: 'bilibili:1',
    platform: 'bilibili',
    roomId: '1',
    roomTitle: 'room',
    state: state,
    startedAt: startedAt,
    scheduleEnabled: scheduleEnabled,
    scheduleDays: days,
    scheduleStartMinutes: start,
    scheduleEndMinutes: end,
  );
}

void main() {
  // 2026-10-26 is a Monday; 2026-10-27 is a Tuesday.
  final monday = DateTime(2026, 10, 26);
  final tuesday = DateTime(2026, 10, 27);

  test('a same-day window includes its start and excludes its end', () {
    final window = task(startedAt: monday, start: 1200, end: 1440);

    expect(window.isWithinSchedule(DateTime(2026, 10, 26, 19, 59)), isFalse);
    expect(window.isWithinSchedule(DateTime(2026, 10, 26, 20, 0)), isTrue);
    expect(window.isWithinSchedule(DateTime(2026, 10, 26, 23, 59)), isTrue);
    expect(window.isWithinSchedule(DateTime(2026, 10, 27, 0, 0)), isFalse);
    expect(window.currentWindowStart(DateTime(2026, 10, 26, 21, 0)), DateTime(2026, 10, 26, 20, 0));
  });

  test('an overnight window belongs to the day it starts', () {
    final window = task(startedAt: monday, start: 1320, end: 120);

    expect(window.isWithinSchedule(DateTime(2026, 10, 26, 23, 0)), isTrue);
    expect(window.isWithinSchedule(DateTime(2026, 10, 27, 1, 0)), isTrue);
    expect(window.isWithinSchedule(DateTime(2026, 10, 27, 3, 0)), isFalse);
    expect(window.currentWindowStart(DateTime(2026, 10, 27, 1, 0)), DateTime(2026, 10, 26, 22, 0));
  });

  test('the weekday filter applies to the day the window starts', () {
    final weekdays = task(startedAt: monday, days: const [1, 2, 3, 4, 5]);

    expect(weekdays.isWithinSchedule(DateTime(2026, 10, 26, 21, 0)), isTrue);
    expect(weekdays.isWithinSchedule(DateTime(2026, 10, 31, 21, 0)), isFalse);
    final fridayOvernight = task(startedAt: monday, days: const [5], start: 1320, end: 120);
    expect(fridayOvernight.isWithinSchedule(DateTime(2026, 10, 31, 1, 0)), isTrue);
    expect(fridayOvernight.isWithinSchedule(DateTime(2026, 10, 30, 23, 0)), isTrue);
  });

  test('equal start and end is the whole day', () {
    final allDay = task(startedAt: monday, start: 0, end: 0);
    expect(allDay.isWithinSchedule(DateTime(2026, 10, 26, 3, 0)), isTrue);
    expect(allDay.currentWindowStart(DateTime(2026, 10, 26, 3, 0)), DateTime(2026, 10, 26));
  });

  test('a task re-arms only after its last start is older than this window', () {
    final window = task(startedAt: DateTime(2026, 10, 26, 19, 0), start: 1200, end: 1440);
    final now = DateTime(2026, 10, 26, 21, 0);

    expect(window.canRearmAt(now), isTrue);
    expect(task(startedAt: DateTime(2026, 10, 26, 20, 30), start: 1200, end: 1440).canRearmAt(now), isFalse);
    expect(task(startedAt: tuesday, start: 1200, end: 1440).canRearmAt(now), isFalse);
  });

  test('the next window start is the next scheduled day at the start time', () {
    final weekdays = task(startedAt: monday, days: const [1, 2, 3, 4, 5], start: 1200, end: 1440);

    expect(weekdays.nextWindowStart(DateTime(2026, 10, 26, 19, 0)), DateTime(2026, 10, 26, 20, 0));
    expect(weekdays.nextWindowStart(DateTime(2026, 10, 26, 21, 0)), DateTime(2026, 10, 27, 20, 0));
    expect(weekdays.nextWindowStart(DateTime(2026, 10, 30, 22, 0)), DateTime(2026, 11, 2, 20, 0));
    expect(task(startedAt: monday, scheduleEnabled: false).nextWindowStart(monday), isNull);
  });

  test('a disabled schedule is always inside', () {
    final disabled = task(startedAt: monday, scheduleEnabled: false, start: 1200, end: 1300);
    expect(disabled.isWithinSchedule(DateTime(2026, 10, 26, 3, 0)), isTrue);
    expect(disabled.currentWindowStart(DateTime(2026, 10, 26, 3, 0)), isNull);
    expect(disabled.needsLiveCheck, isFalse);
    expect(disabled.canRearmAt(DateTime(2026, 10, 26, 3, 0)), isFalse);
  });

  test('only the live check moves a waiting or scheduled task', () {
    expect(task(startedAt: monday, state: RecordingTaskState.waiting).needsLiveCheck, isTrue);
    expect(
      task(startedAt: monday, state: RecordingTaskState.waiting, scheduleEnabled: false).needsLiveCheck,
      isTrue,
      reason: 'an unscheduled waiting room is the plain “record when live” case',
    );
    expect(task(startedAt: monday).needsLiveCheck, isTrue, reason: 'a scheduled take waits for its next window');
    expect(
      task(startedAt: monday, scheduleEnabled: false).needsLiveCheck,
      isFalse,
      reason: 'a finished one-off recording has nothing left to check',
    );
    expect(task(startedAt: monday, state: RecordingTaskState.recording).needsLiveCheck, isFalse);
    expect(task(startedAt: monday, state: RecordingTaskState.failed).needsLiveCheck, isFalse);
  });
}
