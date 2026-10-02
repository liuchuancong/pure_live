import 'package:pure_live/domains/live/domain/live_quality_discovery.dart';

// Opt-in Windows native recording through the production RecorderController.
// Preserve stopped TS before the normal MP4 finalizer removes it, so container
// and bitstream validity can be compared. No signed URL or cookie is persisted.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';
import 'package:pure_live/domains/live/data/platforms/huya/huya_site.dart';
import 'package:pure_live/domains/live/data/platforms/huya/huya_transport_policy.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_scheduler.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/domain/models/record_status.dart';
import 'package:pure_live/domains/recorder/data/record_settings_controller.dart';
import 'package:pure_live/domains/recorder/presentation/pages/recorder/recorder_controller.dart';
import 'package:pure_live/domains/recorder/data/services/cache_service.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_flv_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_service.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

void main() {
  test(
    'Huya native recording maintains one input across credential expiry and preserves raw evidence',
    () async {
      final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT'];
      final decoder = Platform.environment['PURELIVE_FFMPEG'];
      expect(base, isNotEmpty);
      expect(decoder, isNotEmpty);
      final seconds = (int.tryParse(Platform.environment['PURELIVE_HUYA_SECONDS'] ?? '') ?? 325).clamp(310, 600);
      final room = Platform.environment['PURELIVE_HUYA_ROOM'] ?? '660000';
      final output = await Directory(p.join(base!, 'huya-controller-${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final hive = await Directory.systemTemp.createTemp('purelive-huya-record-settings-');
      Hive.init(hive.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      Get.put(
        CacheService(
          defaultDirectoryResolver: () => Directory(p.join(output.path, 'recordings')).create(recursive: true),
        ),
      );
      final task = LiveRecordTask(
        taskId: 'huya_probe',
        roomId: room,
        platform: 'huya',
        title: 'Huya probe',
        nick: 'Huya probe',
        avatar: '',
        cover: '',
        createTime: DateTime.now(),
        autoReconnect: true,
      );
      final native = _RetainingManager(task, output);
      final recorder = Get.put(
        // Opt-in Flutter test kept outside test/ to exclude live networking.
        // ignore: invalid_use_of_visible_for_testing_member
        RecorderController.forTesting(
          settings: RecordSettingsController(),
          ffmpeg: native,
          // ignore: invalid_use_of_visible_for_testing_member
          scheduler: FFmpegScheduler.forTesting(),
        ),
      );
      recorder.tasks.add(task);
      final samples = <Map<String, Object?>>[];
      final summary = <String, Object?>{
        'probe': 'huya-production-controller-recording',
        'room': room,
        'secondsRequested': seconds,
        'credentialsPersisted': false,
        'output': output.path,
      };
      var stage = 'room-bootstrap';
      Future<void> save() async {
        summary.addAll({'stage': stage, 'starts': native.starts, 'rotations': native.rotations, 'samples': samples});
        await File(p.join(output.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
      }

      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
          try {
            final request = await client.getUrl(Uri.https('www.huya.com', '/$room'));
            request.headers.set('user-agent', HuyaSite.nativePlayUserAgent);
            final response = await request.close().timeout(const Duration(seconds: 20));
            expect(response.statusCode, 200);
            final page = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 20));
            final bootstrap = _extractStream(page);
            final profile = (bootstrap['data'] as List).first as Map;
            final info = profile['gameLiveInfo'] as Map;
            final lines = (profile['gameStreamInfoList'] as List).cast<Map>();
            final source = lines.firstWhere((line) => line['sCdnType'] == 'AL', orElse: () => lines.first);
            final line = HuyaLineModel(
              line: source['sFlvUrl'].toString(),
              lineType: HuyaLineType.flv,
              flvAntiCode: source['sFlvAntiCode'].toString(),
              hlsAntiCode: source['sHlsAntiCode'].toString(),
              streamName: source['sStreamName'].toString(),
              cdnType: source['sCdnType'].toString(),
              presenterUid: int.parse((info['lChannelId'] ?? info['uid']).toString()),
            );
            final resolver = _OfficialResolver(HuyaSite(), line);
            Get.put<StreamResolverService>(resolver);
            stage = 'native-start';
            expect(await recorder.startTask(task), isTrue);
            for (var wait = 0; wait < 30 && task.status != RecordStatus.running; wait++) {
              await Future<void>.delayed(const Duration(seconds: 1));
              if (task.lastError?.isNotEmpty == true) break;
            }
            expect(task.status, RecordStatus.running);
            stage = 'continuous-recording';
            for (var elapsed = 0; elapsed < seconds; elapsed++) {
              await Future<void>.delayed(const Duration(seconds: 1));
              samples.add({
                'elapsedSeconds': elapsed + 1,
                'bytes': task.fileSize,
                'status': task.status.name,
                'session': native.getSession(task.taskId)?.sessionId,
              });
              if (elapsed % 30 == 0) await save();
              expect(native.starts, 1, reason: 'healthy native FLV must not be cancelled for credential expiry');
              expect(native.rotations, 0);
              expect(task.status, RecordStatus.running);
            }
            summary['credentialResolutions'] = resolver.calls;
            expect(resolver.calls, greaterThanOrEqualTo(2));
            stage = 'manual-stop-and-finalization';
            await recorder.stopTask(task).timeout(const Duration(seconds: 60));
            expect(task.status, RecordStatus.stopped);
            expect(native.isRunning(task.taskId), isFalse);
            final raw = native.retained;
            expect(raw, isNotEmpty);
            final mp4s = await Directory(task.outputDir!)
                .list()
                .where((f) => f is File && p.extension(f.path) == '.mp4')
                .cast<File>()
                .toList();
            expect(mp4s, hasLength(1));
            stage = 'independent-ts-and-mp4-decode';
            final manifest = File(p.join(output.path, 'raw.ffconcat'));
            await manifest.writeAsString(VideoProcessorService.buildConcatManifest(raw.map((file) => file.path)));
            final results = <Map<String, Object?>>[];
            for (final input in [
              <String>['-f', 'concat', '-safe', '0', '-i', manifest.path],
              <String>['-i', mp4s.single.path],
            ]) {
              final label = results.isEmpty ? 'source-ts' : 'final-mp4';
              final process = await Process.start(decoder!, [
                '-hide_banner',
                '-nostdin',
                '-v',
                'error',
                '-xerror',
                '-threads',
                '2',
                '-filter_threads',
                '1',
                ...input,
                '-map',
                '0:v:0',
                '-map',
                '0:a:0',
                '-progress',
                'pipe:1',
                '-f',
                'null',
                '-',
              ]);
              final standardOutput = process.stdout.transform(utf8.decoder).join();
              final standardError = process.stderr.transform(utf8.decoder).join();
              late final int exit;
              try {
                exit = await process.exitCode.timeout(const Duration(seconds: 90));
              } on TimeoutException {
                process.kill();
                await process.exitCode;
                await Future.wait([standardOutput, standardError]);
                rethrow;
              }
              final errors = await standardError;
              await File(p.join(output.path, '$label-decode.log')).writeAsString(errors);
              await File(p.join(output.path, '$label-progress.log')).writeAsString(await standardOutput);
              results.add({'kind': label, 'exit': exit, 'errorLogEmpty': errors.trim().isEmpty});
            }
            summary.addAll({
              'decoderResults': results,
              'sourceSegments': raw.length,
              'finalBytes': await mp4s.single.length(),
              'finalMp4': mp4s.single.path,
              'nativeStopped': true,
            });
            stage = 'decode-validation';
            await save();
            expect(
              results.every((result) => result['exit'] == 0 && result['errorLogEmpty'] == true),
              isTrue,
              reason: 'Container metadata or exit code alone does not establish complete media validity',
            );
            stage = 'complete';
            await save();
          } finally {
            client.close(force: true);
          }
        }, _RealNetwork());
      } catch (error) {
        summary['failureType'] = error.runtimeType.toString();
        await save();
        fail('Huya recording probe failed at $stage (${error.runtimeType}); preserved summary at ${output.path}');
      } finally {
        if (native.isRunning(task.taskId)) await recorder.stopTask(task);
        Get.delete<RecorderController>(force: true);
        Get.reset();
        await Hive.close();
        await hive.delete(recursive: true);
      }
    },
    skip: Platform.environment['PURELIVE_HUYA_RECORDING_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 14)),
  );
}

class _OfficialResolver extends StreamResolverService {
  _OfficialResolver(this.site, this.line);
  final HuyaSite site;
  final HuyaLineModel line;
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
    final url = await site.getPlayUrl(line, 0);
    discoveryScope?.checkActive();
    if (!HuyaTransportPolicy.hasNativeFlvCredential(url)) throw StateError('native WUP source was not selected');
    return ResolvedRecordStream(
      url: url,
      quality: LivePlayQuality(quality: '原画', id: 'source'),
      qualityCursorId: 'source',
      lineIndex: 0,
      candidateUrls: [url],
      refreshAt: site.getPlayUrlRefreshAt(url),
      invalidAt: site.getPlayUrlInvalidAt(url),
    );
  }
}

