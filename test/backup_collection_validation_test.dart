import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/page_settings_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/modules/tags/live_tag.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('backup-collections-');
    Hive.init(directory.path);
    await HivePrefUtil.init();
  });
  tearDown(Get.reset);
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('bad collections are rejected before app writes for current and legacy imports', () {
    final app = Get.put(AppSettingsController());
    app.enableBackgroundPlay.value = true;
    final before = app.toJson();
    final badSections = <String, Map<String, dynamic>>{
      'favorite': {'favoriteRooms': 'not a list'},
      'history': {'historyRooms': 'not a list'},
      'webdav': {'webDavConfigs': 'not a list'},
      'roomCard': {
        'mobileConfig': {'showAvatar': 'not a boolean'},
      },
      'page': {
        'pageSizeOptions': [12, 'bad'],
      },
      'tags': {
        'roomTagsMap': {
          'room': [1],
        },
      },
    };
    for (final entry in badSections.entries) {
      final error = ['favorite', 'history', 'webdav', 'roomCard'].contains(entry.key)
          ? isA<FormatException>()
          : isA<TypeError>();
      for (final data in <Map<String, dynamic>>[
        {
          'backupVersion': 3,
          'app': {'enableBackgroundPlay': false},
          entry.key: entry.value,
        },
        {
          'enableBackgroundPlay': false,
          ...entry.key == 'tags' ? {'custom_tags_data': entry.value} : entry.value,
        },
      ]) {
        expect(() => BackupController().importAllSettings(data), throwsA(error), reason: entry.key);
        expect(app.toJson(), before, reason: entry.key);
      }
    }
  });

  test('record parsers preserve both object and JSON-string legacy lists', () {
    final room = <String, dynamic>{'roomId': '123', 'platform': 'bilibili', 'title': 'Kept'};
    final webdav = <String, dynamic>{
      'name': 'Local fixture',
      'address': 'https://example.invalid',
      'username': '',
      'password': '',
    };
    for (final encoded in [false, true]) {
      final rooms = [encoded ? jsonEncode(room) : room];
      final favorite = FavoriteRoomController.parseConfig({'favoriteRooms': rooms});
      expect(favorite['favoriteRooms'].single.title, 'Kept');
      final history = HistoryController.parseConfig({'historyRooms': rooms});
      expect(history['historyRooms'].single.roomId, '123');
      final config = WebDavController.parseConfig({
        'webDavConfigs': [encoded ? jsonEncode(webdav) : webdav],
      });
      expect(config['webDavConfigs'].single.name, 'Local fixture');
    }
  });

  test('tag parsing validates mapping before replacing existing tags', () {
    final controller = Get.put(TagManagementController());
    controller.tags.assignAll([LiveTag(id: 'keep', name: 'Original')]);
    controller.roomTagsMap.assignAll({
      'room': ['keep'],
    });
    expect(
      () => controller.importFromJson({
        'tags': [
          {'id': 'new', 'name': 'New'},
        ],
        'roomTagsMap': {
          'room': [42],
        },
      }),
      throwsA(isA<TypeError>()),
    );
    expect(controller.tags.single.id, 'keep');
    expect(controller.roomTagsMap, {
      'room': ['keep'],
    });
    controller.importFromJson({'tags': null});
    expect(controller.tags.single.id, 'keep');
  });

  test('tag import repairs identities and publishes only normalized room mappings', () async {
    await HivePrefUtil.clear();
    final controller = Get.put(TagManagementController());

    controller.importFromJson({
      'tags': [
        {'id': 'duplicate', 'name': 'Second', 'order': 1},
        {'id': 'duplicate', 'name': 'First', 'order': 0},
        {'id': '', 'name': 'Empty identity', 'order': 2},
      ],
      'roomTagsMap': {
        ' room ': ['duplicate', 'duplicate', 'missing'],
        'empty': ['missing'],
      },
    });

    expect(controller.tags.map((tag) => tag.name), ['First', 'Second', 'Empty identity']);
    expect(controller.tags.map((tag) => tag.order), [0, 1, 2]);
    final ids = controller.tags.map((tag) => tag.id).toList(growable: false);
    expect(ids.first, 'duplicate');
    expect(ids.toSet(), hasLength(3));
    expect(controller.roomTagsMap, {
      'room': ['duplicate'],
    });

    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getAnyPref('room_to_tags_mapping_v1'), {
      'room': ['duplicate'],
    });
  });

  test('tags-only import prunes mappings to identities that were replaced', () async {
    await HivePrefUtil.clear();
    final controller = Get.put(TagManagementController());
    controller.tags.assignAll([LiveTag(id: 'old', name: 'Old')]);
    controller.roomTagsMap.assignAll({
      'bilibili:1': ['old'],
    });

    controller.importFromJson({
      'tags': [
        {'id': 'replacement', 'name': 'Replacement', 'order': 0},
      ],
    });

    expect(controller.tags.single.id, 'replacement');
    expect(controller.roomTagsMap, isEmpty);
    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getAnyPref('room_to_tags_mapping_v1'), isEmpty);
  });

  test('page options are eagerly checked before scalar writes', () {
    final controller = Get.put(PageSettingsController());
    controller.showPageSizeSelector.value = true;
    final before = controller.toJson();
    expect(
      () => controller.fromJson({
        'showPageSizeSelector': false,
        'pageSizeOptions': [12, 'bad'],
      }),
      throwsA(isA<TypeError>()),
    );
    expect(controller.toJson(), before);
    final parsed = PageSettingsController.parseConfig({
      'pageSizeOptions': [12, 24],
    });
    expect(parsed['pageSizeOptions'], [12, 24]);
    expect(parsed['pageSizeOptionsRaw'], '[12,24]');
  });
}
