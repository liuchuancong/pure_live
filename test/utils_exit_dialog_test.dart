import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowChannel = MethodChannel('window_manager');
  const trayChannel = MethodChannel('tray_manager');
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late Map<String, dynamic> chinese;
  late ExitSettingsController exitSettings;
  late List<MethodCall> windowCalls;
  bool preventClose = true;
  String? failingWindowMethod;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-exit-dialog-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
    chinese = jsonDecode(await File('assets/translations/zh.json').readAsString()) as Map<String, dynamic>;
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    exitSettings = Get.put(ExitSettingsController());
    Get.put<SettingsService>(_ExitSettingsService(exitSettings), permanent: true);
    windowCalls = <MethodCall>[];
    preventClose = true;
    failingWindowMethod = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, (
      call,
    ) async {
      windowCalls.add(call);
      if (call.method == failingWindowMethod) {
        throw PlatformException(code: 'fixture-failure', message: call.method);
      }
      return switch (call.method) {
        'isVisible' => true,
        'isMinimized' => false,
        'isPreventClose' => preventClose,
        _ => null,
      };
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      trayChannel,
      (_) async => null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(windowChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(trayChannel, null);
    Get.reset();
    await HivePrefUtil.flush();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  test('exit action values have one repaired persistence contract and concise labels', () {
    expect(exitSettings.exitChoose.value, 'exit');
    exitSettings.setExitAction('damaged');
    expect(exitSettings.exitChoose.value, 'exit');
    expect(ExitSettingsController.parseConfig({'exitChoose': 'minimize'})['exitChoose'], 'minimize');
    expect(ExitSettingsController.parseConfig({'exitChoose': 'damaged'})['exitChoose'], 'exit');
    expect(ExitSettingsController.parseConfig({'exitChoose': 7})['exitChoose'], 'exit');
    expect(
      ExitSettingsController.extractConfig({
        'exit': {'exitChoose': 'damaged'},
      })['exitChoose'],
      'exit',
    );
    expect(english['exit_app'], 'Exit');
    expect(chinese['exit_app'], '退出应用');
  });

  testWidgets('large-text exit choice stays reachable and commits only the completed action', (tester) async {
    await _pumpLauncher(tester, english, onPressed: () {}, textScale: 3);
    _restoreSettingsRegistration(exitSettings);

    final flow = (await _startExitFlow(tester)).future;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Minimize').hitTestable(), findsOneWidget);
    expect(find.text('Exit').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('Minimize')).bottom, lessThanOrEqualTo(480));
    expect(tester.getRect(find.text('Exit')).bottom, lessThanOrEqualTo(480));

    final dontAskAgain = find.text("Don't ask again");
    await tester.scrollUntilVisible(dontAskAgain, 80, scrollable: find.byType(Scrollable).last);
    expect(dontAskAgain.hitTestable(), findsOneWidget);
    await tester.tap(dontAskAgain.hitTestable());
    expect(find.text('Minimize').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Minimize').hitTestable());
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => flow), isTrue);
    expect(exitSettings.dontAskExit.value, isTrue);
    expect(exitSettings.exitChoose.value, 'minimize');
    expect(windowCalls.map((call) => call.method), containsAllInOrder(['isPreventClose', 'hide']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed native action rolls the preference back and completes without a framework error', (tester) async {
    failingWindowMethod = 'hide';
    await _pumpLauncher(tester, english, onPressed: () {});
    _restoreSettingsRegistration(exitSettings);

    final flow = (await _startExitFlow(tester)).future;
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't ask again"));
    await tester.tap(find.text('Minimize'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => flow), isFalse);
    expect(exitSettings.dontAskExit.value, isFalse);
    expect(exitSettings.exitChoose.value, 'exit');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed native exit restores close interception and the visible window', (tester) async {
    failingWindowMethod = 'destroy';
    await _pumpLauncher(tester, english, onPressed: () {});
    _restoreSettingsRegistration(exitSettings);

    final flow = (await _startExitFlow(tester)).future;
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't ask again"));
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => flow), isFalse);
    expect(exitSettings.dontAskExit.value, isFalse);
    expect(exitSettings.exitChoose.value, 'exit');
    expect(
      windowCalls.map((call) => call.method),
      containsAllInOrder([
        'isVisible',
        'hide',
        'isPreventClose',
        'setPreventClose',
        'destroy',
        'setPreventClose',
        'isMinimized',
        'show',
        'focus',
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('concurrent close requests share one decision route', (tester) async {
    await _pumpLauncher(tester, english, onPressed: () {});
    _restoreSettingsRegistration(exitSettings);

    late Future<bool> first;
    late Future<bool> second;
    await tester.runAsync(() async {
      first = Utils.showExitDialog();
      second = Utils.showExitDialog();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => first), isFalse);
    expect(await tester.runAsync(() => second), isFalse);
    expect(windowCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remembered minimize uses the native minimize fallback when close interception is off', (tester) async {
    exitSettings.dontAskExit.value = true;
    exitSettings.exitChoose.value = 'minimize';
    preventClose = false;
    await _pumpLauncher(tester, english, onPressed: () {});
    _restoreSettingsRegistration(exitSettings);

    expect(await tester.runAsync(Utils.showExitDialog), isTrue);
    expect(windowCalls.map((call) => call.method), containsAllInOrder(['isPreventClose', 'minimize']));
    expect(find.byType(AlertDialog), findsNothing);
  });
}

Future<({Future<bool> future})> _startExitFlow(WidgetTester tester) async {
  late Future<bool> future;
  await tester.runAsync(() async {
    future = Utils.showExitDialog();
    await Future<void>.delayed(Duration.zero);
  });
  return (future: future);
}

void _restoreSettingsRegistration(ExitSettingsController exitSettings) {
  if (!Get.isRegistered<SettingsService>()) {
    Get.put<SettingsService>(_ExitSettingsService(exitSettings), permanent: true);
  }
}

Future<void> _pumpLauncher(
  WidgetTester tester,
  Map<String, dynamic> translations, {
  required VoidCallback onPressed,
  double textScale = 1,
}) async {
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
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: FilledButton(onPressed: onPressed, child: const Text('Open dialog')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class _Translations extends AssetLoader {
  const _Translations(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}

class _ExitSettingsService extends SettingsService {
  _ExitSettingsService(this._exit);

  final ExitSettingsController _exit;

  @override
  ExitSettingsController get exit => _exit;

  @override
  // Test fixture intentionally skips production service registrations.
  // ignore: must_call_super
  void onInit() {}
}
