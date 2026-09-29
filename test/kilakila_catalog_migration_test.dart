import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/site/kilakila/kilakila_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/search/search_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('kilakila-catalog-migration-');
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

  test('version seven adds Kilakila and later Huajiao and disabling survives disk reopen', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 7);
    await HivePrefUtil.setStringList('hotAreasList', ['huya', 'inke']);
    late FavoriteRoomController settings;
    await HivePrefUtil.persistBatch(() {
      settings = Get.put(FavoriteRoomController());
    });
    expect(settings.hotAreasList.take(6), [
      'huya',
      'inke',
      'kilakila',
      'xiaohongshu',
      'niconico',
      'weibo',
    ]);
    expect(settings.siteCatalogMigration.value, 38);
    final migrated = settings.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    expect(migrated, contains('looklive'));
    await HivePrefUtil.persistBatch(() {
      settings.hotAreasList.remove('kilakila');
      settings.onInit();
    });
    final hidden = migrated.where((id) => id != 'kilakila').toList(growable: false);
    expect(settings.hotAreasList, hidden);
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    final reopened = Get.put(FavoriteRoomController());
    expect(reopened.siteCatalogMigration.value, 38);
    expect(reopened.hotAreasList, hidden);
  });

  test('backup normalization retains Kilakila order and does not duplicate it', () async {
    final settings = Get.put(FavoriteRoomController());
    settings.fromJson({
      'hotAreasList': [' KILAKILA ', 'huya', 'kilakila'],
      'preferPlatform': ' KILAKILA ',
      'favoriteRooms': [],
      'favoriteAreas': [],
    });
    expect(settings.hotAreasList, ['kilakila', 'huya']);
    expect(settings.preferPlatform.value, 'kilakila');
    final json = settings.toJson();
    expect(json['hotAreasList'], ['kilakila', 'huya']);
  });

  test('search selection advertises official user search and web fallback', () async {
    Get.put(SettingsService());
    final controller = SearchController();
    try {
      controller.index.value = controller.sites.indexWhere((site) => site.id == 'kilakila') + 1;
      expect(controller.index.value, greaterThan(0));
      expect(controller.canOpenWebSearch, isTrue);
      expect(controller.capabilityText, 'search_coverage_kilakila');
      expect(
        controller.buildSearchUrl('kilakila', '音乐'),
        'https://live.kilakila.cn/aboutus/serach/kw/%E9%9F%B3%E4%B9%90',
      );
      controller.searchController.text = 'https://evil.test/zhubo/123';
      await controller.doSearch();
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.loading.value, isFalse);
      expect(controller.pendingSiteCount.value, 0);
      expect(controller.hasMore.value, isFalse);
    } finally {
      controller.onClose();
    }
  });

  test('search page consumes website user results and stops on an empty next page', () async {
    Get.put(SettingsService());
    final calls = <Uri>[];
    final adapter = KilakilaSite(
      api: KilakilaApi(
        request: (uri, _) async {
          calls.add(uri);
          return (
            status: 200,
            body: uri.path.endsWith('/p/2')
                ? '<div class="userList"></div>'
                : '<div class="userList"><a href="/zhubo/100">'
                      '<div class="anchor-name">音乐主播</div></a></div>',
          );
        },
      ),
    );
    final controller = SearchController(
      searchSites: [Site(id: 'kilakila', name: '克拉克拉', logo: '', liveSite: adapter)],
    );
    try {
      controller.index.value = 1;
      controller.searchController.text = '音乐';
      await controller.doSearch();
      expect(controller.results.single.roomId, '100');
      expect(controller.results.single.isExplicitlyOfflineNow, isFalse);
      expect(controller.hasMore.value, isTrue);
      await controller.loadMore();
      expect(controller.results.single.roomId, '100');
      expect(controller.hasMore.value, isFalse);
      expect(calls.map((uri) => uri.pathSegments), [
        ['aboutus', 'serach', 'kw', '音乐'],
        ['aboutus', 'serach', 'kw', '音乐', 'p', '2'],
      ]);
    } finally {
      controller.onClose();
    }
  });
}
