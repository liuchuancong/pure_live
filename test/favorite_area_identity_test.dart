import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/utils/settings_upgrade_migration.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_page.dart';
import 'package:pure_live/modules/areas/favorite_areas_controller.dart';
import 'package:pure_live/modules/live_play/widgets/button/favorite_floating_button.dart';

LiveArea area(String platform, {String id = '1', String? type, String name = '分类'}) => LiveArea(
  platform: platform,
  areaId: id,
  areaType: type ?? '',
  areaName: name,
  typeName: '',
  areaPic: '',
  shortName: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('favorite-area-identity-');
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
    await Hive.close().timeout(const Duration(seconds: 15));
    await directory.delete(recursive: true);
  });

  test('same ID on different platforms can both be followed', () {
    final controller = Get.put(FavoriteRoomController());
    expect(controller.addArea(area('huya')), isTrue);
    expect(controller.isFavoriteArea(area('douyu')), isFalse);
    expect(controller.addArea(area('douyu')), isTrue);
    expect(controller.favoriteAreas.value, hasLength(2));
  });

  test('removal matches reconstructed identity and preserves unrelated favorites', () {
    final controller = Get.put(FavoriteRoomController());
    final other = area('douyu');
    controller.favoriteAreas.value = [area('huya'), other];
    expect(controller.removeArea(area('huya', name: '新名称')), isTrue);
    expect(controller.favoriteAreas.value, [other]);
    expect(controller.removeArea(area('huya')), isFalse);
  });

  test('legacy omitted parent remains the same favorite after taxonomy updates', () {
    final controller = Get.put(FavoriteRoomController());
    final old = LiveArea.fromJson({'platform': 'bilibili', 'areaId': '1'});
    controller.favoriteAreas.value = [old];
    expect(controller.isFavoriteArea(area('bilibili', type: '10')), isTrue);
    expect(controller.addArea(area('bilibili', type: '20')), isFalse);
    expect(controller.favoriteAreas.value.single, same(old));
    expect(controller.removeArea(area('bilibili', type: '20')), isTrue);
  });

  test('Missevan catalog and tag namespaces remain independent', () {
    final controller = Get.put(FavoriteRoomController());
    expect(controller.addArea(area('missevan', type: 'catalog')), isTrue);
    expect(controller.isFavoriteArea(area('missevan', type: 'tag')), isFalse);
    expect(controller.addArea(area('missevan', type: 'tag')), isTrue);
    expect(controller.removeArea(area('missevan', type: 'catalog')), isTrue);
    expect(controller.favoriteAreas.value.single.areaType, 'tag');
  });

  test('identity normalizes platform whitespace but preserves case-sensitive IDs', () {
    final controller = Get.put(FavoriteRoomController());
    controller.favoriteAreas.value = [area(' HUYA ', id: ' Game ')];
    expect(controller.isFavoriteArea(area('huya', id: 'Game')), isTrue);
    expect(controller.isFavoriteArea(area('huya', id: 'game')), isFalse);
    expect(controller.isFavoriteArea(area('huya', id: 'Other')), isFalse);
  });

  test('IPTV channel identity survives provider metadata changes', () {
    final controller = Get.put(FavoriteRoomController());
    controller.favoriteAreas.value = [area('iptv', id: 'channel-1', type: 'provider-1')];
    expect(controller.addArea(area('iptv', id: 'channel-1', type: 'provider-2')), isFalse);
    expect(controller.removeArea(area('iptv', id: 'channel-1')), isTrue);
  });

  test('unidentified legacy entries are preserved but not matched or newly added', () {
    final controller = Get.put(FavoriteRoomController());
    final old = LiveArea(areaName: '旧数据');
    controller.favoriteAreas.value = [old];
    expect(controller.isFavoriteArea(LiveArea()), isFalse);
    expect(controller.removeArea(LiveArea()), isFalse);
    expect(controller.addArea(LiveArea()), isFalse);
    expect(controller.favoriteAreas.value, [old]);
  });

  test('unfollow clears only duplicate copies of the selected identity', () {
    final controller = Get.put(FavoriteRoomController());
    final tag = area('missevan', type: 'tag');
    controller.favoriteAreas.value = [area('missevan', type: 'catalog'), tag, area('missevan', type: 'catalog')];
    expect(controller.removeArea(area('missevan', type: 'catalog')), isTrue);
    expect(controller.favoriteAreas.value, [tag]);
  });

  test('missing namespace is not a wildcard and encoded keys resist separators', () {
    expect(area('missevan').hasSameIdentity(area('missevan', type: 'tag')), isFalse);
    expect(area('missevan', type: ' TAG ').hasSameIdentity(area('MISSEVAN', type: 'tag')), isTrue);
    expect(area('a|b', id: 'c').hasSameIdentity(area('a', id: 'b|c')), isFalse);
    expect(area('missevan', type: 'a|b', id: 'c').hasSameIdentity(area('missevan', type: 'a', id: 'b|c')), isFalse);
  });

  test('Hive and backup round trips preserve old fields and namespaced records', () async {
    final originals = [area('huya'), area('douyu'), area('missevan', type: 'catalog'), area('missevan', type: 'tag')];
    final controller = Get.put(FavoriteRoomController());
    controller.favoriteAreas.value = originals;
    final backup = controller.toJson();
    await Hive.box<dynamic>('app_settings').flush();
    Get.reset();
    final restored = Get.put(FavoriteRoomController());
    expect(restored.toJson()['favoriteAreas'], backup['favoriteAreas']);
    restored.fromJson(backup);
    restored.fromJson(backup);
    expect(restored.toJson()['favoriteAreas'], backup['favoriteAreas']);
    expect(restored.isFavoriteArea(area('huya', type: 'new-parent')), isTrue);
    expect(restored.removeArea(area('missevan', type: 'catalog')), isTrue);
    expect(restored.isFavoriteArea(area('missevan', type: 'tag')), isTrue);
  });

  test('raw upgrade merge preserves namespaces, order and legacy parent enrichment', () {
    final current = {
      'favoriteAreas': [
        jsonEncode(area('huya', name: '保留名称').toJson()),
        jsonEncode(area('missevan', type: 'catalog').toJson()),
        jsonEncode(area('iptv', id: 'channel').toJson()),
      ],
    };
    final incoming = {
      'favoriteAreas': jsonEncode({
        'list': [
          area('huya', type: 'parent', name: '替换名称').toJson(),
          area('douyu').toJson(),
          area('missevan', type: 'tag').toJson(),
          area('iptv', id: 'channel', type: 'provider').toJson(),
        ],
      }),
    };
    final merged = SettingsUpgradeMigration.mergeRawSettings(current, [incoming]);
    final items = (jsonDecode(merged['favoriteAreas'] as String) as Map)['list'] as List;
    expect(items, hasLength(5));
    expect(items.map((e) => e['platform']), ['huya', 'missevan', 'iptv', 'douyu', 'missevan']);
    expect(items.first['areaName'], '保留名称');
    expect(items.first['areaType'], 'parent');
    expect(items[2]['areaType'], 'provider');
    expect(items[1]['areaType'], 'catalog');
    expect(items.last['areaType'], 'tag');
    expect(SettingsUpgradeMigration.mergeRawSettings(merged, [incoming]), merged);
  });

  testWidgets('actual favorite actions keep touch targets and update only their target', (tester) async {
    final target = area('huya');
    final other = area('douyu');
    final room = LiveRoom(roomId: 'fixture-room', platform: 'bilibili', nick: 'Fixture host');
    final settings = (await tester.runAsync(() async {
      // Hive's file backend and Flutter's fake widget clock have different
      // I/O scheduling. Use Hive's supported memory backend for this widget;
      // the ordinary async tests above cover the real on-disk round trip.
      await Hive.close().timeout(const Duration(seconds: 15));
      await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
      await HivePrefUtil.init();
      final settings = Get.put(SettingsService());
      settings.fav.favoriteAreas.value = [other];
      await Future<void>.delayed(Duration.zero);
      await Hive.box<dynamic>('app_settings').flush();
      return settings;
    }))!;
    final favoritesPage = Get.put(FavoriteAreasController());
    try {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FavoriteAreaFloatingButton(area: target),
                Obx(() => Text('favorites:${favoritesPage.favoriteAreas.length}')),
                FavoriteFloatingButton(room: room),
                FavoriteFloatingButton(room: room, compact: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('favorites:1'), findsOneWidget);
      for (final button in [
        find.byKey(const ValueKey('favorite-action-button-expanded')),
        find.byKey(const ValueKey('favorite-action-button-compact')),
      ]) {
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(settings.fav.favoriteAreas.value, [other, target]);
      expect(find.text('favorites:2'), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(settings.fav.favoriteAreas.value, [other, target]);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      // Another action while the confirmation is open must also survive.
      final later = area('missevan', type: 'tag');
      settings.fav.favoriteAreas.value = [...settings.fav.favoriteAreas.value, later];
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(settings.fav.favoriteAreas.value, [other, later]);
      expect(find.text('favorites:2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }
  });
}
