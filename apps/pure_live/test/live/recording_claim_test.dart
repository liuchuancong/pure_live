// The cross-window claim: one process holds a task while it captures it.
//
// Without it, two windows can start the same room at once — two takes, two
// directories, and two processes writing the same task row. The claim is a file
// lock the operating system holds for the process's lifetime, so a crash
// releases it instead of leaving a stale "recording" marker behind.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/modules/live/recorder/engine/recording_claim.dart';

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('recording_claim'));
  tearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  test('a task id becomes a file name every platform accepts', () {
    expect(recordingClaimName('bili:123'), 'bili_123.claim');
    expect(recordingClaimName(''), 'task.claim');
    expect(recordingClaimName('bili:房间/1'), 'bili____1.claim');
  });

  test('one claim per task, and only one at a time', () async {
    final first = await acquireRecordingClaim(folder, 'bili:1');
    expect(first, isNotNull);
    // A second open of the same file is refused while the first handle lives —
    // which is what a second window would meet.
    expect(await acquireRecordingClaim(folder, 'bili:1'), isNull);
    // Another task is its own claim.
    final other = await acquireRecordingClaim(folder, 'bili:2');
    expect(other, isNotNull);

    await releaseRecordingClaim(first);
    final again = await acquireRecordingClaim(folder, 'bili:1');
    expect(again, isNotNull);
    // The re-taken claim must be let go too: on Windows an open handle
    // keeps the folder alive and the teardown's delete would fail.
    await releaseRecordingClaim(again);

    await releaseRecordingClaim(other);
    await releaseRecordingClaim(null);
  });
}
