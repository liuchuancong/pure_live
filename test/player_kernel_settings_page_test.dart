import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/settings/pages/player_kernel_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    translations = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    await HivePrefUtil.setString('videoPlayerKey', 'ijk');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      Get.put(SettingsService(), permanent: true);
      await Future<void>.delayed(Duration.zero);
      await HivePrefUtil.flush();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  tearDown(() {
    Get.deleteAll(force: true);
    Get.reset();
  });

  tearDownAll(Hive.close);

  testWidgets('Windows replaces a stale IJK preference and offers MPV and fvp only', (tester) async {
    await _pumpKernelPage(tester, translations, size: const Size(900, 900));

    expect(SettingsService.to.player.videoPlayerKey.v, 'mpv');
    expect(HivePrefUtil.getString('videoPlayerKey'), 'mpv');
    expect(find.text('MPV Player'), findsOneWidget);
    expect(find.text('IJK Player'), findsNothing);
    expect(find.text('Different engines affect performance'), findsOneWidget);

    final engineTile = find.ancestor(of: find.text('Player Engine'), matching: find.byType(ListTile));
    expect(engineTile, findsOneWidget);
    expect(tester.widget<ListTile>(engineTile).onTap, isNotNull);
    expect(availableVideoPlayerKeysForPlatform(TargetPlatform.windows), ['mpv', 'fvp']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }, skip: !Platform.isWindows);

  testWidgets('Windows kernel controls remain reachable in narrow very-large text', (tester) async {
    await _pumpKernelPage(tester, translations, size: const Size(320, 480), textScale: 3);

    final engineTitle = find.text('Player Engine');
    final engineValue = find.text('MPV Player');
    expect(tester.getRect(engineValue).top, greaterThanOrEqualTo(tester.getRect(engineTitle).bottom));
    expect(tester.takeException(), isNull, reason: 'initial kernel page');

    await _scrollPageUntilHitTestable(tester, find.text('MPV Advanced Settings'));
    expect(find.text('MPV Official Docs'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    final videoOutputTitle = find.text('Video Output Driver (--vo)');
    await _scrollPageUntilHitTestable(tester, videoOutputTitle);
    await tester.tap(videoOutputTitle.hitTestable());
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final lastOption = find.text('libmpv');
    final dialogScrollable = find.descendant(of: dialog, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(lastOption, 100, scrollable: dialogScrollable);
    await tester.pumpAndSettle();
    expect(tester.getRect(lastOption).bottom, lessThanOrEqualTo(480));
    await tester.tap(find.ancestor(of: lastOption, matching: find.byType(RadioListTile<String>)));
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.videoOutputDriver.value, 'libmpv');
    expect(dialog, findsNothing);

    final audioOutputTitle = find.text('Audio Output Driver (--ao)');
    await _scrollPageUntilHitTestable(tester, audioOutputTitle);
    final audioOutputValue = find.text('auto (Automatic fallback)');
    expect(tester.getRect(audioOutputValue).top, greaterThanOrEqualTo(tester.getRect(audioOutputTitle).bottom));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  }, skip: !Platform.isWindows);

  testWidgets('Android audio output menu exposes only native fallback drivers', (tester) async {
    SettingsService.to.player.videoPlayerKey.v = 'mpv';
    SettingsService.to.player.audioOutputDriver.v = 'auto';
    await _pumpKernelPage(tester, translations, size: const Size(1200, 1600), platform: TargetPlatform.android);

    final audioOutputTitle = find.text('Audio Output Driver (--ao)');
    await _scrollPageUntilHitTestable(tester, audioOutputTitle);
    expect(find.text('auto (Automatic fallback)'), findsOneWidget);
    await tester.tap(audioOutputTitle.hitTestable());
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    for (final label in <String>[
      'auto (Automatic fallback)',
      'audiotrack (Android AudioTrack)',
      'aaudio (Android 8.0+)',
      'opensles (Legacy fallback)',
      'null (No audio output)',
    ]) {
      expect(find.descendant(of: dialog, matching: find.text(label)), findsOneWidget);
    }
    for (final desktopOnly in <String>['wasapi', 'coreaudio', 'alsa', 'pulse']) {
      expect(
        find.descendant(
          of: dialog,
          matching: find.byWidgetPredicate((widget) => widget is Text && widget.data?.startsWith(desktopOnly) == true),
        ),
        findsNothing,
      );
    }

    await tester.tap(
      find.ancestor(of: find.text('aaudio (Android 8.0+)'), matching: find.byType(RadioListTile<String>)),
    );
    await tester.pumpAndSettle();
    expect(SettingsService.to.player.audioOutputDriver.v, 'aaudio');
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  }, skip: !Platform.isWindows);

  testWidgets('player proxy editor normalizes host and retains the last valid port', (tester) async {
    SettingsService.to.proxy.enableProxy.value = true;
    SettingsService.to.proxy.proxyHost.value = '127.0.0.1';
    SettingsService.to.proxy.proxyPort.value = 7897;
    await _pumpKernelPage(tester, translations, size: const Size(320, 480), textScale: 3);

    final proxyTitle = find.text('Proxy Settings');
    await _scrollPageUntilHitTestable(tester, proxyTitle);
    await tester.tap(proxyTitle.hitTestable());
    await tester.pumpAndSettle();

    final host = find.byKey(const ValueKey('player-proxy-dialog-host'));
    final port = find.byKey(const ValueKey('player-proxy-dialog-port'));
    expect(host, findsOneWidget);
    expect(port, findsOneWidget);
    final dialogScroll = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate(
            (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(host, 80, scrollable: dialogScroll);
    await tester.pumpAndSettle();
    expect(tester.getRect(host).bottom, lessThanOrEqualTo(480));
    await tester.enterText(host, '127。0。0。1');
    await tester.pump();
    expect(SettingsService.to.proxy.proxyHost.value, '127.0.0.1');

    await tester.scrollUntilVisible(port, 80, scrollable: dialogScroll);
    await tester.pumpAndSettle();
    expect(tester.getRect(port).bottom, lessThanOrEqualTo(480));
    await tester.enterText(port, '65536');
    await tester.pump();
    expect(SettingsService.to.proxy.proxyPort.value, 7897);
    expect(find.text('Enter a port from 1 to 65535'), findsOneWidget);

    await tester.enterText(port, '8443');
    await tester.pump();
    expect(SettingsService.to.proxy.proxyPort.value, 8443);
    expect(find.text('Enter a port from 1 to 65535'), findsNothing);
    expect(find.text('Confirm').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Confirm').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  }, skip: !Platform.isWindows);
}

Future<void> _pumpKernelPage(
  WidgetTester tester,
  Map<String, dynamic> translations, {
  required Size size,
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.windows,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
      supportedLocales: const <Locale>[Locale('en')],
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _Translations(translations),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const PlayerKernelSettingsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _pageScrollable() => find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

Future<void> _scrollPageUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(_pageScrollable());
  for (var attempt = 0; attempt < 40; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final position = scrollable.position;
    final next = position.pixels + position.viewportDimension * 0.75;
    position.jumpTo(next > position.maxScrollExtent ? position.maxScrollExtent : next);
    await tester.pump();
  }
  fail('Target did not become hit-testable after bounded page scrolling.');
}

class _Translations extends AssetLoader {
  const _Translations(this.values);

  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => values;
}
