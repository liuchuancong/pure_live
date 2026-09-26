import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/account/account_controller.dart';
import 'package:pure_live/modules/account/account_page.dart';
import 'package:pure_live/routes/app_pages.dart';
import 'package:pure_live/routes/route_path.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Map<String, dynamic> english;
  late Map<String, dynamic> chinese;
  late CookieSettingsController cookies;
  late _TestBilibiliAccountService bilibili;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-account-navigation-test-');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    english = jsonDecode(await File('assets/translations/en.json').readAsString()) as Map<String, dynamic>;
    chinese = jsonDecode(await File('assets/translations/zh.json').readAsString()) as Map<String, dynamic>;
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await HivePrefUtil.clear();
    cookies = CookieSettingsController();
    Get.put<SettingsService>(_TestSettingsService(cookies));
    bilibili = _TestBilibiliAccountService();
    Get.put<BiliBiliAccountService>(bilibili);
    Get.put<AccountController>(_TestAccountController());
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  test('canonical and legacy Douyin cookie paths are both registered exactly once', () {
    final names = AppPages.routes.map((route) => route.name).toList(growable: false);
    expect(names.where((name) => name == RoutePath.kDouyinCookie), hasLength(1));
    expect(names.where((name) => name == RoutePath.kDouyuCookie), hasLength(1));
    expect(names.where((name) => name == RoutePath.kDouyuAccountCookie), hasLength(1));
  });

  testWidgets('Douyin account row opens the canonical cookie route', (tester) async {
    await _pumpAccountPage(tester, english);
    final douyin = find.text('Douyin');
    await _scrollPageUntilHitTestable(tester, douyin);
    await tester.tap(douyin.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('canonical-douyin-cookie')), findsOneWidget);
    expect(find.byKey(const ValueKey('legacy-douyu-cookie')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configured Bilibili account exposes a visible verification state before identity returns', (
    tester,
  ) async {
    bilibili.logined.value = true;
    bilibili.name.value = '';
    await _pumpAccountPage(tester, english);
    expect(find.text('Verifying account…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'zh']) {
    testWidgets('$locale logged-in confirmation names its account and remains reachable at three-times text', (
      tester,
    ) async {
      final labels = locale == 'en' ? english : chinese;
      cookies.huyaCookie.value = 'fixture-cookie';
      await _pumpAccountPage(tester, labels, locale: locale);
      final huya = find.text(labels['site_huya'] as String);
      await _scrollPageUntilHitTestable(tester, huya);
      await tester.tap(huya.hitTestable());
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text(locale == 'en' ? 'Log out of "Huya"?' : '确定退出“虎牙”账号吗？')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(labels['cancel'] as String)).hitTestable(),
        findsOneWidget,
      );
      expect(
        find
            .descendant(of: dialog, matching: find.widgetWithText(FilledButton, labels['logout'] as String))
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('logout confirmation coalesces repeated account row actions', (tester) async {
    cookies.huyaCookie.value = 'fixture-cookie';
    await _pumpAccountPage(tester, english);
    final huyaTile = find.ancestor(of: find.text('Huya'), matching: find.byType(ListTile));
    final onTap = tester.widget<ListTile>(huyaTile).onTap!;

    onTap();
    onTap();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Log out of "Huya"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(cookies.huyaCookie.value, 'fixture-cookie');

    onTap();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(cookies.huyaCookie.value, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bilibili logout keeps the account transaction busy through browser cleanup', (tester) async {
    final cleanup = Completer<void>();
    var cleanupCalls = 0;
    Get.delete<BiliBiliAccountService>(force: true);
    bilibili = _TestBilibiliAccountService(
      browserCookieClearer: () {
        cleanupCalls++;
        return cleanup.future;
      },
    );
    Get.put<BiliBiliAccountService>(bilibili);
    cookies.bilibiliCookie.value = 'fixture-cookie';
    bilibili.logined.value = true;
    bilibili.name.value = 'Fixture account';
    await _pumpAccountPage(tester, english);
    final tile = find.ancestor(of: find.text('Bilibili'), matching: find.byType(ListTile));
    final staleOnTap = tester.widget<ListTile>(tile).onTap!;

    staleOnTap();
    staleOnTap();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(cleanupCalls, 1);
    expect(cookies.bilibiliCookie.value, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);

    staleOnTap();
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(cleanupCalls, 1);

    cleanup.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Douyu account row opens its distinct editor without reusing the legacy Douyin alias', (tester) async {
    await _pumpAccountPage(tester, english);
    final douyu = find.text('Douyu');
    await _scrollPageUntilHitTestable(tester, douyu);
    await tester.tap(douyu.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('canonical-douyu-cookie')), findsOneWidget);
    expect(find.byKey(const ValueKey('legacy-douyu-cookie')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Douyu saved-session row labels local state and clears it on confirmation', (tester) async {
    // The row follows the session the cookie carries, not its length: a token
    // that is still valid is what "signed in" now means.
    cookies.douyuCookie.value = _douyuSessionCookie();
    await _pumpAccountPage(tester, english);
    final douyu = find.text('Douyu');
    await _scrollPageUntilHitTestable(tester, douyu);
    final tile = find.ancestor(of: douyu, matching: find.byType(ListTile));
    expect(find.descendant(of: tile, matching: find.text('Cookie saved on this device')), findsOneWidget);
    final logout = find.descendant(of: tile, matching: find.byType(IconButton));
    await _scrollPageUntilHitTestable(tester, logout);
    await tester.tap(logout.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(cookies.douyuCookie.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Douyu row asks for a new cookie when the stored one carries no session', (tester) async {
    // A pasted cookie that never held a login (or one whose token expired with
    // nothing to renew it with) is not a signed-in state, and the row says so
    // instead of offering a logout for a session that does not exist.
    cookies.douyuCookie.value = 'dy_did=test-device; acf_uid=42';

    await _pumpAccountPage(tester, english);

    final douyu = find.text('Douyu');
    await _scrollPageUntilHitTestable(tester, douyu);
    final tile = find.ancestor(of: douyu, matching: find.byType(ListTile));

    expect(
      find.descendant(of: tile, matching: find.text(english['douyu_session_needs_cookie'] as String)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Cookie saved on this device')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

/// A Douyu cookie that is a real session: `acf_jwt_token` is a JWT and its
/// `exp` is in the future.
String _douyuSessionCookie({Duration validFor = const Duration(hours: 2)}) {
  final expiresAt = DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(utf8.encode(jsonEncode(<String, int>{'exp': expiresAt}))).replaceAll('=', '');
  return 'dy_did=test-device; LTP0=long-term; acf_jwt_token=header.$payload.signature';
}

Future<void> _pumpAccountPage(WidgetTester tester, Map<String, dynamic> translations, {String locale = 'en'}) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: [Locale(locale)],
      startLocale: Locale(locale),
      fallbackLocale: Locale(locale),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _Translations(translations),
      child: Builder(
        builder: (context) => GetMaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          initialRoute: '/',
          getPages: [
            GetPage(name: '/', page: () => const AccountPage()),
            GetPage(
              name: RoutePath.kDouyinCookie,
              page: () => const Scaffold(key: ValueKey('canonical-douyin-cookie')),
            ),
            GetPage(
              name: RoutePath.kDouyuCookie,
              page: () => const Scaffold(key: ValueKey('legacy-douyu-cookie')),
            ),
            GetPage(
              name: RoutePath.kDouyuAccountCookie,
              page: () => const Scaffold(key: ValueKey('canonical-douyu-cookie')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollPageUntilHitTestable(WidgetTester tester, Finder target) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
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
  fail('Account row did not become hit-testable after bounded page scrolling.');
}

class _Translations extends AssetLoader {
  const _Translations(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => translations;
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._cookies) : _font = FontSettingsController();

  final CookieSettingsController _cookies;
  final FontSettingsController _font;

  @override
  CookieSettingsController get cookieManager => _cookies;

  @override
  FontSettingsController get font => _font;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}

class _TestBilibiliAccountService extends BiliBiliAccountService {
  _TestBilibiliAccountService({super.browserCookieClearer}) : super(initialLoadDelay: const Duration(days: 1));

  @override
  // Avoid timers and account network activity in a route/layout fixture.
  // ignore: must_call_super
  void onInit() {}
}

class _TestAccountController extends AccountController {
  @override
  // Avoid delayed Douyin account network activity in a route/layout fixture.
  // ignore: must_call_super
  void onInit() {}
}
