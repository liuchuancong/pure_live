import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';

Map<String, dynamic> detached(Map<String, dynamic> data) => jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('backup-roundtrip-');
    Hive.init(directory.path);
    await HivePrefUtil.init();
  });
  tearDown(() async {
    Get.deleteAll(force: true);
    Get.reset();
    await Hive.box('app_settings').clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<SettingsService> initialize() async {
    Get.testMode = true;
    Get.put(IptvSettingsController(), permanent: true);
    final settings = Get.put(SettingsService());
    await settings.font.ensureInitialized();
    return settings;
  }

  for (final version in [2, 3]) {
    test('v$version complete backup roundtrip preserves omitted credentials', () async {
      final settings = await initialize();
      final backup = settings.backup;
      final source = detached(backup.exportAllSettings());
      source['backupVersion'] = version;
      source['app']['enableBackgroundPlay'] = true;
      source['roomCard']['mobilePreset'] = 'custom';
      source['roomCard']['mobileConfig'] = {
        ...Map<String, dynamic>.from(source['roomCard']['mobileConfig']),
        'showPlatformBadge': true,
        'cornerRadius': 24,
      };
      source['volume']['roomVolumes'] = {'bilibili:123': 0.7};
      source['tags'] = {
        'tags': [
          {'id': 'kept', 'name': 'Roundtrip', 'order': 0},
        ],
        'roomTagsMap': {
          'bilibili:123': ['kept'],
        },
      };
      source['history']['historyRooms'] = [
        {'roomId': '123', 'platform': 'bilibili', 'title': 'Roundtrip'},
      ];
      await backup.restoreAllSettings(source);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final expected = detached(backup.exportAllSettings());
      settings.app.enableBackgroundPlay.value = false;
      settings.vol.roomVolumes = {};
      settings.tagManagement.tags.clear();
      settings.cookieManager.twitchCookie.value = 'local-fixture-cookie';
      settings.webdav.currentWebDavConfig.value = 'local-fixture-config';
      final file = File('${directory.path}/v$version.json')..writeAsStringSync(jsonEncode(source));
      expect(await backup.recover(file), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(detached(backup.exportAllSettings()), expected);
      expect(settings.cookieManager.twitchCookie.value, 'local-fixture-cookie');
      expect(settings.webdav.currentWebDavConfig.value, 'local-fixture-config');
      await Hive.box('app_settings').flush();
      expect(HivePrefUtil.getBool('enableBackgroundPlay'), isTrue);
      expect(jsonDecode(HivePrefUtil.getString('roomVolumes')!), {'bilibili:123': 0.7});
      expect(settings.roomCard.configFor(RoomCardViewport.mobile).showPlatformBadge, isTrue);
      expect(settings.roomCard.configFor(RoomCardViewport.mobile).cornerRadius, 24);
    });
  }

  test('complete legacy backup restores all settings and known export keys are recognizable', () async {
    final settings = await initialize();
    final backup = settings.backup;
    final source = detached(backup.exportAllSettings(includeSensitiveData: true));
    final legacy = <String, dynamic>{};
    for (final entry in source.entries) {
      if (entry.value is! Map) continue;
      if (entry.key == 'tags') {
        legacy['custom_tags_data'] = entry.value;
      } else {
        legacy.addAll(Map<String, dynamic>.from(entry.value));
      }
      for (final field in (entry.value as Map).entries) {
        expect(
          () => BackupController.validateBackupIdentity({
            'backupVersion': 3,
            entry.key: {field.key: field.value},
          }),
          returnsNormally,
          reason: '${entry.key}.${field.key}',
        );
      }
    }
    legacy['enableBackgroundPlay'] = true;
    legacy['twitchCookie'] = 'legacy-fixture-cookie';
    await backup.restoreAllSettings(legacy);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final expected = detached(backup.exportAllSettings(includeSensitiveData: true));
    settings.app.enableBackgroundPlay.value = false;
    settings.cookieManager.twitchCookie.value = '';
    await backup.restoreAllSettings(legacy);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(detached(backup.exportAllSettings(includeSensitiveData: true)), expected);
    expect(settings.cookieManager.twitchCookie.value, 'legacy-fixture-cookie');
  });

  test('late invalid backup field preserves every registered section', () async {
    final settings = await initialize();
    final backup = settings.backup;
    final before = detached(backup.exportAllSettings(includeSensitiveData: true));
    final invalid = detached(before);
    invalid['app']['enableBackgroundPlay'] = !settings.app.enableBackgroundPlay.value;
    invalid['tags'] = {
      'roomTagsMap': {
        'room': [42],
      },
    };
    final file = File('${directory.path}/invalid.json')..writeAsStringSync(jsonEncode(invalid));
    expect(await backup.recover(file), isFalse);
    expect(detached(backup.exportAllSettings(includeSensitiveData: true)), before);
  });
  test('failed storage reports recovery failure and permits a later retry', () async {
    final settings = await initialize();
    final backup = settings.backup;
    final source = detached(backup.exportAllSettings());
    source['app']['enableBackgroundPlay'] = true;
    final file = File('${directory.path}/storage-error.json')..writeAsStringSync(jsonEncode(source));
    // Finish startup migration notifications before injecting a restore-only fault.
    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    await Hive.box('app_settings').close();
    try {
      expect(await backup.recover(file), isFalse);
      // Failed persistence rolls the in-memory controller state back too.
      expect(settings.app.enableBackgroundPlay.value, isFalse);
    } finally {
      await HivePrefUtil.init();
    }
    // Retry the same input after reopening the store.
    expect(await backup.recover(file), isTrue);
    expect(HivePrefUtil.getBool('enableBackgroundPlay'), isTrue);
  });
  test('favorite-only restore changes followed lists and preserves every other favorite preference', () async {
    final settings = await initialize();
    final backup = settings.backup;
    settings.app.enableBackgroundPlay.value = false;
    settings.fav.shieldList.assignAll(['keep-shield']);
    settings.fav.blockedDanmakuUsers.assignAll(['keep-user']);
    settings.fav.hotAreasList.assignAll(['bilibili']);
    settings.fav.preferPlatform.value = 'bilibili';
    settings.fav.favoriteRooms.value = [LiveRoom(roomId: 'old', platform: 'bilibili')];
    settings.fav.favoriteAreas.value = [LiveArea(areaId: 'old-area', platform: 'bilibili')];

    await backup.restoreFavoriteSettings({
      'backupVersion': 3,
      'app': {'enableBackgroundPlay': true},
      'favorite': {
        'shieldList': ['replace-shield'],
        'blockedDanmakuUsers': ['replace-user'],
        'hotAreasList': ['douyu'],
        'preferPlatform': 'douyu',
        'favoriteRooms': [
          {'roomId': ' 200 ', 'platform': ' BILIBILI ', 'title': 'Restored room'},
        ],
        'favoriteAreas': [
          {'areaId': 'music', 'platform': 'douyu', 'areaName': 'Restored area'},
        ],
      },
    });

    expect(settings.app.enableBackgroundPlay.value, isFalse);
    expect(settings.fav.shieldList, ['keep-shield']);
    expect(settings.fav.blockedDanmakuUsers, ['keep-user']);
    expect(settings.fav.hotAreasList, ['bilibili']);
    expect(settings.fav.preferPlatform.value, 'bilibili');
    expect(settings.fav.favoriteRooms.value.single.identityKey, 'bilibili:200');
    expect(settings.fav.favoriteAreas.value.single.identityKey, jsonEncode(['douyu', '', 'music']));
    expect(
      (jsonDecode(HivePrefUtil.getString('favoriteRooms')!) as Map<String, dynamic>)['list'].single['roomId'],
      '200',
    );
    expect(
      (jsonDecode(HivePrefUtil.getString('favoriteAreas')!) as Map<String, dynamic>)['list'].single['areaId'],
      'music',
    );
  });

  test('favorite-only restore accepts legacy lists and ignores malformed unrelated sections', () async {
    final settings = await initialize();
    settings.fav.favoriteRooms.value = [LiveRoom(roomId: 'old', platform: 'bilibili')];
    settings.fav.favoriteAreas.value = [LiveArea(areaId: 'old-area', platform: 'bilibili')];

    await settings.backup.restoreFavoriteSettings({
      'favoriteRooms': [
        {'roomId': 'legacy', 'platform': 'huya'},
      ],
      'favoriteAreas': [
        {'areaId': 'legacy-area', 'platform': 'huya'},
      ],
      'theme': 'malformed but outside the selected restore scope',
    });

    expect(settings.fav.favoriteRooms.value.single.identityKey, 'huya:legacy');
    expect(settings.fav.favoriteAreas.value.single.areaId, 'legacy-area');
  });

  test('favorite-only restore validates its target before mutating either list', () async {
    final settings = await initialize();
    final rooms = [LiveRoom(roomId: 'keep', platform: 'bilibili')];
    final areas = [LiveArea(areaId: 'keep-area', platform: 'bilibili')];
    settings.fav.favoriteRooms.value = rooms;
    settings.fav.favoriteAreas.value = areas;

    for (final data in <Map<String, dynamic>>[
      {'backupVersion': 3},
      {'backupVersion': 3, 'favorite': 'wrong section type'},
      {
        'backupVersion': 3,
        'favorite': {
          'favoriteRooms': [
            {'roomId': 'replacement', 'platform': 'douyu'},
          ],
          'favoriteAreas': 'wrong list type',
        },
      },
      {'favoriteRooms': 'wrong list type'},
    ]) {
      await expectLater(settings.backup.restoreFavoriteSettings(data), throwsFormatException);
      expect(settings.fav.favoriteRooms.value.single.identityKey, 'bilibili:keep');
      expect(settings.fav.favoriteAreas.value.single.areaId, 'keep-area');
    }
  });

  test('overlapping restores reject rather than interleave writes', () async {
    final settings = await initialize();
    final backup = settings.backup;
    final source = detached(backup.exportAllSettings());
    final first = backup.restoreAllSettings(source);
    await expectLater(backup.restoreFavoriteSettings(source), throwsStateError);
    await first;
    final second = backup.restoreFavoriteSettings(source);
    await expectLater(backup.restoreAllSettings(source), throwsStateError);
    await second;
  });

  test('favorites-only file exports exact lists and requires scoped restore', () async {
    final settings = await initialize();
    settings.fav.favoriteRooms.value = [LiveRoom(roomId: '123', platform: 'bilibili')];
    settings.fav.favoriteAreas.value = [LiveArea(areaId: 'music', platform: 'douyu')];
    settings.app.enableBackgroundPlay.value = true;
    settings.cookieManager.twitchCookie.value = 'local-cookie';
    final file = File('${directory.path}/favorites-only.txt');

    expect(await settings.backup.backupFavorites(file), isTrue);
    final exported = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(exported.keys, {'backupVersion', 'backupScope', 'favorite'});
    expect(exported['backupScope'], 'favorites');
    expect((exported['favorite'] as Map).keys, {'favoriteRooms', 'favoriteAreas'});
    expect((exported['favorite']['favoriteRooms'] as List).single['roomId'], '123');
    expect(exported.toString(), isNot(contains('local-cookie')));

    settings.fav.favoriteRooms.value = [];
    settings.fav.favoriteAreas.value = [];
    expect(await settings.backup.recover(file), isFalse);
    expect(settings.fav.favoriteRooms.value, isEmpty);
    await settings.backup.restoreFavoriteSettings(exported);
    expect(settings.fav.favoriteRooms.value.single.identityKey, 'bilibili:123');
    expect(settings.fav.favoriteAreas.value.single.areaId, 'music');
    expect(settings.app.enableBackgroundPlay.value, isTrue);
    expect(settings.cookieManager.twitchCookie.value, 'local-cookie');
  });
}
