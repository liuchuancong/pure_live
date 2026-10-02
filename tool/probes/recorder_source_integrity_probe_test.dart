// Opt-in native remux of retained evidence: no external requests or device use.
// The source directory is read-only; each case gets isolated copies.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/recorder/domain/models/live_record_task.dart';
import 'package:pure_live/domains/recorder/data/services/video_processor_service.dart';

void main() {
  test(
    'native finalizer accepts intact TS and preserves known truncated source',
    () async {
      final sourcePath = Platform.environment['PURELIVE_RETAINED_TS'];
      final base = Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT'];
      expect(sourcePath, isNotEmpty);
      expect(base, isNotEmpty);
      final sources = await Directory(sourcePath!)
          .list(followLinks: false)
          .where((entry) => entry is File && p.extension(entry.path) == '.ts')
          .cast<File>()
          .toList();
      sources.sort((a, b) => a.path.compareTo(b.path));
      expect(sources.length, greaterThanOrEqualTo(2));
      expect(await sources.first.length() % 188, 0);
      expect(
        await sources.last.length() % 188,
        isNot(0),
        reason: 'This probe requires the retained partial TS packet.',
      );
      final output = await Directory(p.join(base!, 'source-integrity-${DateTime.now().microsecondsSinceEpoch}'))
          .create(recursive: true);
      final hive = await Directory.systemTemp.createTemp('purelive-source-integrity-settings-');
      Hive.init(hive.path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      final results = <Map<String, Object?>>[];
      try {
        for (final corrupted in [false, true]) {
          final label = corrupted ? 'truncated' : 'intact';
          final directory = await Directory(p.join(output.path, label)).create();
          final task = LiveRecordTask.fromRoom(LiveRoom(platform: 'huya', roomId: label, nick: 'fixture'))
            ..outputDir = directory.path;
          final original = corrupted ? sources.last : sources.first;
          final source = await original.copy(p.join(directory.path, '${task.recordingFilePrefix}_000000.ts'));
          final result = await VideoProcessorService.to.convertToMp4(task: task);
          results.add({
            'input': label,
            'reportedSuccess': result,
            'sourceRetained': await source.exists(),
            'finalMp4': await directory.list().where((f) => p.extension(f.path) == '.mp4').length,
            'processing': VideoProcessorService.to.isProcessing(task.taskId),
          });
        }
        await File(p.join(output.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
        expect(results.first['reportedSuccess'], true);
        expect(results.first['sourceRetained'], false);
        expect(results.first['finalMp4'], 1);
        expect(results.last['reportedSuccess'], false);
        expect(results.last['sourceRetained'], true);
        expect(results.last['finalMp4'], 0);
        expect(results.every((row) => row['processing'] == false), true);
      } finally {
        Get.reset();
        await Hive.close();
        await hive.delete(recursive: true);
      }
    },
    skip: Platform.environment['PURELIVE_SOURCE_INTEGRITY_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
