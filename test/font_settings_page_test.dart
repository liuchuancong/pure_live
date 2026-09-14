import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/font_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late _TestFontSettingsController font;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-font-settings-test-');
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
    font = _TestFontSettingsController();
    Get.put<SettingsService>(_TestSettingsService(font));
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  test('font import clamps every finite typography value to its supported slider range', () {
    final parsed = FontSettingsController.parseConfig({
      'textScaleFactor': 0.1,
      'fontSizeBodySmall': 99,
      'fontSizeBodyMedium': -2,
      'fontSizeBodyLarge': 999,
      'fontSizeTitleMedium': -10,
      'fontSizeTitleLarge': 100,
    });

    expect(parsed['textScaleFactor'], 0.5);
    expect(parsed['fontSizeBodySmall'], 15.0);
    expect(parsed['fontSizeBodyMedium'], 11.0);
    expect(parsed['fontSizeBodyLarge'], 18.0);
    expect(parsed['fontSizeTitleMedium'], 13.0);
    expect(parsed['fontSizeTitleLarge'], 26.0);
  });

  test('font import rejects non-finite typography before changing existing values', () {
    font.fontSizeBodySmall.value = 14;
    final before = font.toJson();

    expect(() => font.fromJson({'fontSizeTitleLarge': double.infinity}), throwsA(isA<FormatException>()));
    expect(font.toJson(), before);
  });

  test('startup normalizes persisted typography before the first rendered theme', () async {
    await HivePrefUtil.setDouble('textScaleFactor', 8);
    await HivePrefUtil.setDouble('fontSizeBodySmall', -4);
    await HivePrefUtil.setDouble('fontSizeTitleLarge', double.nan);
    final stored = _StartupFontSettingsController()..onInit();
    addTearDown(stored.onClose);

    expect(stored.textScaleFactor.value, FontSettingsController.maxTextScaleFactor);
    expect(stored.fontSizeBodySmall.value, FontSettingsController.minFontSizeBodySmall);
    expect(stored.fontSizeTitleLarge.value, FontSettingsController.defaultFontSizeTitleLarge);
  });

  testWidgets('narrow very-large page exposes every typography description and final slider', (tester) async {
    await _pumpPage(tester, english);

    for (final text in [
      'Used for live viewer counts, badges, and metadata chips',
      'Used for primary descriptive copy and regular list labels',
      'Used for main list item titles and active block descriptors',
      'Used for live room grid titles and popup input headers',
      'Used for top AppBar navigation titles and critical alert headings',
    ]) {
      final description = find.text(text);
      await _scrollUntilHitTestable(tester, description);
      expect(description.hitTestable(), findsOneWidget);
    }

    final finalDescription = find.text('Used for top AppBar navigation titles and critical alert headings');
    expect(finalDescription.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide typography editor keeps a readable centered content width', (tester) async {
    await _pumpPage(tester, english, size: const Size(1440, 900), textScale: 1);

    expect(tester.getSize(find.byKey(const ValueKey('font-settings-content'))).width, 720);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset requires confirmation and restores all five defaults together', (tester) async {
    font.fontSizeBodySmall.value = 9;
    font.fontSizeBodyMedium.value = 17;
    font.fontSizeBodyLarge.value = 18;
    font.fontSizeTitleMedium.value = 13;
    font.fontSizeTitleLarge.value = 26;
    await _pumpPage(tester, english);

    await tester.tap(find.byTooltip('Reset'));
    await _pumpRouteTransition(tester);
    expect(find.byKey(const ValueKey('font-settings-reset-dialog')), findsOneWidget);
    expect(font.fontSizeBodySmall.value, 9);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await _pumpRouteTransition(tester);
    expect(font.fontSizeBodySmall.value, 9);
    expect(font.fontSizeTitleLarge.value, 26);

    await tester.tap(find.byTooltip('Reset'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await _pumpRouteTransition(tester);

    expect(font.fontSizeBodySmall.value, 12);
    expect(font.fontSizeBodyMedium.value, 13);
    expect(font.fontSizeBodyLarge.value, 14);
    expect(font.fontSizeTitleMedium.value, 15);
    expect(font.fontSizeTitleLarge.value, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset confirmation coalesces repeated actions and releases after cancellation', (tester) async {
    await _pumpPage(tester, english);
    final resetAction = find.ancestor(of: find.byTooltip('Reset'), matching: find.byType(IconButton));
    final onPressed = tester.widget<IconButton>(resetAction).onPressed!;

    onPressed();
    onPressed();
    await _pumpRouteTransition(tester);

    expect(find.byKey(const ValueKey('font-settings-reset-dialog')), findsOneWidget);
    final cancel = find.widgetWithText(TextButton, 'Cancel').hitTestable();
    final reset = find.widgetWithText(FilledButton, 'Reset').hitTestable();
    expect(cancel, findsOneWidget);
    expect(reset, findsOneWidget);
    expect(tester.getSize(cancel).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(reset).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(reset).height, greaterThanOrEqualTo(48));
    await tester.tap(cancel);
    await _pumpRouteTransition(tester);

    onPressed();
    await _pumpRouteTransition(tester);
    expect(find.byKey(const ValueKey('font-settings-reset-dialog')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await _pumpRouteTransition(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  Map<String, dynamic> english, {
  Size size = const Size(320, 480),
  double textScale = 3,
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
          home: const FontSettingsPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _scrollUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = find.byKey(const ValueKey('font-settings-scroll'));
  for (var attempt = 0; attempt < 60; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(scrollable, const Offset(0, -140));
    await tester.pump();
  }
  fail('Font setting did not become hit-testable after bounded scrolling.');
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestFontSettingsController extends FontSettingsController {
  @override
  // Test fixture intentionally skips font manifest I/O and theme observers.
  // ignore: must_call_super
  void onInit() {}
}

class _StartupFontSettingsController extends FontSettingsController {
  @override
  Future<void> ensureInitialized() async {}

  @override
  void refreshSystemTheme() {}
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._font);

  final FontSettingsController _font;

  @override
  FontSettingsController get font => _font;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
