// Opt-in production native HLS stop test using a local rolling playlist.
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
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

void main() {
  test(
    'native HLS manual stop drains whole media before closing segment output',
    () async {
      final fixture = Platform.environment['PURELIVE_HLS_STOP_FIXTURE'];
      final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT'];
      final decoder = Platform.environment['PURELIVE_FFMPEG'];
      expect(fixture, isNotEmpty);
      expect(base, isNotEmpty);
      expect(decoder, isNotEmpty);
      final root = await Directory(p.join(base!, 'hls-stop-${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final settings = await Directory.systemTemp.createTemp('purelive-hls-stop-settings-');
      Hive.init(settings.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      final media = Directory(fixture!);
      final segmentFiles = await media
          .list()
          .where((f) => const ['.ts', '.m4s'].contains(p.extension(f.path)))
          .cast<File>()
          .toList();
      segmentFiles.sort((a, b) => a.path.compareTo(b.path));
      expect(segmentFiles.length, greaterThanOrEqualTo(8));
      final fixtureManifest = await File(p.join(media.path, 'fixture.m3u8')).readAsString();
      final metadata = const LineSplitter()
          .convert(fixtureManifest)
          .where((line) => line.startsWith('#EXT-X-KEY:') || line.startsWith('#EXT-X-MAP:'))
          .join('\n');
      for (final match in RegExp(r'URI="([^"]+)"').allMatches(metadata)) {
        expect(
          await File(p.join(media.path, match.group(1)!)).exists(),
          true,
          reason: 'The fixed HLS fixture must include every key/init resource.',
        );
      }
      final duration = int.parse(RegExp(r'#EXT-X-TARGETDURATION:(\d+)').firstMatch(fixtureManifest)!.group(1)!);
      final results = <Map<String, Object?>>[];
      try {
        for (final delay in [150, 700, 1200]) {
          final directory = await Directory(p.join(root.path, '$delay')).create();
          final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final clock = Stopwatch()..start();
          final originSubscription = origin.listen((request) async {
            try {
              if (request.uri.path == '/fixture.m3u8') {
                final count = (2 + clock.elapsedMilliseconds ~/ (duration * 1000)).clamp(2, segmentFiles.length);
                final first = (count - 4).clamp(0, count);
                request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
                request.response.write(
                  '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:$duration\n'
                  '#EXT-X-MEDIA-SEQUENCE:$first\n$metadata\n',
                );
                for (var i = first; i < count; i++) {
                  request.response.write('#EXTINF:$duration.0,\n${p.basename(segmentFiles[i].path)}\n');
                }
                await request.response.close();
              } else {
                final name = request.uri.pathSegments.last;
                final file = File(p.join(media.path, name));
                if (!segmentFiles.any((f) => p.basename(f.path) == name) &&
                    !const ['init.mp4', 'key.bin'].contains(name)) {
                  request.response.statusCode = HttpStatus.notFound;
                  await request.response.close();
                } else {
                  request.response.contentLength = await file.length();
                  await file.openRead().pipe(request.response);
                }
              }
            } on Object {
              try {
                request.response.statusCode = HttpStatus.internalServerError;
                await request.response.close();
              } on Object {
                /* The local native client may have ended its input. */
              }
            }
          });
          final taskId = 'stop_$delay';
          final native = FFmpegManager.to;
          final started = Completer<void>();
          Map<String, dynamic>? terminal;
          final subscription = native.stream.listen((event) {
            if (event.taskId != taskId) return;
            if (event.type == FFmpegEventType.started && !started.isCompleted) started.complete();
            if (event.type == FFmpegEventType.complete || event.type == FFmpegEventType.error) {
              terminal = event.data;
              if (!started.isCompleted) {
                started.completeError(StateError('Native HLS ended before media: ${event.data}'));
              }
            }
          });
          final arguments = FFmpegCommandBuilder.buildRecordArguments(
            url: 'http://127.0.0.1:${origin.port}/fixture.m3u8',
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
            await Future.wait([native.stop(taskId), native.stop(taskId)]).timeout(const Duration(seconds: 35));
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
              'container': p.extension(segmentFiles.first.path),
              'encrypted': metadata.contains('#EXT-X-KEY:'),
              'targetDurationSeconds': duration,
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
              'manualStop': terminal?['manualStop'],
              'stopRequested': terminal?['stopRequested'],
              'stopElapsedMs': terminal?['stopElapsedMs'],
              'inputDrainKind': terminal?['inputDrainKind'],
              'inputDrainBudgetMs': terminal?['inputDrainBudgetMs'],
              'inputFinishRequested': terminal?['inputFinishRequested'],
              'inputIntegrityError': terminal?['inputIntegrityError'],
              'sizes': sizes,
              'packetAligned': sizes.isNotEmpty && sizes.every((s) => s > 0 && s % 188 == 0),
              'decodeCode': code,
              'decodeErrorEmpty': errors.trim().isEmpty,
            });
          } finally {
            if (native.isRunning(taskId)) await native.stop(taskId);
            await execution;
            clock.stop();
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
        expect(
          results.every(
            (r) =>
                r['manualStop'] == true &&
                r['stopRequested'] == true &&
                r['inputFinishRequested'] == true &&
                r['inputDrainKind'] == 'hls' &&
                r['inputIntegrityError'] == false &&
                (r['stopElapsedMs'] as int) >= 0,
          ),
          true,
        );
      } finally {
        Get.reset();
        await Hive.close();
        await settings.delete(recursive: true);
      }
    },
    skip: Platform.environment['PURELIVE_HLS_STOP_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
