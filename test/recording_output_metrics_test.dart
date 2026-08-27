import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/recording_output_metrics.dart';

void main() {
  test('attempt progress remains monotonic across signed URL refreshes', () {
    const firstRetry = RecordingAttemptProgress(baseBytes: 8 * 1024 * 1024, baseSeconds: 7);

    expect(firstRetry.totalBytes(2 * 1024 * 1024), 10 * 1024 * 1024);
    expect(firstRetry.totalSeconds(3), 10);
    expect(firstRetry.totalBytes(-1), 8 * 1024 * 1024);
  });

  test('sums only the active recording prefix segment files', () async {
    final directory = await Directory.systemTemp.createTemp('pure-live-recording-metrics-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}${Platform.pathSeparator}attempt_000000.ts').writeAsBytes(List<int>.filled(128, 1));
    await File('${directory.path}${Platform.pathSeparator}attempt_000001.TS').writeAsBytes(List<int>.filled(256, 2));
    await File('${directory.path}${Platform.pathSeparator}older_000000.ts').writeAsBytes(List<int>.filled(512, 3));
    await File('${directory.path}${Platform.pathSeparator}attempt_notes.txt').writeAsString('ignored');

    final snapshot = await const RecordingOutputMetrics().measure(directoryPath: directory.path, filePrefix: 'attempt');

    expect(snapshot.bytes, 384);
    expect(snapshot.segmentCount, 2);
    expect(snapshot.latestModified, isNotNull);
  });

  test('missing output directory produces an empty snapshot', () async {
    final snapshot = await const RecordingOutputMetrics().measure(
      directoryPath: '${Directory.systemTemp.path}${Platform.pathSeparator}pure-live-missing-output',
      filePrefix: 'attempt',
    );

    expect(snapshot.bytes, 0);
    expect(snapshot.segmentCount, 0);
  });

  test('incremental tracker follows the active segment without rescanning old output', () async {
    final directory = await Directory.systemTemp.createTemp('pure-live-recording-tracker-');
    addTearDown(() => directory.delete(recursive: true));
    final first = File('${directory.path}${Platform.pathSeparator}attempt_000000.ts');
    final second = File('${directory.path}${Platform.pathSeparator}attempt_000001.ts');
    final tracker = const RecordingOutputMetrics().track(directoryPath: directory.path, filePrefix: 'attempt');

    await first.writeAsBytes(List<int>.filled(100, 1));
    expect((await tracker.sample()).bytes, 100);
    await first.writeAsBytes(List<int>.filled(150, 1));
    expect((await tracker.sample()).bytes, 150);

    await second.writeAsBytes(List<int>.filled(40, 2));
    var snapshot = await tracker.sample();
    expect(snapshot.bytes, 190);
    expect(snapshot.segmentCount, 2);

    await second.writeAsBytes(List<int>.filled(60, 2));
    snapshot = await tracker.sample();
    expect(snapshot.bytes, 210);
    expect(snapshot.segmentCount, 2);
  });
}
