// Opt-in local CMAF rendition-window controls. No remote traffic or device use.
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
import 'package:pure_live/domains/recorder/data/services/recorder_proxy_routing.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';

String _window(String source, int skip) {
  final lines = const LineSplitter().convert(source).toList();
  final output = <String>[];
  var index = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
      output.add('#EXT-X-MEDIA-SEQUENCE:$skip');
    } else if (line.startsWith('#EXTINF:')) {
      final uri = lines[++i];
      if (index++ >= skip) output.addAll([line, uri]);
    } else {
      output.add(line);
    }
  }
  return '${output.join('\n')}\n';
}

void main() {
  test(
    'native CMAF distinguishes delivery delay from mismatched rendition start windows',
    () async {
      final fixture = Directory(Platform.environment['PURELIVE_CMAF_WINDOW_FIXTURE']!);
      final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!;
      final ffprobe = Platform.environment['PURELIVE_FFPROBE']!;
      final root = await Directory(p.join(base, 'windows-${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final settings = await Directory(p.join(root.path, 'hive')).create();
      Hive.init(settings.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      configureRecorderProxyRouting((_) => 'DIRECT');
      final files = <String, File>{};
      await for (final entry in fixture.list(recursive: true, followLinks: false)) {
        if (entry is File) files['/${p.relative(entry.path, from: fixture.path).replaceAll('\\', '/')}'] = entry;
      }
      expect(files.keys, containsAll(['/master.m3u8', '/variant_0/index.m3u8', '/variant_1/index.m3u8']));
      final results = <Map<String, Object?>>[];
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          for (final config in [
            (name: 'aligned', skipVideo: 0, delayMs: 0),
            (name: 'aligned-delivery-delay', skipVideo: 0, delayMs: 2500),
            (name: 'video-window-ten-seconds-later', skipVideo: 5, delayMs: 0),
          ]) {
            final directory = await Directory(p.join(root.path, config.name)).create();
            final clock = Stopwatch()..start();
            final requests = <Map<String, Object?>>[];
            final handlers = <Future<void>>{};
            final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
            Future<void> serve(HttpRequest request) async {
              final row = <String, Object?>{'path': request.uri.path, 'requestMs': clock.elapsedMilliseconds};
              requests.add(row);
              try {
                final file = files[request.uri.path];
                if (file == null) {
                  request.response.statusCode = HttpStatus.notFound;
                } else if (request.uri.path.endsWith('.m3u8')) {
                  if (request.uri.path == '/variant_0/index.m3u8' && config.delayMs > 0) {
                    await Future<void>.delayed(Duration(milliseconds: config.delayMs));
                  }
                  final source = await file.readAsString();
                  final skip = request.uri.path == '/variant_0/index.m3u8' ? config.skipVideo : 0;
                  final body = _window(source, skip);
                  row['mediaSequence'] = skip;
                  row['deliveryMs'] = clock.elapsedMilliseconds;
                  request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
                  request.response.write(body);
                } else {
                  final bytes = await file.readAsBytes();
                  row['bytes'] = bytes.length;
                  row['deliveryMs'] = clock.elapsedMilliseconds;
                  request.response.contentLength = bytes.length;
                  request.response.add(bytes);
                }
                await request.response.close();
              } on Object {
                row['connectionEnded'] = true;
                try {
                  await request.response.close();
                } on Object {
                  /* Owned local client ended. */
                }
              }
            }

            final subscription = origin.listen((request) {
              late Future<void> work;
              work = serve(request).whenComplete(() => handlers.remove(work));
              handlers.add(work);
            });
            final native = FFmpegManager.to;
            final taskId = 'cmaf_${config.name}';
            final events = <Map<String, Object?>>[];
            final eventSubscription = native.stream.listen((event) {
              if (event.taskId == taskId) {
                events.add({
                  'type': event.type.name,
                  'atMs': clock.elapsedMilliseconds,
                  'code': event.data['code'],
                  'failureKind': event.data['failure_kind'],
                });
              }
            });
            Future<void>? execution;
            final hlsDiagnostics = HlsRelayDiagnostics();
            try {
              final args = FFmpegCommandBuilder.buildRecordArguments(
                url: 'http://127.0.0.1:${origin.port}/master.m3u8',
                outputDir: directory.path,
                segmentTime: 86400,
                preferBestStream: true,
                rwTimeout: 10,
                threadQueueSize: 512,
                filePrefix: 'capture',
              );
              execution = native.start(
                taskId: taskId,
                arguments: args,
                liveRecording: true,
                hlsDiagnostics: hlsDiagnostics,
              );
              await execution.timeout(const Duration(seconds: 45));
              expect(native.isRunning(taskId), isFalse);
              final captured = await directory.list().where((file) => p.extension(file.path) == '.ts').toList();
              expect(captured, hasLength(1));
              final inspection = await _inspect(ffprobe, captured.single.path);
              final json = jsonDecode(inspection.stdout as String) as Map<String, dynamic>;
              final streams = (json['streams'] as List).cast<Map<String, dynamic>>();
              final packets = (json['packets'] as List).cast<Map<String, dynamic>>();
              final starts = <String, double>{};
              final counts = <String, int>{};
              final maxSteps = <String, double>{};
              for (final stream in streams) {
                final times =
                    packets
                        .where((packet) => packet['stream_index'] == stream['index'] && packet['pts_time'] is String)
                        .map((packet) => double.parse(packet['pts_time'] as String))
                        .toList()
                      ..sort();
                starts[stream['codec_type'] as String] = times.first;
                counts[stream['codec_type'] as String] = times.length;
                var maxStep = 0.0;
                for (var index = 1; index < times.length; index++) {
                  final step = times[index] - times[index - 1];
                  if (step > maxStep) maxStep = step;
                }
                maxSteps[stream['codec_type'] as String] = maxStep;
              }
              final gap = starts['video']! - starts['audio']!;
              final hlsTimeline = hlsDiagnostics.snapshot();
              final traces = (hlsTimeline['requests'] as List).cast<Map<String, Object?>>();
              expect(traces.first['resourceId'], 'root', reason: 'Diagnostics must attach before native execution.');
              expect(hlsTimeline['omittedRequests'], 0);
              final master = traces.first['manifest'] as Map;
              final children = master['children'] as List;
              final videoId = children.singleWhere((child) => child['role'] == 'variant')['resourceId'];
              final audioId = children.singleWhere((child) => child['role'] == 'audio')['resourceId'];
              final videoTrace = traces.firstWhere((trace) => trace['resourceId'] == videoId);
              final audioTrace = traces.firstWhere((trace) => trace['resourceId'] == audioId);
              expect((videoTrace['manifest'] as Map)['segmentCount'], 12 - config.skipVideo);
              expect((videoTrace['manifest'] as Map)['mediaSequence'], config.skipVideo);
              expect((audioTrace['manifest'] as Map)['mediaSequence'], 0);
              if (config.delayMs > 0) {
                expect(
                  (videoTrace['headersMs'] as int) - (videoTrace['startedMs'] as int),
                  greaterThanOrEqualTo(config.delayMs),
                );
              }
              await File(p.join(directory.path, 'hls-timeline.json')).writeAsString(jsonEncode(hlsTimeline));
              final report = <String, Object?>{
                'case': config.name,
                'network': 'loopback-only',
                'videoSkipSegments': config.skipVideo,
                'videoManifestDelayMs': config.delayMs,
                'starts': starts,
                'packetCounts': counts,
                'maxPtsStepSeconds': maxSteps,
                'avStartGapSeconds': gap,
                'nativeEvents': events,
                'requests': requests,
              };
              results.add(report);
              await File(p.join(directory.path, 'packets.json')).writeAsString(inspection.stdout as String);
              // A finite fixture ends without an explicit stop. Production live
              // semantics correctly expose EOF to the recovery controller.
              final terminal = events.last;
              expect(terminal['type'], 'error');
              expect(terminal['code'], 0);
              expect(terminal['failureKind'], 'unexpectedEof');
              expect(counts['video'], config.skipVideo == 0 ? 720 : 420);
              expect(counts['audio'], 1126);
              expect(maxSteps.values, everyElement(lessThan(0.1)));
              if (config.skipVideo == 0) {
                expect(gap.abs(), lessThan(0.1), reason: 'Same timeline must survive delayed manifest delivery.');
              } else {
                expect(
                  gap,
                  inExclusiveRange(9.9, 10.1),
                  reason: 'The deliberately omitted video samples must not be fabricated.',
                );
              }
            } finally {
              if (native.isRunning(taskId)) await native.stop(taskId);
              await execution?.timeout(const Duration(seconds: 15));
              await eventSubscription.cancel();
              await origin.close(force: true);
              await subscription.cancel();
              await Future.wait(handlers.toList());
              clock.stop();
            }
          }
        }, _RealNetwork());
      } finally {
        await File(p.join(root.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
        // ignore: avoid_print
        print(jsonEncode(results.map((row) => {...row, 'requests': (row['requests'] as List).length}).toList()));
        configureRecorderProxyRouting(null);
        Get.reset();
        await Hive.close();
      }
    },
    skip: Platform.environment['PURELIVE_CMAF_WINDOW_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends HttpOverrides {}

Future<ProcessResult> _inspect(String executable, String path) async {
  final process = await Process.start(executable, [
    '-v',
    'error',
    '-show_packets',
    '-show_streams',
    '-show_entries',
    'packet=stream_index,pts_time',
    '-of',
    'json',
    path,
  ]);
  var ended = false;
  Future<String> read(Stream<List<int>> source) async {
    final bytes = <int>[];
    await for (final chunk in source) {
      if (bytes.length + chunk.length > 2 * 1024 * 1024) throw StateError('Inspection output budget');
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  try {
    final result = await Future.wait<Object>([
      process.exitCode,
      read(process.stdout),
      read(process.stderr),
    ], eagerError: true).timeout(const Duration(seconds: 20));
    ended = true;
    expect(result[0], 0);
    expect((result[2] as String).trim(), isEmpty);
    return ProcessResult(process.pid, result[0] as int, result[1], result[2]);
  } finally {
    if (!ended) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}
