import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_page.dart';
import 'package:pure_live/modules/areas/favorite_areas_controller.dart';
import 'package:pure_live/modules/areas/favorite_areas_page.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late FavoriteRoomController favorites;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-favorite-areas-page-test-');
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

  testWidgets('visible platform changes rebuild tabs and retain the selected platform identity', (tester) async {
    favorites.hotAreasList.value = [Sites.bilibiliSite, Sites.huyaSite];
    favorites.favoriteAreas.value = [
      _area(Sites.bilibiliSite, '1', 'Bilibili area'),
      _area(Sites.huyaSite, '2', 'Huya area'),
    ];
    Get.put(FavoriteAreasController());

    await _pumpLocalized(tester, english: english, home: const FavoriteAreasPage());
    await tester.tap(find.text('Huya'));
    await tester.pump(const Duration(milliseconds: 40));

    favorites.hotAreasList.value = [Sites.huyaSite];
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Huya area'), findsOneWidget);
  });

  testWidgets('follow button grows with accessibility text instead of overflowing', (tester) async {
    await _pumpLocalized(
      tester,
      english: english,
      home: Scaffold(body: FavoriteAreaFloatingButton(area: _area(Sites.huyaSite, '2', 'Long favorite area'))),
      size: const Size(320, 480),
      textScale: 3,
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AnimatedContainer)).height, greaterThan(48));
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Long favorite area'), findsOneWidget);
  });

  testWidgets('unfollow confirmation stays reachable for a long area at narrow three-times text', (tester) async {
    final area = _area(Sites.huyaSite, '2', List.filled(8, 'Long favorite area').join(' '));
    favorites.favoriteAreas.value = [area];
    await _pumpLocalized(
      tester,
      english: english,
      home: Scaffold(body: FavoriteAreaFloatingButton(area: area)),
      size: const Size(320, 480),
      textScale: 3,
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Confirm').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Cancel').hitTestable());
    await tester.pumpAndSettle();
    expect(favorites.isFavoriteArea(area), isTrue);
  });

  testWidgets('unfollow confirmation is a single-flight route', (tester) async {
    final area = _area(Sites.huyaSite, '2', 'Favorite area');
    favorites.favoriteAreas.value = [area];
    await _pumpLocalized(
      tester,
      english: english,
      home: Scaffold(body: FavoriteAreaFloatingButton(area: area)),
    );

    final tap = tester.widget<InkWell>(find.byType(InkWell).first).onTap!;
    tap();
    tap();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(favorites.isFavoriteArea(area), isTrue);
  });

  testWidgets('favorite area catalogue remains usable on a narrow large-text viewport', (tester) async {
    favorites.hotAreasList.value = [Sites.huyaSite];
    favorites.favoriteAreas.value = [_area(Sites.huyaSite, '2', 'Long favorite area')];
    Get.put(FavoriteAreasController());

    await _pumpLocalized(
      tester,
      english: english,
      home: const FavoriteAreasPage(),
      size: const Size(320, 480),
      textScale: 3,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('favorite-areas-platform-tabs')), findsOneWidget);
    expect(find.text('Long favorite area'), findsOneWidget);
  });

  testWidgets('incomplete favorite metadata renders a stable localized fallback', (tester) async {
    favorites.hotAreasList.value = [Sites.huyaSite];
    final incomplete = LiveArea(platform: Sites.huyaSite, areaId: '2', areaName: null, typeName: null, areaPic: '');

    await _pumpLocalized(
      tester,
      english: english,
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(width: 160, child: AreaCard(category: incomplete)),
            FavoriteAreaFloatingButton(area: incomplete),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Unnamed area'), findsNWidgets(2));
    expect(find.text('No data available'), findsOneWidget);
    expect(find.text('U'), findsOneWidget);
  });
}

LiveArea _area(String platform, String id, String name) => LiveArea(
  platform: platform,
  areaId: id,
  areaName: name,
  typeName: 'Category',
  areaPic: '',
  areaType: '',
  shortName: '',
);

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Map<String, dynamic> english,
  required Widget home,
  Size size = const Size(420, 800),
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

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._favorites) : _font = FontSettingsController(), _theme = ThemeSettingsController();

  final FavoriteRoomController _favorites;
  final FontSettingsController _font;
  final ThemeSettingsController _theme;

  @override
  FavoriteRoomController get fav => _favorites;

  @override
  FontSettingsController get font => _font;

  @override
  ThemeSettingsController get theme => _theme;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
