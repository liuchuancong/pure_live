import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/search/search_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('openrec-catalog-');
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
  test('catalog nine and audience five append Openrec and TTing; disabled choices survive reopening', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 9);
    await HivePrefUtil.setStringList('hotAreasList', ['huya']);
    await HivePrefUtil.setInt('audienceMetricMigration', 5);
    await HivePrefUtil.setStringList('realOnlinePlatforms', ['twitch']);
    final favorites = Get.put(FavoriteRoomController());
    final app = Get.put(AppSettingsController());
    final expectedPrefix = ['huya', 'openrec', 'ttinglive', 'xiaohongshu', 'niconico', 'weibo'];
    expect(favorites.hotAreasList.take(expectedPrefix.length), expectedPrefix);
    final migrated = favorites.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    final hidden = migrated.where((id) => id != 'openrec').toList(growable: false);
    expect(favorites.siteCatalogMigration.value, 38);
    expect(app.realOnlinePlatforms, ['twitch', 'openrec', 'ttinglive']);
    expect(app.audienceMetricMigration.value, 7);
    favorites.hotAreasList.remove('openrec');
    app.setRealOnlineEnabledFor('openrec', false);
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    expect(Get.put(FavoriteRoomController()).hotAreasList, hidden);
    expect(Get.put(AppSettingsController()).realOnlinePlatforms, ['twitch', 'ttinglive']);
  });
  test('backup preserves pinned owner case, numeric ID, tags and platform order', () {
    final favorites = Get.put(FavoriteRoomController());
    favorites.fromJson({
      'hotAreasList': [' OPENREC ', 'huya', 'openrec'],
      'preferPlatform': ' OPENREC ',
      'favoriteRooms': [
        (LiveRoom(roomId: 'Fixture_Owner@100', userId: '100', platform: 'openrec')..tagIds = ['fixture']).toJson(),
      ],
      'favoriteAreas': [],
    });
    expect(favorites.hotAreasList, ['openrec', 'huya']);
    expect(favorites.preferPlatform.value, 'openrec');
    final result = favorites.toJson();
    final restored = LiveRoom.fromJson((result['favoriteRooms'] as List).single);
    expect(restored.roomId, 'Fixture_Owner@100');
    expect(restored.userId, '100');
    expect(restored.tagIds, ['fixture']);
  });
  test('search advertises exact-channel scope without a web fallback', () {
    Get.put(SettingsService());
    final controller = SearchController();
    try {
      controller.index.value = controller.sites.indexWhere((s) => s.id == 'openrec') + 1;
      expect(controller.index.value, greaterThan(0));
      expect(controller.canOpenWebSearch, isFalse);
      expect(controller.capabilityText, 'search_coverage_openrec');
      expect(() => controller.buildSearchUrl('openrec', 'fixture'), throwsStateError);
    } finally {
      controller.onClose();
    }
  });
}
