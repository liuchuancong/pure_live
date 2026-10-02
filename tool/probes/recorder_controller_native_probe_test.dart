import 'package:pure_live/domains/live/domain/live_quality_discovery.dart';
import 'package:pure_live/domains/live/domain/live_input_recipe.dart';
import 'package:pure_live/domains/recorder/data/services/owned_record_input.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';

// Opt-in loopback native acceptance through the real user recording controller.
// Only the source resolver and storage root are fixtures; capture, sampling,
// user stop, finalization, metrics and task persistence use production code.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_scheduler.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/domain/models/record_status.dart';
import 'package:pure_live/domains/recorder/data/record_settings_controller.dart';
import 'package:pure_live/domains/recorder/presentation/pages/recorder/recorder_controller.dart';
import 'package:pure_live/domains/recorder/data/services/cache_service.dart';
import 'package:pure_live/domains/recorder/data/services/recorder_proxy_routing.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

import 'media_packet_timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'user controller captures, stops, commits, releases and restarts with native HLS retention',
    () async {
      final ownedMode = Platform.environment['PURELIVE_OWNED_RECORD_INPUT_PROBE'] == '1';
      final fixture = Directory(Platform.environment['PURELIVE_ROLLING_HLS_FIXTURE']!);
      final output = await Directory(
        p.join(
          Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!,
          'controller-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final root = await Directory(p.join(output.path, 'records')).create();
      Hive.init((await Directory(p.join(output.path, 'hive')).create()).path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      configureRecorderProxyRouting((_) => 'DIRECT');
      final reports = <Map<String, Object?>>[];
      final events = <Map<String, Object?>>[];
      final manager = FFmpegManager.to;
      final subscription = manager.stream.listen((event) {
        if (events.length < 256 &&
            [FFmpegEventType.startAck, FFmpegEventType.complete, FFmpegEventType.error].contains(event.type)) {
          events.add({
            'task': event.taskId,
            'type': event.type.name,
            for (final key in [
              'code',
              'manualStop',
              'inputDrained',
              'forcedCancel',
              'inputTailDiscarded',
              'inputCoverageIncomplete',
              'inputIntegrityError',
            ])
              if (event.data.containsKey(key)) key: event.data[key],
          });
        }
      });
      RecorderController? controller;
      LiveRecordTask? task;
      var stage = 'fixture';
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final contents = <String, List<int>>{
            '/master.m3u8': await File(p.join(fixture.path, 'master.m3u8')).readAsBytes(),
          };
          for (var track = 0; track < 2; track++) {
            final lines = await File(p.join(fixture.path, 'variant_$track/index.m3u8')).readAsLines();
            final end = lines.indexOf('segment_002.m4s');
            expect(end, greaterThan(0));
            contents['/variant_$track/index.m3u8'] = utf8.encode(
              '${lines.take(end + 1).join('\n').replaceFirst('#EXT-X-MEDIA-SEQUENCE:0', '#EXT-X-MEDIA-SEQUENCE:${track == 0 ? 200 : 100}')}\n',
            );
            for (final name in ['init_$track.mp4', 'segment_000.m4s', 'segment_001.m4s', 'segment_002.m4s']) {
              contents['/variant_$track/$name'] = await File(p.join(fixture.path, 'variant_$track', name))
                  .readAsBytes();
            }
          }
          final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final jobs = <Future<void>>{};
          final requests = <String>[];
          final server = origin.listen((request) {
            late Future<void> job;
            job = () async {
              if (requests.length < 256) requests.add(request.uri.path);
              final bytes = contents[request.uri.path];
              request.response.statusCode = bytes == null ? 404 : 200;
              if (bytes != null) {
                request.response.contentLength = bytes.length;
                request.response.add(bytes);
              }
              await request.response.close();
            }().whenComplete(() => jobs.remove(job));
            jobs.add(job);
          });
          try {
            final cache = Get.put(CacheService(defaultDirectoryResolver: () async => root));
            final resolver = Get.put<StreamResolverService>(
              _Resolver('http://127.0.0.1:${origin.port}/master.m3u8', owned: ownedMode),
            ) as _Resolver;
            final settings = RecordSettingsController()..segmentTime.value = 2;
            final recorder = Get.put<RecorderController>(
              // This opt-in test lives in tool/probes rather than test/.
              // ignore: invalid_use_of_visible_for_testing_member
              RecorderController.forTesting(
                settings: settings,
                ffmpeg: manager,
                inputRecordingBinder: (recipe) => OwnedRecordSource(
                  identity: recipe.identity,
                  createInput: (cancel) async {
                    if (cancel.isCancelled) throw cancel.cancelError!;
                    final relay = (await FFmpegHlsInputRelay.startForArguments(
                      ['-i', 'http://127.0.0.1:${origin.port}/master.m3u8'],
                      drainOnStop: true,
                      enablePrefetch: true,
                    ))!;
                    return _OwnedRelay(relay);
                  },
                ),
                // ignore: invalid_use_of_visible_for_testing_member
                scheduler: FFmpegScheduler.forTesting(),
                outputSampleInterval: const Duration(milliseconds: 100),
              ),
            );
            controller = recorder;
            await recorder.restoreAndAutoPoll();
            final current = task = LiveRecordTask(
              taskId: 'huya_controller_fixture',
              roomId: 'controller_fixture',
              platform: 'huya',
              title: 'native fixture',
              nick: 'native fixture',
              avatar: '',
              cover: '',
              createTime: DateTime.now(),
              autoReconnect: false,
            );
            recorder.tasks.add(current);
            for (var attempt = 0; attempt < 2; attempt++) {
              stage = 'start-$attempt';
              expect(await recorder.startTask(current), isTrue);
              await _until(
                () =>
                    manager.getSession(current.taskId)?.recordedSeconds != null &&
                    manager.getSession(current.taskId)!.recordedSeconds >= 4 &&
                    current.fileSize > 0,
              );
              final session = manager.getSession(current.taskId)!;
              final owned = session.ownedInput as _OwnedRelay?;
              final relay = ownedMode ? owned!.relay : session.inputRelay!;
              if (ownedMode) {
                expect(current.currentUrl, isNull);
                expect(current.toJson().toString(), isNot(contains('http://127.0.0.1:')));
              }
              expect(relay.prefetchEnabled, isTrue);
              // ignore: invalid_use_of_visible_for_testing_member
              expect(relay.prefetchFeedCount, 2);
              expect(cache.isDirectoryProtected(current.outputDir!), isTrue);
              final provisional = current.fileSize;
              final prefix = current.recordingFilePrefix;
              final stop = Stopwatch()..start();
              stage = 'stop-and-finalize-$attempt';
              await recorder.stopTask(current).timeout(const Duration(seconds: 40));
              stop.stop();
              expect(current.status, RecordStatus.stopped);
              expect(current.wasStoppedByUser, isTrue);
              expect(current.pendingAttempts, isEmpty);
              expect(current.lastError, isNull);
              expect(current.inputTailDiscarded, isFalse);
              expect(current.inputCoverageIncomplete, isFalse);
              expect(recorder.runningCount, 0);
              expect(recorder.queuedCount, 0);
              expect(manager.isRunning(current.taskId), isFalse);
              if (ownedMode) {
                expect(owned!.isClosed, true);
                expect(owned.closes, 1);
              }
              expect(VideoProcessorService.to.isProcessing(current.taskId), isFalse);
              expect(cache.isDirectoryProtected(current.outputDir!), isFalse);
              // ignore: invalid_use_of_visible_for_testing_member
              expect(relay.prefetchBodyCount, 0);
              final mp4 = File(p.join(current.outputDir!, '$prefix.mp4'));
              final size = await mp4.length();
              expect(size, greaterThan(10000));
              expect(current.fileSize, size);
              expect(await Directory(current.outputDir!).list().where((f) => p.extension(f.path) == '.ts').length, 0);
              final terminal = events.lastWhere((e) => e['task'] == current.taskId && e['type'] == 'complete');
              expect(terminal['code'], 0);
              expect(terminal['manualStop'], isTrue);
              expect(terminal['inputDrained'], isTrue);
              for (final flag in [
                'forcedCancel',
                'inputTailDiscarded',
                'inputCoverageIncomplete',
                'inputIntegrityError',
              ]) {
                expect(terminal[flag], isFalse);
              }
              stage = 'inspect-$attempt';
              final probe = await _run(Platform.environment['PURELIVE_FFPROBE']!, [
                '-v',
                'error',
                '-show_packets',
                '-show_streams',
                '-show_entries',
                'packet=stream_index,pts_time,dts_time,duration_time:stream=index,codec_type',
                '-of',
                'json',
                mp4.path,
              ]);
              final timeline = inspectMediaPacketTimeline(jsonDecode(probe) as Map);
              final tracks = (timeline['tracks'] as List).cast<Map>();
              expect(tracks.singleWhere((t) => t['type'] == 'video')['packets'], 180);
              expect(tracks.singleWhere((t) => t['type'] == 'audio')['packets'], 282);
              for (final t in tracks) {
                expect(t['completePresentationTimestamps'], isTrue);
                expect(t['observedDtsRegressions'], 0);
                expect(t['knownInternalGapCount'], 0);
              }
              await _run(Platform.environment['PURELIVE_FFMPEG']!, [
                '-v',
                'error',
                '-i',
                mp4.path,
                '-xerror',
                '-fps_mode',
                'passthrough',
                '-enc_time_base',
                'demux',
                '-f',
                'null',
                '-',
              ]);
              reports.add({
                'attempt': attempt,
                'output': mp4.path,
                'bytes': size,
                'provisionalBytes': provisional,
                'stopAndFinalizeMs': stop.elapsedMilliseconds,
                'terminal': terminal,
                'packetTimeline': timeline,
                'fullDecode': 'exit0-stderr-empty',
                'task': current.toJson(),
                'released': true,
              });
            }
            expect(resolver.calls, 2);
            expect(reports.map((r) => r['output']).toSet().length, 2);
            await File(p.join(output.path, 'summary.json')).writeAsString(
              jsonEncode({
                'status': 'passed',
                'scope': 'real-controller-native-loopback-not-gui-android-or-long-duration',
                'ownedInput': ownedMode,
                'attempts': reports,
                'events': events,
                'requests': requests,
              }),
            );
          } finally {
            if (controller != null && task != null) {
              await controller!.stopTask(task!).timeout(const Duration(seconds: 40));
            }
            await origin.close(force: true);
            await server.cancel();
            await Future.wait(jobs.toList()).timeout(const Duration(seconds: 5));
          }
        }, _Network());
      } catch (error) {
        await File(p.join(output.path, 'failure.json')).writeAsString(
          jsonEncode({
            'stage': stage,
            'error': error.toString(),
            'attempts': reports,
            'events': events,
            'task': task?.toJson(),
          }),
        );
        rethrow;
      } finally {
        if (controller != null) Get.delete<RecorderController>(force: true);
        await subscription.cancel();
        configureRecorderProxyRouting(null);
        Get.reset();
        await Hive.close();
      }
    },
    skip: Platform.environment['PURELIVE_CONTROLLER_NATIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _Network extends HttpOverrides {}

class _Resolver extends StreamResolverService {
  _Resolver(this.url, {this.owned = false});
  final bool owned;
  final String url;
  int calls = 0;
  @override
  Future<ResolvedRecordStream> resolveStream({
    required String roomId,
    required String platform,
    required String preferredQuality,
    String? previousQualityId,
    int? previousLineIndex,
    bool renewCurrent = false,
    LiveQualityDiscoveryScope? discoveryScope,
  }) async {
    discoveryScope?.checkActive();
    calls++;
    if (owned) {
      return ResolvedRecordStream.owned(
        input: const _Recipe(),
        quality: LivePlayQuality(quality: 'fixture', id: 'fixture'),
        qualityCursorId: 'fixture',
      );
    }
    return ResolvedRecordStream(
      url: url,
      quality: LivePlayQuality(quality: 'fixture', id: 'fixture'),
      qualityCursorId: 'fixture',
      lineIndex: 0,
      candidateUrls: [url],
    );
  }
}

Future<void> _until(bool Function() done) async {
  final clock = Stopwatch()..start();
  while (!done() && clock.elapsed < const Duration(seconds: 30)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'native controller did not reach the media boundary');
}

Future<String> _run(String exe, List<String> arguments) async {
  final process = await Process.start(exe, arguments);
  var ended = false;
  Future<String> collect(Stream<List<int>> input) async {
    final bytes = <int>[];
    await for (final chunk in input) {
      if (bytes.length + chunk.length > 1024 * 1024) throw StateError('inspection output limit');
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  try {
    final results = await Future.wait<Object>([process.exitCode, collect(process.stdout), collect(process.stderr)])
        .timeout(const Duration(seconds: 20));
    ended = true;
    expect(results[0], 0);
    expect((results[2] as String).trim(), isEmpty);
    return results[1] as String;
  } finally {
    if (!ended) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}

class _Recipe implements LiveInputRecipe {
  const _Recipe();
  @override
  String get identity => 'loopback-recording-fixture';
}

class _OwnedRelay implements OwnedRecordInput {
  _OwnedRelay(this.relay);
  final FFmpegHlsInputRelay relay;
  int closes = 0;
  @override
  bool isClosed = false;
  @override
  Uri get inputUri => relay.inputUri;
  @override
  Duration get drainTimeout => relay.drainTimeout;
  @override
  bool get finishRequested => relay.finishRequested;
  @override
  bool get inputTailDiscarded => relay.inputTailDiscarded;
  @override
  set onCoverageIncomplete(void Function()? listener) => relay.onCoverageIncomplete = listener;
  @override
  List<String> replaceFirstInput(Iterable<String> arguments) => relay.replaceFirstInput(arguments);
  @override
  Future<void> finish() => relay.finish();
  @override
  Future<void> close() async {
    closes++;
    isClosed = true;
    await relay.close();
  }
}
