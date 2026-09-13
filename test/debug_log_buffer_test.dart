import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/get/get.dart';

void main() {
  tearDown(Log.clearDebugLogs);

  test('debug log buffer remains bounded and keeps the newest entries', () {
    Log.clearDebugLogs();

    for (var index = 0; index < Log.maxDebugEntries + 25; index++) {
      Log.addDebugLog('entry-$index');
    }

    expect(Log.allLogs, hasLength(Log.maxDebugEntries));
    expect(Log.allLogs.first.content, 'entry-25');
    expect(Log.allLogs.last.content, 'entry-${Log.maxDebugEntries + 24}');
  });

  test('exposed log snapshot is immutable', () {
    Log.addDebugLog('one');

    expect(() => Log.allLogs.clear(), throwsUnsupportedError);
  });

  test('logging before the settings service exists stays diagnostic-only', () {
    Get.reset();

    expect(() => Log.i('early-startup-log'), returnsNormally);
    expect(Log.allLogs.last.content, 'early-startup-log');
  });

  test('release buffering is enabled only for an active local logging session', () {
    expect(Log.shouldBufferRuntimeLog(releaseMode: true, localLoggingEnabled: false), isFalse);
    expect(Log.shouldBufferRuntimeLog(releaseMode: true, localLoggingEnabled: true), isTrue);
    expect(Log.shouldBufferRuntimeLog(releaseMode: false, localLoggingEnabled: false), isTrue);
  });
}
