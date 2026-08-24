import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/log.dart';

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
}
