import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/account/account_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late CookieSettingsController cookies;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-account-identity-test-');
    SharedPreferences.setMockInitialValues({});
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    cookies = CookieSettingsController();
    Get.put<SettingsService>(_TestSettingsService(cookies));
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    await hiveDirectory.delete(recursive: true);
  });

  test('Bilibili identity is immediate and an older invalid response cannot clear a newer account', () async {
    cookies.bilibiliCookie.value = 'old-cookie';
    final oldResult = Completer<Map<String, dynamic>?>();
    final newResult = Completer<Map<String, dynamic>?>();
    final calls = <String>[];
    final notices = <String>[];
    var browserClearCount = 0;
    final service = BiliBiliAccountService(
      accountLoader: (cookie) {
        calls.add(cookie);
        return cookie == 'old-cookie' ? oldResult.future : newResult.future;
      },
      browserCookieClearer: () async => browserClearCount++,
      notice: notices.add,
      initialLoadDelay: Duration.zero,
    );
    Get.put<BiliBiliAccountService>(service);

    expect(service.logined.value, isTrue);
    await _flushAsync();
    expect(calls, ['old-cookie']);

    service.setCookie(' \r\nnew-cookie\u0000 ');
    final currentLoad = service.loadUserInfo();
    expect(cookies.bilibiliCookie.value, 'new-cookie');
    expect(calls, ['old-cookie', 'new-cookie']);

    newResult.complete({
      'code': 0,
      'data': {'mid': 42, 'uname': 'New account'},
    });
    expect(await currentLoad, isTrue);
    expect(service.name.value, 'New account');
    expect(cookies.bilibiliUid.value, 42);

    oldResult.complete({'code': -101, 'message': 'expired'});
    await _flushAsync();
    expect(cookies.bilibiliCookie.value, 'new-cookie');
    expect(service.name.value, 'New account');
    expect(service.logined.value, isTrue);
    expect(browserClearCount, 0);
    expect(notices, isEmpty);
  });

  test('Bilibili logout invalidates an active lookup and coalesces browser cleanup', () async {
    cookies.bilibiliCookie.value = 'session-cookie';
    cookies.bilibiliUid.value = 7;
    final response = Completer<Map<String, dynamic>?>();
    var browserClearCount = 0;
    final service = BiliBiliAccountService(
      accountLoader: (_) => response.future,
      browserCookieClearer: () async => browserClearCount++,
      notice: (_) {},
      initialLoadDelay: const Duration(days: 1),
    );
    Get.put<BiliBiliAccountService>(service);

    final activeLoad = service.loadUserInfo();
    await Future.wait([service.logout(), service.logout()]);
    expect(cookies.bilibiliCookie.value, isEmpty);
    expect(cookies.bilibiliUid.value, 0);
    expect(service.logined.value, isFalse);
    expect(service.name.value, isEmpty);
    expect(browserClearCount, 1);

    response.complete({
      'code': 0,
      'data': {'mid': 99, 'uname': 'Late account'},
    });
    expect(await activeLoad, isFalse);
    expect(cookies.bilibiliUid.value, 0);
    expect(service.name.value, isEmpty);
  });

  test('current invalid Bilibili session clears local and browser identity once', () async {
    cookies.bilibiliCookie.value = 'expired-cookie';
    cookies.bilibiliUid.value = 8;
    final notices = <String>[];
    var browserClearCount = 0;
    final service = BiliBiliAccountService(
      accountLoader: (_) async => {'code': -101, 'message': 'expired'},
      browserCookieClearer: () async => browserClearCount++,
      notice: notices.add,
      initialLoadDelay: const Duration(days: 1),
    );
    Get.put<BiliBiliAccountService>(service);

    expect(await service.loadUserInfo(), isFalse);
    expect(cookies.bilibiliCookie.value, isEmpty);
    expect(cookies.bilibiliUid.value, 0);
    expect(service.logined.value, isFalse);
    expect(browserClearCount, 1);
    expect(notices, ['bilibili_login_expired']);
  });

  test('Bilibili logout keeps the local account cleared when browser cleanup fails', () async {
    cookies.bilibiliCookie.value = 'session-cookie';
    cookies.bilibiliUid.value = 8;
    final notices = <String>[];
    final service = BiliBiliAccountService(
      accountLoader: (_) async => null,
      browserCookieClearer: () async => throw StateError('fixture cleanup failure'),
      notice: notices.add,
      initialLoadDelay: const Duration(days: 1),
    );
    Get.put<BiliBiliAccountService>(service);

    await service.logout();
    expect(cookies.bilibiliCookie.value, isEmpty);
    expect(cookies.bilibiliUid.value, 0);
    expect(service.logined.value, isFalse);
    expect(service.name.value, isEmpty);
    expect(notices, ['bilibili_logout_cleanup_failed']);
  });

  test('Douyin nickname follows the latest cookie and clears on logout', () async {
    cookies.douyinCookie.value = 'old-cookie';
    final oldResult = Completer<Map<String, dynamic>>();
    final newResult = Completer<Map<String, dynamic>>();
    final calls = <String>[];
    final controller = AccountController(
      douyinAccountLoader: (cookie) {
        calls.add(cookie);
        return cookie == 'old-cookie' ? oldResult.future : newResult.future;
      },
      initialLoadDelay: Duration.zero,
    );
    Get.put<AccountController>(controller);

    await _flushAsync();
    expect(calls, ['old-cookie']);
    cookies.douyinCookie.value = 'new-cookie';
    final currentLoad = controller.loadDouyinAccount();
    expect(calls, ['old-cookie', 'new-cookie']);

    newResult.complete({'nickname': 'New nickname'});
    await currentLoad;
    expect(controller.douyinNickName.value, 'New nickname');
    oldResult.complete({'nickname': 'Old nickname'});
    await _flushAsync();
    expect(controller.douyinNickName.value, 'New nickname');

    cookies.douyinCookie.value = '';
    await _flushAsync();
    expect(controller.douyinNickName.value, isEmpty);
  });

  test('closed account controller ignores a late Douyin identity response', () async {
    cookies.douyinCookie.value = 'session-cookie';
    final result = Completer<Map<String, dynamic>>();
    final controller = AccountController(douyinAccountLoader: (_) => result.future, initialLoadDelay: Duration.zero);
    Get.put<AccountController>(controller);
    await _flushAsync();

    Get.delete<AccountController>();
    result.complete({'nickname': 'Late nickname'});
    await _flushAsync();
    expect(controller.douyinNickName.value, isEmpty);
  });

  test('account logout transaction coalesces all work until completion and then releases', () async {
    final controller = AccountController(initialLoadDelay: const Duration(days: 1));
    Get.put<AccountController>(controller);
    final release = Completer<void>();
    var calls = 0;

    final first = controller.runLogoutTransaction(() {
      calls++;
      return release.future;
    });
    final repeated = controller.runLogoutTransaction(() async => calls++);

    expect(identical(first, repeated), isTrue);
    expect(calls, 1);
    release.complete();
    await Future.wait([first, repeated]);

    await controller.runLogoutTransaction(() async => calls++);
    expect(calls, 2);
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _TestSettingsService extends SettingsService {
  _TestSettingsService(this._cookies);

  final CookieSettingsController _cookies;

  @override
  CookieSettingsController get cookieManager => _cookies;

  @override
  // Test fixture intentionally skips production controller registrations.
  // ignore: must_call_super
  void onInit() {}
}
