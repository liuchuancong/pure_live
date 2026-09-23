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
    folder = await Directory.systemTemp.createTemp('tting-catalog-');
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
    expect(folder.absolute.path.startsWith(Directory.systemTemp.absolute.path), isTrue);
    await folder.delete(recursive: true);
  });
  test('catalog ten and audience six append TTing once and persist disabled choices across reopening', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 10);
    await HivePrefUtil.setStringList('hotAreasList', ['huya', 'openrec']);
    await HivePrefUtil.setInt('audienceMetricMigration', 6);
    await HivePrefUtil.setStringList('realOnlinePlatforms', ['twitch']);
    final favorites = Get.put(FavoriteRoomController());
    final app = Get.put(AppSettingsController());
    final expectedPrefix = ['huya', 'openrec', 'ttinglive', 'xiaohongshu', 'niconico', 'weibo'];
    expect(favorites.hotAreasList.take(expectedPrefix.length), expectedPrefix);
    final migrated = favorites.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    final hidden = migrated.where((id) => id != 'ttinglive').toList(growable: false);
    expect(favorites.siteCatalogMigration.value, 38);
    expect(app.realOnlinePlatforms, ['twitch', 'ttinglive']);
    expect(app.audienceMetricMigration.value, 7);
    favorites.hotAreasList.remove('ttinglive');
    app.setRealOnlineEnabledFor('ttinglive', false);
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    expect(Get.put(FavoriteRoomController()).hotAreasList, hidden);
    expect(Get.put(AppSettingsController()).realOnlinePlatforms, ['twitch']);
  });
  test('backup retains channel and owner identity, tags, normalized ordering and disabled audience choice', () {
    final favorites = Get.put(FavoriteRoomController());
    final app = Get.put(AppSettingsController());
    favorites.fromJson({
      'hotAreasList': [' TTINGLIVE ', 'huya', 'ttinglive'],
      'preferPlatform': ' TTINGLIVE ',
      'favoriteRooms': [
        (LiveRoom(platform: 'ttinglive', roomId: '101', userId: '202')..tagIds = ['fixture']).toJson(),
      ],
      'favoriteAreas': [],
    });
    expect(favorites.hotAreasList, ['ttinglive', 'huya']);
    expect(favorites.preferPlatform.value, 'ttinglive');
    final restored = LiveRoom.fromJson((favorites.toJson()['favoriteRooms'] as List).single);
    expect(restored.roomId, '101');
    expect(restored.userId, '202');
    expect(restored.tagIds, ['fixture']);
    expect(AppSettingsController.normalizeRealOnlinePlatforms([' TTINGLIVE ', 'huya', 'ttinglive']), ['ttinglive']);
    app.setRealOnlineEnabledFor('ttinglive', false);
    app.onInit();
    expect(app.isRealOnlineEnabledFor('ttinglive'), isFalse);
  });
}
