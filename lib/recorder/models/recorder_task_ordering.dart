import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';

/// Stable ordering for the recording centre.
///
/// The aggregate view keeps actionable states first; tasks with the same
/// state, and every status-filtered view, show the newest session first. This
/// prevents a newly stopped recording from being appended below an arbitrarily
/// long history where neither the user nor runtime verification can see it.
class RecorderTaskOrdering {
  const RecorderTaskOrdering._();

  static int _statusPriority(RecordStatus status) {
    switch (status) {
      case RecordStatus.running:
        return 0;
      case RecordStatus.reconnecting:
        return 1;
      case RecordStatus.preparing:
        return 2;
      case RecordStatus.waitingLive:
        return 3;
      case RecordStatus.queued:
        return 4;
      case RecordStatus.processing:
        return 5;
      case RecordStatus.completed:
        return 6;
      case RecordStatus.stopped:
        return 7;
      case RecordStatus.failed:
        return 8;
    }
  }

  static List<LiveRecordTask> forDisplay(Iterable<LiveRecordTask> tasks, {bool groupByStatus = true}) {
    final result = tasks.toList();
    result.sort((left, right) {
      if (groupByStatus) {
        final prioA = _statusPriority(left.status);
        final prioB = _statusPriority(right.status);
        if (prioA != prioB) return prioA.compareTo(prioB);
      }

      final time = right.createTime.compareTo(left.createTime);
      if (time != 0) return time;

      return right.taskId.compareTo(left.taskId);
    });
    return result;
  }
}
