import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/hot_areas/hot_areas_controller.dart';
import 'package:pure_live/modules/hot_areas/hot_areas_page.dart';
import 'package:pure_live/modules/settings/pages/platform_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late FavoriteRoomController favorites;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-platform-settings-test-');
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
    favorites = FavoriteRoomController();
    Get.put<SettingsService>(_TestSettingsService(favorites));
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('platform preference explains its effect and keeps the last platform reachable', (tester) async {
    favorites.preferPlatform.value = Sites.bilibiliSite;
    await _pumpLocalized(
      tester,
      english: english,
      home: const PlatformSettingsPage(),
      size: const Size(320, 480),
      textScale: 3,
    );

    expect(find.text('When enter popular/areas, first platform choice'), findsOneWidget);
    expect(find.text('Customize and manage video filtering tags'), findsOneWidget);
    final preference = find.text('Platform Preference');
    await _scrollPageUntilHitTestable(tester, preference);
    await tester.tap(preference.hitTestable());
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    final network = find.descendant(of: dialog, matching: find.text('Network'));
    await _scrollDialogUntilVisible(tester, dialog: dialog, target: network);
    await tester.tap(find.ancestor(of: network, matching: find.byType(RadioListTile<String>)));
    await tester.pumpAndSettle();

    expect(favorites.preferPlatform.value, Sites.iptvSite);
    expect(find.text('Network'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preference dialog only offers platforms visible in popular and areas', (tester) async {
    favorites.hotAreasList.value = [Sites.bilibiliSite, Sites.iptvSite];
    favorites.preferPlatform.value = Sites.bilibiliSite;
    await _pumpLocalized(tester, english: english, home: const PlatformSettingsPage(), size: const Size(420, 800));

    await tester.tap(find.text('Platform Preference'));
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    expect(find.descendant(of: dialog, matching: find.byType(RadioListTile<String>)), findsNWidgets(2));
    expect(find.descendant(of: dialog, matching: find.text('Douyu')), findsNothing);
    await tester.tap(
      find.ancestor(
        of: find.descendant(of: dialog, matching: find.text('Network')),
        matching: find.byType(RadioListTile<String>),
      ),
    );
    await tester.pumpAndSettle();
    expect(favorites.preferPlatform.value, Sites.iptvSite);
  });

  testWidgets('preference dialog filters many visible platforms by name or id', (tester) async {
    await _pumpLocalized(tester, english: english, home: const PlatformSettingsPage(), size: const Size(420, 800));
    await tester.tap(find.text('Platform Preference'));
    await tester.pumpAndSettle();

    final filter = find.byKey(const ValueKey('prefer-platform-filter'));
    expect(filter, findsOneWidget);
    await tester.enterText(filter, 'weibo');
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    final choices = find.descendant(of: dialog, matching: find.byType(RadioListTile<String>));
    expect(choices, findsOneWidget);
    expect(tester.widget<RadioListTile<String>>(choices).value, Sites.weiboSite);

    await tester.enterText(filter, 'no-such-platform');
    await tester.pumpAndSettle();
    expect(choices, findsNothing);
    expect(find.text('No matching platforms'), findsOneWidget);

    await tester.enterText(filter, 'iptv');
    await tester.pumpAndSettle();
    expect(tester.widget<RadioListTile<String>>(choices).value, Sites.iptvSite);
  });

  testWidgets('preference dialog tracks a changed visible platform order while open', (tester) async {
    favorites.hotAreasList.value = [Sites.bilibiliSite, Sites.iptvSite];
    await _pumpLocalized(tester, english: english, home: const PlatformSettingsPage(), size: const Size(420, 800));
    await tester.tap(find.text('Platform Preference'));
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    final choices = find.descendant(of: dialog, matching: find.byType(RadioListTile<String>));
    expect(choices, findsNWidgets(2));
    favorites.hotAreasList.value = [Sites.weiboSite, Sites.bilibiliSite, Sites.weiboSite];
    await tester.pumpAndSettle();
    expect(choices, findsNWidgets(2));
    expect(tester.widget<RadioListTile<String>>(choices.first).value, Sites.weiboSite);
    expect(tester.widget<RadioListTile<String>>(choices.last).value, Sites.bilibiliSite);
  });

  test('hidden platform preference is rejected and restored backup preference follows visible order', () {
    favorites.hotAreasList.value = [Sites.bilibiliSite, Sites.iptvSite];
    favorites.changePreferPlatform(Sites.douyuSite);
    expect(favorites.preferPlatform.value, Sites.bilibiliSite);

    favorites.fromJson({
      'hotAreasList': [Sites.iptvSite, Sites.bilibiliSite],
      'preferPlatform': Sites.douyuSite,
    });
    expect(favorites.preferPlatform.value, Sites.iptvSite);
  });

  testWidgets('platform rows stack controls and expose drag handles only for persisted visible order', (tester) async {
    favorites.hotAreasList.value = [Sites.bilibiliSite];
    favorites.preferPlatform.value = Sites.bilibiliSite;
    final controller = Get.put(HotAreasController());

    await _pumpLocalized(
      tester,
      english: english,
      home: const HotAreasPage(),
      size: const Size(320, 480),
      textScale: 3,
    );

    expect(find.byType(ReorderableDragStartListener), findsNothing);
    final bilibiliRow = find.byKey(const ValueKey(Sites.bilibiliSite));
    await _scrollPageUntilHitTestable(tester, bilibiliRow);
    final title = find.descendant(of: bilibiliRow, matching: find.text('Bilibili'));
    final platformSwitch = find.descendant(of: bilibiliRow, matching: find.byType(Switch));
    expect(tester.getRect(platformSwitch).top, greaterThanOrEqualTo(tester.getRect(title).bottom));

    tester.widget<Switch>(platformSwitch).onChanged!(false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(favorites.hotAreasList, [Sites.bilibiliSite]);

    final reorderable = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    expect(() => reorderable.onReorderItem!(99, 0), returnsNormally);
    expect(() => reorderable.onReorderItem!(1, 99), returnsNormally);
    expect(controller.sites, hasLength(Sites.supportSites.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiding the preferred platform selects the first remaining visible platform', (tester) async {
    favorites.hotAreasList.value = [Sites.bilibiliSite, Sites.douyuSite];
    favorites.preferPlatform.value = Sites.bilibiliSite;
    Get.put(HotAreasController());

    await _pumpLocalized(tester, english: english, home: const HotAreasPage(), size: const Size(420, 800));

    final bilibiliRow = find.byKey(const ValueKey(Sites.bilibiliSite));
    final platformSwitch = find.descendant(of: bilibiliRow, matching: find.byType(Switch));
    tester.widget<Switch>(platformSwitch).onChanged!(false);
    await tester.pump();
    expect(favorites.hotAreasList, [Sites.douyuSite]);
    expect(favorites.preferPlatform.value, Sites.douyuSite);
    expect(tester.takeException(), isNull);
  });

  test('reordering persists visible platforms and leaves hidden platforms outside the saved order', () {
    favorites.hotAreasList.value = [Sites.bilibiliSite, Sites.douyuSite, Sites.huyaSite];
    final controller = Get.put(HotAreasController());

    controller.onReorder(0, 3);

    expect(favorites.hotAreasList, [Sites.douyuSite, Sites.huyaSite, Sites.bilibiliSite]);
    expect(controller.sites.take(3).map((site) => site.id), [Sites.douyuSite, Sites.huyaSite, Sites.bilibiliSite]);

    final snapshot = controller.sites.map((site) => site.id).toList(growable: false);
    controller.onReorder(3, 0);
    expect(controller.sites.map((site) => site.id), snapshot);
    expect(favorites.hotAreasList, [Sites.douyuSite, Sites.huyaSite, Sites.bilibiliSite]);
  });
}

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Map<String, dynamic> english,
  required Widget home,
  required Size size,
  double textScale = 1,
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
  await tester.pumpAndSettle();
}

Future<void> _scrollPageUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first,
  );
  for (var attempt = 0; attempt < 100; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final position = scrollable.position;
    final next = (position.pixels + position.viewportDimension * 0.4).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump();
  }
  fail('Platform row did not become hit-testable after bounded page scrolling.');
}

Future<void> _scrollDialogUntilVisible(WidgetTester tester, {required Finder dialog, required Finder target}) async {
  final scrollable = find.descendant(of: dialog, matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(target, 100, scrollable: scrollable, maxScrolls: 100);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._favorites) : _font = FontSettingsController();

  final FavoriteRoomController _favorites;
  final FontSettingsController _font;

  @override
  FavoriteRoomController get fav => _favorites;

  @override
  FontSettingsController get font => _font;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
