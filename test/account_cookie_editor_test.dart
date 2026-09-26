import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/account/douyin/douyin_cookie_controller.dart';
import 'package:pure_live/modules/account/douyu/douyu_cookie_controller.dart';
import 'package:pure_live/modules/account/huya/huya_cookie_controller.dart';
import 'package:pure_live/modules/account/kuaishou/kuaishou_cookie_controller.dart';
import 'package:pure_live/modules/account/soop/soop_cookie_controller.dart';
import 'package:pure_live/modules/account/twitch/twitch_cookie_controller.dart';
import 'package:pure_live/modules/account/widgets/account_cookie_editor.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/recorder/services/ffmpeg_header_factory.dart';
import 'package:pure_live/modules/account/yy/yy_cookie_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> english;
  late Directory hiveDirectory;
  late CookieSettingsController cookies;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-cookie-editor-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    cookies = CookieSettingsController();
    Get.put<SettingsService>(_TestSettingsService(FontSettingsController(), cookies));
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  test('account cookie normalization removes surrounding and header-breaking characters', () {
    expect(normalizeAccountCookie('  session=abc; token=def\r\n\t '), 'session=abc; token=def');
    expect(normalizeAccountCookie('\u0000foo=bar\u007f'), 'foo=bar');
    expect(normalizeAccountCookie('   '), isEmpty);

    final parsed = CookieSettingsController.parseConfig({
      'huyaCookie': ' \r\nhuya=backup\u0000 ',
      'douyuCookie': ' \r\ndouyu=backup\u0000 ',
      'douyinCookie': 'douyin=backup',
      'taobaoCookie': ' taobao=backup\r\n ',
    });
    expect(parsed['huyaCookie'], 'huya=backup');
    expect(parsed['douyuCookie'], 'douyu=backup');
    expect(parsed['douyinCookie'], 'douyin=backup');
    expect(parsed.containsKey('taobaoCookie'), isFalse, reason: 'retired Taobao cookie is not restored');
  });

  test('all platform cookie controllers persist the normalized header value', () {
    cookies.huyaCookie.value = ' \r\nhuya=stored\u0000 ';
    cookies.douyuCookie.value = ' \r\ndouyu=stored\u0000 ';
    cookies.douyinCookie.value = ' \r\ndouyin=stored\u0000 ';
    cookies.onInit();
    expect(cookies.huyaCookie.value, 'huya=stored');
    expect(cookies.douyuCookie.value, 'douyu=stored');
    expect(cookies.douyinCookie.value, 'douyin=stored');

    final douyin = DouyinCookieController();
    final huya = HuyaCookieController();
    final douyu = DouyuCookieController();
    final kuaishou = KuaishouCookieController();
    final soop = SoopCookieBindingCookieController();
    final twitch = TwitchCookieBindingCookieController();
    final yy = YyCookieBindingCookieController();
    addTearDown(() {
      douyin.onClose();
      huya.onClose();
      douyu.onClose();
      kuaishou.onClose();
      soop.onClose();
      twitch.onClose();
      yy.onClose();
    });

    douyin.setCookie(' \r\ndouyin=value\u0000 ');
    huya.setCookie(' \r\nhuya=value\u0000 ');
    douyu.setCookie(' \r\ndouyu=value\u0000 ');
    kuaishou.setCookie(' \r\nkuaishou=value\u0000 ');
    soop.setCookie(' \r\nsoop=value\u0000 ');
    twitch.setCookie(' \r\ntwitch=value\u0000 ');
    yy.setCookie(' \r\nyy=value\u0000 ');

    expect(cookies.douyinCookie.value, 'douyin=value');
    expect(cookies.huyaCookie.value, 'huya=value');
    expect(cookies.douyuCookie.value, 'douyu=value');
    expect(cookies.kuaishouCookie.value, 'kuaishou=value');
    expect(cookies.soopCookie.value, 'soop=value');
    expect(cookies.twitchCookie.value, 'twitch=value');
    expect(cookies.yyCookie.value, 'yy=value');
  });

  test('Douyu session reaches signing, playback and recorder headers consistently', () async {
    cookies.douyuCookie.value = 'acf_auth=fixture-secret; dy_did=old-device';
    final request = DouyuUtils.requestHeaders('123');
    final playback = await PlaybackHeaderResolver.resolve(platform: 'douyu', roomId: '123');
    final recorder = await FFmpegHeaderFactory.build(platform: 'douyu', roomId: '123');
    expect(request['cookie'], contains('acf_auth=fixture-secret'));
    expect(playback['cookie'], request['cookie']);
    expect(recorder['cookie'], request['cookie']);
    expect(request['cookie'], contains('dy_did=${DouyuUtils.deviceId}'));
    expect(request['cookie'], isNot(contains('old-device')));
    expect(CookieSettingsController.parseConfig(cookies.toJson())['douyuCookie'], cookies.douyuCookie.value);
    cookies.clearAllCookies();
    expect(DouyuUtils.requestHeaders('123')['cookie'], isNot(contains('fixture-secret')));
  });

  testWidgets('cookie editor saves normalized input at narrow three-times text scale', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? saved;

    await _pumpEditor(tester, english, controller: controller, onSave: (value) => saved = value);
    await _scrollUntilHitTestable(tester, find.byKey(const ValueKey('account-cookie-input')));
    await tester.enterText(find.byKey(const ValueKey('account-cookie-input')), ' \r\nsession=abc; token=def\r\n ');
    await tester.pump();
    await _scrollUntilHitTestable(tester, find.byKey(const ValueKey('account-cookie-save')));
    await tester.tap(find.byKey(const ValueKey('account-cookie-save')));
    await tester.pumpAndSettle();

    expect(saved, 'session=abc; token=def');
    expect(controller.text, 'session=abc; token=def');
    expect(find.text('Cookie saved on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirty editor confirms back while keeping and discarding remain reachable', (tester) async {
    final controller = TextEditingController(text: 'session=old');
    addTearDown(controller.dispose);

    await _pumpEditor(tester, english, controller: controller, onSave: (_) {}, startFromLauncher: true, textScale: 1);
    await tester.tap(find.byKey(const ValueKey('open-cookie-editor')));
    await tester.pumpAndSettle();
    await _scrollUntilHitTestable(tester, find.byKey(const ValueKey('account-cookie-input')));
    await tester.enterText(find.byKey(const ValueKey('account-cookie-input')), 'session=new');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-cookie-discard-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-cookie-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-cookie-input')), findsOneWidget);
    expect(controller.text, 'session=new');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-cookie-discard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-cookie-input')), findsNothing);
    expect(find.byKey(const ValueKey('open-cookie-editor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('all platform cookie pages use the shared editor without a fixed action height', () async {
    const paths = [
      'lib/modules/account/douyin/douyin_cookie_page.dart',
      'lib/modules/account/huya/huya_cookie_page.dart',
      'lib/modules/account/douyu/douyu_cookie_page.dart',
      'lib/modules/account/kuaishou/kuaishou_cookie_page.dart',
      'lib/modules/account/soop/soop_cookie_page.dart',
      'lib/modules/account/twitch/twitch_cookie_page.dart',
      'lib/modules/account/yy/yy_cookie_page.dart',
    ];

    for (final path in paths) {
      final source = await File(path).readAsString();
      expect(source, contains('AccountCookieEditorPage'), reason: path);
      expect(source, isNot(contains('height: 44')), reason: path);
      expect(source, isNot(contains('onSubmitted:')), reason: path);
    }
  });

  test('cookie editor translations are complete in English and Chinese', () async {
    const keys = [
      'cookie_saved_local',
      'discard_cookie_changes',
      'discard_cookie_changes_detail',
      'keep_editing',
      'discard',
    ];
    for (final locale in ['en', 'zh']) {
      final translations = jsonDecode(await File('assets/translations/$locale.json').readAsString());
      for (final key in keys) {
        expect(translations[key], isA<String>().having((value) => value.trim(), key, isNotEmpty));
      }
    }
  });
}

Future<void> _pumpEditor(
  WidgetTester tester,
  Map<String, dynamic> english, {
  required TextEditingController controller,
  required ValueChanged<String> onSave,
  bool startFromLauncher = false,
  double textScale = 3,
}) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  Widget editor() => AccountCookieEditorPage(
    controller: controller,
    hintText: 'Paste the complete Cookie',
    tipText: 'Sign in to the service and open a live channel, then copy the complete Cookie from a browser developer-tools network request. The Cookie stays on this device.',
    onSave: onSave,
  );

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
          home: startFromLauncher
              ? Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: FilledButton(
                        key: const ValueKey('open-cookie-editor'),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => editor())),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                )
              : editor(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: find.byKey(const ValueKey('account-cookie-scroll')), matching: find.byType(Scrollable)).first,
  );
  for (var attempt = 0; attempt < 100; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final position = scrollable.position;
    final next = (position.pixels + position.viewportDimension * 0.35).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pump();
  }
  fail('Cookie editor control did not become hit-testable after bounded scrolling.');
}

class _Translations extends AssetLoader {
  const _Translations(this.english);

  final Map<String, dynamic> english;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => english;
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._font, this._cookies);

  final FontSettingsController _font;
  final CookieSettingsController _cookies;

  @override
  FontSettingsController get font => _font;

  @override
  CookieSettingsController get cookieManager => _cookies;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
