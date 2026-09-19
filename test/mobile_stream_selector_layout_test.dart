import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;
}

class _FontSettings implements FontSettingsController {
  @override
  final fontSizeBodySmall = 12.0.obs;
  @override
  final fontSizeBodyMedium = 13.0.obs;
  @override
  final fontSizeBodyLarge = 14.0.obs;
  @override
  final fontSizeTitleMedium = 15.0.obs;
  @override
  final fontSizeTitleLarge = 20.0.obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsService {
  @override
  final font = _FontSettings();

  @override
  // This layout fixture deliberately skips persistence and background startup.
  // ignore: must_call_super
  void onInit() {}
}

class _LiveController implements LivePlayController {
  _LiveController()
    : state = LivePlayState(
        player: PlayerState(
          qualites: [
            LivePlayQuality(quality: 'Accessibility quality'),
            LivePlayQuality(quality: 'High definition'),
          ],
          playUrls: const ['https://one.invalid/live', 'https://two.invalid/live'],
        ),
      ).obs;

  @override
  final Rx<LivePlayState> state;
  final selections = <(ReloadDataType, int, int)>[];

  @override
  Future<void> setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) async {
    selections.add((reloadDataType, qualityIndex, lineIndex));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VideoController implements VideoController {
  _VideoController() : livePlayController = _LiveController();

  @override
  final _LiveController livePlayController;
  @override
  final isMenuOpen = false.obs;
  int enableCalls = 0;

  @override
  void stopHideController() {}

  @override
  void enableController() => enableCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final selector in ['quality', 'line']) {
    testWidgets('mobile $selector selector gives 3x text a measured row', (tester) async {
      Get.testMode = true;
      Get.put<SettingsService>(_Settings());
      addTearDown(() {
        Get.reset();
        Get.testMode = false;
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = _VideoController();
      final child = selector == 'quality'
          ? ResolutionSelectorButton(key: const ValueKey('selector'), controller: controller)
          : LineSelectorButton(key: const ValueKey('selector'), controller: controller);
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          startLocale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          saveLocale: false,
          path: 'assets/translations',
          assetLoader: const _Loader(),
          child: Builder(
            builder: (context) => GetMaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              theme: ThemeData(platform: TargetPlatform.android),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
                child: child!,
              ),
              home: Scaffold(body: Center(child: child)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('selector')));
      await tester.pumpAndSettle();

      final choice = selector == 'quality'
          ? find.text('Accessibility quality').last
          : find.text('Line 1', skipOffstage: false).last;
      expect(choice, findsOneWidget);
      expect(tester.getSize(choice).height, greaterThan(38), reason: 'the old fixed row clips 3x text to 38 px');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.enableCalls, 1);

      await tester.tap(find.byKey(const ValueKey('selector')));
      await tester.pumpAndSettle();
      final secondChoice = find.text(selector == 'quality' ? 'High definition' : 'Line 2').last;
      await tester.ensureVisible(secondChoice);
      await tester.pumpAndSettle();
      await tester.tap(secondChoice);
      await tester.pumpAndSettle();
      expect(controller.livePlayController.selections, hasLength(1));
      expect(controller.enableCalls, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