class _RetainingManager implements FFmpegManager {
  _RetainingManager(this.task, this.output);
  final LiveRecordTask task;
  final Directory output;
  final FFmpegManager delegate = FFmpegManager.to;
  final retained = <File>[];
  int starts = 0;
  int rotations = 0;
  @override
  Stream<FFmpegEvent> get stream => delegate.stream.asyncMap((event) async {
    if (event.taskId == task.taskId &&
        (event.type == FFmpegEventType.complete || event.type == FFmpegEventType.error) &&
        task.outputDir != null) {
      final folder = await Directory(p.join(output.path, 'raw-${event.data['sessionId']}')).create(recursive: true);
      final files = await Directory(task.outputDir!)
          .list()
          .where((f) => f is File && p.extension(f.path) == '.ts')
          .cast<File>()
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        retained.add(await file.copy(p.join(folder.path, p.basename(file.path))));
      }
    }
    return event;
  });
  @override
  Future<void> start({
    required String taskId,
    required List<String> arguments,
    bool liveRecording = false,
    HlsSourceQueryPolicy? sourceQueryPolicy,
    HlsRelayDiagnostics? hlsDiagnostics,
    FlvRelayDiagnostics? flvDiagnostics,
    bool hlsPrefetch = false,
  }) {
    starts++;
    return delegate.start(
      taskId: taskId,
      arguments: arguments,
      liveRecording: liveRecording,
      sourceQueryPolicy: sourceQueryPolicy,
      hlsDiagnostics: hlsDiagnostics,
      flvDiagnostics: flvDiagnostics,
      hlsPrefetch: hlsPrefetch,
    );
  }

  @override
  Future<void> stop(String taskId) => delegate.stop(taskId);
  @override
  Future<void> refreshLease(String taskId) {
    rotations++;
    return delegate.refreshLease(taskId);
  }

  @override
  bool isRunning(String taskId) => delegate.isRunning(taskId);
  @override
  FFmpegRecordSession? getSession(String taskId) => delegate.getSession(taskId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RealNetwork extends HttpOverrides {}

Map<String, dynamic> _extractStream(String page) {
  final marker = page.indexOf('stream:');
  if (marker < 0) throw const FormatException('room stream metadata missing');
  final start = page.indexOf('{', marker);
  var depth = 0;
  var quoted = false;
  var escaped = false;
  for (var i = start; i < page.length; i++) {
    final char = page[i];
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        quoted = false;
      }
    } else if (char == '"') {
      quoted = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}' && --depth == 0) {
      return jsonDecode(page.substring(start, i + 1)) as Map<String, dynamic>;
    }
  }
  throw const FormatException('room stream metadata truncated');
}
