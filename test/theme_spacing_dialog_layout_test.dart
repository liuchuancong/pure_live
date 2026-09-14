import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/theme_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late _TestThemeSettingsController theme;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-theme-spacing-test-');
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
    theme = _TestThemeSettingsController();
    Get.put<SettingsService>(_TestSettingsService(theme));
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('narrow very-large spacing dialog keeps presets, input and actions reachable', (tester) async {
    await _pumpPage(tester, english);
    final spacingTile = find.text('Horizontal Spacing');
    await _scrollUntilHitTestable(tester, spacingTile);
    await tester.tap(spacingTile.hitTestable());
    await _pumpRouteTransition(tester);

    expect(find.text('0 px'), findsOneWidget);
    expect(find.text('16 px'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await _scrollDialogToBottom(tester);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Confirm').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused input commits after route exit and rejects negative spacing', (tester) async {
    await _pumpPage(tester, english);
    final spacingTile = find.text('Horizontal Spacing');
    await _scrollUntilHitTestable(tester, spacingTile);
    await tester.tap(spacingTile.hitTestable());
    await _pumpRouteTransition(tester);

    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, '-1');
    await _scrollDialogToBottom(tester);
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pump();
    expect(find.text('Enter a spacing from 0 to 64'), findsOneWidget);
    expect(theme.crossAxisSpacing.value, 6);

    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, '9.5');
    await _scrollDialogToBottom(tester);
    await tester.tap(find.text('Confirm').hitTestable());
    await _pumpRouteTransition(tester);
    expect(theme.crossAxisSpacing.value, 9.5);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical spacing preset commits through the same bounded dialog', (tester) async {
    await _pumpPage(tester, english);
    final spacingTile = find.text('Vertical Spacing');
    await _scrollUntilHitTestable(tester, spacingTile);
    await tester.tap(spacingTile.hitTestable());
    await _pumpRouteTransition(tester);

    final preset = find.byKey(const ValueKey('theme-spacing-preset-16'));
    await tester.ensureVisible(preset);
    await tester.pump();
    await tester.tap(preset);
    await _scrollDialogToBottom(tester);
    await tester.tap(find.byKey(const ValueKey('theme-spacing-confirm')));
    await _pumpRouteTransition(tester);

    expect(theme.mainAxisSpacing.value, 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme mode dialog keeps the final choice reachable at very-large text', (tester) async {
    await _pumpPage(tester, english);
    final themeModeTile = find.text('Theme Mode');
    await _scrollUntilHitTestable(tester, themeModeTile);
    await tester.tap(themeModeTile.hitTestable());
    await _pumpRouteTransition(tester);

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    final light = find.text('Light');
    await tester.ensureVisible(light);
    await tester.pump();
    await tester.tap(light.hitTestable());
    await _pumpRouteTransition(tester);

    expect(theme.themeModeName.value, 'Light');
    expect(tester.takeException(), isNull);
  });

  testWidgets('language dialog keeps both complete choices reachable at very-large text', (tester) async {
    await _pumpPage(tester, english);
    final languageTile = find.text('Change language');
    await _scrollUntilHitTestable(tester, languageTile);
    await tester.tap(languageTile.hitTestable());
    await _pumpRouteTransition(tester);

    expect(find.text('English'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    final englishChoice = find.text('English');
    await tester.ensureVisible(englishChoice);
    await tester.pump();
    await tester.tap(englishChoice.hitTestable());
    await _pumpRouteTransition(tester);

    expect(theme.languageName.value, 'English');
    expect(tester.takeException(), isNull);
  });

  test('spacing policy accepts only finite values inside the supported range', () {
    expect(ThemeSpacingPolicy.tryParse('0'), 0);
    expect(ThemeSpacingPolicy.tryParse(' 9.5 '), 9.5);
    expect(ThemeSpacingPolicy.tryParse('64'), 64);
    expect(ThemeSpacingPolicy.tryParse('-0.1'), isNull);
    expect(ThemeSpacingPolicy.tryParse('64.1'), isNull);
    expect(ThemeSpacingPolicy.tryParse('NaN'), isNull);
    expect(ThemeSpacingPolicy.tryParse('Infinity'), isNull);
    expect(ThemeSpacingPolicy.tryParse(''), isNull);
  });
}

Future<void> _scrollDialogToBottom(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(of: find.byKey(const ValueKey('theme-spacing-dialog-scroll')), matching: find.byType(Scrollable))
        .first,
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _scrollUntilHitTestable(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pump();
  }
  fail('Theme setting did not become hit-testable after bounded scrolling.');
}

Future<void> _pumpPage(WidgetTester tester, Map<String, dynamic> english) async {
  tester.view.physicalSize = const Size(320, 480);
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
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: const ThemeSettingsPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestThemeSettingsController extends ThemeSettingsController {
  @override
  // This in-memory fixture intentionally skips theme refresh observers.
  // ignore: must_call_super
  void onInit() {}

  @override
  void changeThemeMode(String mode) => themeModeName.value = mode;

  @override
  Future<void> changeLanguage(String value, BuildContext context) async => languageName.value = value;
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._theme) : _font = FontSettingsController();

  final ThemeSettingsController _theme;
  final FontSettingsController _font;

  @override
  ThemeSettingsController get theme => _theme;

  @override
  FontSettingsController get font => _font;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
