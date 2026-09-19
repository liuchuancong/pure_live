import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_danmaku_style_editor.dart';
import 'package:pure_live/modules/settings/pages/local_interaction_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late Map<String, dynamic> chinese;
  late LocalInteractionController controller;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-local-interaction-settings-test-');
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
    Get.put<FontSettingsController>(_FixtureFontSettingsController());
    Get.put<SettingsService>(_FixtureSettingsService());
    controller = Get.put(LocalInteractionController());
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  test('every supported live platform has its own interaction pack', () {
    final packIds = LocalInteractionController.platformPacks.map((pack) => pack.id).toSet();

    expect(packIds, Sites.supportedSiteIds);
    for (final siteId in Sites.supportedSiteIds) {
      expect(
        LocalInteractionController.packForPlatform(siteId).id,
        siteId,
        reason: '$siteId must not inherit another platform identity',
      );
    }
    expect(LocalInteractionController.packForPlatform('future-site').id, 'generic');
  });

  test('every interaction pack label is translated in both shipped locales', () {
    final packs = [...LocalInteractionController.platformPacks, LocalInteractionController.genericPlatformPack];
    for (final pack in packs) {
      for (final key in [pack.nameKey, pack.currencyKey, pack.levelKey]) {
        expect(english[key], isA<String>().having((value) => value.trim(), 'trimmed value', isNotEmpty));
        expect(chinese[key], isA<String>().having((value) => value.trim(), 'trimmed value', isNotEmpty));
      }
    }
  });

  testWidgets('English settings localize platform names instead of painting Chinese metadata', (tester) async {
    await _pumpPage(tester, english: english);

    expect(find.text('Bilibili'), findsWidgets);
    expect(find.text('哔哩哔哩'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late platform pack can be selected and updates the preview identity', (tester) async {
    await _pumpPage(tester, english: english);

    final yyChip = find.byKey(const ValueKey('local-platform-pack-yy'));
    await _scrollUntilHitTestable(tester, yyChip);
    await tester.tap(yyChip);
    await tester.pump();

    expect(controller.previewPlatform.value, Sites.yySite);
    expect(find.text('🎤 YY'), findsOneWidget);
    expect(find.text('Local level Lv.1 · 1000 local coins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all local interaction controls remain reachable at narrow very-large type', (tester) async {
    controller.history.add('fixture history');
    await _pumpPage(tester, english: english, size: const Size(320, 480), textScale: 3);

    final lastAction = find.text('Clear local interaction history');
    await _scrollUntilHitTestable(tester, lastAction);
    expect(lastAction.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait style sheet keeps its header and controls usable at very-large type', (tester) async {
    await _pumpLocalized(
      tester,
      english: english,
      home: _StyleEditorHost(controller: controller),
      size: const Size(320, 480),
      textScale: 3,
    );

    await tester.tap(find.text('Open style editor'));
    await tester.pump();

    expect(find.byKey(const ValueKey('local-danmaku-style-controls')), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape style dialog keeps split preview and controls usable at large type', (tester) async {
    await _pumpLocalized(
      tester,
      english: english,
      home: _StyleEditorHost(controller: controller),
      size: const Size(720, 360),
      textScale: 2.5,
    );

    await tester.tap(find.text('Open style editor'));
    await tester.pump();

    expect(find.byKey(const ValueKey('local-danmaku-style-dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('local-danmaku-live-preview-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('local-danmaku-style-controls')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('local-danmaku-style-header'))).height, greaterThan(38));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Map<String, dynamic> english,
  Size size = const Size(360, 640),
  double textScale = 1,
}) async {
  await _pumpLocalized(
    tester,
    english: english,
    home: const LocalInteractionSettingsPage(),
    size: size,
    textScale: textScale,
  );
}

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Map<String, dynamic> english,
  required Widget home,
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
          home: home,
        ),
      ),
    ),
  );
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

class _StyleEditorHost extends StatelessWidget {
  const _StyleEditorHost({required this.controller});

  final LocalInteractionController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showLocalDanmakuStyleEditor(context, controller: controller),
          child: const Text('Open style editor'),
        ),
      ),
    );
  }
}

Future<void> _scrollUntilHitTestable(WidgetTester tester, Finder target) async {
  final page = find.byKey(const ValueKey('local-interaction-settings-scroll'));
  final scrollable = find.descendant(of: page, matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(target, 240, scrollable: scrollable, maxScrolls: 240);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _FixtureFontSettingsController extends FontSettingsController {
  @override
  // Avoid platform font discovery in a layout fixture.
  // ignore: must_call_super
  void onInit() {}
}

class _FixtureSettingsService extends SettingsService {
  @override
  // The page resolves explicitly registered controllers through getters.
  // ignore: must_call_super
  void onInit() {}
}
