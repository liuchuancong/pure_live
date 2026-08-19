import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/danmaku_settings_binding.dart';
import 'package:pure_live/modules/live_play/danmaku_viewing_preset.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_settings_page.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-danmaku-surface-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_TestSettingsService(DanmakuSettingsController()));
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('portrait uses the canonical reactive settings surface', (tester) async {
    final portrait = _TestDanmakuSettingsBinding();
    await tester.pumpWidget(_testApp(DanmakuSettingsContent(controller: portrait, includePipSettings: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('danmaku-settings-content-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('danmaku-template-best')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('danmaku-template-best')));
    await tester.pump();
    _expectBestPreset(portrait);
  });

  testWidgets('fullscreen uses the same surface in an adaptive landscape panel', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fullscreen = _TestDanmakuSettingsBinding();
    await tester.pumpWidget(_testApp(SettingsPanel(controller: fullscreen)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fullscreen-danmaku-settings-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('danmaku-settings-content-embedded')), findsOneWidget);
    expect(find.byKey(const ValueKey('danmaku-template-best')), findsOneWidget);
    expect(find.text('PiP danmaku'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('danmaku-template-best')));
    await tester.pump();
    _expectBestPreset(fullscreen);

    final panelRect = tester.getRect(find.byKey(const ValueKey('fullscreen-danmaku-settings-panel')));
    expect(panelRect.width, inInclusiveRange(480, 640));
    expect(panelRect.right, greaterThan(950));
  });

  testWidgets('portrait and compact landscape keep one preset state without overflow', (tester) async {
    final shared = _TestDanmakuSettingsBinding();
    final showLandscapePanel = ValueNotifier<bool>(false);
    addTearDown(showLandscapePanel.dispose);
    await tester.pumpWidget(
      _testApp(
        ValueListenableBuilder<bool>(
          valueListenable: showLandscapePanel,
          builder: (context, landscape, _) =>
              landscape ? SettingsPanel(controller: shared) : DanmakuSettingsPage(controller: shared),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final densityBefore = tester.getRect(find.byKey(const ValueKey('danmaku-template-dense')));
    await tester.tap(find.byKey(const ValueKey('danmaku-template-comfort')));
    await tester.pump();
    final densityAfter = tester.getRect(find.byKey(const ValueKey('danmaku-template-dense')));
    final comfort = DanmakuViewingPreset.values.firstWhere((preset) => preset.id == 'comfort');
    expect(shared.danmakuArea.value, comfort.area);
    expect(densityAfter, densityBefore, reason: 'selecting a preset must not reflow the fullscreen controls');

    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    showLandscapePanel.value = true;
    await tester.pumpAndSettle();

    final selected = tester.widget<ChoiceChip>(find.byKey(const ValueKey('danmaku-template-comfort')));
    expect(selected.selected, isTrue);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byKey(const ValueKey('danmaku-settings-content-embedded')), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('PiP danmaku'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child) {
  return EasyLocalization(
    key: ValueKey<Type>(child.runtimeType),
    supportedLocales: const [Locale('zh')],
    path: 'assets/translations',
    fallbackLocale: const Locale('zh'),
    assetLoader: const _TestAssetLoader(),
    child: Builder(
      builder: (context) => GetMaterialApp(
        locale: context.locale,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

void _expectBestPreset(_TestDanmakuSettingsBinding binding) {
  final best = DanmakuViewingPreset.values.firstWhere((preset) => preset.id == 'best');
  expect(binding.danmakuArea.value, best.area);
  expect(binding.danmakuTopArea.value, best.top);
  expect(binding.danmakuBottomArea.value, best.bottom);
  expect(binding.danmakuSpeed.value, best.speed);
  expect(binding.danmakuFontSize.value, best.fontSize);
  expect(binding.danmakuFontWeight.value, best.fontWeight);
  expect(binding.danmakuFontBorder.value, best.fontBorder);
  expect(binding.danmakuOpacity.value, best.opacity);
  expect(binding.enableDanmakuStroke.value, best.stroke);
}

class _TestDanmakuSettingsBinding implements DanmakuSettingsBinding {
  @override
  final noEmojiMode = false.obs;
  @override
  final danmakuArea = 1.0.obs;
  @override
  final danmakuTopArea = 0.0.obs;
  @override
  final danmakuBottomArea = 0.5.obs;
  @override
  final danmakuSpeed = 120.0.obs;
  @override
  final danmakuFontSize = 16.0.obs;
  @override
  final danmakuFontWeight = 500.obs;
  @override
  final danmakuFontBorder = 1.5.obs;
  @override
  final danmakuOpacity = 1.0.obs;
  @override
  final enableDanmakuStroke = true.obs;
  @override
  final danmakuFps = 60.obs;
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => const {
    'settings_danmaku_title': 'Danmaku settings',
    'danmaku_templates': 'Templates',
    'danmaku_template_best': 'Best',
    'danmaku_template_comfort': 'Comfort',
    'danmaku_template_dense': 'Dense',
    'reset': 'Default',
    'save_current_template': 'Save',
    'restore_saved_template': 'Restore',
    'danmaku_best_preset_desc': 'Recommended viewing area',
    'danmaku_realtime_hint': 'Changes apply immediately',
    'danmaku_template_applied': 'Applied',
    'danmaku_area': 'Area',
    'position': 'Position',
    'style': 'Style',
    'danmaku_screen_interaction': 'Interaction',
    'danmaku_repeat_filter': 'Repeated danmaku filter',
    'collapse_repeated_danmaku': 'Merge repeated text',
    'collapse_repeated_danmaku_desc': 'Hide the same audience text inside the time window',
    'repeated_danmaku_window': 'Merge window',
    'danmaku_no_emoji': 'Pure text',
    'margin_top': 'Top margin',
    'margin_bottom': 'Bottom margin',
    'opacity': 'Opacity',
    'speed': 'Speed',
    'font_size': 'Font size',
    'font_weight': 'Font weight',
    'font_weight_medium': 'Medium',
    'danmaku_stroke': 'Stroke',
    'stroke': 'Stroke width',
    'danmaku_fps': 'FPS',
    'dynamic_follow_display': 'Dynamic',
    'danmaku_tap_action': 'Tap action',
    'danmaku_long_press_action': 'Long press action',
    'pip_danmaku': 'PiP danmaku',
    'pip_danmaku_enable': 'Enable PiP danmaku',
    'pip_danmaku_auto_scale': 'Auto scale',
    'pip_danmaku_original_color': 'Original color',
    'pip_danmaku_max_visible': 'Maximum visible',
    'pip_danmaku_interval': 'Interval',
    'close': 'Close',
  };
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._danmaku) : _font = FontSettingsController();

  final DanmakuSettingsController _danmaku;
  final FontSettingsController _font;

  @override
  DanmakuSettingsController get danmaku => _danmaku;

  @override
  FontSettingsController get font => _font;

  @override
  // Test fixture intentionally skips the production service registrations.
  // ignore: must_call_super
  void onInit() {}
}
