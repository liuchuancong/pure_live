import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/line_selector.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolution_selector.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolutions_row.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/audience_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;
}

class _Host extends GetxController implements LivePlayController {
  _Host({this.site = 'bilibili'})
    : state = LivePlayState(
        room: RoomState(
          detail: LiveRoom(roomId: 'layout', platform: site),
          success: true,
        ),
        player: PlayerState(
          qualites: [
            LivePlayQuality(quality: 'Accessibility quality'),
            LivePlayQuality(quality: 'High definition'),
          ],
          playUrls: const ['https://fixture/one', 'https://fixture/two'],
        ),
      ).obs {
    playerController = PlayerController(this);
  }

  @override
  final Rx<LivePlayState> state;
  @override
  late final PlayerController playerController;
  @override
  final String site;
  final selections = <(ReloadDataType, int, int)>[];

  @override
  Future<void> setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) async {
    selections.add((reloadDataType, qualityIndex, lineIndex));
  }

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void onClose() {
    playerController.onClose();
    super.onClose();
  }
}

class _AppSettings implements AppSettingsController {
  @override
  final preferRealOnlineCounts = false.obs;

  @override
  bool isRealOnlineEnabledFor(String? platform) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsService {
  _Settings(this._app);

  final AppSettingsController _app;

  @override
  AppSettingsController get app => _app;

  @override
  // The layout fixture reads defaults without persistence or background startup.
  // ignore: must_call_super
  void onInit() {}
}

void _expectSingleLineTextHasFullHeight(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final intrinsicHeight = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
  expect(
    paragraph.size.height + 0.01,
    greaterThanOrEqualTo(intrinsicHeight),
    reason: '${tester.widget<Text>(finder).data} is vertically clipped',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('normal playback selectors stay reachable at 320 px and 3x English text', (tester) async {
    Get.testMode = true;
    Get.put<SettingsService>(_Settings(_AppSettings()));
    final host = _Host();
    Get.put<LivePlayController>(host);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      host.onClose();
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
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: ResolutionsRow(controller: host),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accessibility quality'), findsOneWidget);
    expect(find.text('Line 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    _expectSingleLineTextHasFullHeight(
      tester,
      find.descendant(of: find.byType(AudienceInfo), matching: find.byType(Text)),
    );
    _expectSingleLineTextHasFullHeight(tester, find.text('Accessibility quality'));
    _expectSingleLineTextHasFullHeight(tester, find.text('Line 1'));

    await tester.tap(find.byType(ResolutionSelector));
    await tester.pumpAndSettle();
    final quality = find.text('High definition');
    await tester.ensureVisible(quality);
    await tester.tap(quality);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LineSelector));
    await tester.pumpAndSettle();
    final line = find.text('Line 2');
    await tester.ensureVisible(line);
    await tester.tap(line);
    await tester.pumpAndSettle();

    expect(host.selections, [(ReloadDataType.changeQuality, 1, 0), (ReloadDataType.changeLine, 0, 1)]);
    expect(tester.takeException(), isNull);
  });
}
