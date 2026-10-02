// Opt-in synthetic native regression of the production clock-v1 path.
// Old single/legacy controls stay frozen; production single isolates the added
// cost of segmentation from a deliberate change to timestamp preservation.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';
import 'package:pure_live/domains/recorder/data/services/recording_segment_clock.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_flv_input_relay.dart';

import 'frame_hash_timeline.dart';
import 'recording_clock_probe_support.dart';

void main() {
  for (final fixture in ['av_cfr', 'av_vfr', 'video_only', 'audio_only']) {
    test(
      'native segment clock preserves $fixture content and cadence',
      () async {
        final base = Platform.environment['PURELIVE_CLOCK_PROBE_ROOT']!;
        final input = File(p.join(base, 'fixtures', '$fixture.flv'));
        expect(await input.exists(), true);
        final output = await Directory(p.join(base, 'runs', '$fixture-${DateTime.now().microsecondsSinceEpoch}'))
            .create(recursive: true);
        Hive.init(p.join(output.path, 'settings'));
        await HivePrefUtil.init();
        Get.testMode = true;
        Get.put(LogController());
        final manager = FFmpegManager.to;
        final report = <String, Object?>{
          'fixture': fixture,
          'scope': 'synthetic-Windows-native-not-device-acceptance',
          'contract': 'failed',
        };
        final results = <String, Map<String, FrameHashTimeline>>{};
        final media = [if (fixture != 'audio_only') 'video', if (fixture != 'video_only') 'audio'];
        final ownedIds = <String>[];
        try {
          results['source'] = await decodeClockMedia(input, output, 'source', media);
          final variants = <String, Object?>{};
          report['variants'] = variants;
          for (final variant in ['single', 'legacy', 'productionSingle', 'candidate']) {
            report['stage'] = '$variant-record';
            final dir = await Directory(p.join(output.path, variant)).create();
            final task = LiveRecordTask.fromRoom(LiveRoom(platform: 'clockfixture', roomId: '$fixture-$variant'))
              ..outputDir = dir.path
              ..recordedSeconds = 26;
            ownedIds.add(task.taskId);
            final args = FFmpegCommandBuilder.buildRecordArguments(
              url: input.absolute.path,
              outputDir: dir.path,
              segmentTime: variant == 'single' || variant == 'productionSingle' ? 86400 : 10,
              preferBestStream: true,
              rwTimeout: 15,
              threadQueueSize: 512,
              filePrefix: task.recordingFilePrefix,
            ).toList();
            final journal = File(p.join(dir.path, RecordingSegmentClock.journalName(task.recordingFilePrefix)));
            if (variant == 'single' || variant == 'legacy') {
              // Preserve the prior muxing contract; changing the production
              // builder must not silently turn the regression baseline green.
              args[args.indexOf('-segment_format_options') + 1] = 'flush_packets=1';
              args[args.length - 1] = args.last.replaceFirst('.clock-v1.ts', '.ts');
              for (final option in ['-segment_list', '-segment_list_type']) {
                final index = args.indexOf(option);
                expect(index, greaterThanOrEqualTo(0));
                args.removeRange(index, index + 2);
              }
            }
            // A finite local fixture ends normally. The live service deliberately
            // reports an unsolicited EOF as a recoverable error even at code 0;
            // that network recovery contract is separate from this muxing test.
            final record = await runClockNative(manager, task.taskId, args);
            final segments =
                (await dir.list(followLinks: false).toList())
                    .whereType<File>()
                    .where((f) => p.extension(f.path) == '.ts')
                    .toList()
                  ..sort((a, b) => a.path.compareTo(b.path));
            expect(segments.length, variant == 'single' || variant == 'productionSingle' ? 1 : greaterThanOrEqualTo(3));
            final target = File(p.join(dir.path, '${task.recordingFilePrefix}.mp4'));
            final evidence = <String, Object?>{'segments': segments.length, 'nativeRecord': record, 'arguments': args};
            variants[variant] = evidence;
            report['stage'] = '$variant-merge';
            final mergeEvents = <Map<String, Object?>>[];
            final subscription = manager.stream.listen((event) {
              if (event.taskId == 'merge_${task.taskId}_${task.recordingFilePrefix}' &&
                  [FFmpegEventType.complete, FFmpegEventType.error].contains(event.type)) {
                mergeEvents.add({'type': event.type.name, 'code': event.data['code']});
              }
            });
            try {
              expect(await VideoProcessorService.to.convertToMp4(task: task, deleteSourceTs: false), true);
              expect(mergeEvents, hasLength(1));
              expect(mergeEvents.single, {'type': 'complete', 'code': 0});
              evidence['nativeMerge'] = mergeEvents.single;
              evidence['productionFinalizer'] = true;
              if (variant == 'candidate') evidence['journal'] = await journal.readAsString();
            } finally {
              await subscription.cancel();
            }
            expect(await target.length(), greaterThan(0));
            report['stage'] = '$variant-decode';
            results[variant] = await decodeClockMedia(target, output, variant, media);
          }
          final comparisons = <String, Object?>{};
          report['stage'] = 'comparison-gates';
          report['comparisons'] = comparisons;
          for (final kind in media) {
            final reference = results['single']![kind]!;
            comparisons[kind] = {
              'sourceToSingle': results['source']![kind]!.compare(reference),
              'sourceToCandidate': results['source']![kind]!.compare(results['candidate']![kind]!),
              'singleToLegacy': reference.compare(results['legacy']![kind]!),
              'singleToCandidate': reference.compare(results['candidate']![kind]!),
              'sourceToProductionSingle': results['source']![kind]!.compare(results['productionSingle']![kind]!),
              'productionSingleToCandidate': results['productionSingle']![kind]!.compare(results['candidate']![kind]!),
            };
          }
          // Keep all variants' observations before any clock verdict fails.
          for (final kind in media) {
            final checks = comparisons[kind] as Map;
            for (final comparison in checks.values.cast<Map>()) {
              expect(comparison['orderedContentEqual'], true, reason: '$fixture/$kind');
            }
            final candidate = checks['productionSingleToCandidate'] as Map;
            expect(
              candidate['offsetSpreadSeconds'] as double,
              lessThanOrEqualTo(kind == 'video' ? 2 / 90000 : 2 / 44100),
              reason: '$fixture/$kind candidate vs same-profile single',
            );
          }
          if (fixture == 'av_cfr') {
            final baseline = (comparisons['video'] as Map)['singleToLegacy'] as Map;
            expect(
              baseline['offsetSpreadSeconds'] as double,
              greaterThan(0.001),
              reason: 'synthetic baseline must actually reproduce drift',
            );
          }
          report['contract'] = 'passed';
        } catch (error) {
          report['error'] = error.toString();
          rethrow;
        } finally {
          for (final id in ownedIds) {
            if (manager.isRunning(id)) await manager.stop(id).timeout(const Duration(seconds: 30));
          }
          await File(p.join(output.path, 'summary.json'))
              .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
          // ignore: avoid_print
          print(jsonEncode(report));
          Get.reset();
          await Hive.close();
        }
      },
      skip: Platform.environment['PURELIVE_CLOCK_PROBE'] != '1',
      timeout: const Timeout(Duration(minutes: 6)),
    );
  }
  test(
    'production clock survives manual FLV drain across multiple segments',
    () => HttpOverrides.runWithHttpOverrides(_manualStopClock, _DirectClockHttp()),
    skip: Platform.environment['PURELIVE_CLOCK_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _manualStopClock() async {
  final base = Platform.environment['PURELIVE_CLOCK_PROBE_ROOT']!;
  final bytes = await File(p.join(base, 'fixtures', 'av_cfr.flv')).readAsBytes();
  final root = await Directory(p.join(base, 'runs', 'manual-stop-${DateTime.now().microsecondsSinceEpoch}'))
      .create(recursive: true);
  Hive.init(p.join(root.path, 'settings'));
  await HivePrefUtil.init();
  Get.testMode = true;
  Get.put(LogController());
  final manager = FFmpegManager.to;
  final directory = await Directory(p.join(root.path, 'recording')).create();
  final task = LiveRecordTask.fromRoom(LiveRoom(platform: 'clockfixture', roomId: 'manual-stop'))
    ..outputDir = directory.path
    ..recordedSeconds = 26;
  final report = <String, Object?>{'fixture': 'manual-stop', 'contract': 'failed', 'stage': 'start'};
  final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final release = Completer<void>();
  final serverSubscription = origin.listen((request) async {
    try {
      request.response.bufferOutput = false;
      request.response.add(bytes);
      await request.response.flush();
      // No upstream EOF: the user stop must finish the actual production relay.
      await release.future;
      await request.response.close();
    } on Object {
      /* Owned reader closed during stop. */
    }
  });
  final diagnostics = FlvRelayDiagnostics(maxCaptureBytes: 4 * 1024 * 1024);
  final terminal = <String, Object?>{};
  final events = manager.stream.listen((event) {
    if (event.taskId == task.taskId && [FFmpegEventType.complete, FFmpegEventType.error].contains(event.type)) {
      terminal.addAll({
        'type': event.type.name,
        for (final key in [
          'code',
          'manualStop',
          'forcedCancel',
          'inputDrained',
          'inputIntegrityError',
          'inputCoverageIncomplete',
        ])
          if (event.data.containsKey(key)) key: event.data[key],
      });
    }
  });
  Future<void>? execution;
  Object? executionError;
  try {
    final args = FFmpegCommandBuilder.buildRecordArguments(
      url: 'http://127.0.0.1:${origin.port}/fixture.flv',
      outputDir: directory.path,
      segmentTime: 10,
      preferBestStream: true,
      rwTimeout: 15,
      threadQueueSize: 512,
      filePrefix: task.recordingFilePrefix,
    );
    report['arguments'] = args;
    execution = manager
        .start(taskId: task.taskId, arguments: args, liveRecording: true, flvDiagnostics: diagnostics)
        .catchError((Object error) {
          executionError = error;
        });
    final waiting = Stopwatch()..start();
    while (diagnostics.submittedBytes != bytes.length || manager.getSession(task.taskId)?.mediaStarted != true) {
      if (executionError != null) throw StateError('Manual clock start failed: $executionError');
      if (waiting.elapsed > const Duration(seconds: 25)) {
        throw TimeoutException('Manual clock fixture was not consumed');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    report['stage'] = 'manual-stop';
    final stopping = Stopwatch()..start();
    await manager.stop(task.taskId).timeout(const Duration(seconds: 15));
    await execution.timeout(const Duration(seconds: 15));
    if (executionError != null) throw StateError('Manual clock execution failed: $executionError');
    await Future<void>.delayed(Duration.zero);
    report['terminal'] = terminal;
    report['stopMilliseconds'] = stopping.elapsedMilliseconds;
    expect(terminal['type'], 'complete');
    expect(terminal['code'], 0);
    expect(terminal['manualStop'], true);
    expect(terminal['forcedCancel'], false);
    expect(terminal['inputDrained'], true);
    expect(terminal['inputIntegrityError'], false);
    expect(diagnostics.truncated, false);
    expect(diagnostics.capturedBytes, bytes);
    final captured = await File(p.join(root.path, 'submitted.flv')).writeAsBytes(diagnostics.capturedBytes);
    final segments = await directory
        .list()
        .where((file) => file is File && file.path.endsWith('.clock-v1.ts'))
        .toList();
    expect(segments.length, greaterThanOrEqualTo(3));
    report['segments'] = segments.length;
    report['journal'] = await File(p.join(directory.path, RecordingSegmentClock.journalName(task.recordingFilePrefix)))
        .readAsString();
    report['stage'] = 'production-merge';
    expect(await VideoProcessorService.to.convertToMp4(task: task, deleteSourceTs: false), true);
    final actual = File(p.join(directory.path, '${task.recordingFilePrefix}.mp4'));
    final referenceDirectory = await Directory(p.join(root.path, 'single')).create();
    final reference = LiveRecordTask.fromRoom(LiveRoom(platform: 'clockfixture', roomId: 'manual-reference'))
      ..outputDir = referenceDirectory.path
      ..recordedSeconds = 26;
    report['referenceNative'] = await runClockNative(
      manager,
      reference.taskId,
      FFmpegCommandBuilder.buildRecordArguments(
        url: captured.path,
        outputDir: referenceDirectory.path,
        segmentTime: 86400,
        preferBestStream: true,
        rwTimeout: 15,
        threadQueueSize: 512,
        filePrefix: reference.recordingFilePrefix,
      ),
    );
    expect(await VideoProcessorService.to.convertToMp4(task: reference, deleteSourceTs: false), true);
    final single = await decodeClockMedia(
      File(p.join(referenceDirectory.path, '${reference.recordingFilePrefix}.mp4')),
      root,
      'single',
      ['video', 'audio'],
    );
    final candidate = await decodeClockMedia(actual, root, 'candidate', ['video', 'audio']);
    final source = await decodeClockMedia(captured, root, 'source', ['video', 'audio']);
    final comparisons = <String, Object?>{};
    report['comparisons'] = comparisons;
    report['stage'] = 'comparison-gates';
    for (final kind in ['video', 'audio']) {
      final fromSource = source[kind]!.compare(single[kind]!);
      final compared = single[kind]!.compare(candidate[kind]!);
      comparisons[kind] = {'sourceToSingle': fromSource, 'singleToCandidate': compared};
      expect(fromSource['orderedContentEqual'], true);
      expect(compared['orderedContentEqual'], true);
      expect(compared['offsetSpreadSeconds'] as double, lessThanOrEqualTo(kind == 'video' ? 2 / 90000 : 2 / 44100));
    }
    report['contract'] = 'passed';
  } catch (error) {
    report['error'] = error.toString();
    rethrow;
  } finally {
    if (!release.isCompleted) release.complete();
    for (final id in [task.taskId, 'clockfixture_manual-reference']) {
      if (manager.isRunning(id)) await manager.stop(id).timeout(const Duration(seconds: 30));
    }
    await origin.close(force: true);
    await serverSubscription.cancel();
    await events.cancel();
    await execution?.timeout(const Duration(seconds: 30));
    await File(p.join(root.path, 'summary.json')).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    // ignore: avoid_print
    print(jsonEncode(report));
    Get.reset();
    await Hive.close();
  }
}

class _DirectClockHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context)..findProxy = (_) => 'DIRECT';
}
