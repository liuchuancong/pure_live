import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;

  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('fc2live-catalog-');
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
    await folder.delete(recursive: true);
  });

  test('catalog thirty-one adds FC2 Live once and preserves a later hide', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 30);
    await HivePrefUtil.setStringList('hotAreasList', [Sites.huyaSite, Sites.goodGameSite]);
    final favorites = Get.put(FavoriteRoomController());
    expect(favorites.hotAreasList, [Sites.huyaSite, Sites.goodGameSite, Sites.fc2LiveSite]);
    expect(favorites.siteCatalogMigration.value, 31);
    favorites.hotAreasList.remove(Sites.fc2LiveSite);
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    final reopened = Get.put(FavoriteRoomController());
    expect(reopened.hotAreasList, [Sites.huyaSite, Sites.goodGameSite]);
    expect(reopened.siteCatalogMigration.value, 31);
  });
}
