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
  late Directory folder;
  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('xiaohongshu-catalog-');
    Hive.init(folder.path);
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
    expect(folder.absolute.path.startsWith(Directory.systemTemp.absolute.path), true);
    await folder.delete(recursive: true);
  });
  test('catalog eleven adds only XHS once, preserving hidden sites and audience settings', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 11);
    await HivePrefUtil.setStringList('hotAreasList', ['huya']);
    await HivePrefUtil.setInt('audienceMetricMigration', 7);
    await HivePrefUtil.setStringList('realOnlinePlatforms', ['twitch']);
    final favorites = Get.put(FavoriteRoomController());
    final app = Get.put(AppSettingsController());
    final expectedPrefix = ['huya', 'xiaohongshu', 'niconico', 'weibo'];
    expect(favorites.hotAreasList.take(expectedPrefix.length), expectedPrefix);
    final migrated = favorites.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    final hidden = migrated.where((id) => id != 'xiaohongshu').toList(growable: false);
    expect(favorites.siteCatalogMigration.value, 38);
    expect(app.realOnlinePlatforms, ['twitch']);
    expect(app.audienceMetricMigration.value, 7);
    favorites.hotAreasList.remove('xiaohongshu');
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    expect(Get.put(FavoriteRoomController()).hotAreasList, hidden);
    expect(Get.put(AppSettingsController()).realOnlinePlatforms, ['twitch']);
  });
  test('backup preserves exact broadcast string and tags without inventing owner identity', () {
    final favorites = Get.put(FavoriteRoomController());
    favorites.fromJson({
      'hotAreasList': [' XIAOHONGSHU ', 'huya', 'xiaohongshu'],
      'preferPlatform': ' XIAOHONGSHU ',
      'favoriteRooms': [
        (LiveRoom(platform: 'xiaohongshu', roomId: '570429070963278308')..tagIds = ['fixture']).toJson(),
      ],
      'favoriteAreas': [],
    });
    expect(favorites.hotAreasList, ['xiaohongshu', 'huya']);
    expect(favorites.preferPlatform.value, 'xiaohongshu');
    final restored = LiveRoom.fromJson((favorites.toJson()['favoriteRooms'] as List).single);
    expect(restored.roomId, '570429070963278308');
    expect(restored.userId, anyOf(isNull, isEmpty));
    expect(restored.tagIds, ['fixture']);
    expect(AppSettingsController.normalizeRealOnlinePlatforms(['xiaohongshu', 'twitch']), ['twitch']);
  });
}
