import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_status.dart';

void main() {
  test('record task schema survives numeric drift and prefers enum names', () {
    final task = LiveRecordTask.fromJson(<String, dynamic>{
      'taskId': 'douyin_1',
      'roomId': 1,
      'platform': 'DOUYIN',
      'title': 42,
      'liveStatus': 999,
      'liveStatusName': 'replay',
      'status': -10,
      'statusName': 'waitingLive',
      'recordedSeconds': '12',
      'recordSpeed': '1.25',
      'autoReconnect': 'true',
      'createTime': '2026-08-27T08:00:00.000',
    });

    expect(task.platform, 'douyin');
    expect(task.roomId, '1');
    expect(task.title, '42');
    expect(task.liveStatus, LiveStatus.replay);
    expect(task.status, RecordStatus.waitingLive);
    expect(task.recordedSeconds, 12);
    expect(task.recordSpeed, 1.25);
    expect(task.autoReconnect, isTrue);
  });

  test('missing or corrupt enums use safe stopped and unknown fallbacks', () {
    final missing = LiveRecordTask.fromJson(<String, dynamic>{'roomId': '2', 'platform': 'huya'});
    final corrupt = LiveRecordTask.fromJson(<String, dynamic>{
      'roomId': '3',
      'platform': 'bilibili',
      'liveStatus': 'not-an-index',
      'status': 'not-an-index',
    });

    expect(missing.liveStatus, LiveStatus.unknown);
    expect(missing.status, RecordStatus.stopped);
    expect(corrupt.liveStatus, LiveStatus.unknown);
    expect(corrupt.status, RecordStatus.stopped);
  });

  test('new recording file prefixes are collision-resistant within one second', () {
    final first = LiveRecordTask.fromJson(<String, dynamic>{
      'roomId': '1',
      'platform': 'cc',
      'createTime': '2026-08-27T08:00:00.001',
    });
    final second = LiveRecordTask.fromJson(<String, dynamic>{
      'roomId': '1',
      'platform': 'cc',
      'createTime': '2026-08-27T08:00:00.002',
    });

    expect(first.recordingFilePrefix, isNot(second.recordingFilePrefix));
  });

  test('signed stream URLs are never persisted or restored', () {
    final task = LiveRecordTask.fromJson(<String, dynamic>{
      'roomId': '1',
      'platform': 'douyin',
      'currentUrl': 'https://cdn.test/live.flv?token=secret',
    });

    expect(task.currentUrl, isNull);
    task.currentUrl = 'https://cdn.test/live.flv?token=runtime';
    expect(task.toJson(), isNot(contains('currentUrl')));
  });
}
