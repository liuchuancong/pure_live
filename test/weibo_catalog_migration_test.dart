import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

const _id = '1022:2321325000000000000000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('weibo-catalog-');
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
    expect(folder.absolute.path.startsWith('${Directory.systemTemp.absolute.path}${Platform.pathSeparator}'), isTrue);
    await folder.delete(recursive: true);
  });

  test('catalog thirteen adds only Weibo once and persists a later hide across a real Hive reopen', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 13);
    await HivePrefUtil.setStringList('hotAreasList', ['huya', 'ttinglive']);
    await HivePrefUtil.setInt('audienceMetricMigration', 7);
    await HivePrefUtil.setStringList('realOnlinePlatforms', ['twitch']);
    final favorites = Get.put(FavoriteRoomController());
    final app = Get.put(AppSettingsController());
    final expectedPrefix = ['huya', 'ttinglive', 'weibo'];
    expect(favorites.hotAreasList.take(expectedPrefix.length), expectedPrefix);
    final migrated = favorites.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    final hidden = migrated.where((id) => id != 'weibo').toList(growable: false);
    expect(favorites.siteCatalogMigration.value, 38);
    expect(app.realOnlinePlatforms, ['twitch']);
    expect(app.audienceMetricMigration.value, 7);
    favorites.hotAreasList.remove('weibo');
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    expect(Get.put(FavoriteRoomController()).hotAreasList, hidden);
    expect(Get.put(AppSettingsController()).realOnlinePlatforms, ['twitch']);
  });

  test('current catalog preserves an explicitly empty selected-site list', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 38);
    await HivePrefUtil.setStringList('hotAreasList', []);
    final favorites = Get.put(FavoriteRoomController());
    expect(favorites.hotAreasList, isEmpty);
    expect(favorites.siteCatalogMigration.value, 38);
  });

  test('backup preserves selected sites, separate broadcast/owner identities and tags', () {
    final favorites = Get.put(FavoriteRoomController());
    favorites.fromJson({
      'hotAreasList': [' WEIBO ', 'huya', 'weibo'],
      'preferPlatform': ' WEIBO ',
      'favoriteRooms': [
        (LiveRoom(platform: 'weibo', roomId: _id, userId: '101')..tagIds = ['fixture']).toJson(),
      ],
      'favoriteAreas': [],
    });
    expect(favorites.hotAreasList, ['weibo', 'huya']);
    expect(favorites.preferPlatform.value, 'weibo');
    final restored = LiveRoom.fromJson((favorites.toJson()['favoriteRooms'] as List).single);
    expect(restored.roomId, _id);
    expect(restored.userId, '101');
    expect(restored.tagIds, ['fixture']);
    expect(AppSettingsController.normalizeRealOnlinePlatforms(['weibo', 'twitch']), ['twitch']);
    favorites.fromJson({
      'hotAreasList': ['huya'],
      'favoriteRooms': [],
      'favoriteAreas': [],
    });
    expect(favorites.hotAreasList, ['huya']);
  });
}
