import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/services/recorder_continuation_policy.dart';

void main() {
  test('unexpected stream exit resumes monitoring when auto reconnect is enabled', () {
    expect(
      RecorderContinuationPolicy.shouldMonitorAfterExit(
        manuallyStopped: false,
        autoReconnect: true,
      ),
      isTrue,
    );
    expect(
      RecorderContinuationPolicy.shouldMonitorAfterExit(manuallyStopped: true, autoReconnect: true),
      isFalse,
    );
    expect(
      RecorderContinuationPolicy.shouldMonitorAfterExit(
        manuallyStopped: false,
        autoReconnect: false,
      ),
      isFalse,
    );
  });

  test('expired CDN and I/O failures resolve a fresh stream before retrying', () {
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(errorCode: -5, rawLogs: 'Input/output error'),
      isTrue,
    );
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(
        errorCode: 1,
        rawLogs: 'HTTP error 403 Forbidden',
      ),
      isTrue,
    );
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(
        errorCode: 1,
        rawLogs: 'HTTP error 404 Not Found',
      ),
      isTrue,
    );
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(
        errorCode: 1,
        rawLogs: 'Error opening input https://cdn.example/live: Invalid argument',
      ),
      isTrue,
    );
  });

  test('local path and malformed output failures do not loop', () {
    expect(RecorderContinuationPolicy.shouldRetryFailure(errorCode: -2, rawLogs: ''), isFalse);
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(errorCode: 1, rawLogs: 'Permission denied'),
      isFalse,
    );
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(
        errorCode: 1,
        rawLogs: 'Error opening output file',
      ),
      isFalse,
    );
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(
        errorCode: 1,
        rawLogs: 'Unrecognized option reconnect',
      ),
      isFalse,
    );
    expect(
      RecorderContinuationPolicy.shouldRetryFailure(errorCode: 1, rawLogs: 'Protocol not found'),
      isFalse,
    );
  });

  test('polling backoff is bounded and can be disabled', () {
    expect(
      RecorderContinuationPolicy.pollingDelay(
        failureCount: 3,
        baseSeconds: 10,
        maximumSeconds: 60,
        enableBackoff: true,
      ),
      const Duration(seconds: 60),
    );
    expect(
      RecorderContinuationPolicy.pollingDelay(
        failureCount: 20,
        baseSeconds: 30,
        maximumSeconds: 300,
        enableBackoff: true,
      ),
      const Duration(seconds: 300),
    );
    expect(
      RecorderContinuationPolicy.pollingDelay(
        failureCount: 8,
        baseSeconds: 30,
        maximumSeconds: 300,
        enableBackoff: false,
      ),
      const Duration(seconds: 30),
    );
  });

  test('unexpected live EOF reconnects quickly without ignoring configured failures', () {
    expect(
      RecorderContinuationPolicy.reconnectDelay(
        failureCount: 0,
        configuredBaseSeconds: 120,
        configuredMaximumSeconds: 600,
        enableBackoff: true,
        unexpectedEof: true,
      ),
      const Duration(seconds: 2),
    );
    expect(
      RecorderContinuationPolicy.reconnectDelay(
        failureCount: 5,
        configuredBaseSeconds: 120,
        configuredMaximumSeconds: 600,
        enableBackoff: true,
        unexpectedEof: true,
      ),
      const Duration(seconds: 15),
    );
    expect(
      RecorderContinuationPolicy.reconnectDelay(
        failureCount: 0,
        configuredBaseSeconds: 120,
        configuredMaximumSeconds: 600,
        enableBackoff: true,
        unexpectedEof: false,
      ),
      const Duration(seconds: 120),
    );
  });

  test('unexpected live EOF never falls into the slow offline polling state', () {
    expect(
      RecorderContinuationPolicy.shouldEnterPollingAfterRetryLimit(
        retryCount: 1000,
        maximumRetries: 3,
        unexpectedEof: true,
      ),
      isFalse,
    );
    expect(
      RecorderContinuationPolicy.shouldEnterPollingAfterRetryLimit(
        retryCount: 3,
        maximumRetries: 3,
        unexpectedEof: false,
      ),
      isTrue,
    );
  });

  test('signed recorder lease prefetches before rotation and catches up after resume', () {
    final now = DateTime.utc(2026, 8, 30, 7);
    final refreshAt = now.add(const Duration(seconds: 100));

    expect(
      RecorderContinuationPolicy.leasePrefetchDelay(now: now, refreshAt: refreshAt),
      const Duration(seconds: 95),
    );
    expect(
      RecorderContinuationPolicy.leaseRotationDelay(now: now, refreshAt: refreshAt),
      const Duration(seconds: 100),
    );
    expect(
      RecorderContinuationPolicy.leasePrefetchDelay(
        now: refreshAt.add(const Duration(seconds: 1)),
        refreshAt: refreshAt,
      ),
      Duration.zero,
    );
    expect(
      RecorderContinuationPolicy.leaseRotationDelay(
        now: refreshAt.add(const Duration(seconds: 1)),
        refreshAt: refreshAt,
      ),
      Duration.zero,
    );
  });

  test('a restarted recording gets a fresh timestamp and zeroed progress', () {
    final task =
        LiveRecordTask.fromRoom(
            LiveRoom(roomId: '1', platform: 'bilibili', title: 'title', nick: 'nick'),
          )
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
