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
import 'package:pure_live/recorder/consts/recorder_config.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, dynamic> translations;
  late Map<String, dynamic> englishTranslations;
  late RecordSettingsController settings;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('pure-live-recorder-settings-page-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(directory.path);
    await HivePrefUtil.init();
    translations = jsonDecode(await File('assets/translations/zh.json').readAsString()) as Map<String, dynamic>;
    englishTranslations = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });
  setUp(() async {
    Get.testMode = true;
    await HivePrefUtil.clear();
    Get.put<SettingsService>(_SettingsService());
    settings = Get.put<RecordSettingsController>(_RecorderSettings());
  });
  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final size in [const Size(360, 780), const Size(900, 500)]) {
    testWidgets('resume setting is visible independently of polling at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('zh')],
          path: 'assets/translations',
          fallbackLocale: const Locale('zh'),
          assetLoader: _Translations(translations),
          child: Builder(
            builder: (context) => GetMaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const RecordSettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final resume = find.widgetWithText(SwitchListTile, translations['auto_start_boot'] as String);
      await tester.scrollUntilVisible(resume, 500, maxScrolls: 30);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<SwitchListTile>(resume).value, isFalse);
      final description = tester.widget<Text>(find.text(translations['auto_start_boot_desc'] as String));
      expect(description.maxLines, isNull, reason: 'resume conditions must not be truncated to one line');
      await tester.tap(find.descendant(of: resume, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(settings.autoStartOnBoot.value, isTrue);
      expect(settings.enablePolling.value, isFalse);
      settings.enablePolling.value = true;
      await tester.pumpAndSettle();
      await tester.ensureVisible(resume);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(resume).value, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('open-folder header action keeps a 48dp touch target', (tester) async {
    await _pumpRecorderSettings(
      tester,
      translations: translations,
      locale: const Locale('zh'),
      size: const Size(360, 780),
      textScale: 1,
    );

    final label = find.text(translations['recorder_open_folder'] as String);
    await _scrollPageUntilHitTestable(tester, label);
    final button = find.ancestor(of: label, matching: find.byType(TextButton));
    expect(button, findsOneWidget);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('narrow very-large text keeps recorder controls and every quality reachable', (tester) async {
    settings.managedRecordPath.value = r'C:\Users\tester\Pure Live\Recordings\A very long managed recording folder';
    await _pumpRecorderSettings(
      tester,
      translations: englishTranslations,
      locale: const Locale('en'),
      size: const Size(320, 480),
      textScale: 3,
    );

    expect(find.text('Original'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'initial recorder settings');

    final openFolder = find.text('Open Folder');
    await _scrollPageUntilHitTestable(tester, openFolder);
    expect(tester.getRect(openFolder).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull, reason: 'cache heading actions');

    final qualityTitle = find.text('Default Recording Quality');
    await _scrollPageUntilHitTestable(tester, qualityTitle);
    await tester.tap(qualityTitle.hitTestable());
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'quality selector');

    final smooth = find.text('Smooth');
    final dialogScrollable = find.descendant(of: dialog, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(smooth, 100, scrollable: dialogScrollable);
    await tester.pumpAndSettle();
    expect(tester.getRect(smooth).bottom, lessThanOrEqualTo(480));
    await tester.tap(find.ancestor(of: smooth, matching: find.byType(RadioListTile<String>)));
    await tester.pumpAndSettle();
    expect(settings.defaultQuality.value, '流畅');
    expect(find.text('Smooth'), findsOneWidget);

    final clearFolder = find.text('Clear Recording Folder');
    await _scrollPageUntilHitTestable(tester, clearFolder);
    await tester.tap(clearFolder.hitTestable());
    await tester.pumpAndSettle();
    expect(settings.cacheClearPromptOpen.value, isTrue);
    expect(settings.cacheClearPending.value, isFalse, reason: 'confirmation is not a cache operation');
    final clearDialog = find.byType(AlertDialog);
    expect(clearDialog, findsOneWidget);
    final cancel = find.descendant(of: clearDialog, matching: find.text('Cancel'));
    final clear = find.descendant(of: clearDialog, matching: find.text('Clear'));
    expect(cancel.hitTestable(), findsOneWidget);
    expect(clear.hitTestable(), findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(clearDialog, findsNothing);
    expect(settings.cacheClearPromptOpen.value, isFalse);
    expect(settings.cacheClearPending.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('numeric recorder editors preserve valid values until bounded input is confirmed', (tester) async {
    settings.enableCacheLimit.value = true;
    await _pumpRecorderSettings(
      tester,
      translations: englishTranslations,
      locale: const Locale('en'),
      size: const Size(320, 480),
      textScale: 3,
    );

    final maxTasks = find.text('Maximum Concurrent Recording Tasks');
    await _scrollPageUntilHitTestable(tester, maxTasks);
    await tester.tap(maxTasks.hitTestable());
    await tester.pumpAndSettle();
    final taskInput = find.byKey(const ValueKey('record-max-tasks-input'));
    expect(taskInput, findsOneWidget);
    await tester.enterText(taskInput, '99');
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pump();
    expect(settings.maxTaskCount.value, 3);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter a whole number from 1 to 10'), findsOneWidget);
    final tenTasks = find.widgetWithText(ChoiceChip, '10');
    await _scrollDialogUntilVisible(tester, dialog: find.byType(AlertDialog), target: tenTasks);
    await tester.tap(tenTasks);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(tenTasks).selected, isTrue);
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pumpAndSettle();
    expect(settings.maxTaskCount.value, 10);
    expect(find.byType(AlertDialog), findsNothing);

    final cacheLimit = find.text('Cache Limit');
    await _scrollPageUntilHitTestable(tester, cacheLimit);
    await tester.tap(cacheLimit.hitTestable());
    await tester.pumpAndSettle();
    final cacheInput = find.byKey(const ValueKey('record-cache-limit-input'));
    expect(cacheInput, findsOneWidget);
    await tester.enterText(cacheInput, '0');
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pump();
    expect(settings.maxCacheMB.value, 1024);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter a whole number greater than zero'), findsOneWidget);
    await tester.enterText(cacheInput, '2048');
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pumpAndSettle();
    expect(settings.maxCacheMB.value, 2048);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cache-limit switch invokes the controller transaction', (tester) async {
    await _pumpRecorderSettings(
      tester,
      translations: englishTranslations,
      locale: const Locale('en'),
      size: const Size(360, 780),
      textScale: 1,
    );

    final cacheLimit = find.widgetWithText(SwitchListTile, 'Enable Cache Limit');
    await _scrollPageUntilHitTestable(tester, cacheLimit);
    await tester.tap(find.descendant(of: cacheLimit, matching: find.byType(Switch)));
    await tester.pump();

    expect((settings as _RecorderSettings).cacheLimitUpdates, [true]);
    expect(tester.widget<SwitchListTile>(cacheLimit).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('described timeout and queue menus keep their final choices reachable', (tester) async {
    await _pumpRecorderSettings(
      tester,
      translations: englishTranslations,
      locale: const Locale('en'),
      size: const Size(320, 480),
      textScale: 3,
    );

    final timeoutTitle = find.text('Read/Write Timeout');
    await _scrollPageUntilHitTestable(tester, timeoutTitle);
    await tester.tap(timeoutTitle.hitTestable());
    await tester.pumpAndSettle();
    var dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final safeTimeout = find.descendant(of: dialog, matching: find.text('60s'));
    await _scrollDialogUntilVisible(tester, dialog: dialog, target: safeTimeout);
    await tester.tap(find.ancestor(of: safeTimeout, matching: find.byType(RadioListTile<int>)));
    await tester.pumpAndSettle();
    expect(settings.rwTimeout.value, 60);
    expect(dialog, findsNothing);

    final queueTitle = find.text('Input Buffer Queue');
    await _scrollPageUntilHitTestable(tester, queueTitle);
    await tester.tap(queueTitle.hitTestable());
    await tester.pumpAndSettle();
    dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final largestQueue = find.descendant(of: dialog, matching: find.text('8192'));
    await _scrollDialogUntilVisible(tester, dialog: dialog, target: largestQueue);
    await tester.tap(find.ancestor(of: largestQueue, matching: find.byType(RadioListTile<int>)));
    await tester.pumpAndSettle();
    expect(settings.threadQueueSize.value, 8192);
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpRecorderSettings(
  WidgetTester tester, {
  required Map<String, dynamic> translations,
  required Locale locale,
  required Size size,
  required double textScale,
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
      supportedLocales: [locale],
      startLocale: locale,
      fallbackLocale: locale,
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
          home: const RecordSettingsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _recorderSettingsScrollable() =>
    find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

Future<void> _scrollDialogUntilVisible(WidgetTester tester, {required Finder dialog, required Finder target}) async {
  final scrollable = find.descendant(of: dialog, matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(target, 100, scrollable: scrollable, maxScrolls: 100);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _scrollPageUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(_recorderSettingsScrollable());
  scrollable.position.jumpTo(scrollable.position.minScrollExtent);
  await tester.pump();
  for (var attempt = 0; attempt < 1000; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pump();
      if (target.hitTestable().evaluate().isNotEmpty) return;
    }
    final position = scrollable.position;
    final next = (position.pixels + 20).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump();
  }
  final position = scrollable.position;
  fail(
    'Recorder setting did not become hit-testable after bounded scrolling '
    '(targets=${target.evaluate().length}, pixels=${position.pixels}, max=${position.maxScrollExtent}).',
  );
}

class _Translations extends AssetLoader {
  _Translations(this.values);
  final Map<String, dynamic> values;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}

// UI state uses memory under FakeAsync; persistence is tested with real Hive IO
// in recorder_settings_persistence_test.dart. Storage platform APIs are not used.
class _RecorderSettings extends RecordSettingsController {
  final _resume = false.obs;
  final _polling = false.obs;
  final _cacheLimit = false.obs;
  final cacheLimitUpdates = <bool>[];
  @override
  RxBool get autoStartOnBoot => _resume;
  @override
  RxBool get enablePolling => _polling;
  @override
  RxBool get enableCacheLimit => _cacheLimit;
  @override
  Future<void> updateEnableCacheLimit(bool value) async {
    cacheLimitUpdates.add(value);
    enableCacheLimit.value = value;
  }

  @override
  Future<void> updateDefaultQuality(String value) async {
    defaultQuality.value = RecorderConfig.normalizeDefaultQuality(value);
  }

  @override
  Future<void> updateMaxTask(int value) async {
    maxTaskCount.value = RecorderConfig.normalizeMaxTaskCount(value);
  }

  @override
  Future<void> updateMaxCache(int value) async {
    maxCacheMB.value = RecorderConfig.normalizeMaxCacheMB(value);
  }

  @override
  Future<void> updateRwTimeout(int value) async {
    rwTimeout.value = RecorderConfig.normalizeRwTimeout(value);
  }

  @override
  Future<void> updateThreadQueueSize(int value) async {
    threadQueueSize.value = RecorderConfig.normalizeThreadQueueSize(value);
  }

  @override
  Future<void> initRecordPath() async {}
  @override
  Future<void> refreshStorageInfo() async {}
}

class _SettingsService extends SettingsService {
  @override
  final font = FontSettingsController();
  @override
  // Test only the recorder page, not unrelated production service registration.
  // ignore: must_call_super
  void onInit() {}
}
