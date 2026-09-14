import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('pure-live-window-size-boundary-');
    Hive.init(directory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
  });

  tearDown(() async {
    Get.reset();
    await HivePrefUtil.flush();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('startup window dimensions share one bounded finite contract', () {
    expect(WindowSizeController.normalizeStoredWidth(399), WindowSizeController.minWindowWidth);
    expect(WindowSizeController.normalizeStoredHeight(299), WindowSizeController.minWindowHeight);
    expect(
      WindowSizeController.normalizeStoredWidth(WindowSizeController.maxWindowDimension + 1),
      WindowSizeController.maxWindowDimension,
    );
    expect(WindowSizeController.normalizeStoredHeight(double.infinity), WindowSizeController.defaultWindowHeight);
    expect(WindowSizeController.tryParseWindowSize('400', '300'), const Size(400, 300));
    expect(WindowSizeController.tryParseWindowSize('399', '300'), isNull);
    expect(WindowSizeController.tryParseWindowSize('400', '16385'), isNull);
    expect(WindowSizeController.tryParseWindowSize('NaN', '720'), isNull);
  });

  test('persisted main and PiP geometry are repaired before consumers and export', () async {
    await HivePrefUtil.setDouble('window_width', double.infinity);
    await HivePrefUtil.setDouble('window_height', -5);
    await HivePrefUtil.setString('windows_pip_display_id', 'display-corrupt');
    await HivePrefUtil.setDouble('windows_pip_width', double.infinity);
    await HivePrefUtil.setDouble('windows_pip_height', 360);
    await HivePrefUtil.setDouble('windows_pip_x', double.nan);
    await HivePrefUtil.setDouble('windows_pip_y', 10);

    final settings = Get.put(WindowSizeController());

    expect(settings.resolvedStoredWidth, WindowSizeController.defaultWindowWidth);
    expect(settings.resolvedStoredHeight, WindowSizeController.minWindowHeight);
    expect(settings.windowSize.value, const Size(1280, 300));
    expect(settings.windowsPip.hasValidBounds, isFalse);
    expect(settings.windowsPip.toJson(), {
      'displayId': '',
      'windowsPipWidth': 0.0,
      'windowsPipHeight': 0.0,
      'windowsPipX': 0.0,
      'windowsPipY': 0.0,
    });
    expect(settings.toJson()['storedWidth'], WindowSizeController.defaultWindowWidth);
    expect(settings.toJson()['storedHeight'], WindowSizeController.minWindowHeight);

    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getDouble('window_width'), WindowSizeController.defaultWindowWidth);
    expect(HivePrefUtil.getDouble('window_height'), WindowSizeController.minWindowHeight);
    expect(HivePrefUtil.getString('windows_pip_display_id'), isEmpty);
    expect(HivePrefUtil.getDouble('windows_pip_width'), 0.0);
    expect(HivePrefUtil.getDouble('windows_pip_height'), 0.0);
    expect(HivePrefUtil.getDouble('windows_pip_x'), 0.0);
    expect(HivePrefUtil.getDouble('windows_pip_y'), 0.0);
  });

  test('runtime writes and window callbacks keep the last canonical size', () async {
    final settings = Get.put(WindowSizeController());

    settings.storedWidth.value = 1;
    settings.storedHeight.value = double.nan;
    await Future<void>.delayed(Duration.zero);
    expect(settings.storedWidth.value, WindowSizeController.minWindowWidth);
    expect(settings.storedHeight.value, WindowSizeController.defaultWindowHeight);
    expect(settings.windowSize.value, const Size(400, 720));

    settings.updateSize(Size.zero);
    expect(settings.windowSize.value, const Size(400, 720));
    settings.updateSize(const Size(20000, 900));
    expect(settings.windowSize.value, const Size(16384, 900));
  });

  test('runtime PiP capture keeps display identity and bounds in one canonical snapshot', () async {
    final settings = Get.put(WindowSizeController());

    settings.windowsPip.update(const Size(640, 360), const Offset(-120, 80), ' DISPLAY-2 ');

    expect(settings.windowsPip.isValid, isTrue);
    expect(settings.windowsPip.toJson(), {
      'displayId': 'DISPLAY-2',
      'windowsPipWidth': 640.0,
      'windowsPipHeight': 360.0,
      'windowsPipX': -120.0,
      'windowsPipY': 80.0,
    });
    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    expect(HivePrefUtil.getString('windows_pip_display_id'), 'DISPLAY-2');
  });

  test('current and legacy backup geometry normalize ranges and reject malformed scalars', () {
    final parsed = WindowSizeController.parseConfig({
      'storedWidth': 320,
      'storedHeight': 200,
      'windowsPip': {
        'displayId': 'display-1',
        'windowsPipWidth': 640,
        'windowsPipHeight': 360,
        'windowsPipX': -120,
        'windowsPipY': 20,
      },
    });
    expect(parsed['storedWidth'], WindowSizeController.minWindowWidth);
    expect(parsed['storedHeight'], WindowSizeController.minWindowHeight);
    expect(parsed['windowsPip'], {
      'displayId': 'display-1',
      'windowsPipWidth': 640.0,
      'windowsPipHeight': 360.0,
      'windowsPipX': -120.0,
      'windowsPipY': 20.0,
    });

    final legacy = WindowSizeController.extractConfig({
      'windowSize': {
        'storedWidth': 20000,
        'storedHeight': 100,
        'windowsPipDisplayId': 'legacy-display',
        'windowsPipWidth': -1,
        'windowsPipHeight': 360,
        'windowsPipX': 20,
        'windowsPipY': 30,
      },
    });
    expect(legacy['storedWidth'], WindowSizeController.maxWindowDimension);
    expect(legacy['storedHeight'], WindowSizeController.minWindowHeight);
    expect(legacy['windowsPip'], {
      'displayId': '',
      'windowsPipWidth': 0.0,
      'windowsPipHeight': 0.0,
      'windowsPipX': 0.0,
      'windowsPipY': 0.0,
    });

    expect(() => WindowSizeController.parseConfig({'storedWidth': '900'}), throwsA(isA<TypeError>()));
    expect(() => WindowSizeController.parseConfig({'storedHeight': double.infinity}), throwsA(isA<FormatException>()));
    expect(
      () => WindowSizeController.parseConfig({
        'windowsPip': {'displayId': 7},
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => WindowSizeController.parseConfig({
        'windowsPip': {'windowsPipWidth': double.nan},
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
