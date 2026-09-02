import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-settings-lifecycle-test-');
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('IPTV settings has one permanent lifecycle owner', () {
    Get.put(SettingsService(), permanent: true);
    Get.put(IptvSettingsController(), permanent: true);

    final iptv = Get.find<IptvSettingsController>();
    expect(iptv.initialized, isTrue);
    expect(Get.isPrepared<IptvSettingsController>(), isFalse);
    expect(Get.delete<IptvSettingsController>(), isFalse);
    expect(Get.find<IptvSettingsController>(), same(iptv));
  });

  test('ordinary settings controllers remain lazy', () {
    Get.put(SettingsService(), permanent: true);

    expect(Get.isPrepared<AppSettingsController>(), isTrue);
  });
}
