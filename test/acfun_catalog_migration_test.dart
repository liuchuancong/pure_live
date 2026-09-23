import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('pure-live-acfun-catalog-');
    Hive.init(directory.path);
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
    await directory.delete(recursive: true);
  });

  test('catalog upgrade appends new platforms and preserves existing order and disabled platforms', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 2);
    await HivePrefUtil.setStringList('hotAreasList', ['huya', 'bilibili']);
    final settings = Get.put(FavoriteRoomController());
    final expectedPrefix = [
      'huya',
      'bilibili',
      'acfun',
      'picarto',
      'twitcasting',
      'missevan',
      'inke',
      'kilakila',
      'huajiao',
      'openrec',
      'ttinglive',
      'xiaohongshu',
      'niconico',
      'weibo',
    ];
    expect(settings.hotAreasList.take(expectedPrefix.length), expectedPrefix);
    final migrated = settings.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    final hidden = migrated.where((id) => id != 'acfun').toList(growable: false);
    expect(settings.siteCatalogMigration.value, 38);
    settings.hotAreasList.remove('acfun');
    settings.onInit();
    expect(settings.hotAreasList, hidden);
  });

  test('online-count capability is explicit and backup normalization preserves an AcFun toggle', () {
    final capability = LiveRoom.audienceCapabilityFor('acfun');
    expect(capability.onlineAvailableInRoomLists, isTrue);
    expect(capability.hasPopularity, isFalse);
    expect(capability.hasTotalViewers, isFalse);
    expect(AppSettingsController.defaultRealOnlinePlatforms, contains('acfun'));
    expect(AppSettingsController.normalizeRealOnlinePlatforms([' ACFUN ', 'huya']), ['acfun']);
  });

  test('online-count upgrade adds AcFun once without re-enabling other disabled counters', () async {
    await HivePrefUtil.setInt('audienceMetricMigration', 2);
    await HivePrefUtil.setStringList('realOnlinePlatforms', ['twitch']);
    final settings = Get.put(AppSettingsController());
    expect(settings.realOnlinePlatforms, ['twitch', 'acfun', 'picarto', 'twitcasting', 'openrec', 'ttinglive']);
    expect(settings.audienceMetricMigration.value, 7);
    settings.setRealOnlineEnabledFor('acfun', false);
    settings.onInit();
    expect(settings.realOnlinePlatforms, ['twitch', 'picarto', 'twitcasting', 'openrec', 'ttinglive']);
    await Hive.box<dynamic>('app_settings').flush();
    expect(HivePrefUtil.getStringList('realOnlinePlatforms'), [
      'twitch',
      'picarto',
      'twitcasting',
      'openrec',
      'ttinglive',
    ]);
  });
}
