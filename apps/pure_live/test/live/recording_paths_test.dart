// A throwaway check of the recorder's pure path helpers: the take directory a
// task names, and which settled tasks the current recording folder does not
// hold. Run with: flutter test test/live/recording_paths_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

RecordingTask _task(String? path, {RecordingTaskState state = RecordingTaskState.stopped, bool processing = false}) =>
    RecordingTask(
      id: 'bili:1',
      platform: 'bili',
      roomId: '1',
      roomTitle: '房间',
      state: state,
      startedAt: DateTime.utc(2026, 10, 31),
      filePath: path,
      postProcessing: processing,
    );

void main() {
  test('a task names the folder its take lives in', () {
    expect(_task(r'D:\录播\old\take_a\rec.combined.mp4').takeDirectory, r'D:\录播\old\take_a');
    expect(_task(r'D:\录播\old\take_a').takeDirectory, r'D:\录播\old\take_a');
    expect(_task('/data/old/take_a').takeDirectory, '/data/old/take_a');
    expect(_task(null).takeDirectory, '');
    // The one file a row ever names is the joined MP4, so the rule is that
    // extension — not “does the tail carry a dot”. A take folder named after a
    // room with a number in it is still a folder.
    expect(_task(r'D:\录播\old\3.5 万粉纪念_20261031').takeDirectory, r'D:\录播\old\3.5 万粉纪念_20261031');
    expect(_task('/data/old/3.5_x/take.MP4').takeDirectory, '/data/old/3.5_x');
  });

  test('stranded tasks are the settled rows outside the current folder', () {
    const root = r'D:\录播\PureLiveRecords';
    final tasks = [
      _task(r'D:\录播\old\take_a', state: RecordingTaskState.recording),
      _task(r'D:\录播\old\take_b', processing: true),
      _task(r'D:\其他\PureLiveRecords\take_c'),
      _task(r'D:\录播\PureLiveRecords\take_d'),
      _task(r'D:\录播\PureLiveRecords'),
      _task(''),
      _task(null),
    ];
    expect(strandedTasksOf(tasks, root), [tasks[2]]);
    // A trailing separator on the root is the same folder.
    expect(strandedTasksOf(tasks, r'D:\录播\PureLiveRecords\'), [tasks[2]]);
  });

  test('a path written on another separator style is not this folder', () {
    expect(strandedTasksOf([_task(r'D:\x\take')], '/data/records').length, 1);
    expect(strandedTasksOf([_task('/data/records/take')], '/data/records'), isEmpty);
    expect(strandedTasksOf([_task('/other/take')], '/data/records').length, 1);
  });
}
