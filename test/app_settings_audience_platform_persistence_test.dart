import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-audience-platform-settings-');
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
    Get.testMode = false;
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('backup parser and config extraction canonicalize audience platform ids', () {
    final parsed = AppSettingsController.parseConfig({
      'realOnlinePlatforms': [' DOUYIN ', 'SOOP', 'douyin', 'huya'],
    });
    final extracted = AppSettingsController.extractConfig({
      'app': {
        'realOnlinePlatforms': [' PICARTO ', 'TWITCH', 'picarto', 'yy'],
      },
    });

    expect(parsed['realOnlinePlatforms'], ['douyin', 'soop']);
    expect(extracted['realOnlinePlatforms'], ['picarto', 'twitch']);
    expect(
      () => AppSettingsController.parseConfig({
        'realOnlinePlatforms': ['douyin', 7],
      }),
      throwsA(isA<TypeError>()),
    );
  });

  test('startup repairs same-length legacy spellings before the first consumer', () async {
    await HivePrefUtil.setInt('audienceMetricMigration', 7);
    await HivePrefUtil.setStringList('realOnlinePlatforms', [' DOUYIN ', 'SOOP']);

    final settings = Get.put(AppSettingsController());

    expect(settings.realOnlinePlatforms, ['douyin', 'soop']);
    expect(settings.isRealOnlineEnabledFor(' DOUYIN '), isTrue);
    expect(settings.isRealOnlineEnabledFor('soop'), isTrue);

    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getStringList('realOnlinePlatforms'), ['douyin', 'soop']);
  });

  test('runtime malformed writes stay consumer-safe and are repaired once', () async {
    await HivePrefUtil.setInt('audienceMetricMigration', 7);
    final settings = Get.put(AppSettingsController());

    settings.realOnlinePlatforms.assignAll([' DOUYIN ', 'SOOP', 'douyin', 'huya']);

    expect(settings.isRealOnlineEnabledFor('douyin'), isTrue);
    expect(settings.isRealOnlineEnabledFor('soop'), isTrue);
    expect(settings.isRealOnlineEnabledFor('huya'), isFalse);
    expect(settings.toJson()['realOnlinePlatforms'], ['douyin', 'soop']);

    await Future<void>.delayed(Duration.zero);
    expect(settings.realOnlinePlatforms, ['douyin', 'soop']);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getStringList('realOnlinePlatforms'), ['douyin', 'soop']);

    settings.realOnlinePlatforms.assignAll([' DOUYIN ']);
    settings.setRealOnlineEnabledFor('douyin', false);
    expect(settings.realOnlinePlatforms, isEmpty);
  });
}
