import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/modules/hongguo/hongguo.dart';

void main() {
  group('the comment settings', () {
    test('read a hand-edited file clamped to what the layer draws', () {
      final settings = HongguoDanmakuSettings.fromJson(const <String, Object?>{
        'enabled': 'yes',
        'fontSize': 99,
        'opacity': 0.05,
        'speed': 5,
        'density': 'wall',
      });

      expect(settings.enabled, isTrue);
      expect(settings.fontSize, 40);
      expect(settings.opacity, 0.2);
      expect(settings.speed, 2);
      expect(settings.density, HongguoDanmakuDensity.normal);
    });

    test('a missing file falls back to the reference defaults', () {
      final settings = HongguoDanmakuSettings.fromJson(const {});

      expect(settings.enabled, isTrue);
      expect(settings.fontSize, 24);
      expect(settings.opacity, 0.9);
      expect(settings.speed, 1);
      expect(settings.density, HongguoDanmakuDensity.normal);
      expect(settings.lineHeight, closeTo(40.8, 1e-9));
    });

    test('the row budget follows the picture, the size and the density', () {
      const sparse = HongguoDanmakuSettings(density: HongguoDanmakuDensity.sparse);
      const normal = HongguoDanmakuSettings.standard;
      const dense = HongguoDanmakuSettings(density: HongguoDanmakuDensity.dense);

      // 200 / 40.8 fits four rows.
      expect(sparse.lanesFor(200), 1);
      expect(normal.lanesFor(200), 3);
      expect(dense.lanesFor(200), 4);

      // A collapsed picture still gets one row, a tall one stops at eight.
      expect(dense.lanesFor(0), 1);
      expect(dense.lanesFor(4000), 8);
    });
  });

  group('the lane planner', () {
    test('hands out the free rows in turn and keeps one row at a time busy', () {
      final planner = HongguoDanmakuPlanner();

      expect(planner.laneFor(0, lanes: 2), 0);
      expect(planner.laneFor(0, lanes: 2), 1);
      expect(planner.laneFor(0, lanes: 2), isNull);
      expect(planner.laneFor(700, lanes: 2), 0);
      expect(planner.laneFor(1000, lanes: 2), 1);
    });

    test('forgets every row when playback starts over', () {
      final planner = HongguoDanmakuPlanner()
        ..laneFor(0, lanes: 1)
        ..reset();

      expect(planner.laneFor(1, lanes: 1), 0);
      expect(planner.laneFor(2, lanes: 0), isNull);
    });
  });

  group('the comment settings controller', () {
    late ProviderContainer container;

    setUp(() async {
      await StoragePrefs.initSeeded({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('starts from the stored file', () async {
      await StoragePrefs.setString(
        kHongguoDanmakuPrefsKey,
        jsonEncode({'enabled': false, 'fontSize': 32.0, 'opacity': 0.5, 'speed': 1.5, 'density': 'dense'}),
      );

      final settings = container.read(hongguoDanmakuSettingsProvider);

      expect(settings.enabled, isFalse);
      expect(settings.fontSize, 32);
      expect(settings.opacity, 0.5);
      expect(settings.speed, 1.5);
      expect(settings.density, HongguoDanmakuDensity.dense);
    });

    test('clamps what it writes and keeps the rest untouched', () async {
      final controller = container.read(hongguoDanmakuSettingsProvider.notifier);

      await controller.setFontSize(7);
      await controller.setOpacity(3);
      await controller.setSpeed(0.1);
      await controller.setDensity(HongguoDanmakuDensity.sparse);

      final settings = container.read(hongguoDanmakuSettingsProvider);
      expect(settings.enabled, isTrue);
      expect(settings.fontSize, 14);
      expect(settings.opacity, 1);
      expect(settings.speed, 0.5);
      expect(settings.density, HongguoDanmakuDensity.sparse);

      final stored = jsonDecode(StoragePrefs.getString(kHongguoDanmakuPrefsKey)!) as Map<String, Object?>;
      expect(stored['fontSize'], 14);
      expect(stored['density'], 'sparse');
    });
  });
}
