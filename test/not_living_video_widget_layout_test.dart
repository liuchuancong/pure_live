import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/placeholder/not_living_video_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;
}

class _Controller implements LivePlayController {
  @override
  final room = LiveRoom(
    platform: 'bilibili',
    roomId: 'offline-layout',
    title: 'A long offline room title that must remain readable',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  // This layout fixture does not start persistence or background services.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('offline room header preserves full text height at 3x scale', (tester) async {
    Get.testMode = true;
    Get.put(GlobalPlayerState());
    Get.put<SettingsService>(_Settings());
    addTearDown(() {
      Get.reset();
      Get.testMode = false;
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(body: NotLivingVideoWidget(controller: _Controller())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.byKey(const ValueKey('offline-room-title'));
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).data, 'A long offline room title that must remain readable');
    final paragraph = tester.renderObject<RenderParagraph>(title);
    final header = find.byKey(const ValueKey('offline-room-header'));
    expect(
      paragraph.size.height + 0.01,
      greaterThanOrEqualTo(paragraph.getMaxIntrinsicHeight(paragraph.size.width)),
      reason: 'The fixed offline header must not vertically clip scaled room titles.',
    );
    expect(tester.getSize(header).height, greaterThan(55));

    final hint = find.text('Please switch to another live room');
    expect(hint, findsOneWidget);
    await tester.ensureVisible(hint);
    await tester.pump();
    expect(find.byKey(const ValueKey('offline-room-content-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
