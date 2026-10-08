// Module: test/models/task_models_test.dart
// Purpose: Verify the task models from docs/contracts/platform-models.md section 13.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

void main() {
  group('TaskDescriptor', () {
    test('test_taskDescriptor_defaults_matchTheDocumentedValues', () {
      const descriptor = TaskDescriptor(id: 'source.refresh.1', type: 'source.refresh');

      expect(descriptor.priority, TaskPriority.normal);
      expect(descriptor.networkRequired, isFalse);
      expect(descriptor.backgroundAllowed, isTrue);
      expect(descriptor.deduplicationKey, isNull);
    });

    test('test_taskDescriptor_jsonRoundTrip_preservesFieldsAndToleratesUnknownKeys', () {
      const original = TaskDescriptor(
        id: 'ticket.refresh.1',
        type: 'ticket.refresh',
        priority: TaskPriority.critical,
        networkRequired: true,
        backgroundAllowed: false,
        deduplicationKey: 'ticket:media-1',
        metadata: <String, Object?>{'platform.cached_at': '2026-10-08T12:00:00.000Z'},
      );

      final decoded = TaskDescriptor.fromJson(<String, Object?>{...original.toJson(), 'newField': 1});

      expect(decoded.id, original.id);
      expect(decoded.type, original.type);
      expect(decoded.priority, TaskPriority.critical);
      expect(decoded.networkRequired, isTrue);
      expect(decoded.backgroundAllowed, isFalse);
      expect(decoded.deduplicationKey, 'ticket:media-1');
      expect(decoded.metadata['platform.cached_at'], '2026-10-08T12:00:00.000Z');
      expect(decoded, original);
    });

    test('test_taskDescriptor_toJson_omitsInheritedDefaults', () {
      const descriptor = TaskDescriptor(id: 'a', type: 'epg.update');

      expect(descriptor.toJson(), <String, Object?>{'id': 'a', 'type': 'epg.update', 'priority': 'normal'});
    });

    test('test_taskDescriptor_equalityIgnoresPriorityAndMetadata', () {
      // A re-prioritised task is still the same task, so a queue index keyed on it does not fork.
      const first = TaskDescriptor(id: 'a', type: 'x', priority: TaskPriority.low);
      const raised = TaskDescriptor(id: 'a', type: 'y', priority: TaskPriority.critical);

      expect(first, raised);
    });

    test('test_taskDescriptor_fromJson_unknownPriorityFallsBackToNormal', () {
      final decoded = TaskDescriptor.fromJson(<String, Object?>{'id': 'a', 'type': 'x', 'priority': 'urgent'});

      expect(decoded.priority, TaskPriority.normal);
    });

    test('test_taskDescriptor_fromJson_missingRequiredField_throwsFormatException', () {
      expect(() => TaskDescriptor.fromJson(<String, Object?>{'type': 'x'}), throwsFormatException);
    });
  });

  group('TaskStatus', () {
    test('test_taskStatus_isTerminal_cancelledCountsAsTerminalButNotFailed', () {
      // platform-models.md section 20 invariant 9: a cancellation is not an ordinary failure.
      bool terminal(TaskState value) => TaskStatus(taskId: 'a', state: value).isTerminal;

      expect(terminal(TaskState.completed), isTrue);
      expect(terminal(TaskState.cancelled), isTrue);
      expect(terminal(TaskState.failed), isTrue);
      expect(terminal(TaskState.pending), isFalse);
      expect(terminal(TaskState.paused), isFalse);
    });

    test('test_taskStatus_progress_absentMeansNoMeaningfulProgress', () {
      const status = TaskStatus(taskId: 'a', state: TaskState.running);
      expect(status.progress, isNull);
      expect(status.toJson().containsKey('progress'), isFalse);
    });

    test('test_taskStatus_jsonRoundTrip_keepsErrorAndTimestamps', () {
      final original = TaskStatus(
        taskId: 'a',
        state: TaskState.failed,
        progress: 0.5,
        startedAt: DateTime.utc(2026, 10, 8, 12),
        completedAt: DateTime.utc(2026, 10, 8, 12, 30),
        error: const PlatformErrorInfo(
          code: PlatformErrorCodes.taskFailed,
          message: 'boom',
          category: PlatformErrorCategory.task,
          retryable: true,
        ),
      );

      final decoded = TaskStatus.fromJson(original.toJson());

      expect(decoded.taskId, 'a');
      expect(decoded.state, TaskState.failed);
      expect(decoded.progress, 0.5);
      expect(decoded.startedAt, original.startedAt);
      expect(decoded.completedAt, original.completedAt);
      expect(decoded.error?.code, PlatformErrorCodes.taskFailed);
      expect(decoded.error?.retryable, isTrue);
      expect('$decoded', contains('failed'));
    });
  });

  group('TaskResult', () {
    test('test_taskResult_ok_keepsTheValueOutOfTheSerialisedForm', () {
      // A result value is whatever the task produced for its caller; storing it would put a repository
      // object or a file handle into the database.
      final result = TaskResult.ok(<String, Object?>{'count': 3});

      expect(result.success, isTrue);
      expect(result.value, <String, Object?>{'count': 3});
      expect(result.toJson().containsKey('value'), isFalse);
    });

    test('test_taskResult_failure_carriesTheErrorAndReportsItsCode', () {
      final result = TaskResult.failure(
        const PlatformErrorInfo(code: PlatformErrorCodes.taskCancelled, message: 'user stopped it'),
      );

      expect(result.success, isFalse);
      expect(result.value, isNull);
      expect(result.error?.code, PlatformErrorCodes.taskCancelled);
      expect('$result', contains('task.cancelled'));
    });

    test('test_taskResult_fromJson_readsBackSuccessAndError', () {
      final decoded = TaskResult.fromJson(<String, Object?>{
        'success': false,
        'error': <String, Object?>{'code': 'task.timeout', 'message': 'too slow'},
      });

      expect(decoded.success, isFalse);
      expect(decoded.error?.code, 'task.timeout');
    });
  });
}
