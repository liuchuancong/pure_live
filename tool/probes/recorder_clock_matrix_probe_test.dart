// Opt-in retained/synthetic media matrix. Real production recorder and finalizer;
// all original inputs are immutable and no device or live upstream is involved.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/data/services/recording_segment_clock.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

import 'frame_hash_timeline.dart';
import 'recording_clock_probe_support.dart';

void main() {
  for (final name in [
    'weibo-retained',
    'hevc-aac48-stereo',
    'hevc10-aac48',
    'h264-dual-audio',
    'h264-ts-wrap',
    'aac-jitter-silence',
  ]) {
    test(
      'production clock matrix: $name',
      () async {
        final manifest =
            jsonDecode(await File(Platform.environment['PURELIVE_CLOCK_MATRIX_MANIFEST']!).readAsString()) as Map;
        final specification = (manifest['cases'] as List).cast<Map>().singleWhere((entry) => entry['id'] == name);
        final input = File(specification['input'] as String);
        expect(await input.length(), lessThanOrEqualTo(64 * 1024 * 1024));
        expect(await _digest(input), specification['sha256']);
        final tracks = (specification['tracks'] as List).cast<Map>();
        final labels = tracks.map((entry) => entry['label'] as String).toList();
        expect(labels.toSet().length, tracks.length);
        final pixels = <String, String>{
          for (final track in tracks)
            if (track['kind'] == 'video') track['label'] as String: track['pixelFormat'] as String,
        };
        final root = await Directory(
          p.join(
            Platform.environment['PURELIVE_CLOCK_MATRIX_OUTPUT']!,
            '$name-${DateTime.now().microsecondsSinceEpoch}',
          ),
        ).create(recursive: true);
        Hive.init(p.join(root.path, 'settings'));
        await HivePrefUtil.init();
        Get.testMode = true;
        Get.put(LogController());
        final manager = FFmpegManager.to;
        final ownedIds = <String>[];
        final report = <String, Object?>{
          'case': name,
          'inputSha256': specification['sha256'],
          'contract': 'failed',
          'stage': 'source-decode',
        };
        final results = <String, Map<String, FrameHashTimeline>>{};
        final variants = <String, Object?>{};
        report['variants'] = variants;
        try {
          results['source'] = await decodeClockMedia(input, root, 'source', labels, pixelFormats: pixels);
          for (final variant in ['single', 'legacy', 'clockV1', 'productionSingle', 'production']) {
            final directory = await Directory(p.join(root.path, variant)).create();
            final task = LiveRecordTask.fromRoom(LiveRoom(platform: 'clockmatrix', roomId: '$name-$variant'))
              ..outputDir = directory.path
              ..recordedSeconds = specification['recordedSeconds'] as int;
            final prefix = task.recordingFilePrefix;
            final id = task.taskId;
            ownedIds.addAll([id, 'merge_${id}_$prefix']);
            final args = FFmpegCommandBuilder.buildRecordArguments(
              url: input.path,
              outputDir: directory.path,
              segmentTime: variant == 'single' || variant == 'productionSingle' ? 86400 : 10,
              preferBestStream: false,
              rwTimeout: 15,
              threadQueueSize: 512,
              filePrefix: prefix,
            ).toList();
            if (variant == 'single' || variant == 'legacy') {
              args[args.indexOf('-segment_format_options') + 1] = 'flush_packets=1';
              args[args.length - 1] = args.last.replaceFirst('.clock-v1.ts', '.ts');
              for (final option in ['-segment_list', '-segment_list_type']) {
                final index = args.indexOf(option);
                args.removeRange(index, index + 2);
              }
            } else if (variant == 'clockV1') {
              // Keep the pre-PES-fix control executable, including its journal.
              args[args.indexOf('-segment_format_options') + 1] = 'flush_packets=1:avoid_negative_ts=disabled';
            }
            final evidence = <String, Object?>{'arguments': args};
            variants[variant] = evidence;
            report['stage'] = '$variant-record';
            evidence['record'] = await runClockNative(manager, id, args);
            final segments = VideoProcessorService.selectAttemptSegments(
              candidates: (await directory.list(followLinks: false).toList()).whereType<File>().where(
                (file) => file.path.endsWith('.ts'),
              ),
              filePrefix: prefix,
            )..sort((left, right) => left.path.compareTo(right.path));
            expect(
              segments.length,
              variant == 'single' || variant == 'productionSingle'
                  ? 1
                  : greaterThanOrEqualTo(specification['minimumSegments'] as int),
            );
            final journal = File(p.join(directory.path, RecordingSegmentClock.journalName(prefix)));
            final archive = await Directory(p.join(directory.path, 'retained')).create();
            final archiveEntries = <Map<String, Object?>>[];
            for (final file in [...segments, if (await journal.exists()) journal]) {
              final copy = await file.copy(p.join(archive.path, p.basename(file.path)));
              expect(await _digest(copy), await _digest(file));
              archiveEntries.add({
                'name': p.basename(file.path),
                'bytes': await file.length(),
                'sha256': await _digest(copy),
              });
            }
            evidence['retained'] = archiveEntries;
            final foreign = await File(p.join(directory.path, '${prefix}_other_000000.clock-v1.ts'))
                .writeAsBytes([9, 8, 7]);
            final foreignJournal = await File(p.join(directory.path, '${prefix}_other.clock-v1.csv'))
                .writeAsString('foreign');
            final mergeEvents = <Map<String, Object?>>[];
            final subscription = manager.stream.listen((event) {
              if (event.taskId == 'merge_${id}_$prefix' &&
                  [FFmpegEventType.complete, FFmpegEventType.error].contains(event.type)) {
                mergeEvents.add({'type': event.type.name, 'code': event.data['code']});
              }
            });
            try {
              report['stage'] = '$variant-merge';
              // Use the default source-deletion path, after immutable copies exist.
              expect(await VideoProcessorService.to.convertToMp4(task: task), true);
              expect(mergeEvents, [
                {'type': 'complete', 'code': 0},
              ]);
              evidence['merge'] = mergeEvents.single;
            } finally {
              await subscription.cancel();
            }
            for (final file in segments) {
              expect(await file.exists(), false, reason: 'successful production source cleanup');
            }
            expect(await journal.exists(), false);
            expect(await foreign.readAsBytes(), [9, 8, 7]);
            expect(await foreignJournal.readAsString(), 'foreign');
            expect(
              await directory
                  .list()
                  .where((file) => file.path.endsWith('.partial') || file.path.endsWith('.ffconcat'))
                  .length,
              0,
            );
            evidence['sourceAndJournalCleanup'] = true;
            final output = File(p.join(directory.path, '$prefix.mp4'));
            report['stage'] = '$variant-streams';
            final metadata = await probeClockMediaFile(output);
            evidence['outputMetadata'] = metadata;
            _verifyTracks(metadata, tracks);
            report['stage'] = '$variant-decode';
            results[variant] = await decodeClockMedia(output, root, variant, labels, pixelFormats: pixels);
          }
          final comparisons = <String, Map<String, Object?>>{};
          report['comparisons'] = comparisons;
          report['stage'] = 'comparison-gates';
          for (final track in tracks) {
            final label = track['label'] as String;
            final source = results['source']![label]!;
            final single = results['single']![label]!;
            comparisons[label] = {
              'sourceToSingle': source.compare(single),
              'sourceToProduction': source.compare(results['production']![label]!),
              'singleToLegacy': single.compare(results['legacy']![label]!),
              'singleToProduction': single.compare(results['production']![label]!),
              'singleToClockV1': single.compare(results['clockV1']![label]!),
              'sourceToProductionSingle': source.compare(results['productionSingle']![label]!),
              'productionSingleToProduction': results['productionSingle']![label]!.compare(
                results['production']![label]!,
              ),
            };
          }
          for (final track in tracks) {
            final label = track['label'] as String;
            final checks = comparisons[label]!;
            for (final comparison in checks.values.cast<Map>()) {
              expect(comparison['orderedContentEqual'], true, reason: '$name/$label content');
            }
            final production = checks['productionSingleToProduction'] as Map;
            final rate = track['kind'] == 'video' ? 90000 : track['sampleRate'] as int;
            expect(
              production['offsetSpreadSeconds'] as double,
              lessThanOrEqualTo(2 / rate),
              reason: '$name/$label exact clock',
            );
            if (track['kind'] == 'audio' && (name == 'weibo-retained' || name == 'aac-jitter-silence')) {
              // The old single already changes source cadence through PES
              // interpolation. Keep that control and require closer fidelity,
              // rather than manufacturing its lossy timestamps in new output.
              final oldSource = checks['sourceToSingle'] as Map;
              final newSource = checks['sourceToProduction'] as Map;
              expect(newSource['offsetSpreadSeconds'] as double, lessThan(oldSource['offsetSpreadSeconds'] as double));
            }
          }
          if (specification['legacyRepro'] == true) {
            final old = comparisons['video_0']!['singleToLegacy'] as Map;
            expect(old['offsetSpreadSeconds'] as double, greaterThan(0.01));
            final prePacket = comparisons['audio_0']!['singleToClockV1'] as Map;
            expect(prePacket['offsetSpreadSeconds'] as double, greaterThan(2 / 44100));
          }
          report['contract'] = 'passed';
        } catch (error) {
          report['error'] = error.toString();
          rethrow;
        } finally {
          for (final id in ownedIds) {
            if (manager.isRunning(id)) await manager.stop(id).timeout(const Duration(seconds: 30));
          }
          await File(p.join(root.path, 'summary.json'))
              .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
          // ignore: avoid_print
          print(jsonEncode(report));
          Get.reset();
          await Hive.close();
        }
      },
      skip: Platform.environment['PURELIVE_CLOCK_MATRIX'] != '1',
      timeout: const Timeout(Duration(minutes: 6)),
    );
  }
}

Future<String> _digest(File file) async => (await sha256.bind(file.openRead()).first).toString();

void _verifyTracks(Map<String, dynamic> metadata, List<Map> tracks) {
  final streams = (metadata['streams'] as List)
      .cast<Map>()
      .where((stream) => stream['codec_type'] == 'video' || stream['codec_type'] == 'audio')
      .toList();
  expect(streams.length, tracks.length, reason: 'all requested media streams must survive');
  for (final track in tracks) {
    final ordinal = int.parse((track['label'] as String).split('_').last);
    final stream = streams.where((stream) => stream['codec_type'] == track['kind']).elementAt(ordinal);
    expect(stream['codec_name'], track['codec']);
    if (track['kind'] == 'video') {
      expect(stream['width'], track['width']);
      expect(stream['height'], track['height']);
      expect(stream['pix_fmt'], track['pixelFormat']);
    } else {
      expect(int.parse(stream['sample_rate'] as String), track['sampleRate']);
      expect(stream['channels'], track['channels']);
    }
  }
}
