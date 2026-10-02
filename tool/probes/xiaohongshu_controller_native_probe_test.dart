// Opt-in real registered XHS source -> user recording controller -> FFmpegKit.
// Only storage and the local network route are isolated; no fake room/source,
// hardcoded media URL, replacement recorder or finalizer is used.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/network/http_client.dart' as app_http;
import 'package:pure_live/get/get.dart';
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
    'XHS real controller captures, stops, finalizes, releases and restarts',
    () async {
      final output = await Directory(
        p.join(
          Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!,
          'xhs-controller-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final root = await Directory(p.join(output.path, 'records')).create();
      Hive.init((await Directory(p.join(output.path, 'hive')).create()).path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      var mediaRouteCalls = 0;
      configureRecorderProxyRouting((_) {
        mediaRouteCalls++;
        return 'DIRECT';
      });
      final reports = <Map<String, Object?>>[];
      final events = <Map<String, Object?>>[];
      final requests = <Map<String, Object?>>[];
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
      var stage = 'setup';
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final previous = app_http.HttpClient.instance.dio;
          final dio = Dio(
            BaseOptions(connectTimeout: const Duration(seconds: 15)),
          )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT');
          dio.interceptors.add(
            InterceptorsWrapper(
              onResponse: (response, handler) {
                if (requests.length < 32) {
                  requests.add({
                    'status': response.statusCode,
                    'host': response.requestOptions.uri.host,
                    'kind': response.requestOptions.uri.path.startsWith('/livestream/') ? 'share-page' : 'other',
                    'redirectsDisabled': !response.requestOptions.followRedirects,
                  });
                }
                handler.next(response);
              },
            ),
          );
          app_http.HttpClient.instance.dio = dio;
          try {
            final cache = Get.put(CacheService(defaultDirectoryResolver: () async => root));
            Get.put(StreamResolverService());
            final settings = RecordSettingsController()..segmentTime.value = 4;
            final recorder = Get.put<RecorderController>(
              // ignore: invalid_use_of_visible_for_testing_member
              RecorderController.forTesting(
                settings: settings,
                ffmpeg: manager,
                // ignore: invalid_use_of_visible_for_testing_member
                scheduler: FFmpegScheduler.forTesting(),
                outputSampleInterval: const Duration(milliseconds: 100),
              ),
            );
            controller = recorder;
            await recorder.restoreAndAutoPoll();
            final current = task = LiveRecordTask(
              taskId: 'xiaohongshu_native_probe',
              roomId: '570429070963278308',
              platform: 'xiaohongshu',
              title: 'Public XHS native acceptance',
              nick: 'XHS acceptance',
              avatar: '',
              cover: '',
              createTime: DateTime.now(),
              autoReconnect: false,
            );
            recorder.tasks.add(current);
            for (var attempt = 0; attempt < 2; attempt++) {
              final eventStart = events.length;
              stage = 'start-$attempt';
              expect(await recorder.startTask(current), true);
              await _until(
                () =>
                    manager.getSession(current.taskId)?.recordedSeconds != null &&
                    manager.getSession(current.taskId)!.recordedSeconds >= 8 &&
                    current.fileSize > 0,
                () =>
                    current.status == RecordStatus.failed ||
                    (events.skip(eventStart).any((e) => e['type'] == 'complete')),
              );
              final relay = manager.getSession(current.taskId)!.inputRelay!;
              expect(relay.prefetchEnabled, true);
              // Enabling the option does not imply admission. For example,
              // the observed legacy EXT-X-ALLOW-CACHE tag retains the original
              // relay path instead of silently dropping unsupported metadata.
              // ignore: invalid_use_of_visible_for_testing_member
              final prefetchFeeds = relay.prefetchFeedCount;
              expect(cache.isDirectoryProtected(current.outputDir!), true);
              final provisional = current.fileSize;
              final recordedSeconds = manager.getSession(current.taskId)!.recordedSeconds;
              final prefix = current.recordingFilePrefix;
              stage = 'stop-and-finalize-$attempt';
              final stop = Stopwatch()..start();
              await recorder.stopTask(current).timeout(const Duration(seconds: 45));
              stop.stop();
              expect(current.status, RecordStatus.stopped);
              expect(current.wasStoppedByUser, true);
              expect(current.pendingAttempts, isEmpty);
              expect(current.lastError, null);
              expect(current.inputTailDiscarded, false);
              expect(current.inputCoverageIncomplete, false);
              expect(recorder.runningCount, 0);
              expect(recorder.queuedCount, 0);
              expect(manager.isRunning(current.taskId), false);
              expect(VideoProcessorService.to.isProcessing(current.taskId), false);
              expect(cache.isDirectoryProtected(current.outputDir!), false);
              // ignore: invalid_use_of_visible_for_testing_member
              expect(relay.prefetchBodyCount, 0);
              final mp4 = File(p.join(current.outputDir!, '$prefix.mp4'));
              final size = await mp4.length();
              expect(size, greaterThan(10000));
              expect(current.fileSize, size);
              expect(await Directory(current.outputDir!).list().where((f) => p.extension(f.path) == '.ts').length, 0);
              final terminal = events
                  .skip(eventStart)
                  .lastWhere((e) => e['task'] == current.taskId && e['type'] == 'complete');
              expect(terminal['code'], 0);
              expect(terminal['manualStop'], true);
              expect(terminal['inputDrained'], true);
              for (final flag in [
                'forcedCancel',
                'inputTailDiscarded',
                'inputCoverageIncomplete',
                'inputIntegrityError',
              ]) {
                expect(terminal[flag], false);
              }
              stage = 'inspect-$attempt';
              final probe = await _run(Platform.environment['PURELIVE_FFPROBE']!, [
                '-v',
                'error',
                '-show_packets',
                '-show_streams',
                '-show_entries',
                'packet=stream_index,pts_time,dts_time,duration_time:stream=index,codec_type,codec_name,width,height',
                '-of',
                'json',
                mp4.path,
              ]);
              await File(p.join(output.path, 'packets-$attempt.json')).writeAsString(probe);
              final packetData = jsonDecode(probe) as Map;
              final timeline = inspectMediaPacketTimeline(packetData);
              final tracks = (timeline['tracks'] as List).cast<Map>();
              final video = tracks.singleWhere((t) => t['type'] == 'video');
              final audio = tracks.singleWhere((t) => t['type'] == 'audio');
              expect(video['packets'], greaterThan(0));
              expect(audio['packets'], greaterThan(0));
              for (final track in tracks) {
                expect(track['completePresentationTimestamps'], true);
                expect(track['observedDtsRegressions'], 0);
                expect(track['knownInternalGapCount'], 0);
              }
              final av = timeline['av'] as Map;
              expect(av['commonCoveredSeconds'] as num, greaterThanOrEqualTo(7.5));
              expect((av['audioMinusVideoStartSeconds'] as num).abs(), lessThanOrEqualTo(.1));
              expect((av['audioMinusVideoEndSeconds'] as num).abs(), lessThanOrEqualTo(.1));
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
                'recordedSecondsAtStop': recordedSeconds,
                'prefetchFeedsAtStop': prefetchFeeds,
                'stopAndFinalizeMs': stop.elapsedMilliseconds,
                'terminal': terminal,
                'packetTimeline': timeline,
                'streams': packetData['streams'],
                'fullDecode': 'exit0-stderr-empty',
                'released': true,
                'pendingAttempts': current.pendingAttempts.length,
              });
            }
            expect(reports.map((r) => r['output']).toSet().length, 2);
            expect(requests.where((r) => r['kind'] == 'share-page').length, greaterThanOrEqualTo(2));
            await File(p.join(output.path, 'summary.json')).writeAsString(
              jsonEncode({
                'status': 'passed',
                'scope': 'real-controller-native-public-source-not-gui-android-long-duration-or-source-completeness',
                'attempts': reports,
                'events': events,
                'requests': requests,
                'mediaRouteCalls': mediaRouteCalls,
              }),
            );
          } finally {
            try {
              if (controller != null && task != null) {
                await controller!.stopTask(task!).timeout(const Duration(seconds: 45));
              }
            } finally {
              app_http.HttpClient.instance.dio = previous;
              dio.close(force: true);
            }
          }
        }, _Network());
      } catch (error) {
        await File(p.join(output.path, 'failure.json')).writeAsString(
          jsonEncode({
            'stage': stage,
            'error': error.toString(),
            'attempts': reports,
            'events': events,
            'requests': requests,
            'status': task?.status.name,
            'lastError': task?.lastError,
          }),
        );
        rethrow;
      } finally {
        if (controller != null) {
          Get.delete<RecorderController>(force: true);
        }
        await subscription.cancel();
        configureRecorderProxyRouting(null);
        Get.reset();
        await Hive.close();
      }
    },
    skip: Platform.environment['PURELIVE_XHS_CONTROLLER_NATIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _Network extends HttpOverrides {}

Future<void> _until(bool Function() done, bool Function() ended) async {
  final clock = Stopwatch()..start();
  while (!done() && !ended() && clock.elapsed < const Duration(seconds: 60)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(done(), true, reason: 'native recording ended or did not reach eight media seconds');
}

Future<String> _run(String exe, List<String> arguments) async {
  final process = await Process.start(exe, arguments);
  var ended = false;
  Future<String> collect(Stream<List<int>> input) async {
    final bytes = <int>[];
    await for (final chunk in input) {
      if (bytes.length + chunk.length > 2 * 1024 * 1024) {
        throw StateError('inspection output limit');
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  try {
    final result = await Future.wait<Object>([process.exitCode, collect(process.stdout), collect(process.stderr)])
        .timeout(const Duration(seconds: 25));
    ended = true;
    expect(result[0], 0);
    expect((result[2] as String).trim(), isEmpty);
    return result[1] as String;
  } finally {
    if (!ended) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}
