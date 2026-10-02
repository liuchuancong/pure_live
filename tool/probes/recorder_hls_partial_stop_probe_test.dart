// Opt-in deterministic native probe: pause an fMP4 response mid-payload,
// then stop through the production manager. No phone or external HTTP traffic.
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
    'native HLS stop during a partial fMP4 response preserves complete output packets',
    () async {
      final fixture = Directory(Platform.environment['PURELIVE_HLS_PARTIAL_FIXTURE']!);
      final root = await Directory(
        p.join(
          Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!,
          'hls-partial-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final decoder = Platform.environment['PURELIVE_FFMPEG']!;
      final settings = await Directory(p.join(root.path, 'hive')).create();
      Hive.init(settings.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      final files = await fixture.list().where((f) => p.extension(f.path) == '.m4s').cast<File>().toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      expect(files.length, greaterThanOrEqualTo(4));
      final results = <Map<String, Object?>>[];
      try {
        // A complete-body control exercises the same native/relay/output path.
        for (final fraction in [1.0, 0.25, 0.5, 0.9]) {
          final directory = await Directory(p.join(root.path, '$fraction')).create();
          final partial = Completer<void>();
          final release = Completer<void>();
          var manifestRequests = 0;
          var partialBytes = 0;
          var completeBytes = 0;
          final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final originSubscription = origin.listen((request) async {
            try {
              if (request.uri.path == '/fixture.m3u8') {
                final count = ++manifestRequests == 1 ? 3 : 4;
                request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
                request.response.write(
                  '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:2\n'
                  '#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-MAP:URI="init.mp4"\n',
                );
                for (final file in files.take(count)) {
                  request.response.write('#EXTINF:2,\n${p.basename(file.path)}\n');
                }
                await request.response.close();
                return;
              }
              final name = request.uri.pathSegments.last;
              final allowed = name == 'init.mp4' || files.take(4).any((f) => p.basename(f.path) == name);
              if (!allowed) {
                request.response.statusCode = HttpStatus.notFound;
                await request.response.close();
                return;
              }
              final bytes = await File(p.join(fixture.path, name)).readAsBytes();
              request.response.contentLength = bytes.length;
              request.response.bufferOutput = false;
              if (name == p.basename(files[3].path)) {
                completeBytes = bytes.length;
                partialBytes = (bytes.length * fraction).floor();
                request.response.add(bytes.sublist(0, partialBytes));
                await request.response.flush();
                if (!partial.isCompleted) partial.complete();
                if (fraction < 1) await release.future;
                request.response.add(bytes.sublist(partialBytes));
              } else {
                request.response.add(bytes);
              }
              await request.response.close();
            } on Object {
              // Stop closes the relay upstream connection while the fixture is
              // paused; keep that ownership local and settle the handler.
              try {
                await request.response.close();
              } on Object {
                /* Already closed. */
              }
            }
          });
          final native = FFmpegManager.to;
          final taskId = 'partial_$fraction';
          final started = Completer<void>();
          Map<String, dynamic>? terminal;
          final events = native.stream.listen((event) {
            if (event.taskId != taskId) return;
            if (event.type == FFmpegEventType.started && !started.isCompleted) started.complete();
            if (event.type == FFmpegEventType.complete || event.type == FFmpegEventType.error) terminal = event.data;
          });
          final arguments = FFmpegCommandBuilder.buildRecordArguments(
            url: 'http://127.0.0.1:${origin.port}/fixture.m3u8',
            outputDir: directory.path,
            filePrefix: 'fixture',
            segmentTime: 30,
            preferBestStream: true,
            rwTimeout: 30,
            threadQueueSize: 1024,
          );
          final execution = native.start(taskId: taskId, liveRecording: true, arguments: arguments);
          try {
            await Future.wait([started.future, partial.future]).timeout(const Duration(seconds: 35));
            final session = native.getSession(taskId)!;
            final watch = Stopwatch()..start();
            await native.stop(taskId).timeout(const Duration(seconds: 25));
            await execution;
            watch.stop();
            await File(p.join(directory.path, 'native.log')).writeAsString(session.diagnosticTail);
            final segments = await directory.list().where((f) => p.extension(f.path) == '.ts').cast<File>().toList();
            segments.sort((a, b) => a.path.compareTo(b.path));
            final concat = File(p.join(directory.path, 'source.ffconcat'));
            await concat.writeAsString(VideoProcessorService.buildConcatManifest(segments.map((f) => f.path)));
            final decoded = await _decode(decoder, [
              '-nostdin',
              '-hide_banner',
              '-v',
              'error',
              '-xerror',
              '-err_detect',
              'explode',
              '-threads',
              '2',
              '-f',
              'concat',
              '-safe',
              '0',
              '-i',
              concat.path,
              '-map',
              '0:v:0',
              '-map',
              '0:a:0',
              '-f',
              'null',
              '-',
            ]);
            await File(p.join(directory.path, 'decode.log')).writeAsString(decoded.errors);
            results.add({
              'fraction': fraction,
              'segmentFormatOptions': arguments.contains('-segment_format_options')
                  ? arguments[arguments.indexOf('-segment_format_options') + 1]
                  : null,
              'partialBytes': partialBytes,
              'completeBytes': completeBytes,
              'stopMs': watch.elapsedMilliseconds,
              'terminal': terminal,
              'sourceFiles': segments.map((f) => f.path).toList(),
              'sourceBytes': await Future.wait(segments.map((f) => f.length())),
              'decodeCode': decoded.code,
              'decodeErrorEmpty': (decoded.errors).trim().isEmpty,
              'nativeRunning': native.isRunning(taskId),
            });
            await File(p.join(root.path, 'summary.json'))
                .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
          } finally {
            if (!release.isCompleted) release.complete();
            if (native.isRunning(taskId)) await native.stop(taskId);
            await execution;
            await events.cancel();
            await origin.close(force: true);
            await originSubscription.cancel();
          }
        }
        await File(p.join(root.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
        // ignore: avoid_print
        print(jsonEncode({'evidence': root.path, 'results': results}));
        expect(
          results.every((r) => r['decodeCode'] == 0 && r['decodeErrorEmpty'] == true && r['nativeRunning'] == false),
          true,
          reason: 'Cancellation of a partially delivered HLS fragment must not commit a damaged output packet.',
        );
        expect(
          results.every((r) {
            final terminal = r['terminal'] as Map<String, dynamic>?;
            return terminal?['inputDrained'] == true &&
                terminal?['forcedCancel'] == false &&
                terminal?['inputTailDiscarded'] == ((r['fraction'] as double) < 1) &&
                terminal?['inputIntegrityError'] == false;
          }),
          true,
          reason: 'Whole-fragment staging must avoid native cancellation and disclose discarded input.',
        );
      } finally {
        Get.reset();
        await Hive.close();
        // Retain this probe's isolated settings and media evidence; no user box.
      }
    },
    skip: Platform.environment['PURELIVE_HLS_PARTIAL_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<({int code, String errors})> _decode(String decoder, List<String> arguments) async {
  final process = await Process.start(decoder, arguments);
  final stdoutDone = process.stdout.drain<void>();
  final errorsDone = process.stderr.transform(utf8.decoder).join();
  int code;
  try {
    code = await process.exitCode.timeout(const Duration(seconds: 30));
  } on TimeoutException {
    process.kill();
    await process.exitCode;
    rethrow;
  } finally {
    await stdoutDone;
  }
  return (code: code, errors: await errorsDone);
}
