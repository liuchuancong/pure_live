import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/app_refresh_rate_mode.dart';
import 'package:pure_live/common/services/display_mode_service.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/general_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> translations;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-general-settings-layout-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
    translations = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    DisplayModeService.info.value = null;
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_TestSettingsService(), permanent: true);
  });

  tearDown(() {
    Get.deleteAll(force: true);
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('refresh-rate choices remain readable and selectable in narrow very-large text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Translations(translations),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: const GeneralSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Interface refresh rate'), findsOneWidget);
    await tester.tap(find.text('Interface refresh rate'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Power saving (default)'), findsOneWidget);
    expect(find.text('Low power'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Medium power'), findsOneWidget);
    expect(find.text('Highest (device maximum)'), findsOneWidget);
    expect(find.text('High power'), findsOneWidget);

    final dialogScroll = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate(
            (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(find.text('Highest (device maximum)'), 120, scrollable: dialogScroll);
    await tester.ensureVisible(find.text('Highest (device maximum)'));
    await tester.pumpAndSettle();
    final performanceLabelTopLeft = tester.getTopLeft(find.text('Highest (device maximum)'));
    expect(performanceLabelTopLeft.dy, inInclusiveRange(0, 479));
    expect(tester.takeException(), isNull);

    await tester.tapAt(performanceLabelTopLeft + const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(SettingsService.to.app.refreshRateMode, AppRefreshRateMode.performance);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !Platform.isWindows);

  testWidgets('window-size editor localizes presets and keeps every control reachable in narrow very-large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Translations(translations),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: const GeneralSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Startup Window Size'));
    await tester.pumpAndSettle();
    expect(find.text('Startup Window Size').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Startup Window Size'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('1080 × 720 (Default)'), findsOneWidget);
    expect(find.text('1280 × 720 (720P)'), findsOneWidget);
    expect(find.text('1600 × 900'), findsOneWidget);
    expect(find.text('1920 × 1080 (1080P)'), findsOneWidget);
    expect(find.text('2560 × 1440 (2K)'), findsOneWidget);
    expect(find.textContaining('默认'), findsNothing);
    expect(find.text('Width'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Width 400–16384 · Height 300–16384'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    final dialogScroll = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate(
            (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.ensureVisible(find.text('1080 × 720 (Default)'));
    await tester.pumpAndSettle();
    final defaultPresetTopLeft = tester.getTopLeft(find.text('1080 × 720 (Default)'));
    await tester.tapAt(defaultPresetTopLeft + const Offset(4, 4));
    await tester.pump();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).map((field) => field.controller!.text),
      orderedEquals(['1080', '720']),
    );
    await tester.scrollUntilVisible(find.text('Height'), 80, scrollable: dialogScroll);
    await tester.ensureVisible(find.text('Height'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Height')).dy, inInclusiveRange(0, 479));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(SettingsService.to.window.storedWidth.value, 1280);
    expect(SettingsService.to.window.storedHeight.value, 720);

    await tester.tap(find.text('Startup Window Size'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '20000');
    await tester.enterText(fields.at(1), '900');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(find.text('Enter a window size within the supported range'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(SettingsService.to.window.storedWidth.value, 1280);
    expect(SettingsService.to.window.storedHeight.value, 720);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: !Platform.isWindows);

  testWidgets('countdown editor keeps preset and custom actions reachable in narrow very-large text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Translations(translations),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: const GeneralSettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Time before app exit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time before app exit'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    for (final minutes in [15, 30, 45, 60, 90, 120, 180]) {
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('$minutes min')), findsOneWidget);
    }
    expect(find.text('Custom Duration'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    final presetScroll = _dialogVerticalScrollable();
    await tester.scrollUntilVisible(find.text('15 min'), 80, scrollable: presetScroll);
    await tester.ensureVisible(find.text('15 min'));
    await tester.pumpAndSettle();
    final presetTopLeft = tester.getTopLeft(find.text('15 min'));
    expect(presetTopLeft.dy, inInclusiveRange(0, 479));
    expect(tester.takeException(), isNull);
    await tester.tapAt(presetTopLeft + const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(SettingsService.to.exit.autoShutDownTime.value, 15);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Time before app exit'));
    await tester.pumpAndSettle();
    final customInput = find.byType(TextField);
    await tester.ensureVisible(customInput);
    await tester.pumpAndSettle();
    await tester.enterText(customInput, '525601');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(SettingsService.to.exit.autoShutDownTime.value, 15);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(customInput, '7');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(SettingsService.to.exit.autoShutDownTime.value, 7);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Finder _dialogVerticalScrollable() {
  return find
      .descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate(
          (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
}

class _Translations extends AssetLoader {
  const _Translations(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}

class _TestSettingsService extends SettingsService {
  final AppSettingsController _app = _TestAppSettingsController();
  final ExitSettingsController _exit = _TestExitSettingsController();
  final FontSettingsController _font = FontSettingsController();
  final StartupController _startup = StartupController();
  final WindowSizeController _window = WindowSizeController();

  @override
  AppSettingsController get app => _app;

  @override
  ExitSettingsController get exit => _exit;

  @override
  FontSettingsController get font => _font;

  @override
  StartupController get startup => _startup;

  @override
  WindowSizeController get window => _window;

  @override
  // Test fixture intentionally skips production service registrations.
  // ignore: must_call_super
  void onInit() {}

  @override
  void onClose() {
    _exit.onClose();
    super.onClose();
  }
}

class _TestAppSettingsController extends AppSettingsController {
  final RxString _refreshRateModeName = AppRefreshRateMode.powerSaving.storageValue.obs;

  @override
  RxString get refreshRateModeName => _refreshRateModeName;
}

class _TestExitSettingsController extends ExitSettingsController {
  final RxInt _autoShutDownTime = 120.obs;
  final RxBool _enableAutoShutDownTime = false.obs;

  @override
  RxInt get autoShutDownTime => _autoShutDownTime;

  @override
  RxBool get enableAutoShutDownTime => _enableAutoShutDownTime;
}
