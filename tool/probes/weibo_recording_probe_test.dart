// Opt-in actual WeiboSite -> production recorder manager -> finalizer. Registry,
// controller UI, Android and long-running acceptance remain separate stages.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/common/http_client.dart' as app_http;
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/weibo/weibo_site.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/recorder/services/ffmpeg_flv_input_relay.dart';
import 'package:pure_live/recorder/services/recorder_proxy_routing.dart';
import 'package:pure_live/recorder/services/recording_output_metrics.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';

import 'media_packet_timeline.dart';
import 'recording_clock_probe_support.dart';

void main() {
  test(
    'Weibo production adapter records, drains, finalizes and completely decodes public media',
    () async {
      final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!;
      final output = await Directory(p.join(base, 'weibo-${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final settings = await Directory(p.join(output.path, 'isolated-settings')).create();
      Hive.init(settings.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      var routeCalls = 0;
      configureRecorderProxyRouting((_) {
        routeCalls++;
        return 'DIRECT';
      });
      final manager = FFmpegManager.to;
      final inputEvidence = FlvRelayDiagnostics(maxCaptureBytes: 32 * 1024 * 1024);
      final evidenceDir = await Directory(p.join(output.path, 'input-evidence')).create();
      LiveRecordTask? task;
      Future<void>? recording;
      final events = <Map<String, Object?>>[];
      final requests = <Map<String, Object?>>[];
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'contract': 'failed',
        'stage': 'directory',
        'registered': false,
        'route': 'DIRECT',
        'deviceUi': false,
      };
      final subscription = manager.stream.listen((e) {
        if (e.taskId != task?.taskId ||
            ![
              FFmpegEventType.startAck,
              FFmpegEventType.started,
              FFmpegEventType.complete,
              FFmpegEventType.error,
            ].contains(e.type)) {
          return;
        }
        events.add({
          'type': e.type.name,
          for (final key in [
            'code',
            'manualStop',
            'inputDrained',
            'forcedCancel',
            'inputTailDiscarded',
            'inputCoverageIncomplete',
            'inputIntegrityError',
          ])
            if (e.data.containsKey(key)) key: e.data[key],
        });
      });
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final previous = app_http.HttpClient.instance.dio;
          final dio = Dio(
            BaseOptions(connectTimeout: const Duration(seconds: 15)),
          )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT');
          dio.interceptors.add(
            InterceptorsWrapper(
              onResponse: (r, h) {
                requests.add({
                  'kind': r.requestOptions.uri.path.contains('pc_recommend') ? 'directory' : 'detail',
                  'status': r.statusCode,
                });
                h.next(r);
              },
            ),
          );
          app_http.HttpClient.instance.dio = dio;
          try {
            final site = WeiboSite();
            final directory = await site.getDirectoryPage();
            expect(directory.rooms, isNotEmpty);
            report['directoryCards'] = directory.rooms.length;
            final candidate = directory.rooms.first;
            report['stage'] = 'detail';
            final detail = await site.getRoomDetailForRecording(roomId: candidate.roomId!, platform: site.id);
            expect(detail.userId, candidate.userId);
            expect(detail.isLiveNow, true);
            final quality = (await site.getPlayQualites(detail: detail)).single;
            report['stage'] = 'fresh-resolution';
            final resolution = await site.resolvePlayUrls(detail: detail, quality: quality);
            expect(resolution.urls, isNotEmpty);
            expect(resolution.appliedQualityData, 'original');
            report['declaredMediaExtension'] = p.extension(Uri.parse(resolution.urls.first).path).toLowerCase();
            final current = task = LiveRecordTask.fromRoom(detail)..outputDir = output.path;
            final headers = await FFmpegHeaderFactory.build(platform: site.id, roomId: detail.roomId!);
            final arguments = FFmpegCommandBuilder.buildRecordArguments(
              url: resolution.urls.first,
              outputDir: output.path,
              segmentTime: 10,
              preferBestStream: true,
              rwTimeout: 15,
              threadQueueSize: 512,
              filePrefix: current.recordingFilePrefix,
              headers: headers,
            );
            report['stage'] = 'native-start';
            await manager.initialize();
            var ended = false;
            Object? startError;
            recording = manager
                .start(taskId: current.taskId, arguments: arguments, liveRecording: true, flvDiagnostics: inputEvidence)
                .then<void>(
                  (_) {
                    ended = true;
                  },
                  onError: (Object e) {
                    startError = e;
                    ended = true;
                  },
                );
            final tracker = const RecordingOutputMetrics().track(
              directoryPath: output.path,
              filePrefix: current.recordingFilePrefix,
            );
            final samples = <Map<String, int>>[];
            final clock = Stopwatch()..start();
            var reached = false;
            while (clock.elapsed < const Duration(seconds: 60) && !ended) {
              await Future<void>.delayed(const Duration(milliseconds: 500));
              final snapshot = await tracker.sample();
              final seconds = manager.getSession(current.taskId)?.recordedSeconds ?? 0;
              samples.add({
                'elapsedMs': clock.elapsedMilliseconds,
                'bytes': snapshot.bytes,
                'segments': snapshot.segmentCount,
                'mediaSeconds': seconds,
              });
              if (seconds >= 12 && snapshot.segmentCount >= 2) {
                reached = true;
                break;
              }
            }
            clock.stop();
            report['captureSamples'] = samples;
            report['targetReached'] = reached;
            expect(startError, isNull);
            expect(ended, false);
            expect(reached, true);
            final session = manager.getSession(current.taskId)!;
            current.recordedSeconds = session.recordedSeconds;
            report['stage'] = 'manual-stop';
            await manager.stop(current.taskId).timeout(const Duration(seconds: 30));
            await recording!.timeout(const Duration(seconds: 10));
            expect(manager.isRunning(current.taskId), false);
            await Future<void>.delayed(Duration.zero);
            final terminal = events.lastWhere((e) => e['type'] == 'complete' || e['type'] == 'error');
            expect(terminal['code'], 0);
            expect(terminal['manualStop'], true);
            expect(terminal['inputDrained'], true);
            for (final key in [
              'forcedCancel',
              'inputTailDiscarded',
              'inputCoverageIncomplete',
              'inputIntegrityError',
            ]) {
              expect(terminal[key], false, reason: key);
            }
            current.inputTailDiscarded = false;
            current.inputCoverageIncomplete = false;
            final before = await const RecordingOutputMetrics().measure(
              directoryPath: output.path,
              filePrefix: current.recordingFilePrefix,
            );
            expect(before.segmentCount, greaterThanOrEqualTo(2));
            expect(before.bytes, greaterThan(10000));
            current.fileSize = before.bytes;
            expect(samples.map((s) => s['bytes']).where((b) => b! > 0).toSet().length, greaterThanOrEqualTo(3));
            // Snapshot this stopped attempt before the production finalizer
            // removes TS files. No second network stream and no altered input.
            final source = File(p.join(evidenceDir.path, 'submitted.flv'));
            await source.writeAsBytes(inputEvidence.capturedBytes, flush: true);
            expect(inputEvidence.truncated, false);
            expect(inputEvidence.submittedBytes, greaterThan(0));
            expect(await source.length(), inputEvidence.submittedBytes);
            final segments = VideoProcessorService.selectAttemptSegments(
              candidates: (await output.list(followLinks: false).toList()).whereType<File>().where(
                (file) => p.extension(file.path) == '.ts',
              ),
              filePrefix: current.recordingFilePrefix,
            )..sort((a, b) => a.path.compareTo(b.path));
            expect(segments, hasLength(before.segmentCount));
            expect(before.bytes, lessThanOrEqualTo(64 * 1024 * 1024));
            for (final segment in segments) {
              await segment.copy(p.join(evidenceDir.path, p.basename(segment.path)));
            }
            report['retainedSegmentCount'] = segments.length;
            report['stage'] = 'production-finalize';
            expect(await VideoProcessorService.to.convertToMp4(task: current), true);
            expect(VideoProcessorService.to.isProcessing(current.taskId), false);
            final finalMetrics = await const RecordingOutputMetrics().measureFinalized(
              directoryPath: output.path,
              filePrefix: current.recordingFilePrefix,
            );
            final mp4 = p.join(output.path, '${current.recordingFilePrefix}.mp4');
            expect(await File(mp4).length(), finalMetrics.bytes);
            expect(
              (await const RecordingOutputMetrics().measure(
                directoryPath: output.path,
                filePrefix: current.recordingFilePrefix,
              )).segmentCount,
              0,
            );
            report['stage'] = 'packet-inspection';
            final packets = await _run(Platform.environment['PURELIVE_FFPROBE']!, [
              '-v',
              'error',
              '-show_packets',
              '-show_streams',
              '-show_entries',
              'packet=stream_index,pts_time,dts_time,duration_time:stream=index,codec_type,codec_name,width,height',
              '-of',
              'json',
              mp4,
            ]);
            await File(p.join(output.path, 'packets.json')).writeAsString(packets);
            final packetData = jsonDecode(packets) as Map;
            report['streams'] = (packetData['streams'] as List)
                .map(
                  (s) => {
                    for (final key in ['codec_type', 'codec_name', 'width', 'height'])
                      if ((s as Map).containsKey(key)) key: s[key],
                  },
                )
                .toList();
            final timeline = inspectMediaPacketTimeline(packetData);
            report['timeline'] = timeline;
            // Collect the same-attempt input/segment evidence and complete
            // decode before applying timeline gates; a gap must not hide them.
            report['inputEvidence'] = await _inspectInputs(evidenceDir);
            report['stage'] = 'full-decode';
            final decode = await _runResult(Platform.environment['PURELIVE_FFMPEG']!, [
              '-v',
              'error',
              '-threads',
              '4',
              '-i',
              mp4,
              '-xerror',
              '-fps_mode',
              'passthrough',
              '-enc_time_base',
              'demux',
              '-f',
              'null',
              '-',
            ]);
            await File(p.join(output.path, 'decode.stderr')).writeAsString(decode.stderr);
            report['fullDecode'] = decode.code == 0;
            report['fullDecodeStderrEmpty'] = decode.stderr.trim().isEmpty;
            report['stage'] = 'packet-and-decode-gates';
            expect(decode.code, 0);
            expect(decode.stderr.trim(), isEmpty);
            final tracks = (timeline['tracks'] as List).cast<Map>();
            expect(tracks.where((t) => t['type'] == 'audio'), hasLength(1));
            expect(tracks.where((t) => t['type'] == 'video'), hasLength(1));
            for (final track in tracks) {
              expect(track['completePresentationTimestamps'], true);
              expect(track['observedDtsRegressions'], 0);
            }
            // A public source may itself have cadence gaps or AAC time-base
            // quantization. Remux the exact retained FLV once as a reference;
            // the production multi-segment output must retain its decoded
            // content and add no clock step relative to that single remux.
            final reference = File(p.join(evidenceDir.path, 'single-reference.mp4'));
            await _run(Platform.environment['PURELIVE_FFMPEG']!, [
              '-v',
              'error',
              '-i',
              source.path,
              '-map',
              '0:v:0',
              '-map',
              '0:a:0',
              '-c',
              'copy',
              reference.path,
            ]);
            final sourceFrames = await decodeClockMedia(source, evidenceDir, 'source', ['video', 'audio']);
            final referenceFrames = await decodeClockMedia(reference, evidenceDir, 'reference', ['video', 'audio']);
            final outputFrames = await decodeClockMedia(File(mp4), evidenceDir, 'output', ['video', 'audio']);
            final frameComparisons = <String, Map<String, Object?>>{};
            for (final kind in ['video', 'audio']) {
              final sourceToReference = sourceFrames[kind]!.compare(referenceFrames[kind]!);
              final referenceToOutput = referenceFrames[kind]!.compare(outputFrames[kind]!);
              frameComparisons[kind] = {
                'sourceToReference': sourceToReference,
                'referenceToOutput': referenceToOutput,
                'sourceToOutput': sourceFrames[kind]!.compare(outputFrames[kind]!),
              };
              expect(sourceToReference['orderedContentEqual'], true, reason: '$kind reference content');
              expect(referenceToOutput['orderedContentEqual'], true, reason: '$kind final content');
              expect(
                referenceToOutput['offsetSpreadSeconds'] as double,
                lessThanOrEqualTo(kind == 'video' ? 2 / 90000 : 2 / 44100),
                reason: '$kind added clock step',
              );
            }
            report['frameComparisons'] = frameComparisons;
            expect((timeline['av'] as Map)['commonCoveredSeconds'] as num, greaterThanOrEqualTo(10));
            report.addAll({
              'contract': 'passed',
              'stage': 'complete',
              'output': mp4,
              'bytes': finalMetrics.bytes,
              'sourceSegments': before.segmentCount,
              'nativeStopped': true,
              'fullDecode': true,
              'fullDecodeStderrEmpty': true,
              'finalizerReleased': true,
              'mediaRouteCalls': routeCalls,
              'apiRequestCount': requests.length,
            });
          } finally {
            app_http.HttpClient.instance.dio = previous;
            dio.close(force: true);
          }
        }, _RealNetwork());
      } catch (e) {
        report['failureType'] = e.runtimeType.toString();
        if (e is TestFailure) report['invariant'] = e.message?.replaceAll(RegExp(r'https?://[^\s]+'), '[url]');
        rethrow;
      } finally {
        try {
          if (task != null && manager.isRunning(task!.taskId)) {
            await manager.stop(task!.taskId).timeout(const Duration(seconds: 30));
          }
          await recording?.timeout(const Duration(seconds: 15));
        } finally {
          await subscription.cancel();
          await File(p.join(evidenceDir.path, 'submitted.flv')).writeAsBytes(inputEvidence.capturedBytes);
          report['relayEvidence'] = {
            'submittedBytes': inputEvidence.submittedBytes,
            'submittedPackets': inputEvidence.submittedPackets,
            'captureTruncated': inputEvidence.truncated,
            'scope': 'submitted-header-and-tags-not-socket-delivery-or-source-completeness',
          };
          report['nativeEvents'] = events;
          report['apiRequests'] = requests;
          await File(p.join(output.path, 'summary.json'))
              .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
          // ignore: avoid_print
          print(jsonEncode(report));
          Get.reset();
          await Hive.close();
          configureRecorderProxyRouting(null);
        }
      }
    },
    skip: Platform.environment['PURELIVE_WEIBO_RECORDING_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _RealNetwork extends HttpOverrides {}

Future<String> _run(String exe, List<String> args) async {
  final result = await _runResult(exe, args);
  expect(result.code, 0);
  expect(result.stderr.trim(), isEmpty);
  return result.stdout;
}

Future<List<Map<String, Object?>>> _inspectInputs(Directory directory) async {
  final results = <Map<String, Object?>>[];
  final files = (await directory.list(followLinks: false).toList()).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!['.flv', '.ts'].contains(p.extension(file.path))) continue;
    final result = await _runResult(Platform.environment['PURELIVE_FFPROBE']!, [
      '-v',
      'error',
      '-show_packets',
      '-show_streams',
      '-show_entries',
      'packet=stream_index,pts_time,dts_time,duration_time:stream=index,codec_type,codec_name,width,height',
      '-of',
      'json',
      file.path,
    ]);
    await File('${file.path}.packets.json').writeAsString(result.stdout);
    await File('${file.path}.probe.stderr').writeAsString(result.stderr);
    results.add({
      'file': p.basename(file.path),
      'bytes': await file.length(),
      'probeExitCode': result.code,
      'probeStderrEmpty': result.stderr.trim().isEmpty,
      if (result.code == 0) 'timeline': inspectMediaPacketTimeline(jsonDecode(result.stdout) as Map),
    });
  }
  return results;
}

Future<({int code, String stdout, String stderr})> _runResult(String exe, List<String> args) async {
  final process = await Process.start(exe, args);
  var ended = false;
  Future<String> collect(Stream<List<int>> source) async {
    final bytes = <int>[];
    await for (final b in source) {
      if (bytes.length + b.length > 4 * 1024 * 1024) throw StateError('inspection output limit');
      bytes.addAll(b);
    }
    return utf8.decode(bytes);
  }

  try {
    final result = await Future.wait<Object>([process.exitCode, collect(process.stdout), collect(process.stderr)])
        .timeout(const Duration(seconds: 30));
    ended = true;
    return (code: result[0] as int, stdout: result[1] as String, stderr: result[2] as String);
  } finally {
    if (!ended) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}
