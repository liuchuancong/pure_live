// Opt-in actual PlayerManager dispatch with a desktop FFmpeg native boundary.
// UI/native renderer and device acceptance remain separate.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_watch.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/recorder/data/services/live_input_playback_binding.dart';
import 'package:pure_live/core/player/core/player_manager.dart';
import 'package:pure_live/core/player/core/engine_fallback_manager.dart';
import 'package:pure_live/core/player/core/line_fallback_manager.dart';
import 'package:pure_live/core/player/models/player_engine.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/player_state.dart';

import '../../test/support/owned_source_test_player.dart';

import 'package:pure_live/domains/recorder/data/services/niconico_hls_input.dart';

import 'niconico_capture_contract.dart';
import 'niconico_relay_probe_test.dart' show QuietNiconicoProbeLogController, runNiconicoNativeStage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'production PlayerManager opens an owned niconico recipe and cleans its native consumer',
    () async {
      Get.put(GlobalPlayerState());
      addTearDown(() => Get.delete<GlobalPlayerState>(force: true));
      Get.put<LogController>(QuietNiconicoProbeLogController());
      addTearDown(() => Get.delete<LogController>(force: true));
      final env = io.Platform.environment;
      final directory = io.Directory(env['PURELIVE_NICONICO_MANAGER_OUTPUT']!);
      await directory.create(recursive: true);
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'result': 'failed',
        'stage': 'watch',
        'applicationPlayer': false,
        'applicationManager': true,
        'nativeOpenIncludesCapture': true,
        'nativeConsumer': 'desktop-ffmpeg',
        'recordingMode': false,
        'route': 'PROXY 127.0.0.1:7897',
      };
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
          );
        HttpClient.instance.dio = dio;
        NiconicoHlsInput? input;
        final source = NiconicoPlaybackInput(
          programId: env['PURELIVE_NICONICO_PROGRAM']!,
          resolution: env['PURELIVE_NICONICO_SELECTED_RESOLUTION'],
          findProxy: (_) => 'PROXY 127.0.0.1:7897',
          openInput: (watch, {required resolution, bandwidth, required recording, required findProxy, cancel}) async {
            report['watchStatus'] = watch.status.name;
            report['watchAccess'] = watch.access.name;
            report['stage'] = 'input';
            report['selectedResolution'] = resolution;
            expect(recording, false);
            final created = await NiconicoHlsInput.open(
              watch,
              resolution: resolution,
              bandwidth: bandwidth,
              recording: recording,
              findProxy: findProxy,
              cancel: cancel,
            );
            input = created;
            return created;
          },
        );
        Future<void> consume(String url, List<String> choices, Map<String, String> headers, bool private) async {
          expect(Uri.parse(url).host, '127.0.0.1');
          expect(choices, [url]);
          expect(headers, isEmpty);
          expect(private, true);
          final output = '${directory.path}/capture.mp4';
          report['stage'] = 'consume';
          await runNiconicoNativeStage(
            env['PURELIVE_FFMPEG']!,
            [
              '-hide_banner',
              '-v',
              'verbose',
              '-debug_ts',
              '-nostdin',
              '-n',
              '-rw_timeout',
              '25000000',
              '-i',
              url,
              '-t',
              '6',
              '-map',
              '0:v:0',
              '-map',
              '0:a:0',
              '-c',
              'copy',
              output,
            ],
            directory,
            'consume',
            const Duration(seconds: 90),
          );
          report['captureBytes'] = await io.File(output).length();
          report['stage'] = 'inspect';
          final json = await runNiconicoNativeStage(
            env['PURELIVE_FFPROBE']!,
            ['-v', 'error', '-show_packets', '-show_streams', '-show_format', '-of', 'json', output],
            directory,
            'inspect',
            const Duration(seconds: 20),
          );
          await io.File('${directory.path}/packets.json').writeAsString(json);
          final metadata = jsonDecode(json) as Map<String, dynamic>;
          final contract = inspectNiconicoCapture(metadata);
          report['captureContract'] = contract;
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
          report['decoded'] = true;
          expect(contract['passed'], true, reason: '${contract['failures']}');
          expect(input!.isClosed, false);
          // Playback does not silently turn on recording/prefetch policy.
          // ignore: invalid_use_of_visible_for_testing_member
          report['prefetchFeeds'] = input!.prefetchFeedCount;
          // ignore: invalid_use_of_visible_for_testing_member
          expect(input!.prefetchFeedCount, 0);
        }

        final native = _NativeConsumer(consume);
        final manager = PlayerManager(
          playerCreator: (_) => native,
          fallbackManager: EngineFallbackManager(
            defaultEngine: PlayerEngine.mediaKit,
            supportedEngines: [PlayerEngine.mediaKit],
          ),
          lineManager: LineFallbackManager(),
          // This boundary waits for the entire six-second capture, not merely
          // native open acknowledgement. It is not the production open limit.
          sourceOpenTimeout: const Duration(seconds: 90),
          transientLiveRetryDelays: const [],
          useHardStopOnExit: () => false,
          audioModeServiceSync: (_, _) async {},
          audioSessionStart: (_) async {},
        )..configureDefaultEngine(PlayerEngine.mediaKit);
        final errors = manager.onError.listen((error) {
          final cause = error.error;
          report['managerErrorType'] = error.type.name;
          report['managerErrorCode'] = error.code;
          report['managerCauseType'] = cause.runtimeType.toString();
          if (cause is NiconicoException) report['managerCauseKind'] = cause.kind.name;
        });
        try {
          await manager.playSource(
            source.source,
            room: LiveRoom(roomId: source.programId, platform: 'niconico'),
          );
          expect(manager.currentSourceCommit?.source, same(source.source));
          expect(manager.currentSourceCommit!.urls, isEmpty);
          expect(manager.currentSourceCommit!.currentUrl, isEmpty);
          expect(native.openedSourceIdentities.single, source.source.identity);

          report['transactionCommitted'] = true;
          await manager.close();
          expect(input!.cleanupSucceeded, true);
          report['result'] = 'passed';
        } catch (error) {
          report['failureType'] = error.runtimeType.toString();
          if (error is NiconicoException) report['failureKind'] = error.kind.name;
          rethrow;
        } finally {
          try {
            await manager.dispose();
          } finally {
            await errors.cancel();
            HttpClient.instance.dio = previous;
            dio.close(force: true);
            report['inputClosed'] = input?.isClosed;
            report['cleanupSucceeded'] = input?.cleanupSucceeded;
            report['retainedCookies'] = input?.retainedCookieCount;
            // ignore: invalid_use_of_visible_for_testing_member
            report['relayResources'] = input?.resourceCount;
            // ignore: invalid_use_of_visible_for_testing_member
            if (input?.cleanupSucceeded != true || (input?.resourceCount ?? 0) != 0) report['result'] = 'failed';
            await io.File('${directory.path}/report.json').writeAsString(jsonEncode(report));
            // ignore: avoid_print
            print(jsonEncode(report));
          }
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_NICONICO_MANAGER_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _RealNetwork extends io.HttpOverrides {}

class _NativeConsumer extends OwnedSourceTestPlayer {
  _NativeConsumer(this.consume) : super(PlayerEngine.mediaKit, (_) => null, emitPlaying: false);
  final Future<void> Function(String, List<String>, Map<String, String>, bool) consume;
  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    await super.setDataSource(url, playUrls, headers, room: room, audioOnly: audioOnly);
    await consume(url, playUrls, headers, openedPrivateInputs.last);
    emitUnexpectedPlaying(true);
  }
}
