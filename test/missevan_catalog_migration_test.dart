import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/core/site/missevan/missevan_api.dart';
import 'package:pure_live/core/site/missevan/missevan_site.dart';
import 'package:pure_live/modules/search/search_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('missevan-integration-');
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

  test('migration appends Missevan and subsequent platforms, retains hidden choices and persists disabling', () async {
    await HivePrefUtil.setInt('siteCatalogMigration', 5);
    await HivePrefUtil.setStringList('hotAreasList', ['huya', 'twitcasting']);
    final controller = Get.put(FavoriteRoomController());
    expect(controller.hotAreasList.take(11), [
      'huya',
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
    ]);
    expect(controller.siteCatalogMigration.value, 38);
    final migrated = controller.hotAreasList.toList(growable: false);
    expect(migrated.toSet(), hasLength(migrated.length));
    expect(migrated, contains('looklive'));
    controller.hotAreasList.remove('missevan');
    controller.onInit();
    final hidden = migrated.where((id) => id != 'missevan').toList(growable: false);
    expect(controller.hotAreasList, hidden);
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    expect(Get.put(FavoriteRoomController()).hotAreasList, hidden);
  });

  test('heat-only platform never becomes a concurrent-viewer setting', () async {
    await HivePrefUtil.setInt('audienceMetricMigration', 5);
    await HivePrefUtil.setStringList('realOnlinePlatforms', ['twitch']);
    final controller = Get.put(AppSettingsController());
    expect(controller.realOnlinePlatforms, ['twitch', 'openrec', 'ttinglive']);
    expect(AppSettingsController.normalizeRealOnlinePlatforms(['missevan', 'twitch']), ['twitch']);
  });

  test('search selection advertises native live and offline lookup without web fallback', () {
    Get.put(SettingsService());
    final controller = SearchController();
    try {
      controller.index.value = controller.sites.indexWhere((s) => s.id == 'missevan') + 1;
      expect(controller.index.value, greaterThan(0));
      expect(controller.canOpenWebSearch, isFalse);
      expect(controller.canSearchNatively, isTrue);
      expect(controller.capabilityText, 'search_coverage_live_and_offline');
      expect(() => controller.buildSearchUrl('missevan', 'example'), throwsStateError);
    } finally {
      controller.onClose();
    }
  });

  test('search page resolves an exact Missevan room once and retains its offline state', () async {
    Get.put(SettingsService());
    var calls = 0;
    final site = Site(
      id: 'missevan',
      name: '猫耳 FM',
      logo: '',
      liveSite: MissevanSite(
        api: MissevanApi(
          request: (uri, cancel) async {
            calls++;
            expect(uri.path, '/api/v2/live/100');
            return (
              status: 200,
              body: jsonEncode({
                'code': 0,
                'info': {
                  'room': {
                    'room_id': 100,
                    'creator_id': 200,
                    'creator_username': 'Fixture',
                    'name': '离线测试',
                    'status': {'open': 0},
                    'statistics': {'score': 10},
                    'channel': 'stale',
                  },
                },
              }),
            );
          },
        ),
      ),
    );
    final controller = SearchController(searchSites: [site]);
    try {
      controller.index.value = 1;
      controller.searchController.text = 'https://fm.missevan.com/live/100';
      await controller.doSearch();
      expect(controller.results.single.roomId, '100');
      expect(controller.results.single.isExplicitlyOfflineNow, isTrue);
      expect(controller.hasMore.value, isFalse);
      await controller.loadMore();
      expect(calls, 1);
      controller.setIncludeOffline(false);
      expect(controller.results, isEmpty);
      expect(controller.hasFilteredOfflineResults, isTrue);
    } finally {
      controller.onClose();
    }
  });
}
