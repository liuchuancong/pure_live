import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/video_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-video-settings-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_TestSettingsService());
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('resolution preferences localize stable values and keep whole options tappable', (tester) async {
    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.windows,
    );

    await tester.scrollUntilVisible(find.text('Desktop Default Volume'), 120, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    final volumeTitle = tester.getRect(find.text('Desktop Default Volume'));
    final volumeValue = tester.getRect(find.text('100%'));
    expect(volumeValue.top, greaterThanOrEqualTo(volumeTitle.bottom));
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Resolution Preference'), 180, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsNWidgets(2));
    expect(find.text('原画'), findsNothing);

    await tester.tap(find.text('Resolution Preference'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    for (final label in ['Original', 'Blu-ray 8 Mbps', 'Blu-ray 4 Mbps', 'Super HD', 'Smooth']) {
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(label)), findsOneWidget);
    }
    expect(find.text('原画'), findsNothing);
    expect(tester.takeException(), isNull);

    final smoothOption = find.widgetWithText(SimpleDialogOption, 'Smooth');
    await tester.ensureVisible(smoothOption);
    await tester.pumpAndSettle();
    await tester.tap(smoothOption);
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.preferResolution.value, '流畅');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Smooth'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Mobile Network Quality'), 120, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile Network Quality'));
    await tester.pumpAndSettle();
    final cellularOption = find.widgetWithText(SimpleDialogOption, 'Blu-ray 4 Mbps');
    await tester.ensureVisible(cellularOption);
    await tester.pumpAndSettle();
    await tester.tap(cellularOption);
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.preferResolutionCellular.value, '蓝光4M');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Blu-ray 4 Mbps'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !Platform.isWindows);

  testWidgets('unknown resolution values render and select through the canonical default', (tester) async {
    SettingsService.to.player.preferResolution.value = 'retired-wifi-quality';
    SettingsService.to.player.preferResolutionCellular.value = 'retired-cellular-quality';

    await _pumpVideoSettings(tester, english: english, size: const Size(420, 800), platform: TargetPlatform.windows);

    await tester.scrollUntilVisible(find.text('Resolution Preference'), 180, scrollable: _pageScrollable());
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsNWidgets(2));
    expect(find.text('retired-wifi-quality'), findsNothing);
    expect(find.text('retired-cellular-quality'), findsNothing);
    expect(SettingsService.to.player.preferResolution.value, 'retired-wifi-quality');

    await tester.tap(find.text('Resolution Preference'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<String>>(find.descendant(of: dialog, matching: find.byType(RadioGroup<String>)))
          .groupValue,
      '原画',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Original'));
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.preferResolution.value, '原画');
    expect(dialog, findsNothing);
  }, skip: !Platform.isWindows);

  testWidgets('Windows PiP reset coalesces confirmation and preserves or clears the whole saved geometry', (
    tester,
  ) async {
    final window = SettingsService.to.window;
    window.windowsPip.update(const Size(640, 360), const Offset(120, 80), 'DISPLAY-1');

    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.windows,
    );

    final resetEntry = find.ancestor(of: find.text('Reset PiP position and size'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, resetEntry);
    final resetTap = tester.widget<ListTile>(resetEntry).onTap!;

    resetTap();
    resetTap();
    await _pumpRouteTransition(tester);

    final dialog = find.byKey(const ValueKey('windows-pip-reset-dialog'));
    expect(dialog, findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(window.windowsPip.displayId.value, 'DISPLAY-1');
    expect(window.windowsPip.size, const Size(640, 360));
    expect(window.windowsPip.position, const Offset(120, 80));

    final cancel = find.widgetWithText(TextButton, 'Cancel').hitTestable();
    final reset = find.widgetWithText(FilledButton, 'Reset').hitTestable();
    expect(cancel, findsOneWidget);
    expect(reset, findsOneWidget);
    expect(tester.getSize(cancel).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(reset).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(reset).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(dialog).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(dialog).bottom, lessThanOrEqualTo(480));

    await tester.tap(cancel);
    await _pumpRouteTransition(tester);
    expect(dialog, findsNothing);
    expect(window.windowsPip.displayId.value, 'DISPLAY-1');
    expect(window.windowsPip.size, const Size(640, 360));
    expect(window.windowsPip.position, const Offset(120, 80));

    resetTap();
    await _pumpRouteTransition(tester);
    expect(dialog, findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reset').hitTestable());
    await _pumpRouteTransition(tester);

    expect(dialog, findsNothing);
    expect(window.windowsPip.displayId.value, isEmpty);
    expect(window.windowsPip.size, Size.zero);
    expect(window.windowsPip.position, Offset.zero);
    expect(window.windowsPip.isValid, isFalse);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isWindows);

  testWidgets('ASMR timer keeps every preset and action reachable in narrow very-large text', (tester) async {
    await _pumpVideoSettings(
      tester,
      english: english,
      size: const Size(320, 480),
      textScale: 3,
      platform: TargetPlatform.android,
    );

    final timerEntry = find.ancestor(of: find.text('Auto sleep playback duration'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, timerEntry);
    await tester.tap(timerEntry.hitTestable());
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.byType(ActionChip)), findsNWidgets(10));
    expect(find.descendant(of: dialog, matching: find.text('Custom playback duration')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    for (final label in ['15 min', '30 min', '45 min', '1 h', '90 min', '2 h', '4 h', '8 h', '12 h', '1 d']) {
      expect(find.descendant(of: dialog, matching: find.text(label)), findsOneWidget);
    }
    final lastPreset = find.descendant(of: dialog, matching: find.byType(ActionChip)).last;
    await tester.ensureVisible(lastPreset);
    await tester.pumpAndSettle();
    expect(tester.getRect(lastPreset).bottom, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  }, skip: !Platform.isWindows);

  testWidgets('ASMR timer keeps a focused custom input alive through route dismissal', (tester) async {
    await _pumpVideoSettings(tester, english: english, size: const Size(420, 800), platform: TargetPlatform.android);

    final timerEntry = find.ancestor(of: find.text('Auto sleep playback duration'), matching: find.byType(ListTile));
    await _scrollPageUntilHitTestable(tester, timerEntry);
    await tester.tap(timerEntry.hitTestable());
    await tester.pumpAndSettle();
    final customInput = find.byType(TextField);
    await tester.ensureVisible(customInput);
    await tester.pumpAndSettle();
    await tester.enterText(customInput, '7');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(SettingsService.to.app.asmrSleepMinutes.value, 7);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !Platform.isWindows);
}

Future<void> _pumpVideoSettings(
  WidgetTester tester, {
  required Map<String, dynamic> english,
  required Size size,
  double textScale = 1,
  required TargetPlatform platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _Translations(english),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: VideoSettingsPage(platformOverride: platform),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _pageScrollable() {
  return find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
}

Future<void> _scrollPageUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(_pageScrollable());
  for (var attempt = 0; attempt < 30; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final position = scrollable.position;
    final next = position.pixels + position.viewportDimension * 0.75;
    position.jumpTo(next > position.maxScrollExtent ? position.maxScrollExtent : next);
    await tester.pump();
  }
  fail('Target did not become hit-testable after bounded page scrolling.');
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestSettingsService extends SettingsService {
  final AppSettingsController _app = AppSettingsController();
  final DanmakuSettingsController _danmaku = DanmakuSettingsController();
  final FontSettingsController _font = FontSettingsController();
  final PlayerSettingsController _player = PlayerSettingsController();
  final VolumeSettingsController _volume = VolumeSettingsController();
  final WindowSizeController _window = WindowSizeController();

  @override
  AppSettingsController get app => _app;

  @override
  DanmakuSettingsController get danmaku => _danmaku;

  @override
  FontSettingsController get font => _font;

  @override
  PlayerSettingsController get player => _player;

  @override
  VolumeSettingsController get vol => _volume;

  @override
  WindowSizeController get window => _window;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
