import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/utils/play_quality_label.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolution_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final translations = <String, Map<String, dynamic>>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final language in ['zh', 'en']) {
      translations[language] =
          jsonDecode(await File('assets/translations/$language.json').readAsString()) as Map<String, dynamic>;
    }
  });
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  for (final language in ['zh', 'en']) {
    testWidgets('$language active quality is localized, bounded, and distinct from menu options', (tester) async {
      final quality = LivePlayQuality(quality: 'Original', id: 0, isPlaybackUnconfirmed: true);
      final controller = Get.put<LivePlayController>(_LabelController(quality));
      final expected = language == 'zh' ? '未确认 · Original' : 'Unconfirmed · Original';
      await tester.pumpWidget(
        EasyLocalization(
          key: ValueKey(language),
          supportedLocales: const [Locale('zh'), Locale('en')],
          startLocale: Locale(language),
          saveLocale: false,
          path: 'assets/translations',
          assetLoader: _LoadedTranslations(translations),
          child: Builder(
            builder: (context) => GetMaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(width: 120, child: ResolutionSelector(controller: controller)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(quality.playbackLabel, expected);
      expect(quality.selectionId, 0);
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(ResolutionSelector));
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsOneWidget, reason: 'menu keeps the request label');
      expect(find.text(expected), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      controller.state.value = controller.state.value.copyWith(
        player: controller.state.value.player.copyWith(qualites: [quality.withPlaybackUnconfirmed(false)]),
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsNothing);
      expect(find.text('Original'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _LoadedTranslations extends AssetLoader {
  const _LoadedTranslations(this.translations);
  final Map<String, Map<String, dynamic>> translations;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => translations[locale.languageCode]!;
}

class _LabelController extends GetxController implements LivePlayController {
  _LabelController(LivePlayQuality quality) {
    state.value = LivePlayState(
      room: const RoomState(success: true),
      player: PlayerState(qualites: [quality]),
    );
    playerController = PlayerController(this);
  }
  @override
  final Rx<LivePlayState> state = const LivePlayState().obs;
  @override
  late final PlayerController playerController;
  // Only the selector-facing contract is used, without live service startup.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void updateUI({
    Object? screenMode,
    int? refreshKey,
    bool? isMenuOpen,
    int? closeTimes,
    bool? closeTimeFlag,
    bool? displayVideoLayer,
  }) {}

  @override
  void onClose() {
    playerController.onClose();
    super.onClose();
  }
}
