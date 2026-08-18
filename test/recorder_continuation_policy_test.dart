import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/services/recorder_continuation_policy.dart';

void main() {
  test('unexpected stream exit resumes monitoring when auto reconnect is enabled', () {
    expect(RecorderContinuationPolicy.shouldMonitorAfterExit(manuallyStopped: false, autoReconnect: true), isTrue);
    expect(RecorderContinuationPolicy.shouldMonitorAfterExit(manuallyStopped: true, autoReconnect: true), isFalse);
    expect(RecorderContinuationPolicy.shouldMonitorAfterExit(manuallyStopped: false, autoReconnect: false), isFalse);
  });

  test('a restarted recording gets a fresh timestamp and zeroed progress', () {
    final task = LiveRecordTask.fromRoom(LiveRoom(roomId: '1', platform: 'bilibili', title: 'title', nick: 'nick'))
      ..recordedSeconds = 120
      ..fileSize = 1024
      ..lastUpdate = DateTime(2026, 1, 1);
    final nextStart = DateTime(2026, 8, 19, 4, 30);

    task.beginNewRecording(now: nextStart);

    expect(task.createTime, nextStart);
    expect(task.recordedSeconds, 0);
    expect(task.fileSize, 0);
    expect(task.lastUpdate, isNull);
  });
}
