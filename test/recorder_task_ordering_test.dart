import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/recorder_task_ordering.dart';

void main() {
  group('RecorderTaskOrdering.forDisplay', () {
    test('aggregate view groups actionable states, then newest first', () {
      final stoppedNew = _task('stopped-new', RecordStatus.stopped, '2026-09-04T21:00:00');
      final runningOld = _task('running-old', RecordStatus.running, '2026-09-04T19:00:00');
      final stoppedOld = _task('stopped-old', RecordStatus.stopped, '2026-09-04T18:00:00');

      final result = RecorderTaskOrdering.forDisplay(<LiveRecordTask>[
        stoppedOld,
        stoppedNew,
        runningOld,
      ], groupByStatus: true);

      expect(result.map((task) => task.taskId), <String>['running-old', 'stopped-new', 'stopped-old']);
    });

    test('status-filtered view is newest first', () {
      final result = RecorderTaskOrdering.forDisplay(<LiveRecordTask>[
        _task('old', RecordStatus.stopped, '2026-09-04T18:00:00'),
        _task('new', RecordStatus.stopped, '2026-09-04T21:00:00'),
      ], groupByStatus: false);

      expect(result.map((task) => task.taskId), <String>['new', 'old']);
    });

    test('running sorts before queued regardless of time', () {
      final running = _task('running', RecordStatus.running, '2026-09-04T01:00:00');
      final queued = _task('queued', RecordStatus.queued, '2026-09-04T23:00:00');

      final result = RecorderTaskOrdering.forDisplay(<LiveRecordTask>[queued, running]);

      expect(result.map((task) => task.taskId), <String>['running', 'queued']);
    });

    test('same status and same time falls back to taskId for stable order', () {
      final a = _task('aaa', RecordStatus.stopped, '2026-09-04T21:00:00');
      final b = _task('bbb', RecordStatus.stopped, '2026-09-04T21:00:00');

      final result = RecorderTaskOrdering.forDisplay(<LiveRecordTask>[a, b]);

      expect(result.map((task) => task.taskId), <String>['bbb', 'aaa']);
    });

    test('does not mutate the input list', () {
      final input = <LiveRecordTask>[
        _task('stopped', RecordStatus.stopped, '2026-09-04T18:00:00'),
        _task('running', RecordStatus.running, '2026-09-04T19:00:00'),
      ];
      final snapshot = input.map((t) => t.taskId).toList();

      RecorderTaskOrdering.forDisplay(input);

      expect(input.map((t) => t.taskId), snapshot);
    });

    test('empty input yields empty output', () {
      final result = RecorderTaskOrdering.forDisplay(<LiveRecordTask>[]);
      expect(result, isEmpty);
    });
  });
}

LiveRecordTask _task(String taskId, RecordStatus status, String createTime) =>
    LiveRecordTask.fromJson(<String, dynamic>{
      'taskId': taskId,
      'roomId': taskId,
      'platform': 'bilibili',
      'statusName': status.name,
      'createTime': createTime,
    });
