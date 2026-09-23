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
    folder = await Directory.systemTemp.createTemp('popkontv-catalog-');
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

  test('catalog twenty-four adds PopkonTV once and preserves a later hide', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 23);
    await HivePrefUtil.setStringList('hotAreasList', [Sites.huyaSite, Sites.pandaLiveSite]);
    final favorites = Get.put(FavoriteRoomController());
    final expectedPrefix = [Sites.huyaSite, Sites.pandaLiveSite, Sites.popkonSite];
    expect(favorites.hotAreasList.take(expectedPrefix.length), expectedPrefix);
    final migrated = favorites.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    expect(favorites.siteCatalogMigration.value, 38);
    favorites.hotAreasList.remove(Sites.popkonSite);
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    final reopened = Get.put(FavoriteRoomController());
    expect(reopened.hotAreasList, migrated.where((id) => id != Sites.popkonSite).toList(growable: false));
    expect(reopened.siteCatalogMigration.value, 38);
  });
}
