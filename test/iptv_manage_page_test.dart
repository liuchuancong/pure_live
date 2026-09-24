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
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/iptv/iptv_manage.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, dynamic> zh;
  late Map<String, dynamic> en;
  late _Database db;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('iptv-manage-page-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    Hive.init(directory.path);
    await HivePrefUtil.init();
    zh = jsonDecode(await File('assets/translations/zh.json').readAsString()) as Map<String, dynamic>;
    en = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });

  setUp(() {
    Get.testMode = true;
    Get.put<SettingsService>(_Settings());
    db = _Database();
    final service = DbService()..db = db;
    Get.put(service);
  });

  tearDown(() async {
    db.completePending();
    Get.deleteAll(force: true);
    Get.reset();
    await db.close();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    String language = 'en',
    Size size = const Size(900, 900),
    double scale = 1,
    bool settle = true,
  }) async {
    final translations = language == 'zh' ? zh : en;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      db.completePending();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('zh'), Locale('en')],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: _Translations(translations),
        child: Builder(
          builder: (context) => GetMaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            navigatorObservers: [FlutterSmartDialog.observer],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: FlutterSmartDialog.init()(context, child),
            ),
            home: const IptvManagePage(),
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

  for (final language in ['zh', 'en']) {
    testWidgets('$language resources stay reachable at 320x480 and 3x text', (tester) async {
      await open(tester, language: language, size: const Size(320, 480), scale: 3);
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byType(Switch), 220, scrollable: scroll, maxScrolls: 30);
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsWidgets);
      await tester.scrollUntilVisible(find.text(db.epgs.single.name), 220, scrollable: scroll, maxScrolls: 30);
      await tester.pumpAndSettle();
      expect(find.text(db.epgs.single.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an empty database shows the source-specific empty state', (tester) async {
    db.providerItems.clear();
    db.epgs.clear();
    await open(tester);
    expect(find.text('No subscription sources'), findsOneWidget);
    expect(find.text('Import a playlist or programme guide from IPTV settings.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure is visible and retry restores the resources', (tester) async {
    db.failProviderRead = true;
    await open(tester);
    expect(find.text('Could not load subscription sources'), findsOneWidget);
    expect(find.text(en['retry'] as String), findsOneWidget);
    db.failProviderRead = false;
    await tester.tap(find.text(en['retry'] as String));
    await tester.pumpAndSettle();
    expect(find.text(db.providerItems.single.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late initial load stops after the manage page is disposed', (tester) async {
    final providers = Completer<List<Provider>>();
    db.providerReply = providers;
    await open(tester, settle: false);
    for (var frame = 0; frame < 10 && db.providerReads == 0; frame++) {
      await tester.pump();
    }
    expect(db.providerReads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    providers.complete(db.providerItems);
    await tester.pumpAndSettle();
    expect(db.epgReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete completion under a newer route removes only its own dialog', (tester) async {
    db.epgs.clear();
    final deletion = Completer<void>();
    db.deleteReply = deletion;
    await open(tester);
    await tester.tap(find.text(en['webdav_delete'] as String));
    await tester.pumpAndSettle();
    final navigator = Navigator.of(tester.element(find.byType(AlertDialog)));
    await tester.tap(find.text(en['confirm'] as String));
    await tester.pump();
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Newer route')))));
    await tester.pumpAndSettle();
    deletion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Newer route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text(db.providerName), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late auto-sync toggle after deletion does not revive or index a removed item', (tester) async {
    db.epgs.clear();
    final update = Completer<void>();
    db.updateReply = update;
    await open(tester);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    toggle.onChanged!(true);
    await tester.pump();
    expect(db.updateCalls, 1);
    await tester.tap(find.text(en['webdav_delete'] as String));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing, reason: 'a pending item update serializes destructive actions');
    expect(find.text(db.providerName), findsOneWidget);
    update.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text(en['webdav_delete'] as String));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en['confirm'] as String));
    await tester.pumpAndSettle();
    expect(find.text(db.providerName), findsNothing);
    toggle.onChanged!(false);
    await tester.pumpAndSettle();
    expect(db.updateCalls, 1, reason: 'an old switch callback cannot update a deleted provider');
    expect(find.text(db.providerName), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

class _Translations extends AssetLoader {
  const _Translations(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}

class _Settings extends SettingsService {
  final _font = FontSettingsController();
  final _theme = ThemeSettingsController();

  @override
  FontSettingsController get font => _font;

  @override
  ThemeSettingsController get theme => _theme;

  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Database extends AppDatabase {
  _Database() : super.forTesting(NativeDatabase.memory());

  final providerName = 'A very long network television subscription source';
  late final List<Provider> providerItems = [
    Provider(
      id: 'network-provider',
      name: providerName,
      type: 'm3u',
      url: 'https://example.test/a/very/long/subscription/list.m3u',
      sortOrder: 0,
      enabled: true,
      createdAt: DateTime(2026),
      isAutoUpdate: false,
    ),
  ];
  final List<EpgSource> epgs = [
    EpgSource(
      id: 'local-epg',
      name: 'A very long local television programme guide source',
      url: r'C:\fixtures\guide.xml',
      enabled: true,
      refreshIntervalHours: 24,
      createdAt: DateTime(2026),
      isAutoUpdate: false,
    ),
  ];
  bool failProviderRead = false;
  Completer<List<Provider>>? providerReply;
  Completer<void>? deleteReply;
  Completer<void>? updateReply;
  int providerReads = 0;
  int epgReads = 0;
  int updateCalls = 0;

  @override
  Future<List<Provider>> getAllProviders() async {
    providerReads++;
    if (failProviderRead) throw StateError('fixture provider read failed');
    final reply = providerReply;
    if (reply != null) return reply.future;
    return List.of(providerItems);
  }

  @override
  Future<Provider?> getProviderById(String id) async {
    for (final provider in providerItems) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  @override
  Future<List<EpgSource>> getAllEpgSources() async {
    epgReads++;
    return List.of(epgs);
  }

  @override
  Future<void> deleteProviderCascading(String providerId) async {
    final reply = deleteReply;
    if (reply != null) await reply.future;
    providerItems.removeWhere((provider) => provider.id == providerId);
  }

  @override
  Future<void> updateProviderUpdateStatus(String providerId, bool status) async {
    updateCalls++;
    final reply = updateReply;
    if (reply != null) await reply.future;
    final index = providerItems.indexWhere((provider) => provider.id == providerId);
    if (index >= 0) providerItems[index] = providerItems[index].copyWith(isAutoUpdate: status);
  }

  void completePending() {
    if (providerReply case final reply? when !reply.isCompleted) reply.complete(List.of(providerItems));
    if (deleteReply case final reply? when !reply.isCompleted) reply.complete();
    if (updateReply case final reply? when !reply.isCompleted) reply.complete();
  }
}
