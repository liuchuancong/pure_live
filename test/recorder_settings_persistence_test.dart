import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/consts/recorder_config.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure_live_recorder_settings_');
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('recorder switches persist when their reactive values change', () async {
    final controller = RecordSettingsController();

    controller.autoReconnect.value = false;
    controller.enablePolling.value = true;
    controller.enableCacheLimit.value = true;
    controller.preferBestStream.value = false;

    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();

    expect(RecorderConfig.autoReconnect, isFalse);
    expect(RecorderConfig.enablePolling, isTrue);
    expect(RecorderConfig.enableCacheLimit, isTrue);
    expect(RecorderConfig.preferBestStream, isFalse);
  });

  test('cache-limit getter observes changes made after first read', () async {
    expect(RecorderConfig.enableCacheLimit, RecorderConfig.defaultEnableCacheLimit);

    await RecorderConfig.setEnableCacheLimit(true);

    expect(RecorderConfig.enableCacheLimit, isTrue);
  });
}
