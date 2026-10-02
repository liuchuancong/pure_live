// Opt-in real Windows FFmpegKit recording/finalization. Public short media is
// retained only in the caller's ignored output directory; credentials and
// signed input URLs are never written by this probe.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/live/data/platforms/acfun/acfun_api.dart';
import 'package:pure_live/domains/live/data/platforms/acfun/acfun_site.dart';
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
    'AcFun production resolver, native segment growth, stop, MP4 commit and independent decode',
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
      final output = await Directory(p.join(outputRoot!, 'AcFun 录制 ${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final manager = FFmpegManager.to;
      LiveRecordTask? task;
      Future<void>? recording;
      StreamSubscription<Object?>? events;
      StreamSubscription<VideoProcessEvent>? mergeEvents;
      var stage = 'official-metadata';
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
          final proxy = Platform.environment['PURELIVE_PROBE_PROXY'];
          if (proxy?.isNotEmpty == true) {
            final address = Uri.parse(proxy!);
            client.findProxy = (_) => 'PROXY ${address.host}:${address.port}';
          }
          try {
            final api = AcfunApi(
              request: (method, url, {query, body, headers}) async {
                final uri = Uri.parse(url)
                    .replace(queryParameters: query?.map((key, value) => MapEntry(key, '$value')));
                final request = await client.openUrl(method, uri);
                headers?.forEach((key, value) {
                  if (value != null) request.headers.set(key, value);
                });
                if (body != null) {
                  request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
                  request.write(Uri(queryParameters: body.map((key, value) => MapEntry(key, '$value'))).query);
                }
                final response = await request.close().timeout(const Duration(seconds: 15));
                if (response.statusCode != 200) throw const FormatException('Non-success response');
                final buffer = BytesBuilder(copy: false);
                await for (final bytes in response.timeout(const Duration(seconds: 15))) {
                  buffer.add(bytes);
                  if (buffer.length > 1024 * 1024) throw const FormatException('Oversized response');
                }
                return jsonDecode(utf8.decode(buffer.takeBytes()));
              },
            );
            final directory = await api.directory(count: 2);
            expect(directory.rooms, isNotEmpty);
            final author = AcfunApi.text(directory.rooms.first['authorId']);
            final resolver = StreamResolverService(siteResolver: (_) => AcfunSite(api: api));
            final source = await resolver.resolveStream(roomId: author, platform: 'acfun', preferredQuality: '原画');
            final current = LiveRecordTask.fromRoom(LiveRoom(platform: 'acfun', roomId: author, nick: 'AcFun probe'))
              ..outputDir = output.path;
            task = current;
            final headers = await FFmpegHeaderFactory.build(platform: 'acfun', roomId: author);
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
            stage = 'independent-file-inspection';
            final inspection = await Process.run(ffprobe!, [
              '-v',
              'error',
              '-show_streams',
              '-show_format',
              '-of',
              'json',
              mp4,
            ]).timeout(const Duration(seconds: 15));
            expect(inspection.exitCode, 0);
            final metadata = jsonDecode(inspection.stdout as String) as Map<String, dynamic>;
            final format = metadata['format'] as Map<String, dynamic>;
            final duration = double.parse(format['duration'] as String);
            final streams = (metadata['streams'] as List).cast<Map<String, dynamic>>();
            expect(duration, greaterThan(15));
            expect(duration, lessThan(40));
            expect(streams.any((stream) => stream['codec_type'] == 'video'), isTrue);
            expect(streams.any((stream) => stream['codec_type'] == 'audio'), isTrue);
            stage = 'independent-decode';
            final decode = await Process.run(ffmpeg!, [
              '-v',
              'error',
              '-i',
              mp4,
              '-xerror',
              '-f',
              'null',
              '-',
            ]).timeout(const Duration(seconds: 30));
            expect(decode.exitCode, 0);
            final summary = {
              'probe': 'acfun-production-native-recording',
              'nativeFfmpeg': version,
              'quality': source.quality.quality,
              'qualityId': source.qualityCursorId,
              'segmentCount': segments.segmentCount,
              'provisionalBytes': segments.bytes,
              'committedBytes': committed.bytes,
              'output': mp4,
              'durationSeconds': duration,
              'growthSamples': samples,
              'nativeStopped': true,
              'finalizerReleased': true,
              'sourceSegmentsRemovedAfterCommit': true,
              'independentDecodeExit': decode.exitCode,
              'independentDecodeScope': 'entire-output-with-xerror',
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
            client.close(force: true);
          }
        }, _RealNetwork());
      } catch (error) {
        fail('AcFun recording probe failed at $stage (${error.runtimeType})');
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
    skip: Platform.environment['PURELIVE_ACFUN_RECORDING_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends HttpOverrides {}
