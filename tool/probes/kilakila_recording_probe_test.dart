// Opt-in real Windows FFmpegKit recording/finalization. Public short media is
// retained only in the caller's ignored output directory; credentials and
// signed input URLs are never written by this probe.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pure_live/core/network/http_client.dart' as app_http;
import 'package:pure_live/domains/live/data/platforms/sites.dart';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/data/platforms/kilakila/kilakila_site.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_header_factory.dart';
import 'package:pure_live/domains/recorder/data/services/recording_output_metrics.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

void main() {
  test(
    'Kilakila production resolver, native segment growth, stop, MP4 commit and independent decode',
    () async {
      final outputRoot = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT'];
      final ffprobe = Platform.environment['PURELIVE_FFPROBE'];
      final ffmpeg = Platform.environment['PURELIVE_FFMPEG'];
      expect(outputRoot, isNotEmpty);
      expect(ffprobe, isNotEmpty);
      expect(ffmpeg, isNotEmpty);
      final hive = await Directory.systemTemp.createTemp('purelive-recording-probe-settings-');
      Hive.init(hive.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      final output = await Directory(p.join(outputRoot!, 'Kilakila 录制 ${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final manager = FFmpegManager.to;
      LiveRecordTask? task;
      Future<void>? recording;
      StreamSubscription<Object?>? events;
      StreamSubscription<VideoProcessEvent>? mergeEvents;
      var stage = 'official-metadata';
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final previous = app_http.HttpClient.instance.dio;
          final dio = Dio(
            BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 20)),
          )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => HttpClient());
          app_http.HttpClient.instance.dio = dio;
          try {
            final site = Sites.of('kilakila').liveSite as KilakilaSite;
            final categories = (await site.getCategores(1, 30)).single.children;
            final risingStars = categories.singleWhere((category) => category.areaId == '107');
            final directory = await site.getDirectoryPage(category: risingStars);
            expect(directory.rooms, isNotEmpty);
            final requestedOwner = Platform.environment['PURELIVE_KILAKILA_RECORDING_UID'];
            final author = requestedOwner ?? directory.rooms.firstWhere((room) => room.isLiveNow).roomId!;
            expect(RegExp(r'^[1-9][0-9]{0,31}$').hasMatch(author), isTrue);
            final transport = Platform.environment['PURELIVE_KILAKILA_RECORDING_TRANSPORT'] ?? 'hls';
            expect({'hls', 'flv'}, contains(transport));
            final source = await StreamResolverService().resolveStream(
              roomId: author,
              platform: 'kilakila',
              preferredQuality: transport,
            );
            expect(source.qualityCursorId, transport);
            expect(source.invalidAt, isNull, reason: 'No verified hard-expiry timestamp is advertised.');
            final sourceUri = Uri.parse(source.url);
            expect(sourceUri.scheme, 'https');
            expect(sourceUri.host, 'pull.live.hongrenshuo.com.cn');
            expect(sourceUri.path, endsWith(transport == 'hls' ? '.m3u8' : '.flv'));
            final current = LiveRecordTask.fromRoom(
              LiveRoom(platform: 'kilakila', roomId: author, nick: 'Kilakila probe'),
            )..outputDir = output.path;
            task = current;
            final headers = await FFmpegHeaderFactory.build(platform: 'kilakila', roomId: author);
            final arguments = FFmpegCommandBuilder.buildRecordArguments(
              url: source.url,
              outputDir: output.path,
              segmentTime: 10,
              preferBestStream: true,
              rwTimeout: 10,
              threadQueueSize: 512,
              filePrefix: current.recordingFilePrefix,
              headers: headers,
            );
            stage = 'native-initialization';
            await manager.initialize();
            final version = FFmpegKitExtended.getFFmpegVersion();
            final observed = <String>[];
            events = manager.stream.listen((event) {
              if (event.taskId == current.taskId) observed.add(event.type.name);
            });
            final tracker = const RecordingOutputMetrics().track(
              directoryPath: output.path,
              filePrefix: current.recordingFilePrefix,
            );
            final samples = <int>[];
            var ended = false;
            Object? startError;
            stage = 'native-recording';
            recording = manager
                .start(taskId: current.taskId, arguments: arguments, liveRecording: true)
                .then<void>(
                  (_) {
                    ended = true;
                  },
                  onError: (Object error) {
                    startError = error;
                    ended = true;
                  },
                );
            for (var second = 0; second < 26 && !ended; second++) {
              await Future<void>.delayed(const Duration(seconds: 1));
              samples.add((await tracker.sample()).bytes);
            }
            expect(startError, isNull, reason: 'Native recording must open the selected production input.');
            expect(ended, isFalse, reason: 'The live input must remain active until the explicit stop.');
            final session = manager.getSession(current.taskId);
            current.recordedSeconds = session?.recordedSeconds ?? 0;
            stage = 'native-stop';
            await manager.stop(current.taskId);
            await recording!.timeout(const Duration(seconds: 15));
            expect(manager.isRunning(current.taskId), isFalse);
            expect(observed, contains(FFmpegEventType.started.name));
            expect(observed, contains(FFmpegEventType.complete.name));
            final segments = await const RecordingOutputMetrics().measure(
              directoryPath: output.path,
              filePrefix: current.recordingFilePrefix,
            );
            expect(segments.segmentCount, greaterThanOrEqualTo(2));
            expect(samples.where((bytes) => bytes > 0).toSet().length, greaterThanOrEqualTo(3));
            for (var index = 1; index < samples.length; index++) {
              expect(samples[index], greaterThanOrEqualTo(samples[index - 1]));
            }
            expect(segments.bytes, greaterThan(100 * 1024));
            current.fileSize = segments.bytes;
            // Retain diagnostic input copies before the production finalizer commits.
            // They live below a distinct subdirectory and never enter its manifest.
            final retained = await Directory(p.join(output.path, 'probe-source')).create();
            await for (final entry in output.list()) {
              if (entry is File && p.extension(entry.path) == '.ts') {
                await entry.copy(p.join(retained.path, p.basename(entry.path)));
              }
            }
            stage = 'production-mp4-finalization';
            final mergeProgress = <double>[];
            VideoProcessEvent? mergedEvent;
            mergeEvents = VideoProcessorService.to.stream.listen((event) {
              if (event.taskId != current.taskId) return;
              if (event.type == VideoProcessEventType.progress) mergeProgress.add(event.progress);
              if (event.type == VideoProcessEventType.completed) mergedEvent = event;
            });
            expect(await VideoProcessorService.to.convertToMp4(task: current), isTrue);
            await Future<void>.delayed(Duration.zero);
            expect(mergedEvent?.progress, 1);
            expect(mergeProgress.every((value) => value >= 0 && value < 1), isTrue);
            expect(VideoProcessorService.to.isProcessing(current.taskId), isFalse);
            final committed = await const RecordingOutputMetrics().measureFinalized(
              directoryPath: output.path,
              filePrefix: current.recordingFilePrefix,
            );
            expect(committed.bytes, greaterThan(100 * 1024));
            final remaining = await const RecordingOutputMetrics().measure(
              directoryPath: output.path,
              filePrefix: current.recordingFilePrefix,
            );
            expect(remaining.segmentCount, 0);
            final mp4 = p.join(output.path, '${current.recordingFilePrefix}.mp4');
            expect(await File(mp4).length(), committed.bytes);
            stage = 'independent-file-inspection';
            final inspection = await _runOwned(ffprobe!, [
              '-v',
              'error',
              '-show_streams',
              '-show_format',
              '-of',
              'json',
              mp4,
            ], timeout: const Duration(seconds: 15));
            expect(inspection.exitCode, 0);
            final metadata = jsonDecode(inspection.stdout as String) as Map<String, dynamic>;
            final format = metadata['format'] as Map<String, dynamic>;
            final duration = double.parse(format['duration'] as String);
            final streams = (metadata['streams'] as List).cast<Map<String, dynamic>>();
            expect(duration, greaterThan(15));
            expect(duration, lessThan(40));
            expect(streams.any((stream) => stream['codec_type'] == 'audio'), isTrue);
            stage = 'independent-decode';
            final decode = await _runOwned(ffmpeg!, [
              '-v',
              'error',
              '-i',
              mp4,
              '-xerror',
              // Preserve the demux clock for VFR input: rounding decoded frames
              // to the nominal FPS can manufacture null-mux DTS collisions.
              '-fps_mode',
              'passthrough',
              '-enc_time_base',
              'demux',
              '-f',
              'null',
              '-',
            ], timeout: const Duration(seconds: 30));
            await File(p.join(output.path, 'decode-diagnostics.json')).writeAsString(
              jsonEncode({
                'exitCode': decode.exitCode,
                'stderr': decode.stderr,
                'scope': 'entire-output-with-xerror-and-demux-clock',
              }),
            );
            expect(decode.exitCode, 0);
            expect((decode.stderr as String).trim(), isEmpty, reason: 'Exit zero alone is not clean decoding.');
            final summary = {
              'probe': 'kilakila-production-native-recording',
              'utc': DateTime.now().toUtc().toIso8601String(),
              'transport': transport,
              'ownerUid': author,
              'directoryType': 107,
              'risingStarCount': directory.rooms.length,
              'requestedOwner': requestedOwner != null,
              'nativeEvents': observed,
              'unknownHardExpiry': source.invalidAt == null,
              'nativeFfmpeg': version,
              'quality': source.quality.quality,
              'qualityId': source.qualityCursorId,
              'segmentCount': segments.segmentCount,
              'provisionalBytes': segments.bytes,
              'committedBytes': committed.bytes,
              'finalizedMetricMatchesFile': true,
              'output': mp4,
              'durationSeconds': duration,
              'growthSamples': samples,
              'nativeStopped': true,
              'registeredProductionResolver': true,
              'routing': 'direct anonymous API and media; app proxy/relay and UI not covered',
              'finalizerReleased': true,
              'sourceSegmentsRemovedAfterCommit': true,
              'independentDecodeExit': decode.exitCode,
              'independentDecodeScope': 'entire-output-with-xerror-and-demux-clock',
              'independentDecodeStderrEmpty': true,
              'diagnosticSourceCopiesRetained': true,
              'mergeProgressSamples': mergeProgress,
              'streams': streams
                  .map(
                    (s) => {
                      'type': s['codec_type'],
                      'codec': s['codec_name'],
                      'width': s['width'],
                      'height': s['height'],
                    },
                  )
                  .toList(),
              'credentialsPersisted': false,
              'evidenceLayer': 'windows-native-recording-and-finalization-not-device-ui-or-long-duration',
            };
            await File(p.join(output.path, 'summary.json'))
                .writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
            // ignore: avoid_print
            print(jsonEncode(summary));
          } finally {
            app_http.HttpClient.instance.dio = previous;
            dio.close(force: true);
          }
        }, _RealNetwork());
      } catch (error) {
        fail('Kilakila recording probe failed at $stage (${error.runtimeType})');
      } finally {
        if (task != null && manager.isRunning(task!.taskId)) await manager.stop(task!.taskId);
        await recording?.timeout(const Duration(seconds: 15));
        await events?.cancel();
        await mergeEvents?.cancel();
        Get.reset();
        await Hive.close();
        await hive.delete(recursive: true);
      }
    },
    skip: Platform.environment['PURELIVE_KILAKILA_RECORDING_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends HttpOverrides {}

Future<ProcessResult> _runOwned(String executable, List<String> arguments, {required Duration timeout}) async {
  final process = await Process.start(executable, arguments);
  var completed = false;
  Future<String> collect(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > 1024 * 1024) throw StateError('Inspection output limit');
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  try {
    final result = await Future.wait<Object>([
      process.exitCode,
      collect(process.stdout),
      collect(process.stderr),
    ], eagerError: true).timeout(timeout);
    completed = true;
    return ProcessResult(process.pid, result[0] as int, result[1], result[2]);
  } finally {
    if (!completed) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}
