import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/iptv/iptv_page.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Map<String, dynamic> translations;
  late Map<String, dynamic> english;
  late _Settings settings;
  late _Database db;
  Future<void> Function()? loadDefaults;
  int defaultLoads = 0;
  final imports = <(bool, String, String, Completer<bool>)>[];
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('iptv-settings-page-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(dir.path);
    await HivePrefUtil.init();
    translations = jsonDecode(await File('assets/translations/zh.json').readAsString()) as Map<String, dynamic>;
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });
  setUp(() {
    imports.clear();
    loadDefaults = null;
    defaultLoads = 0;
    Get.testMode = true;
    settings = Get.put<SettingsService>(_Settings()) as _Settings;
    settings.iptv.customIptvUserAgent.v = 'Original-Agent';
    settings.iptv.isAutoSyncEnabled.v = false;
    settings.iptv.autoSyncHoursInterval.v = 24;
    settings.iptv.selectedSourceId.v = 'fixture';
    settings.iptv.selectedSourceName.v = 'Fixture';
    Get.put(ThemeSettingsController());
    db = _Database();
    final service = DbService();
    service.db = db;
    Get.put(service);
  });
  tearDown(() async {
    Get.deleteAll(force: true);
    Get.reset();
    await db.close();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double scale = 1,
    String language = 'zh',
    bool settle = true,
  }) async {
    final strings = language == 'en' ? english : translations;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh'), Locale('en')],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Translations(strings),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: FlutterSmartDialog.init()(context, child),
            ),
            home: IptvPage(
              loadDefaultEpg: () async {
                defaultLoads++;
                if (loadDefaults != null) await loadDefaults!();
              },
              importFromNetwork: (epg, url, name) {
                final pending = Completer<bool>();
                imports.add((epg, url, name, pending));
                return pending.future;
              },
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final f = find.text(translations[key] as String);
    if (f.evaluate().isEmpty) await tester.scrollUntilVisible(f, 150);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('focused UA cancel disposes only after dialog subtree unmounts', (tester) async {
    await open(tester);
    await tap(tester, 'custom_ua_title');
    await tester.enterText(find.byType(TextField), 'discarded');
    await tap(tester, 'cancel');
    expect(settings.iptv.customIptvUserAgent.v, 'Original-Agent');
    await finish(tester);
  });
  testWidgets('UA save updates the existing settings tile immediately', (tester) async {
    await open(tester);
    await tap(tester, 'custom_ua_title');
    await tester.enterText(find.byType(TextField), '  Saved-Agent  ');
    await tap(tester, 'confirm');
    expect(settings.iptv.customIptvUserAgent.v, 'Saved-Agent');
    expect(find.text('Saved-Agent'), findsOneWidget);
    expect(find.text('Original-Agent'), findsNothing);
    await finish(tester);
  });
  testWidgets('UA editing fits narrow large-text window', (tester) async {
    await open(tester, size: const Size(320, 480), scale: 2);
    await tap(tester, 'custom_ua_title');
    expect(tester.takeException(), isNull);
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('all sync intervals remain reachable in short large-text window', (tester) async {
    settings.iptv.isAutoSyncEnabled.v = true;
    await open(tester, size: const Size(320, 480), scale: 2);
    await tap(tester, 'sync_interval_title');
    expect(tester.takeException(), isNull);
    final last = find.text('72 ${translations['hours']}');
    await tester.ensureVisible(last);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(settings.iptv.autoSyncHoursInterval.v, 72);
    await finish(tester);
  });
  testWidgets('UA draft clear and barrier dismissal preserve saved value and reopen cleanly', (tester) async {
    await open(tester);
    await tap(tester, 'custom_ua_title');
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.tap(find.descendant(of: find.byType(TextField), matching: find.byType(IconButton)));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(settings.iptv.customIptvUserAgent.v, 'Original-Agent');
    await tap(tester, 'custom_ua_title');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Original-Agent');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await finish(tester);
  });
  testWidgets('empty UA is an explicit saved reset rather than cancellation', (tester) async {
    await open(tester);
    await tap(tester, 'custom_ua_title');
    await tester.enterText(find.byType(TextField), '   ');
    await tap(tester, 'confirm');
    expect(settings.iptv.customIptvUserAgent.v, isEmpty);
    await tap(tester, 'custom_ua_title');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('external settings update refreshes the visible full UA text', (tester) async {
    await open(tester);
    const value = 'Example-Agent-with-a-long-value-and-a-different-suffix';
    settings.iptv.customIptvUserAgent.v = value;
    await tester.pumpAndSettle();
    expect(find.text(value), findsOneWidget);
    expect(find.text('Original-Agent'), findsNothing);
    await finish(tester);
  });
  testWidgets('interval dismissal preserves saved setting and every choice commits', (tester) async {
    settings.iptv.isAutoSyncEnabled.v = true;
    await open(tester);
    await tap(tester, 'sync_interval_title');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(settings.iptv.autoSyncHoursInterval.v, 24);
    for (final hours in [2, 6, 12, 24, 48, 72]) {
      await tap(tester, 'sync_interval_title');
      final f = find.text('$hours ${translations['hours']}');
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
      expect(settings.iptv.autoSyncHoursInterval.v, hours);
      expect(find.byType(AlertDialog), findsNothing);
    }
    await finish(tester);
  });
  for (final language in ['zh', 'en']) {
    testWidgets('UA text resize and keyboard insets remain usable in $language', (tester) async {
      await open(tester, size: const Size(320, 640), scale: 2, language: language);
      final strings = language == 'en' ? english : translations;
      final entry = find.text(strings['custom_ua_title'] as String);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Keyboard-Agent');
      final drag = find.byWidgetPredicate((w) => w is GestureDetector && w.onVerticalDragUpdate != null).last;
      await tester.ensureVisible(drag);
      await tester.drag(drag, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(MediaQuery.textScalerOf(tester.element(field)).scale(10), 20);
      expect(tester.takeException(), isNull);
      final confirm = find.text(strings['confirm'] as String);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(settings.iptv.customIptvUserAgent.v, 'Keyboard-Agent');
      await finish(tester);
    });
    testWidgets('IPTV EPG import tile has a translated label in $language', (tester) async {
      await open(tester, language: language);
      final strings = language == 'en' ? english : translations;
      expect(strings['import_epg_source'], isA<String>());
      final label = find.text(strings['import_epg_source'] as String);
      await tester.scrollUntilVisible(label, 150);
      expect(label, findsOneWidget);
      expect(find.text('import_epg_source'), findsNothing);
      await finish(tester);
    });
  }
  Future<void> openImport(WidgetTester tester, {bool epg = false}) async {
    await tap(tester, epg ? 'import_epg_source' : 'import_playlist');
    await tap(tester, 'network_import');
  }

  Future<void> enterImport(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), '  https://example.test/list.m3u  ');
    await tester.enterText(find.byType(TextField).at(1), '  Network fixture  ');
  }

  testWidgets('network import focused cancellation retains route-owned controllers', (tester) async {
    await open(tester);
    await openImport(tester);
    await enterImport(tester);
    await tap(tester, 'cancel');
    expect(find.byType(TextField), findsNothing);
    expect(imports, isEmpty);
    await finish(tester);
  });
  testWidgets('network import fits small large-text window', (tester) async {
    await open(tester, size: const Size(320, 480), scale: 2);
    await openImport(tester);
    expect(tester.takeException(), isNull);
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('pending import accepts only one submission and failure preserves draft for retry', (tester) async {
    await open(tester);
    await openImport(tester);
    await enterImport(tester);
    final button = find.text(translations['confirm'] as String);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    final count = imports.length;
    for (final entry in imports) {
      entry.$4.complete(false);
    }
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '  Network fixture  ');
    await tester.tap(button);
    await tester.pump();
    expect(imports, hasLength(2));
    imports.last.$4.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(IptvPage), findsOneWidget);
    await finish(tester);
  });
  testWidgets('closing pending import does not pop a later dialog and blocks duplicate import', (tester) async {
    await open(tester);
    await openImport(tester);
    await enterImport(tester);
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    expect(find.text(translations['iptv_import_close_hint'] as String), findsOneWidget);
    await tester.tap(find.text(translations['close'] as String));
    await tester.pumpAndSettle();
    await tester.tap(find.text(translations['import_playlist'] as String));
    await tester.pumpAndSettle();
    expect(find.text(translations['network_import'] as String), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(imports, hasLength(1));
    await tap(tester, 'custom_ua_title');
    await tester.enterText(find.byType(TextField), 'unrelated draft');
    imports.single.$4.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'unrelated draft');
    await tap(tester, 'cancel');
    await openImport(tester);
    expect(find.byType(TextField), findsNWidgets(2));
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('success under a newer route removes only the owned import dialog', (tester) async {
    await open(tester);
    await openImport(tester);
    await enterImport(tester);
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    final navigator = Navigator.of(tester.element(find.byType(AlertDialog)));
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Newer route')))));
    await tester.pumpAndSettle();
    imports.single.$4.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Newer route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(IptvPage), findsOneWidget);
    await finish(tester);
  });
  testWidgets('thrown import failure releases the gate and retains a usable draft', (tester) async {
    await open(tester);
    await openImport(tester, epg: true);
    await enterImport(tester);
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    expect(imports.single.$1, isTrue);
    expect(imports.single.$2, 'https://example.test/list.m3u');
    expect(imports.single.$3, 'Network fixture');
    imports.single.$4.completeError(StateError('fixture failure'));
    await tester.pumpAndSettle();
    expect(find.text(translations['network_import_failed'] as String), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).at(0)).readOnly, isFalse);
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    imports.last.$4.complete(true);
    await tester.pumpAndSettle();
    expect(imports, hasLength(2));
    expect(find.byType(AlertDialog), findsNothing);
    await finish(tester);
  });
  testWidgets('invalid or missing import fields create no request and keep both drafts', (tester) async {
    await open(tester);
    await openImport(tester);
    await tap(tester, 'confirm');
    expect(find.text(translations['enter_download_link'] as String), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'not a URL');
    await tap(tester, 'confirm');
    expect(find.text(translations['invalid_download_link'] as String), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'https://example.test/list.xml');
    await tap(tester, 'confirm');
    expect(find.text(translations['enter_file_name'] as String), findsOneWidget);
    expect(imports, isEmpty);
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('network import accepts a complete long-TLD URL and rejects an embedded URL substring', (tester) async {
    await open(tester);
    await openImport(tester);
    await tester.enterText(find.byType(TextField).at(0), 'https://example.technology/list.m3u');
    await tester.enterText(find.byType(TextField).at(1), 'Modern host');
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    expect(imports, hasLength(1));
    expect(imports.single.$2, 'https://example.technology/list.m3u');
    imports.single.$4.complete(true);
    await tester.pumpAndSettle();

    await openImport(tester);
    await tester.enterText(find.byType(TextField).at(0), 'prefix https://example.test/list.m3u');
    await tester.enterText(find.byType(TextField).at(1), 'Embedded host');
    await tap(tester, 'confirm');
    expect(find.text(translations['invalid_download_link'] as String), findsOneWidget);
    expect(imports, hasLength(1));
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('completed import is not relabelled failed when only refreshing the list fails', (tester) async {
    await open(tester);
    await openImport(tester);
    await enterImport(tester);
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    db.failProviderRead = true;
    imports.single.$4.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(imports, hasLength(1));
    expect(find.text(translations['network_import_failed'] as String), findsNothing);
    await finish(tester);
  });
  testWidgets('leaving the page before import completion does not refresh disposed UI', (tester) async {
    await open(tester);
    await openImport(tester);
    await enterImport(tester);
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    final reads = db.providerReads;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    imports.single.$4.complete(true);
    await tester.pumpAndSettle();
    expect(db.providerReads, reads);
    expect(tester.takeException(), isNull);
  });
  Future<void> beginSourceSelection(WidgetTester tester, {String language = 'zh'}) async {
    final strings = language == 'en' ? english : translations;
    final entry = find.text(strings['active_epg_source'] as String);
    if (entry.evaluate().isEmpty) await tester.scrollUntilVisible(entry, 150);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pump();
  }

  testWidgets('EPG chooser loads visibly and cancellation ignores a late result', (tester) async {
    await open(tester);
    final pending = Completer<List<EpgSource>>();
    db.readSources = () => pending.future;
    await beginSourceSelection(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text(translations['cancel'] as String));
    await tester.pumpAndSettle();
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.iptv.selectedSourceId.v, 'fixture');
    await finish(tester);
  });
  testWidgets('EPG source read failure is not an empty list and offers retry', (tester) async {
    await open(tester);
    db.readSources = () => Future.error(StateError('fixture query failed'));
    await beginSourceSelection(tester);
    await tester.pumpAndSettle();
    expect(find.text(translations['no_epg_sources_found'] as String), findsNothing);
    expect(find.text(translations['retry'] as String), findsOneWidget);
    db.readSources = () async => [];
    await tap(tester, 'retry');
    expect(find.text(translations['no_epg_sources_found'] as String), findsOneWidget);
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('disposed IPTV page does not open a chooser after a late read', (tester) async {
    await open(tester);
    final pending = Completer<List<EpgSource>>();
    db.readSources = () => pending.future;
    await beginSourceSelection(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('EPG chooser title and close action fit large text on narrow screens', (tester) async {
    await open(tester, size: const Size(320, 480), scale: 2);
    await beginSourceSelection(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(IptvPage), findsOneWidget);
    await finish(tester);
  });
  EpgSource source(String id, String name) => EpgSource(
    id: id,
    name: name,
    url: 'https://example.test/$id.xml',
    enabled: true,
    refreshIntervalHours: 24,
    createdAt: DateTime(2026),
    isAutoUpdate: false,
  );
  testWidgets('old chooser completion cannot replace a reopened chooser or persist a selection', (tester) async {
    await open(tester);
    settings.iptv.selectedSourceName.v = 'Keep selection';
    final first = Completer<List<EpgSource>>();
    db.readSources = () => first.future;
    await beginSourceSelection(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final second = Completer<List<EpgSource>>();
    db.readSources = () => second.future;
    await beginSourceSelection(tester);
    first.complete([source('old', 'Old result')]);
    await tester.pump();
    expect(find.text('Old result'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    second.complete([source('new', 'New result')]);
    await tester.pumpAndSettle();
    expect(find.text('New result'), findsOneWidget);
    expect(settings.iptv.selectedSourceId.v, 'fixture');
    expect(settings.iptv.selectedSourceName.v, 'Keep selection');
    await tester.tap(find.text('New result'));
    await tester.pumpAndSettle();
    expect(settings.iptv.selectedSourceId.v, 'new');
    expect(settings.iptv.selectedSourceName.v, 'New result');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(IptvPage), findsOneWidget);
    await finish(tester);
  });
  testWidgets('rapid source-entry callbacks open one dialog and start one read', (tester) async {
    await open(tester);
    final pending = Completer<List<EpgSource>>();
    db.readSources = () => pending.future;
    final entry = find.text(translations['active_epg_source'] as String);
    await tester.scrollUntilVisible(entry, 150);
    await tester.pumpAndSettle();
    final action = tester.widget<InkWell>(find.ancestor(of: entry, matching: find.byType(InkWell)).first).onTap!;
    final reads = db.sourceReads;
    action();
    action();
    await tester.pump();
    expect(db.sourceReads, reads + 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('retry is single-flight and error has a dedicated message', (tester) async {
    await open(tester);
    db.readSources = () => Future.error(StateError('fixture'));
    await beginSourceSelection(tester);
    await tester.pumpAndSettle();
    expect(find.text(translations['epg_sources_load_failed'] as String), findsOneWidget);
    final pending = Completer<List<EpgSource>>();
    db.readSources = () => pending.future;
    final callback = tester
        .widget<TextButton>(find.widgetWithText(TextButton, translations['retry'] as String))
        .onPressed!;
    final reads = db.sourceReads;
    callback();
    callback();
    await tester.pump();
    expect(db.sourceReads, reads + 1);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text(translations['epg_sources_load_failed'] as String), findsNothing);
    await tap(tester, 'cancel');
    await finish(tester);
  });
  testWidgets('closing a loading chooser also contains a late read error', (tester) async {
    await open(tester);
    final pending = Completer<List<EpgSource>>();
    db.readSources = () => pending.future;
    await beginSourceSelection(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    pending.completeError(StateError('late fixture failure'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await finish(tester);
  });
  for (final language in ['zh', 'en']) {
    testWidgets('long source lists and labels stay selectable with large text in $language', (tester) async {
      await open(tester, size: const Size(320, 480), scale: 2, language: language);
      db.readSources = () async =>
          List.generate(20, (i) => source('s$i', 'Source $i - long television programme guide name'));
      await beginSourceSelection(tester, language: language);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final list = find.descendant(of: dialog, matching: find.byType(ListView));
      final scroll = find.descendant(of: list, matching: find.byType(Scrollable)).first;
      final last = find.descendant(of: list, matching: find.text('Source 19 - long television programme guide name'));
      // Twenty multi-line entries exceed 9,000 logical pixels at 2x text.
      await tester.scrollUntilVisible(last, 180, scrollable: scroll, maxScrolls: 80);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(MediaQuery.textScalerOf(tester.element(last)).scale(10), 20);
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(settings.iptv.selectedSourceId.v, 's19');
      expect(settings.iptv.selectedSourceName.v, 'Source 19 - long television programme guide name');
      await finish(tester);
    });
  }
  testWidgets('initial IPTV database failure is caught and offers a working retry', (tester) async {
    db.readSources = () => Future.error(StateError('initial DB fixture failure'));
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(translations['retry'] as String), findsOneWidget);
    expect(defaultLoads, 0);
    db.readSources = null;
    await tap(tester, 'retry');
    expect(find.text(translations['retry'] as String), findsNothing);
    expect(defaultLoads, 0);
    await finish(tester);
  });
  testWidgets('default EPG import exception is visible and remains retryable', (tester) async {
    db.readSources = () async => [];
    loadDefaults = () => Future.error(StateError('default fixture failure'));
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(defaultLoads, 1);
    expect(find.text(translations['retry'] as String), findsOneWidget);
    loadDefaults = () async {
      db.readSources = null;
    };
    await tap(tester, 'retry');
    expect(defaultLoads, 2);
    expect(find.text(translations['retry'] as String), findsNothing);
    await finish(tester);
  });
  testWidgets('default import with no resulting source is not a silent successful initialization', (tester) async {
    db.readSources = () async => [];
    await open(tester);
    expect(defaultLoads, 1);
    expect(find.text(translations['retry'] as String), findsOneWidget);
    expect(settings.iptv.selectedSourceId.v, 'fixture');
    await finish(tester);
  });
  testWidgets('page exit stops the next initialization query and default import', (tester) async {
    final pending = Completer<List<EpgSource>>();
    db.readSources = () => pending.future;
    await open(tester, settle: false);
    for (var frame = 0; frame < 10 && db.sourceReads == 0; frame++) {
      await tester.pump();
    }
    expect(db.sourceReads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(db.providerReads, 0);
    expect(defaultLoads, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('initialization retry shares one read and does not overwrite an intervening selection', (tester) async {
    db.readSources = () => Future.error(StateError('initial failure'));
    await open(tester);
    final pending = Completer<List<EpgSource>>();
    db.readSources = () => pending.future;
    final retry = tester
        .widget<TextButton>(find.widgetWithText(TextButton, translations['retry'] as String))
        .onPressed!;
    final reads = db.sourceReads;
    retry();
    retry();
    await tester.pump();
    expect(db.sourceReads, reads + 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    settings.iptv.selectedSourceId.v = 'chosen-while-loading';
    settings.iptv.selectedSourceName.v = 'New choice';
    pending.complete([source('default', 'Default')]);
    await tester.pumpAndSettle();
    expect(settings.iptv.selectedSourceId.v, 'chosen-while-loading');
    expect(settings.iptv.selectedSourceName.v, 'New choice');
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(defaultLoads, 0);
    await finish(tester);
  });
  testWidgets('successful default load refreshes and selects a source only when selection is empty', (tester) async {
    settings.iptv.selectedSourceId.v = '';
    settings.iptv.selectedSourceName.v = '';
    db.readSources = () async => [];
    loadDefaults = () async {
      db.readSources = () async => [source('ready', 'Ready source')];
    };
    await open(tester);
    expect(defaultLoads, 1);
    expect(settings.iptv.selectedSourceId.v, 'ready');
    expect(settings.iptv.selectedSourceName.v, 'Ready source');
    expect(find.text(translations['retry'] as String), findsNothing);
    await finish(tester);
  });
  testWidgets('default load late failure after page disposal has no UI follow-up', (tester) async {
    db.readSources = () async => [];
    final pending = Completer<void>();
    loadDefaults = () => pending.future;
    await open(tester, settle: false);
    for (var frame = 0; frame < 12 && defaultLoads == 0; frame++) {
      await tester.pump();
    }
    expect(defaultLoads, 1);
    final sourceReads = db.sourceReads;
    final providerReads = db.providerReads;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    pending.completeError(StateError('late import failure'));
    await tester.pumpAndSettle();
    expect(db.sourceReads, sourceReads);
    expect(db.providerReads, providerReads);
    expect(tester.takeException(), isNull);
  });
  testWidgets('manual successful source import clears the default-source warning', (tester) async {
    db.readSources = () async => [];
    await open(tester);
    expect(find.text(translations['iptv_default_epg_unavailable'] as String), findsOneWidget);
    await openImport(tester, epg: true);
    await enterImport(tester);
    await tester.tap(find.text(translations['confirm'] as String));
    await tester.pump();
    db.readSources = null;
    imports.single.$4.complete(true);
    await tester.pumpAndSettle();
    expect(find.text(translations['iptv_default_epg_unavailable'] as String), findsNothing);
    expect(defaultLoads, 1);
    await finish(tester);
  });
  for (final language in ['zh', 'en']) {
    testWidgets('initialization error and retry fit large text in $language', (tester) async {
      db.readSources = () => Future.error(StateError('fixture'));
      await open(tester, size: const Size(320, 480), scale: 2, language: language);
      final strings = language == 'en' ? english : translations;
      expect(find.text(strings['iptv_initial_load_failed'] as String), findsOneWidget);
      expect(tester.takeException(), isNull);
      db.readSources = null;
      final retry = find.text(strings['retry'] as String);
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text(strings['iptv_initial_load_failed'] as String), findsNothing);
      expect(settings.iptv.selectedSourceId.v, 'fixture');
      await finish(tester);
    });
  }
}

class _Translations extends AssetLoader {
  const _Translations(this.values);
  final Map<String, dynamic> values;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}

class _Settings extends SettingsService {
  final _font = FontSettingsController();
  final _iptv = IptvSettingsController();
  @override
  FontSettingsController get font => _font;
  @override
  IptvSettingsController get iptv => _iptv;
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Database extends AppDatabase {
  _Database() : super.forTesting(NativeDatabase.memory());
  Future<List<EpgSource>> Function()? readSources;
  int sourceReads = 0;
  bool failProviderRead = false;
  int providerReads = 0;
  @override
  Future<List<Provider>> getAllProviders() async {
    providerReads++;
    if (failProviderRead) throw StateError('fixture read failed');
    return [];
  }

  @override
  Future<List<EpgSource>> getAllEpgSources() async {
    sourceReads++;
    if (readSources != null) return readSources!();
    return [
      EpgSource(
        id: 'fixture',
        name: 'Fixture',
        url: 'https://example.test/epg.xml',
        enabled: true,
        refreshIntervalHours: 24,
        createdAt: DateTime(2026),
        isAutoUpdate: false,
      ),
    ];
  }
}
