import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/cache_data_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late _TestCacheController cache;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-cache-page-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    cache = _TestCacheController();
    Get.put<SettingsService>(_TestSettingsService(cache));
  });

  tearDown(Get.reset);

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('narrow very-large text keeps cache size and every action reachable', (tester) async {
    await _pumpPage(tester, english);

    expect(find.text('12.34 MB'), findsOneWidget);
    for (final label in ['Refresh live thumbnails', 'Clear Local Cache']) {
      final target = find.text(label);
      expect(target, findsOneWidget);
      await tester.ensureVisible(target);
      await tester.pump();
      await _scrollUntilHitTestable(tester, target);
      expect(target.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('cache confirmation remains operable and cancellation preserves data', (tester) async {
    await _pumpPage(tester, english);
    final clearTile = find.text('Clear Local Cache');
    await _scrollUntilHitTestable(tester, clearTile);
    await tester.tap(clearTile.hitTestable());
    await _pumpRouteTransition(tester);

    expect(find.text('Clear Local Cache?'), findsOneWidget);
    final cancel = find.widgetWithText(TextButton, 'Cancel').hitTestable();
    final clear = find.widgetWithText(FilledButton, 'Clear').hitTestable();
    expect(cancel, findsOneWidget);
    expect(clear, findsOneWidget);
    expect(tester.getSize(cancel).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(clear).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(clear).height, greaterThanOrEqualTo(48));
    await tester.tap(cancel);
    await _pumpRouteTransition(tester);
    expect(cache.clearCalls, 0);

    await _scrollUntilHitTestable(tester, clearTile);
    await tester.tap(clearTile.hitTestable());
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear').hitTestable());
    await _pumpRouteTransition(tester);
    expect(cache.clearCalls, 1);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cache clear confirmation and active clear share one transaction', (tester) async {
    cache.clearCompleter = Completer<CacheClearResult>();
    await _pumpPage(tester, english);
    final tile = find.ancestor(of: find.text('Clear Local Cache'), matching: find.byType(ListTile));
    final staleOnTap = tester.widget<ListTile>(tile).onTap!;

    staleOnTap();
    staleOnTap();
    await _pumpRouteTransition(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await _pumpRouteTransition(tester);
    expect(cache.clearCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);

    staleOnTap();
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(cache.clearCalls, 1);

    cache.clearCompleter!.complete(const CacheClearResult(remainingSizeMB: 0, failedOperations: 0));
    await tester.pump();
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
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
          home: const CacheDataSettingsPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _scrollUntilHitTestable(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pump();
  }
  fail('Cache action did not become hit-testable after bounded scrolling.');
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestCacheController extends CacheController {
  _TestCacheController()
    : super(cacheDirectoryResolver: () async => const <Directory>[], encodedImageCacheClearer: () async {});

  int clearCalls = 0;
  Completer<CacheClearResult>? clearCompleter;

  @override
  // Test fixture avoids the production refresh timer registration.
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<double> getCacheSize() async {
    cacheSizeMB.value = 12.34;
    return cacheSizeMB.value;
  }

  @override
  Future<void> refreshImageCache({bool refreshVisible = true}) async {}

  @override
  Future<CacheClearResult> clearCache() async {
    clearCalls++;
    final pending = clearCompleter;
    if (pending != null) return pending.future;
    cacheSizeMB.value = 0;
    return const CacheClearResult(remainingSizeMB: 0, failedOperations: 0);
  }
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._cache) : _font = FontSettingsController();

  final CacheController _cache;
  final FontSettingsController _font;

  @override
  CacheController get cache => _cache;

  @override
  FontSettingsController get font => _font;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
