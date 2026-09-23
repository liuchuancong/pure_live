import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/core/site/inke/inke_api.dart';
import 'package:pure_live/core/site/inke/inke_site.dart';
import 'package:pure_live/modules/search/search_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  setUpAll(() async {
    folder = await Directory.systemTemp.createTemp('inke-catalog-migration-');
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

  test('version six adds Inke and subsequent platforms and disabling survives disk reopen', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 6);
    await HivePrefUtil.setStringList('hotAreasList', ['huya', 'missevan']);
    late FavoriteRoomController settings;
    await HivePrefUtil.persistBatch(() {
      settings = Get.put(FavoriteRoomController());
    });
    expect(settings.hotAreasList.take(10), [
      'huya',
      'missevan',
      'inke',
      'kilakila',
      'huajiao',
      'openrec',
      'ttinglive',
      'xiaohongshu',
      'niconico',
      'weibo',
    ]);
    expect(settings.siteCatalogMigration.value, 38);
    final migrated = settings.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    expect(migrated, contains('looklive'));
    await HivePrefUtil.persistBatch(() {
      settings.hotAreasList.remove('inke');
      settings.onInit();
    });
    final hidden = migrated.where((id) => id != 'inke').toList(growable: false);
    expect(settings.hotAreasList, hidden);
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    await Hive.close();
    await HivePrefUtil.init();
    final reopened = Get.put(FavoriteRoomController());
    expect(reopened.siteCatalogMigration.value, 38);
    expect(reopened.hotAreasList, hidden);
  });

  test('backup normalization retains Inke order and does not duplicate it', () async {
    final settings = Get.put(FavoriteRoomController());
    settings.fromJson({
      'hotAreasList': [' INKE ', 'huya', 'inke'],
      'preferPlatform': ' INKE ',
      'favoriteRooms': [],
      'favoriteAreas': [],
    });
    expect(settings.hotAreasList, ['inke', 'huya']);
    expect(settings.preferPlatform.value, 'inke');
    final json = settings.toJson();
    expect(json['hotAreasList'], ['inke', 'huya']);
  });

  test('actual search flow advertises exact UID lookup without web fallback', () async {
    Get.put(SettingsService());
    final controller = SearchController();
    try {
      controller.index.value = controller.sites.indexWhere((site) => site.id == 'inke') + 1;
      expect(controller.index.value, greaterThan(0));
      expect(controller.canOpenWebSearch, isFalse);
      expect(controller.canSearchNatively, isTrue);
      expect(controller.capabilityText, 'search_coverage_showcase_snapshot');
      expect(() => controller.buildSearchUrl('inke', 'example'), throwsStateError);
      controller.searchController.text = 'https://www.inke.cn/';
      await controller.doSearch();
      expect(controller.results, isEmpty);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.loading.value, isFalse);
      expect(controller.pendingSiteCount.value, 0);
      expect(controller.hasMore.value, isFalse);
    } finally {
      controller.onClose();
    }
  });

  test('search page resolves an exact Inke UID without reading showcase media', () async {
    Get.put(SettingsService());
    var calls = 0;
    final adapter = InkeSite(
      api: InkeApi(
        request: (uri, _) async {
          calls++;
          expect(uri.path, '/web/live_share_pc');
          expect(uri.queryParameters['uid'], '100');
          return (
            status: 200,
            body: jsonEncode({
              'error_code': 0,
              'data': {
                'live_uid': '100',
                'liveid': '200',
                'status': 1,
                'media_info': {'inke_id': 100, 'nick': 'Fixture'},
                'live_name': 'Test',
              },
            }),
          );
        },
      ),
    );
    final controller = SearchController(
      searchSites: [Site(id: 'inke', name: '映客', logo: '', liveSite: adapter)],
    );
    try {
      controller.index.value = 1;
      controller.searchController.text = 'https://www.inke.cn/liveroom/index.html?uid=100&id=stale';
      await controller.doSearch();
      expect(controller.results.single.roomId, '100');
      expect(controller.results.single.data, isNull);
      expect(controller.hasMore.value, isFalse);
      await controller.loadMore();
      expect(calls, 1);
    } finally {
      controller.onClose();
    }
  });

  test('search page shows bounded nickname matches and accurate coverage', () async {
    Get.put(SettingsService());
    final adapter = InkeSite(
      api: InkeApi(
        request: (uri, _) async => (
          status: 200,
          body: jsonEncode({
            'error_code': 0,
            'data': uri.path.endsWith('Live_top_pc')
                ? {
                    'list': [
                      {'uid': 100, 'live_id': '200', 'nick': '音乐主播'},
                      {'uid': 101, 'live_id': '201', 'nick': '聊天主播'},
                    ],
                  }
                : {
                    'list': [
                      {
                        'tab_key': 'MUSIC',
                        'channel_name': '音乐',
                        'list': [
                          {'uid': 102, 'live_id': '202', 'nick': '音乐电台'},
                        ],
                      },
                    ],
                  },
          }),
        ),
      ),
    );
    final controller = SearchController(
      searchSites: [Site(id: 'inke', name: '映客', logo: '', liveSite: adapter)],
    );
    try {
      controller.index.value = 1;
      expect(controller.capabilityText, 'search_coverage_showcase_snapshot');
      controller.searchController.text = '音乐';
      await controller.doSearch();
      expect(controller.results.map((room) => room.roomId), ['100', '102']);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.hasMore.value, isTrue);
      await controller.loadMore();
      expect(controller.results.map((room) => room.roomId), ['100', '102']);
      expect(controller.hasMore.value, isFalse);
    } finally {
      controller.onClose();
    }
  });
}
