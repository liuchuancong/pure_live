// Explicit local native test. Its origin is a paced fixed FLV fixture, not a CDN.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_flv_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

void main() {
  test(
    'native FLV manual stop drains whole media before closing segment output',
    () async {
      final fixture = Platform.environment['PURELIVE_FLV_STOP_FIXTURE'];
      final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT'];
      final decoder = Platform.environment['PURELIVE_FFMPEG'];
      expect(fixture, isNotEmpty);
      expect(base, isNotEmpty);
      expect(decoder, isNotEmpty);
      final root = await Directory(p.join(base!, 'flv-stop-${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final settings = await Directory.systemTemp.createTemp('purelive-flv-stop-settings-');
      Hive.init(settings.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      final packets = FlvInputFramer().add(await File(fixture!).readAsBytes()).toList();
      final results = <Map<String, Object?>>[];
      try {
        for (final delay in [150, 700, 1200]) {
          final directory = await Directory(p.join(root.path, '$delay')).create();
          final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          var closed = false;
          final originSubscription = origin.listen((request) async {
            request.response.bufferOutput = false;
            final clock = Stopwatch()..start();
            try {
              for (var i = 0; i < packets.length && !closed; i++) {
                final packet = packets[i];
                if (i > 0) {
                  final timestamp = (packet[7] << 24) | (packet[4] << 16) | (packet[5] << 8) | packet[6];
                  final wait = timestamp - clock.elapsedMilliseconds;
                  if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
                }
                if (closed) break;
                request.response.add(packet);
                await request.response.flush();
              }
              await request.response.close();
            } on Object {
              /* Native input ended at the requested stop boundary. */
            }
          });
          final taskId = 'stop_$delay';
          final native = FFmpegManager.to;
          final started = Completer<void>();
          Map<String, dynamic>? terminal;
          final subscription = native.stream.listen((event) {
            if (event.taskId != taskId) return;
            if (event.type == FFmpegEventType.started && !started.isCompleted) started.complete();
            if (event.type == FFmpegEventType.complete || event.type == FFmpegEventType.error) terminal = event.data;
          });
          final arguments = FFmpegCommandBuilder.buildRecordArguments(
            url: 'http://127.0.0.1:${origin.port}/fixture.flv',
            outputDir: directory.path,
            segmentTime: 10,
            preferBestStream: true,
            rwTimeout: 5,
            threadQueueSize: 128,
            filePrefix: 'fixture',
          );
          final execution = native.start(taskId: taskId, arguments: arguments, liveRecording: true);
          try {
            await started.future.timeout(const Duration(seconds: 25));
            final session = native.getSession(taskId)!;
            await Future<void>.delayed(Duration(milliseconds: delay));
            final stopping = Stopwatch()..start();
            await Future.wait([native.stop(taskId), native.stop(taskId)]).timeout(const Duration(seconds: 15));
            await execution;
            stopping.stop();
            await Future<void>.delayed(Duration.zero);
            await File(p.join(directory.path, 'native.log')).writeAsString(session.diagnosticTail);
            final files = await directory.list().where((f) => p.extension(f.path) == '.ts').cast<File>().toList();
            files.sort((a, b) => a.path.compareTo(b.path));
            final sizes = await Future.wait(files.map((f) => f.length()));
            final manifest = File(p.join(directory.path, 'source.ffconcat'));
            await manifest.writeAsString(VideoProcessorService.buildConcatManifest(files.map((f) => f.path)));
            final process = await Process.start(decoder!, [
              '-hide_banner',
              '-nostdin',
              '-v',
              'error',
              '-xerror',
              '-threads',
              '2',
              '-f',
              'concat',
              '-safe',
              '0',
              '-i',
              manifest.path,
              '-map',
              '0:v:0',
              '-map',
              '0:a:0',
              '-f',
              'null',
              '-',
            ]);
            final stdoutDone = process.stdout.drain<void>();
            final errorsDone = process.stderr.transform(utf8.decoder).join();
            int code;
            try {
              code = await process.exitCode.timeout(const Duration(seconds: 30));
            } on TimeoutException {
              process.kill();
              await process.exitCode;
              rethrow;
            }
            await stdoutDone;
            final errors = await errorsDone;
            await File(p.join(directory.path, 'decode.log')).writeAsString(errors);
            results.add({
              'delayMs': delay,
              'stopMs': stopping.elapsedMilliseconds,
              'nativeRunning': native.isRunning(taskId),
              'integrityError': session.hasMediaIntegrityError,
              // A stopped live input can log demux I/O. Preserve that evidence;
              // separately assert output writes and full independent decoding.
              'outputWriteError':
                  session.diagnosticTail.toLowerCase().contains('error writing trailer') ||
                  session.diagnosticTail.toLowerCase().contains('error muxing a packet'),
              'inputDrained': terminal?['inputDrained'],
              'forcedCancel': terminal?['forcedCancel'],
              'sizes': sizes,
              'packetAligned': sizes.isNotEmpty && sizes.every((s) => s > 0 && s % 188 == 0),
              'decodeCode': code,
              'decodeErrorEmpty': errors.trim().isEmpty,
            });
          } finally {
            if (native.isRunning(taskId)) await native.stop(taskId);
            await execution;
            closed = true;
            await subscription.cancel();
            await originSubscription.cancel();
            await origin.close(force: true);
          }
        }
        await File(p.join(root.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
        expect(
          results.every(
            (r) =>
                r['nativeRunning'] == false &&
                r['outputWriteError'] == false &&
                r['packetAligned'] == true &&
                r['decodeCode'] == 0 &&
                r['decodeErrorEmpty'] == true,
          ),
          true,
          reason: 'Original TS must remain fully decodable after manual stop.',
        );
        expect(results.every((r) => r['inputDrained'] == true && r['forcedCancel'] == false), true);
      } finally {
        Get.reset();
        await Hive.close();
        await settings.delete(recursive: true);
      }
    },
    skip: Platform.environment['PURELIVE_FLV_STOP_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
