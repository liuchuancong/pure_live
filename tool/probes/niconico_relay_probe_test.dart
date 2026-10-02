// Opt-in external protocol/native evidence, not application or Android acceptance.
// Own one anonymous seat and one production relay; record six seconds, decode
// both tracks, then close all owners. Signed URLs/cookies stay out of process args.
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_api.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_watch.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/niconico_hls_input.dart';

import 'niconico_capture_contract.dart';

void main() {
  test(
    'Niconico owned session through production relay records and decodes audio/video',
    () async {
      Get.put<LogController>(QuietNiconicoProbeLogController());
      addTearDown(() => Get.delete<LogController>(force: true));
      final env = io.Platform.environment;
      final directory = io.Directory(env['PURELIVE_NICONICO_RELAY_OUTPUT']!);
      await directory.create(recursive: true);
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'result': 'failed',
        'stage': 'watch',
        'decoded': false,
        'route': 'PROXY 127.0.0.1:7897',
        'applicationConsumer': false,
      };
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
          );
        NiconicoHlsInput? input;
        final diagnostics = HlsRelayDiagnostics();
        HttpClient.instance.dio = dio;
        try {
          final watch = await NiconicoApi().room(env['PURELIVE_NICONICO_PROGRAM']!);
          report['watchStatus'] = watch.status.name;
          report['watchAccess'] = watch.access.name;
          report['stage'] = 'session';
          final resolution = env['PURELIVE_NICONICO_SELECTED_RESOLUTION'];
          final owned = await NiconicoHlsInput.open(
            watch,
            resolution: resolution,
            recording: resolution != null,
            findProxy: (_) => 'PROXY 127.0.0.1:7897',
            diagnostics: diagnostics,
          );
          input = owned;
          report['cookiesAtStart'] = owned.retainedCookieCount;
          report['selectedResolution'] = resolution;
          report['productionInputOwner'] = true;
          final output = '${directory.path}/capture.mp4';
          report['stage'] = 'record';
          await runNiconicoNativeStage(
            env['PURELIVE_FFMPEG']!,
            owned.replaceFirstInput([
              '-hide_banner',
              '-v',
              'verbose',
              '-debug_ts',
              '-nostdin',
              '-n',
              '-rw_timeout',
              '25000000',
              '-i',
              owned.inputUri.toString(),
              '-t',
              '6',
              '-map',
              '0:v:0',
              '-map',
              '0:a:0',
              '-c',
              'copy',
              output,
            ]),
            directory,
            'record',
            const Duration(seconds: 90),
          );
          report['captureBytes'] = await io.File(output).length();
          // ignore: invalid_use_of_visible_for_testing_member
          report['prefetchFeeds'] = owned.prefetchFeedCount;
          if (resolution != null) {
            // ignore: invalid_use_of_visible_for_testing_member
            expect(owned.prefetchFeedCount, 2, reason: 'explicit pair must actually be admitted');
          }
          report['stage'] = 'inspect';
          final metadata = jsonDecode(
            await runNiconicoNativeStage(
              env['PURELIVE_FFPROBE']!,
              ['-v', 'error', '-show_packets', '-show_streams', '-show_format', '-of', 'json', output],
              directory,
              'inspect',
              const Duration(seconds: 20),
            ),
          ) as Map<String, dynamic>;
          final streams = (metadata['streams'] as List).cast<Map<String, dynamic>>();
          expect(streams.where((s) => s['codec_type'] == 'video').length, 1);
          expect(streams.where((s) => s['codec_type'] == 'audio').length, 1);
          final duration = double.parse((metadata['format'] as Map)['duration'] as String);
          report['durationSeconds'] = duration;
          final contract = inspectNiconicoCapture(metadata);
          report['captureContract'] = contract;
          report['streams'] = streams
              .map(
                (s) => <String, Object?>{
                  'type': s['codec_type'],
                  'codec': s['codec_name'],
                  if (s['width'] != null) 'width': s['width'],
                  if (s['height'] != null) 'height': s['height'],
                },
              )
              .toList();
          report['stage'] = 'decode';
          await runNiconicoNativeStage(
            env['PURELIVE_FFMPEG']!,
            [
              '-hide_banner',
              '-v',
              'error',
              '-xerror',
              '-nostdin',
              '-i',
              output,
              '-map',
              '0:v:0',
              '-map',
              '0:a:0',
              '-f',
              'null',
              '-',
            ],
            directory,
            'decode',
            const Duration(seconds: 30),
          );
          expect(owned.isClosed, false);
          report['decoded'] = true;
          report['keepSeatSent'] = owned.seatKeepAlivesSent;
          report['stage'] = 'duration';
          expect(contract['passed'], true, reason: '${contract['failures']}');
          report['result'] = 'passed';
          await owned.close();
        } catch (error) {
          report['result'] = 'failed';
          report['failureType'] = error.runtimeType.toString();
          if (error is NiconicoException) report['failureKind'] = error.kind.name;
          fail('Niconico relay probe failed at ${report['stage']} (${report['failureType']})');
        } finally {
          try {
            await input?.close();
          } finally {
            HttpClient.instance.dio = previous;
            dio.close(force: true);
            await io.File('${directory.path}/relay.json').writeAsString(jsonEncode(diagnostics.snapshot()));
            report['sessionClosed'] = input?.isClosed;
            report['cleanupSucceeded'] = input?.cleanupSucceeded;
            report['retainedCookies'] = input?.retainedCookieCount;
            // This opt-in test lives under tool/probes rather than test/.
            // ignore: invalid_use_of_visible_for_testing_member
            report['relayResources'] = input?.resourceCount;
            // ignore: invalid_use_of_visible_for_testing_member
            if (input?.cleanupSucceeded != true || (input?.resourceCount ?? 0) != 0) report['result'] = 'failed';
            await io.File('${directory.path}/report.json').writeAsString(jsonEncode(report));
            // ignore: avoid_print
            print(jsonEncode(report));
          }
          if (input != null) expect(input.cleanupSucceeded, true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_NICONICO_RELAY_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _RealNetwork extends io.HttpOverrides {}

class QuietNiconicoProbeLogController extends GetxController implements LogController {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
  @override
  bool get enableLog => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> runNiconicoNativeStage(
  String executable,
  List<String> args,
  io.Directory directory,
  String stage,
  Duration timeout,
) async {
  final process = await io.Process.start(executable, args);
  final stdout = <int>[];
  final stderr = <int>[];
  void capture(List<int> target, List<int> chunk) {
    final remaining = 1024 * 1024 - target.length;
    if (remaining > 0) target.addAll(chunk.take(remaining));
  }

  final out = process.stdout.listen((chunk) => capture(stdout, chunk));
  final err = process.stderr.listen((chunk) => capture(stderr, chunk));
  final drained = Future.wait<void>([out.asFuture<void>(), err.asFuture<void>()]);
  unawaited(drained.catchError((Object _) => <void>[]));
  var exited = false;
  try {
    final code = await process.exitCode.timeout(timeout);
    exited = true;
    await drained.timeout(const Duration(seconds: 5));
    if (code != 0) throw StateError('Native $stage failed ($code)');
    return utf8.decode(stdout);
  } finally {
    if (!exited) process.kill();
    await process.exitCode;
    await out.cancel();
    await err.cancel();
    await io.File('${directory.path}/$stage.stderr.log').writeAsBytes(stderr);
  }
}
