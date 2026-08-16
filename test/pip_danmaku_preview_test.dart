import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
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
          builder: (context) => MaterialApp(
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
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
    'pip_danmaku_preview_text': 'preview',
    'pip_danmaku_disabled': 'disabled',
  };
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._danmaku);

  final DanmakuSettingsController _danmaku;

  @override
  DanmakuSettingsController get danmaku => _danmaku;

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
