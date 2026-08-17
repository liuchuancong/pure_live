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
import 'package:pure_live/modules/settings/pages/pip_danmaku_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-pip-preview-test-');
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

  tearDown(() {
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('font size slider value rebuilds the PiP preview immediately', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh')],
        path: 'assets/translations',
        fallbackLocale: const Locale('zh'),
        assetLoader: const _TestAssetLoader(),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const Scaffold(body: SizedBox(width: 350, child: PipDanmakuPreview())),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    dynamic painter = _previewPainter(tester);
    expect(painter.fontSize, closeTo(12, 0.01));

    SettingsService.to.danmaku.pipDanmakuFontSize.value = 22;
    await tester.pump();

    painter = _previewPainter(tester);
    expect(painter.fontSize, closeTo(22, 0.01));
  });

  testWidgets('mobile settings scroll independently while preview stays pinned', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh')],
        path: 'assets/translations',
        fallbackLocale: const Locale('zh'),
        assetLoader: const _TestAssetLoader(),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const PipDanmakuSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final preview = find.byKey(const ValueKey('pip-danmaku-preview-pane'));
    final settings = find.byKey(const ValueKey('pip-danmaku-settings-scroll'));
    final before = tester.getTopLeft(preview);
    await tester.drag(settings, const Offset(0, -260));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.getTopLeft(preview), before);
    final scrollableState = tester.state<ScrollableState>(
      find.descendant(of: settings, matching: find.byType(Scrollable)),
    );
    expect(scrollableState.position.pixels, greaterThan(0));
  });

  testWidgets('pure-text switch refreshes preview content immediately', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh')],
        path: 'assets/translations',
        fallbackLocale: const Locale('zh'),
        assetLoader: const _TestAssetLoader(),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const Scaffold(body: SizedBox(width: 350, child: PipDanmakuPreview())),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    dynamic painter = _previewPainter(tester);
    expect((painter.painters.first.text as TextSpan).text, contains('🎉'));

    SettingsService.to.danmaku.pipDanmakuNoEmojiMode.value = true;
    await tester.pump();

    painter = _previewPainter(tester);
    expect((painter.painters.first.text as TextSpan).text, isNot(contains('🎉')));
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'pip_danmaku_preview_text': 'preview',
    'pip_danmaku_disabled': 'disabled',
    'pip_danmaku': 'PiP danmaku',
    'pip_danmaku_desc': 'Adjust while preview remains visible',
    'pip_danmaku_preview': 'Preview',
    'pip_danmaku_reset': 'Reset',
    'pip_danmaku_enable': 'Enable',
    'pip_danmaku_auto_scale': 'Auto scale',
    'danmaku_no_emoji': 'Pure text',
    'pip_danmaku_original_color': 'Original color',
    'font_size': 'Font size',
    'speed': 'Speed',
    'opacity': 'Opacity',
    'danmaku_area': 'Area',
    'pip_danmaku_max_visible': 'Maximum visible',
    'pip_danmaku_interval': 'Interval',
    'danmaku_fps': 'FPS',
    'dynamic_follow_display': 'Dynamic',
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

dynamic _previewPainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(PipDanmakuPreview), matching: find.byType(CustomPaint)),
  );
  return customPaint.painter;
}
