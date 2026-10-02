// Opt-in, fixed local FLV replay. No CDN, device, user configuration or media rewrite.
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
import 'package:pure_live/domains/recorder/data/services/ffmpeg_flv_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

void main() {
  test(
    'native AVC stop preserves frames and metadata; stalled/EOF tails retain source',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final fixture = Platform.environment['PURELIVE_FLV_STOP_FIXTURE']!;
        final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!;
        final decoder = Platform.environment['PURELIVE_FFMPEG']!;
        final root = await Directory(p.join(base, 'avc-stop-${DateTime.now().microsecondsSinceEpoch}'))
            .create(recursive: true);
        final settings = await Directory.systemTemp.createTemp('purelive-avc-stop-settings-');
        Hive.init(settings.path);
        await HivePrefUtil.init();
        Get.testMode = true;
        Get.put(LogController());
        final packets = FlvInputFramer().add(await File(fixture).readAsBytes()).toList();
        final boundary = FlvAvcAccessUnitBoundary();
        var cut = -1;
        for (var i = 0; i < packets.length; i++) {
          final packet = packets[i];
          boundary.observe(packet);
          if (packet[0] == 9 && _timestamp(packet) >= 6000 && boundary.hasPendingAccessUnit) {
            cut = i;
            break;
          }
        }
        expect(cut, greaterThan(0));
        var expectedEnd = cut;
        do {
          expectedEnd++;
          boundary.observe(packets[expectedEnd]);
        } while (boundary.hasPendingAccessUnit);
        final results = <Map<String, Object?>>[];
        try {
          for (final label in ['clean', 'picture', 'stalled', 'eof']) {
            final directory = await Directory(p.join(root.path, label)).create();
            final prefixEnd = label == 'clean' ? cut - 1 : cut;
            final prefix = packets.take(prefixEnd + 1).expand((x) => x).toList();
            final tail = packets.skip(prefixEnd + 1).expand((x) => x).toList();
            final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
            final release = Completer<void>();
            var closed = false;
            Future<void>? serving;
            final upstream = origin.listen((request) {
              serving = () async {
                try {
                  request.response.bufferOutput = false;
                  request.response.add(prefix);
                  await request.response.flush();
                  await release.future;
                  if (!closed && label != 'eof') {
                    request.response.add(tail);
                    await request.response.flush();
                  }
                  await request.response.close();
                } on Object {
                  /* Owned reader was stopped. */
                }
              }();
            });
            var task = LiveRecordTask.fromRoom(LiveRoom(platform: 'kilakila', roomId: label, nick: 'Local AVC fixture'))
              ..outputDir = directory.path;
            final manager = FFmpegManager.to;
            final started = Completer<void>();
            Map<String, dynamic>? terminal;
            final events = manager.stream.listen((event) {
              if (event.taskId != task.taskId) return;
              if (event.type == FFmpegEventType.started && !started.isCompleted) started.complete();
              if (event.type == FFmpegEventType.complete || event.type == FFmpegEventType.error) terminal = event.data;
            });
            final execution = manager.start(
              taskId: task.taskId,
              liveRecording: true,
              arguments: FFmpegCommandBuilder.buildRecordArguments(
                url: 'http://127.0.0.1:${origin.port}/fixture.flv',
                outputDir: directory.path,
                segmentTime: 10,
                preferBestStream: true,
                rwTimeout: 5,
                threadQueueSize: 128,
                filePrefix: task.recordingFilePrefix,
              ),
            );
            try {
              await started.future.timeout(const Duration(seconds: 15));
              final session = manager.getSession(task.taskId)!;
              final relay = session.flvInputRelay!;
              await _until(() => relay.forwardedBytes == prefix.length);
              expect(relay.hasPendingAccessUnit, label != 'clean');
              final clock = Stopwatch()..start();
              final stopping = manager.stop(task.taskId);
              await _until(() => relay.finishRequested);
              if (label == 'picture' || label == 'eof') release.complete();
              await stopping.timeout(const Duration(seconds: 15));
              await execution;
              clock.stop();
              await Future<void>.delayed(Duration.zero);
              final healthy = label == 'clean' || label == 'picture';
              expect(manager.isRunning(task.taskId), false);
              expect(terminal, isNotNull);
              expect(terminal!['flvAccessUnitPending'], !healthy);
              expect(terminal!['inputIntegrityError'], !healthy);
              expect(terminal!['inputDrained'], healthy);
              expect(terminal!['forcedCancel'], label == 'stalled');
              final expectedBytes = packets
                  .take((label == 'picture' ? expectedEnd : prefixEnd) + 1)
                  .fold<int>(0, (n, x) => n + x.length);
              expect(relay.forwardedBytes, expectedBytes);
              final segments = await directory
                  .list()
                  .where((f) => f is File && p.extension(f.path) == '.ts')
                  .cast<File>()
                  .toList();
              expect(segments, isNotEmpty);
              final sourceCopy = await Directory(p.join(directory.path, 'probe-source')).create();
              for (final segment in segments) {
                await segment.copy(p.join(sourceCopy.path, p.basename(segment.path)));
              }
              task.recordedSeconds = session.recordedSeconds;
              if (!healthy) {
                task.queuePendingAttempt(
                  directoryPath: directory.path,
                  filePrefix: task.recordingFilePrefix,
                  inputIntegrityError: true,
                );
                task = LiveRecordTask.fromJson(task.toJson());
              }
              final committed = await VideoProcessorService.to.convertToMp4(task: task);
              expect(committed, healthy);
              expect(VideoProcessorService.to.isProcessing(task.taskId), false);
              for (final segment in segments) {
                expect(await segment.exists(), !healthy);
              }
              int? decodeExit;
              String? decodeError;
              if (healthy) {
                final output = p.join(directory.path, '${task.recordingFilePrefix}.mp4');
                final process = await Process.start(decoder, [
                  '-v',
                  'error',
                  '-i',
                  output,
                  '-xerror',
                  '-fps_mode',
                  'passthrough',
                  '-enc_time_base',
                  'demux',
                  '-f',
                  'null',
                  '-',
                ]);
                final stdoutDone = process.stdout.drain<void>();
                final stderrDone = process.stderr.transform(utf8.decoder).join();
                try {
                  decodeExit = await process.exitCode.timeout(const Duration(seconds: 25));
                } on TimeoutException {
                  process.kill();
                  await process.exitCode;
                  rethrow;
                }
                await stdoutDone;
                decodeError = await stderrDone;
                await File(p.join(directory.path, 'decode.log')).writeAsString(decodeError);
                expect(decodeExit, 0);
                expect(decodeError, isEmpty);
              } else {
                expect(await directory.list().where((f) => p.extension(f.path) == '.mp4').length, 0);
              }
              results.add({
                'case': label,
                'prefixBytes': prefix.length,
                'forwardedBytes': relay.forwardedBytes,
                'stopMilliseconds': clock.elapsedMilliseconds,
                'terminal': terminal,
                'mp4Committed': committed,
                'sourceSegmentsRetained': !healthy,
                'decodeExit': decodeExit,
                'decodeError': decodeError,
                'nativeRunning': false,
                'sourceBytesRewritten': false,
              });
              await File(p.join(root.path, 'summary.json'))
                  .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
            } finally {
              closed = true;
              if (!release.isCompleted) release.complete();
              if (manager.isRunning(task.taskId)) await manager.stop(task.taskId);
              await execution.timeout(const Duration(seconds: 15));
              await events.cancel();
              await origin.close(force: true);
              await upstream.cancel();
              await serving;
            }
          }
        } finally {
          Get.reset();
          await Hive.close();
          await settings.delete(recursive: true);
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_AVC_STOP_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends HttpOverrides {}

int _timestamp(List<int> packet) => (packet[7] << 24) | (packet[4] << 16) | (packet[5] << 8) | packet[6];
Future<void> _until(bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 3)) throw TimeoutException('Expected owned relay state');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
