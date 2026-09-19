import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/room_card_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/room_card_settings_page.dart';
import 'package:pure_live/modules/settings/pages/theme_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> english;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    Get.put(SettingsService(), permanent: true);
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
  });

  testWidgets('theme page exposes room card settings and the preview follows independent controls', (tester) async {
    await tester.runAsync(() async {
      await HivePrefUtil.setString('room_card_mobile_preset', RoomCardPreset.detailed.storageKey);
      await HivePrefUtil.setString('room_card_mobile_config', jsonEncode(RoomCardAppearance.detailed.toJson()));
      await HivePrefUtil.setString('room_card_desktop_preset', RoomCardPreset.compact.storageKey);
      await HivePrefUtil.setString('room_card_desktop_config', jsonEncode(RoomCardAppearance.compact.toJson()));
    });

    await _pump(tester, english, home: const ThemeSettingsPage(), size: const Size(900, 1000));

    expect(find.byKey(const ValueKey('room-card-settings-entry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-card-settings-entry')).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RoomCardSettingsPage), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-target-mobile')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-target-desktop')), findsOneWidget);
    expect(SettingsService.to.roomCard.currentViewport, RoomCardViewport.desktop);
    expect(find.byKey(const ValueKey('room-card-compact-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-cover-layout')), findsNothing);
    expect(find.byKey(const ValueKey('room-card-platform-badge')), findsNothing);
    expect(find.byKey(const ValueKey('room-card-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-anchor-name')), findsOneWidget);
    final compactHeight = tester.getSize(find.byKey(const ValueKey('room-card-surface'))).height;
    final compactShape = tester.widget<Card>(find.byKey(const ValueKey('room-card-surface'))).shape;
    expect((compactShape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(12));

    await tester.tap(find.byKey(const ValueKey('room-card-preset-normal')).hitTestable());
    await tester.pump();
    expect(SettingsService.to.roomCard.configFor(RoomCardViewport.desktop), RoomCardAppearance.standard);
    expect(find.byKey(const ValueKey('room-card-cover-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-compact-layout')), findsNothing);
    expect(find.byKey(const ValueKey('room-card-platform-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-anchor-name')), findsOneWidget);
    final standardHeight = tester.getSize(find.byKey(const ValueKey('room-card-surface'))).height;
    expect(standardHeight, greaterThan(compactHeight * 2));

    final settingsScroll = tester.state<ScrollableState>(
      find.descendant(of: find.byKey(const ValueKey('room-card-settings-scroll')), matching: find.byType(Scrollable)),
    );
    settingsScroll.position.jumpTo(settingsScroll.position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(const ValueKey('room-card-layout-compact')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-card-layout-compact')).hitTestable());
    await tester.pump();
    expect(SettingsService.to.roomCard.configFor(RoomCardViewport.desktop).layout, RoomCardLayout.compact);
    expect(SettingsService.to.roomCard.presetFor(RoomCardViewport.desktop), RoomCardPreset.custom);

    settingsScroll.position.jumpTo(0);
    await tester.pump();
    expect(find.byKey(const ValueKey('room-card-compact-layout')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-card-target-mobile')).hitTestable());
    await tester.pump();
    expect(SettingsService.to.roomCard.configFor(RoomCardViewport.mobile), RoomCardAppearance.detailed);
    expect(find.byKey(const ValueKey('room-card-platform-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-card-anchor-name')), findsOneWidget);
    final detailedShape = tester.widget<Card>(find.byKey(const ValueKey('room-card-surface'))).shape;
    expect((detailedShape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(20));

    settingsScroll.position.jumpTo(520.clamp(0, settingsScroll.position.maxScrollExtent).toDouble());
    await tester.pump();
    expect(find.byKey(const ValueKey('room-card-platform-always')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room card settings remain scrollable at 320x480 with 3x text', (tester) async {
    await _pump(tester, english, home: const RoomCardSettingsPage(), size: const Size(320, 480), textScale: 3);

    expect(find.byKey(const ValueKey('room-card-target-selector')), findsOneWidget);
    expect(find.byTooltip('Reset current layout'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final page = find.byKey(const ValueKey('room-card-settings-scroll'));
    final cornerRadius = find.text('Corner radius', skipOffstage: false);
    for (var attempt = 0; attempt < 30 && cornerRadius.evaluate().isEmpty; attempt++) {
      await tester.drag(page, const Offset(0, -2000));
      await tester.pump();
    }
    expect(cornerRadius, findsOneWidget);
    await tester.ensureVisible(cornerRadius);
    await tester.pump();

    expect(find.text('Corner radius'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> english, {
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}
