import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/settings/pages/local_config_preveiw.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late _FixtureBackupController backup;
  late _FixtureAuthController auth;
  late _LogStatusFixture logStatus;
  late _FixtureLogController logController;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-backup-layout-test-');
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
    backup = _FixtureBackupController(_fixtureConfig());
    Get.put<BackupController>(backup);
    Get.put<FontSettingsController>(_FixtureFontSettingsController());
    logStatus = _LogStatusFixture();
    logController = _FixtureLogController(logStatus.apply);
    Get.put<LogController>(logController);
    Get.put<SettingsService>(_FixtureSettingsService());
    auth = Get.put<AuthController>(_FixtureAuthController()) as _FixtureAuthController;
    auth.isInitSuccess = true;
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('backup log control stacks below readable text in narrow very-large type', (tester) async {
    await _pumpLocalized(tester, english: english, home: const BackupPage());

    expect(find.text('Backup & Restore'), findsOneWidget);
    final title = find.text('Enable Local Log');
    await _scrollUntilHitTestable(tester, title);
    final tile = find.ancestor(of: title, matching: find.byType(ListTile));
    final subtitle = find.descendant(of: tile, matching: find.text('Write logs to local files when enabled'));
    final toggle = find.descendant(of: tile, matching: find.byType(Switch));

    expect(tester.widget<Text>(subtitle).maxLines, isNull);
    expect(tester.getRect(toggle).top, greaterThanOrEqualTo(tester.getRect(title).bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('local log switch waits for the runtime transaction and reports rollback', (tester) async {
    await _pumpLocalized(tester, english: english, home: const BackupPage());

    final title = find.text('Enable Local Log');
    await _scrollUntilHitTestable(tester, title);
    final toggle = find.byKey(const ValueKey('local-log-switch'));
    await _scrollUntilHitTestable(tester, toggle);

    logController.updateServerInfo('127.0.0.1', 45678);
    await tester.pump();
    expect(find.text('View Logs in Browser'), findsNothing);

    logStatus.prepare();
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('Updating local logging…'), findsOneWidget);
    expect(tester.widget<Switch>(toggle).onChanged, isNull);

    logStatus.complete(false);
    await tester.pumpAndSettle();
    expect(logController.storedEnableLog.value, isFalse);
    expect(find.text('Local logging was not changed. The switch shows the active runtime state.'), findsOneWidget);

    logStatus.prepare();
    await tester.tap(toggle);
    await tester.pump();
    logStatus.complete(true);
    await tester.pumpAndSettle();
    expect(logController.storedEnableLog.value, isTrue);
    expect(find.text('Write logs to local files when enabled'), findsOneWidget);
    logController.updateServerInfo('127.0.0.1', 45678);
    await tester.pumpAndSettle();
    await _scrollUntilHitTestable(tester, find.text('View Logs in Browser'));
    expect(find.text('http://127.0.0.1:45678'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backup connection status stacks its progress control below readable text', (tester) async {
    auth.isInitSuccess = false;
    auth.isConnecting = true;
    await _pumpLocalized(tester, english: english, home: const BackupPage());

    final title = find.text('Connecting to Firebase...');
    final tile = find.ancestor(of: title, matching: find.byType(ListTile));
    final subtitle = find.descendant(of: tile, matching: find.text('Initializing Firebase services. Please wait...'));
    final progress = find.descendant(of: tile, matching: find.byType(CircularProgressIndicator));

    expect(tester.widget<Text>(subtitle).maxLines, isNull);
    expect(tester.getRect(progress).top, greaterThanOrEqualTo(tester.getRect(title).bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('local preview labels its raw data as local', (tester) async {
    await _pumpLocalized(tester, english: english, home: const LocalConfigPreviewPage());

    final localHeading = find.text('Local Config Raw Preview');
    await _scrollLocalPreviewUntilHitTestable(tester, localHeading);
    expect(localHeading.hitTestable(), findsOneWidget);
    expect(find.text('Cloud Config Raw Preview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local preview module count excludes backup metadata fields', (tester) async {
    await _pumpLocalized(tester, english: english, home: const LocalConfigPreviewPage());

    expect(find.text('Config Modules'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local preview summary and raw data remain reachable in narrow very-large type', (tester) async {
    await _pumpLocalized(tester, english: english, home: const LocalConfigPreviewPage());

    final pageScroll = find.byKey(const ValueKey('local-config-scroll-view'));
    expect(pageScroll, findsOneWidget);
    final rawPreview = find.byKey(const ValueKey('local-config-raw-preview'));
    await _scrollLocalPreviewUntilHitTestable(tester, rawPreview);
    expect(rawPreview.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local preview keeps a compact four-column summary on a wide standard viewport', (tester) async {
    await _pumpLocalized(
      tester,
      english: english,
      home: const LocalConfigPreviewPage(),
      size: const Size(1000, 700),
      textScale: 1,
    );

    final cards = [
      'favorites',
      'history',
      'tags',
      'modules',
    ].map((key) => find.byKey(ValueKey('local-config-meta-$key'))).toList(growable: false);
    final top = tester.getRect(cards.first).top;
    for (final card in cards) {
      expect(tester.getRect(card).top, closeTo(top, 0.1));
    }
    expect(tester.takeException(), isNull);
  });

  test('config section count ignores backup and future metadata fields', () {
    final data = {..._fixtureConfig(), 'createdAt': 'fixture-time'};
    expect(BackupController.countConfigSections(data), 5);
  });
}

Map<String, dynamic> _fixtureConfig() => {
  'backupVersion': 3,
  'sensitiveDataIncluded': false,
  'favorite': {
    'favoriteRooms': [{}, {}],
  },
  'history': {
    'historyRooms': [{}],
  },
  'tags': {
    'tags': [{}, {}, {}],
  },
  'app': <String, dynamic>{},
  'theme': <String, dynamic>{},
};

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Map<String, dynamic> english,
  required Widget home,
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
          home: home,
        ),
      ),
    ),
  );
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _scrollUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(target, 100, scrollable: scrollable, maxScrolls: 60);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _scrollLocalPreviewUntilHitTestable(WidgetTester tester, Finder target) async {
  final page = find.byKey(const ValueKey('local-config-scroll-view'));
  final scrollable = tester.state<ScrollableState>(find.descendant(of: page, matching: find.byType(Scrollable)).first);
  for (var attempt = 0; attempt < 60; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final position = scrollable.position;
    final next = (position.pixels + position.viewportDimension * 0.35).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump();
  }
  fail('Local config preview target did not become hit-testable after bounded scrolling.');
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _FixtureBackupController extends BackupController {
  _FixtureBackupController(this.data);

  final Map<String, dynamic> data;

  @override
  Map<String, dynamic> exportAllSettings({bool includeSensitiveData = false}) => data;
}

class _FixtureLogController extends LogController {
  _FixtureLogController(Future<bool> Function(bool enabled) applyLogStatus) : super(applyLogStatus: applyLogStatus);

  @override
  // Avoid file logging side effects in a layout fixture.
  // ignore: must_call_super
  Future<void> onInit() async {}
}

class _LogStatusFixture {
  Completer<bool>? _next;

  void prepare() => _next = Completer<bool>();

  Future<bool> apply(bool enabled) => _next!.future;

  void complete(bool result) => _next!.complete(result);
}

class _FixtureFontSettingsController extends FontSettingsController {
  @override
  // Avoid platform font discovery in a layout fixture.
  // ignore: must_call_super
  void onInit() {}
}

class _FixtureSettingsService extends SettingsService {
  @override
  // The page resolves its explicitly registered controllers through getters.
  // ignore: must_call_super
  void onInit() {}
}

class _FixtureAuthController extends AuthController {
  @override
  // Avoid Firebase and network activity in a layout fixture.
  // ignore: must_call_super
  void onInit() {}
}
