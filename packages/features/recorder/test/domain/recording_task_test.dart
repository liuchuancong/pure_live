// Module: test/domain/recording_task_test.dart
// Purpose: Pins the transition table, the elapsed rule and the file-name guard.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_recorder/pure_live_recorder.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

ContentRef _room(String id) => ContentRef(sourceId: 'huya', contentId: id, kind: ContentKind.liveRoom);

void main() {
  late FixedClock clock;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 10, 10, 12));
  });

  RecordingTask _queued({String name = 'room.m3u8'}) => RecordingTask(ref: _room('r1'), fileName: name, clock: clock);

  test('test_recordingTask_aQueuedRecordingHasNoElapsed', () {
    final task = _queued();
    clock.advance(const Duration(hours: 1));

    expect(
      task.elapsed,
      Duration.zero,
      reason: 'a growing number for something that never started reads as "still going"',
    );
    expect(task.state, RecordingState.queued);
    expect(task.endReason, isNull);
  });

  test('test_recordingTask_beginStartsTheClock', () {
    final task = _queued().begin();
    clock.advance(const Duration(minutes: 3));

    expect(task.isRecording, isTrue);
    expect(task.elapsed, const Duration(minutes: 3));
  });

  test('test_recordingTask_stopFreezesTheElapsedAndNamesTheReason', () {
    final task = _queued().begin();
    clock.advance(const Duration(minutes: 5));
    final stopped = task.stop(RecordingEndReason.userStopped);
    clock.advance(const Duration(minutes: 10));

    expect(stopped.state, RecordingState.stopped);
    expect(stopped.endReason, RecordingEndReason.userStopped);
    expect(stopped.elapsed, const Duration(minutes: 5), reason: 'the number must stop moving at the stop');
    expect(stopped.stoppedAt, DateTime.utc(2026, 10, 10, 12, 5));
  });

  test('test_recordingTask_terminalStatesRefuseEveryTransition', () {
    final stopped = _queued().begin().stop(RecordingEndReason.streamEnded);

    expect(stopped.begin, throwsA(isA<RecordingFailure>()));
    expect(() => stopped.stop(RecordingEndReason.diskFull), throwsA(isA<RecordingFailure>()));
    expect(() => stopped.fail(RecordingEndReason.encoderError), throwsA(isA<RecordingFailure>()));
    expect(stopped.state, RecordingState.stopped, reason: 'a late encoder callback cannot resurrect it');
  });

  test('test_recordingTask_aSecondBeginIsRefusedNotIgnored', () {
    final task = _queued().begin();

    expect(
      task.begin,
      throwsA(isA<RecordingFailure>().having((error) => error.reason, 'reason', contains('already writing'))),
    );
  });

  test('test_recordingTask_stoppingSomethingThatNeverStartedIsRefused', () {
    expect(
      () => _queued().stop(RecordingEndReason.userStopped),
      throwsA(isA<RecordingFailure>().having((error) => error.reason, 'reason', contains('never started'))),
    );
  });

  test('test_recordingTask_aUserStopIsNeverRecordedAsAFailure', () {
    final task = _queued().begin();

    expect(
      () => task.fail(RecordingEndReason.userStopped),
      throwsA(isA<RecordingFailure>().having((error) => error.reason, 'reason', contains('not a failure'))),
    );
  });

  test('test_recordingTask_diskFullIsAFailureWithAReasonAttached', () {
    final failed = _queued().begin().fail(RecordingEndReason.diskFull);

    expect(failed.state, RecordingState.failed);
    expect(failed.endReason, RecordingEndReason.diskFull);
    expect(failed.isTerminal, isTrue);
  });

  test('test_recordingTask_idDoesNotCollideAcrossPathLikeContentIds', () {
    // 'a' + 'b/c' and 'a/b' + 'c' used to share one slash-joined id.
    final first = RecordingTask(ref: _room('a/b'), fileName: 'x.mp4', createdAt: DateTime.utc(2026, 1, 1));
    final second = RecordingTask(ref: _room('b/c'), fileName: 'x.mp4', createdAt: DateTime.utc(2026, 1, 1));
    final third = RecordingTask(ref: _room('b/c'), fileName: 'x.mp4', createdAt: DateTime.utc(2026, 1, 1));

    expect(first.id == second.id, isFalse);
    expect(second.id, third.id);
  });

  test('test_recordingTask_idChangesWhenTheRecordingStartsAgain', () {
    final morning = RecordingTask(ref: _room('r1'), fileName: 'x.mp4', createdAt: DateTime.utc(2026, 10, 10, 8));
    final evening = RecordingTask(ref: _room('r1'), fileName: 'x.mp4', createdAt: DateTime.utc(2026, 10, 10, 20));

    expect(morning.id == evening.id, isFalse, reason: 'two recordings of one room are two files');
  });

  test('test_recordingTask_rejectsAFileNameThatEscapesTheDirectory', () {
    for (final name in <String>['../evil.mp4', 'a/b.mp4', r'a\b.mp4', '..', 'a\tb.mp4', '   ']) {
      expect(
        () => RecordingTask(ref: _room('r1'), fileName: name, clock: clock),
        throwsA(anyOf(isA<RecordingFailure>(), isA<ArgumentError>())),
        reason: '"$name" must not be joined onto the recording directory',
      );
    }
  });

  test('test_recordingTask_beginUsesTheInjectedClockNotWallTime', () {
    final task = _queued().begin();
    expect(task.beganAt, DateTime.utc(2026, 10, 10, 12));
    expect(task.elapsed, Duration.zero);
  });

  test('test_recordingTask_equalityFollowsTheStateItIsIn', () {
    final a = _queued().begin();
    final b = _queued().begin();

    expect(a, b, reason: 'same id and same state is the same task as far as a list is concerned');
    expect(a == a.stop(RecordingEndReason.userStopped), isFalse);
  });
}
