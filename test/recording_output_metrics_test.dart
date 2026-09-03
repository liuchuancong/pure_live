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

  test('finalization replaces only one provisional attempt in the session total', () {
    expect(
      RecordingOutputMetrics.reconcileFinalizedBytes(
        totalBytes: 200,
        sourceBytes: 100,
        finalizedBytes: 90,
      ),
      190,
    );
  });

  test('partial finalization retries preserve output committed by earlier passes', () {
    final afterFirst = RecordingOutputMetrics.reconcileFinalizedBytes(
      totalBytes: 200,
      sourceBytes: 100,
      finalizedBytes: 90,
    );
    final afterRetry = RecordingOutputMetrics.reconcileFinalizedBytes(
      totalBytes: afterFirst,
      sourceBytes: 100,
      finalizedBytes: 80,
    );

    expect(afterRetry, 170);
  });

  test('finalization recovers committed output when provisional bytes were not persisted', () {
    expect(
      RecordingOutputMetrics.reconcileFinalizedBytes(
        totalBytes: 0,
        sourceBytes: 100,
        finalizedBytes: 90,
      ),
      90,
    );
  });

  test('sums only the active recording prefix segment files', () async {
    final directory = await Directory.systemTemp.createTemp('pure-live-recording-metrics-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}${Platform.pathSeparator}attempt_000000.ts')
        .writeAsBytes(List<int>.filled(128, 1));
    await File('${directory.path}${Platform.pathSeparator}attempt_000001.TS')
        .writeAsBytes(List<int>.filled(256, 2));
    await File('${directory.path}${Platform.pathSeparator}older_000000.ts')
        .writeAsBytes(List<int>.filled(512, 3));
    await File('${directory.path}${Platform.pathSeparator}attempt_notes.txt')
        .writeAsString('ignored');

    final snapshot = await const RecordingOutputMetrics().measure(
      directoryPath: directory.path,
      filePrefix: 'attempt',
    );

    expect(snapshot.bytes, 384);
    expect(snapshot.segmentCount, 2);
    expect(snapshot.latestModified, isNotNull);
  });

  test('missing output directory produces an empty snapshot', () async {
    final snapshot = await const RecordingOutputMetrics().measure(
      directoryPath:
          '${Directory.systemTemp.path}${Platform.pathSeparator}pure-live-missing-output',
      filePrefix: 'attempt',
    );

    expect(snapshot.bytes, 0);
    expect(snapshot.segmentCount, 0);
  });

  test('finalized output reports the newest committed same-prefix MP4', () async {
    final directory = await Directory.systemTemp.createTemp('pure-live-finalized-metrics-');
    addTearDown(() => directory.delete(recursive: true));
    const prefix = '20260901_115810_719';
    final oldOutput = File('${directory.path}${Platform.pathSeparator}$prefix.mp4');
    final currentOutput = File('${directory.path}${Platform.pathSeparator}$prefix-1.mp4');
    await oldOutput.writeAsBytes(List<int>.filled(17, 1), flush: true);
    await oldOutput.setLastModified(DateTime(2026, 9, 1, 11, 58));
    await currentOutput.writeAsBytes(List<int>.filled(29, 2), flush: true);
    await currentOutput.setLastModified(DateTime(2026, 9, 1, 11, 59));
    await File('${directory.path}${Platform.pathSeparator}${prefix}_000000.ts')
        .writeAsBytes(List<int>.filled(101, 3));
    await File('${directory.path}${Platform.pathSeparator}$prefix.mp4.partial')
        .writeAsBytes(List<int>.filled(211, 4));

    final snapshot = await const RecordingOutputMetrics().measureFinalized(
      directoryPath: directory.path,
      filePrefix: prefix,
    );

    expect(snapshot.bytes, 29);
    expect(snapshot.segmentCount, 1);
    expect(snapshot.latestModified, DateTime(2026, 9, 1, 11, 59));
  });

  test('finalized output ignores other attempts and incomplete files', () async {
    final directory = await Directory.systemTemp.createTemp('pure-live-finalized-empty-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}${Platform.pathSeparator}other.mp4')
        .writeAsBytes(List<int>.filled(31, 1));
    await File('${directory.path}${Platform.pathSeparator}target.mp4.partial')
        .writeAsBytes(List<int>.filled(43, 2));

    final snapshot = await const RecordingOutputMetrics().measureFinalized(
      directoryPath: directory.path,
      filePrefix: 'target',
    );

    expect(snapshot.bytes, 0);
    expect(snapshot.segmentCount, 0);
  });

  test('incremental tracker follows the active segment without rescanning old output', () async {
    final directory = await Directory.systemTemp.createTemp('pure-live-recording-tracker-');
    addTearDown(() => directory.delete(recursive: true));
    final first = File('${directory.path}${Platform.pathSeparator}attempt_000000.ts');
    final second = File('${directory.path}${Platform.pathSeparator}attempt_000001.ts');
    final tracker = const RecordingOutputMetrics().track(
      directoryPath: directory.path,
      filePrefix: 'attempt',
    );

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

  test('incremental tracker discovers a non-zero first segment after recovery', () async {
    final directory = await Directory.systemTemp.createTemp('pure-live-recording-recovery-');
    addTearDown(() => directory.delete(recursive: true));
    final third = File('${directory.path}${Platform.pathSeparator}attempt_000003.ts');
    final fourth = File('${directory.path}${Platform.pathSeparator}attempt_000004.ts');
    final tracker = const RecordingOutputMetrics().track(
      directoryPath: directory.path,
      filePrefix: 'attempt',
    );

    await third.writeAsBytes(List<int>.filled(70, 1));
    var snapshot = await tracker.sample();
    expect(snapshot.bytes, 70);
    expect(snapshot.segmentCount, 1);

    await fourth.writeAsBytes(List<int>.filled(30, 2));
    snapshot = await tracker.sample();
    expect(snapshot.bytes, 100);
    expect(snapshot.segmentCount, 2);
  });
}
