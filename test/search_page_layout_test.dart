import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/widgets/app_status_view.dart';
import 'package:pure_live/common/widgets/room_card.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/search/search_controller.dart' as search;
import 'package:pure_live/modules/search/search_page.dart';
import 'package:pure_live/modules/search/search_ranking.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keep the real registry, capability text, Rx state and controller ownership.
// Replace only OS WebView detection and actions that would perform network/UI I/O.
class _Controller extends search.SearchController {
  int searches = 0;
  int webSearches = 0;
  int moreCalls = 0;
  bool filteredOffline = false;
  @override
  bool get hasFilteredOfflineResults => filteredOffline;
  Future<void> searchWithoutNativeAdapter() => super.doSearch();
  @override
  Future<bool> isWebView2Installed() async => true;
  @override
  Future<void> doSearch() async {
    searches++;
  }

  @override
  Future<void> openWebSearch() async {
    webSearches++;
  }

  @override
  Future<void> loadMore() async {
    if (hasMore.value && !loading.value && !loadingMore.value) {
      moreCalls++;
      loadingMore.value = true;
    }
  }
}

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;
}

Future<_Controller> _mount(
  WidgetTester tester, {
  String lang = 'en',
  Size size = const Size(320, 640),
  double scale = 1,
  double keyboard = 0,
  String? platform,
  String state = 'empty',
  TargetPlatform target = TargetPlatform.android,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    Get.reset();
  });
  late _Controller c;
  var initialized = false;
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: [Locale(lang)],
      startLocale: Locale(lang),
      fallbackLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => GetMaterialApp(
          theme: ThemeData(platform: target),
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              if (!initialized) {
                initialized = true;
                Get.put(SettingsService(), permanent: true);
                SettingsService.to.fav.hotAreasList.value = Sites.supportSites.map((site) => site.id).toList();
                c = _Controller();
                Get.put<search.SearchController>(c);
                if (platform != null) {
                  final position = c.sites.indexWhere((site) => site.id == platform);
                  expect(position, greaterThanOrEqualTo(0));
                  c.index.value = position + 1;
                }
                c.searched.value = state != 'initial';
                c.loading.value = state == 'loading';
                c.searchController.text = 'fixture';
                if (state == 'error' || state == 'partial') {
                  c.errorMessage.value = List.filled(5, 'Search failed for a platform; try again.').join(' ');
                }
                if (state == 'partial' || state == 'results') {
                  c.results.assignAll(
                    List.generate(
                      12,
                      (i) => LiveRoom(
                        platform: 'bilibili',
                        roomId: '$i',
                        title: 'Room $i',
                        nick: 'Anchor $i',
                        status: true,
                      ),
                    ),
                  );
                }
              }
              return const SearchPage();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return c;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scroll = find.byKey(const ValueKey('search-content'));
  for (var attempt = 0; attempt < 64 && target.hitTestable().evaluate().isEmpty; attempt++) {
    await tester.drag(scroll, const Offset(0, -140));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });
  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
  });
  tearDown(Get.reset);
  tearDownAll(Hive.close);

  for (final platform in [Sites.xiaohongshuSite, Sites.ttingSite, Sites.iptvSite, Sites.bilibiliSite]) {
    testWidgets('empty search action follows actual $platform capability', (tester) async {
      final c = await _mount(tester, platform: platform);
      final status = tester.widget<AppStatusView>(find.byType(AppStatusView));
      expect(status.onButtonPressed != null, c.canOpenWebSearch);
      if (c.canOpenWebSearch) {
        status.onButtonPressed!();
        expect(c.webSearches, 1);
      }
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final lang in ['zh', 'en']) {
    for (final state in ['initial', 'loading', 'empty', 'error', 'partial', 'results']) {
      testWidgets('$lang $state remains reachable in short large-text viewport', (tester) async {
        final c = await _mount(tester, lang: lang, size: const Size(640, 320), scale: 2, state: state);
        expect(tester.takeException(), null);
        final scroll = find.byType(CustomScrollView);
        expect(scroll, findsOneWidget);
        expect(c.scrollController.positions, hasLength(1));
        await tester.drag(scroll, const Offset(0, -1600));
        await tester.pump();
        expect(tester.takeException(), null);
        expect(c.scrollController.offset, greaterThan(0));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(c.scrollController.hasClients, false);
      });
    }
    for (final viewport in [
      (name: 'portrait', size: const Size(320, 640), scale: 1.0, keyboard: 0.0),
      (name: 'keyboard', size: const Size(320, 640), scale: 2.0, keyboard: 320.0),
      (name: 'desktop', size: const Size(1280, 720), scale: 1.5, keyboard: 0.0),
    ]) {
      for (final state in ['initial', 'loading', 'empty', 'error', 'partial', 'results']) {
        testWidgets('$lang $state ${viewport.name} retains content and scroll ownership', (tester) async {
          final c = await _mount(
            tester,
            lang: lang,
            size: viewport.size,
            scale: viewport.scale,
            keyboard: viewport.keyboard,
            state: state,
            target: viewport.name == 'desktop' ? TargetPlatform.windows : TargetPlatform.android,
          );
          expect(tester.takeException(), null);
          expect(c.scrollController.positions, hasLength(1));
          final scroll = find.byKey(const ValueKey('search-content'));
          if (state == 'results' || state == 'partial') {
            await _reveal(tester, find.text('Room 11'));
            expect(find.text('Room 11').hitTestable(), findsOneWidget);
            expect(tester.widget<CustomScrollView>(scroll).semanticChildCount, 12);
          } else if (state == 'error') {
            final button = find.descendant(of: find.byType(AppStatusView), matching: find.byType(TextButton));
            await _reveal(tester, button);
            await tester.tap(button);
            expect(c.searches, 1);
          }
          expect(tester.takeException(), null);
        });
      }
    }
  }

  for (final platform in [Sites.kuaishouSite, Sites.openrecSite, Sites.kilakilaSite]) {
    testWidgets('$platform unsupported native search offers only a useful action', (tester) async {
      final c = await _mount(tester, platform: platform);
      expect(c.canSearchNatively, false);
      await c.searchWithoutNativeAdapter();
      await tester.pump();
      expect(c.errorMessage.value, isNotEmpty);
      final status = tester.widget<AppStatusView>(find.byType(AppStatusView));
      expect(status.subtitle, c.errorMessage.value);
      expect(status.onButtonPressed != null, c.canOpenWebSearch);
      if (c.canOpenWebSearch) {
        status.onButtonPressed!();
        expect(c.webSearches, 1);
      }
      expect(c.searches, 0);
      expect(tester.takeException(), null);
    });
  }

  for (final platform in [
    Sites.picartoSite,
    Sites.inkeSite,
    Sites.missevanSite,
    Sites.twitcastingSite,
    Sites.huajiaoSite,
  ]) {
    testWidgets('$platform native search is actionable and keeps its web capability', (tester) async {
      final c = await _mount(tester, platform: platform);
      expect(c.canSearchNatively, true);
      expect(find.text(c.capabilityText), findsOneWidget);
      final status = tester.widget<AppStatusView>(find.byType(AppStatusView));
      expect(status.onButtonPressed != null, c.canOpenWebSearch);
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();
      expect(c.searches, 1);
      expect(tester.takeException(), null);
    });
  }

  testWidgets('filter, sort, capability and empty message update without unrelated state changes', (tester) async {
    final c = await _mount(tester);
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, true);
    await tester.tap(find.byType(FilterChip));
    await tester.pump();
    expect(c.includeOffline.value, false);
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, false);
    await tester.ensureVisible(find.byType(PopupMenuButton<LiveSearchSortMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<LiveSearchSortMode>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is PopupMenuItem<LiveSearchSortMode> && w.value == LiveSearchSortMode.audience),
    );
    await tester.pumpAndSettle();
    expect(c.sortMode.value, LiveSearchSortMode.audience);
    c.index.value = c.sites.indexWhere((s) => s.id == Sites.xiaohongshuSite) + 1;
    c.errorMessage.value = 'A new error with no result-count change';
    c.scrollController.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text(c.capabilityText), findsOneWidget);
    var status = tester.widget<AppStatusView>(find.byType(AppStatusView));
    expect(status.subtitle, c.errorMessage.value);
    status.onButtonPressed!();
    expect(c.searches, 1);
    c.filteredOffline = true;
    c.errorMessage.value = '';
    await tester.pumpAndSettle();
    status = tester.widget<AppStatusView>(find.byType(AppStatusView));
    status.onButtonPressed!();
    await tester.pump();
    expect(c.includeOffline.value, true);
    expect(c.webSearches, 0);
    expect(tester.takeException(), null);
  });

  testWidgets('paging and partial-error close retain results, offset and a single position', (tester) async {
    final c = await _mount(tester, state: 'results', size: const Size(640, 320));
    final position = c.scrollController.position;
    final sites = c.sites;
    c.hasMore.value = true;
    await tester.pump();
    c.scrollController.jumpTo(c.scrollController.position.maxScrollExtent);
    await tester.pump();
    expect(c.moreCalls, 1);
    final offset = c.scrollController.offset;
    c.results.add(LiveRoom(platform: 'bilibili', roomId: '12', title: 'Room 12', nick: 'Anchor 12', status: true));
    c.hasMore.value = false;
    c.loadingMore.value = false;
    await tester.pump();
    expect(c.scrollController.offset, closeTo(offset, 0.1));
    expect(identical(c.scrollController.position, position), true);
    expect(identical(c.sites, sites), true);
    expect(c.scrollController.positions, hasLength(1));
    c.errorMessage.value = 'Partial failure';
    c.scrollController.jumpTo(0);
    await tester.pump();
    final banner = find.byType(MaterialBanner);
    final close = find.descendant(of: banner, matching: find.byType(TextButton));
    await _reveal(tester, close);
    await tester.tap(close);
    await tester.pump();
    expect(c.errorMessage.value, isEmpty);
    expect(c.results, hasLength(13));
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.byType(RoomCard), findsWidgets);
    expect(tester.takeException(), null);
  });
}
