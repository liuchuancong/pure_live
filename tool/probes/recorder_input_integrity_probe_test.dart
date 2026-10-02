// Opt-in native packet-damage propagation and source-retention probe.
// Uses a fixed local TS fixture; never opens a phone or external stream.
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
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

void main() {
  test(
    'native capture propagates packet damage and preserves the exact source attempt',
    () async {
      final fixture = Platform.environment['PURELIVE_HLS_STOP_FIXTURE']!;
      final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!;
      final decoder = Platform.environment['PURELIVE_FFMPEG']!;
      final original = await File(p.join(fixture, 'segment000.ts')).readAsBytes();
      expect(original.length, greaterThan(188 * 10));
      expect(original.length % 188, 0);
      final root = await Directory(p.join(base, 'input-integrity-${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final settings = await Directory.systemTemp.createTemp('purelive-input-integrity-settings-');
      Hive.init(settings.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      final results = <Map<String, Object?>>[];
      try {
        for (final damaged in [false, true]) {
          final directory = await Directory(p.join(root.path, damaged ? 'damaged' : 'healthy')).create();
          final input = File(p.join(root.path, damaged ? 'truncated.ts' : 'intact.ts'));
          await input.writeAsBytes(damaged ? original.sublist(0, original.length - 97) : original, flush: true);
          final task = LiveRecordTask.fromRoom(LiveRoom(platform: 'picarto', roomId: 'fixture_$damaged'))
            ..outputDir = directory.path;
          final native = FFmpegManager.to;
          final terminal = Completer<FFmpegEvent>();
          final subscription = native.stream.listen((event) {
            if (event.taskId == task.taskId &&
                (event.type == FFmpegEventType.complete || event.type == FFmpegEventType.error) &&
                !terminal.isCompleted) {
              terminal.complete(event);
            }
          });
          final execution = native.start(
            taskId: task.taskId,
            liveRecording: true,
            arguments: FFmpegCommandBuilder.buildRecordArguments(
              url: input.path,
              outputDir: directory.path,
              filePrefix: task.recordingFilePrefix,
              segmentTime: 10,
              preferBestStream: true,
              rwTimeout: 5,
              threadQueueSize: 128,
            ),
          );
          try {
            await execution.timeout(const Duration(seconds: 30));
            final event = await terminal.future.timeout(const Duration(seconds: 5));
            await File(p.join(directory.path, 'terminal.json'))
                .writeAsString(const JsonEncoder.withIndent('  ').convert(event.data));
            expect(event.data['manualStop'], false);
            expect(event.data['stopRequested'], false);
            expect(event.data['stopElapsedMs'], isNull);
            expect(event.data['inputDrainKind'], 'none');
            expect(event.data['inputFinishRequested'], false);
            expect(event.data['forcedCancel'], false);
            final segments = await directory.list().where((f) => p.extension(f.path) == '.ts').cast<File>().toList();
            expect(segments, isNotEmpty);
            task.queuePendingAttempt(
              directoryPath: directory.path,
              filePrefix: task.recordingFilePrefix,
              inputIntegrityError: event.data['inputIntegrityError'] == true,
            );
            final restored = LiveRecordTask.fromJson(task.toJson());
            final merged = await VideoProcessorService.to.convertToMp4(task: restored);
            final outputs = await directory.list().where((f) => p.extension(f.path) == '.mp4').cast<File>().toList();
            int? decodeCode;
            String? decodeErrors;
            if (outputs.length == 1) {
              final process = await Process.start(decoder, [
                '-nostdin',
                '-v',
                'error',
                '-xerror',
                '-err_detect',
                'explode',
                '-threads',
                '2',
                '-i',
                outputs.single.path,
                '-map',
                '0:v:0',
                '-map',
                '0:a:0',
                '-f',
                'null',
                '-',
              ]);
              final outputDone = process.stdout.drain<void>();
              final errorsDone = process.stderr.transform(utf8.decoder).join();
              try {
                decodeCode = await process.exitCode.timeout(const Duration(seconds: 30));
              } on TimeoutException {
                process.kill();
                await process.exitCode;
                rethrow;
              }
              await outputDone;
              decodeErrors = await errorsDone;
              await File(p.join(directory.path, 'decode.log')).writeAsString(decodeErrors);
            }
            final retained = await Future.wait(segments.map((f) => f.exists()));
            results.add({
              'damagedInput': damaged,
              'captureCode': event.data['code'],
              'inputIntegrityError': event.data['inputIntegrityError'],
              'persistedIntegrityError': restored.pendingAttempts.single.inputIntegrityError,
              'mergeSucceeded': merged,
              'sourceRetained': retained.every((value) => value),
              'mp4Count': outputs.length,
              'decodeCode': decodeCode,
              'decodeErrorEmpty': decodeErrors?.trim().isEmpty,
              'nativeRunning': native.isRunning(task.taskId),
            });
          } finally {
            if (native.isRunning(task.taskId)) await native.stop(task.taskId);
            await execution;
            await subscription.cancel();
          }
        }
        await File(p.join(root.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
        final healthy = results.first;
        final damaged = results.last;
        expect(healthy['inputIntegrityError'], false);
        expect(healthy['mergeSucceeded'], true);
        expect(healthy['sourceRetained'], false);
        expect(healthy['decodeCode'], 0);
        expect(healthy['decodeErrorEmpty'], true);
        expect(damaged['inputIntegrityError'], true);
        expect(damaged['persistedIntegrityError'], true);
        expect(damaged['mergeSucceeded'], false);
        expect(damaged['sourceRetained'], true);
        expect(damaged['mp4Count'], 0);
        expect(results.every((row) => row['nativeRunning'] == false), true);
      } finally {
        Get.reset();
        await Hive.close();
        await settings.delete(recursive: true);
      }
    },
    skip: Platform.environment['PURELIVE_INPUT_INTEGRITY_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
