import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/storage/hive_rx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  late CookieSettingsController cookies;

  setUp(() {
    cookies = CookieSettingsController();
    // 每个实例读写的是同一批 Hive 键，先清干净再摆数据。
    cookies.clearAllCookies();
  });

  group('账号 cookie 配置', () {
    test('斗鱼登出清掉整组凭据，别家不受影响', () {
      cookies.douyuCookie.v = 'dy_auth=abc; acf_did=dev';
      cookies.douyuCookieSavedAt.v = 1791057199;
      cookies.douyuLtp0.v = 'long-term-passport-key';
      cookies.douyuDid.v = 'device-id';
      cookies.huyaCookie.v = 'huya-session';
      cookies.bilibiliCookie.v = 'SESSDATA=xxx';
      cookies.bilibiliUid.v = 12345;

      cookies.clearDouyuSession();

      // 只抹 cookie 的话，passport 的长期续期密钥还会留在本地，也还会跟着
      // 勾选了敏感数据的备份一起导出——"已登出"就名不副实。
      expect(cookies.douyuCookie.v, isEmpty);
      expect(cookies.douyuLtp0.v, isEmpty);
      expect(cookies.douyuDid.v, isEmpty);
      expect(cookies.douyuCookieSavedAt.v, 0);

      expect(cookies.huyaCookie.v, 'huya-session');
      expect(cookies.bilibiliCookie.v, 'SESSDATA=xxx');
      expect(cookies.bilibiliUid.v, 12345);
    });

    test('只剩斗鱼续期凭据时也算"还有账号"，清除入口才可点', () {
      expect(cookies.hasAnyCredential, isFalse);

      // 登出只抹了 cookie、把 ltp0 留下的那种半干净状态：界面上要看得出来
      // 还有凭据没清，否则"清除所有账号"是灰的，用户以为已经干净了。
      cookies.douyuLtp0.v = 'long-term-passport-key';
      expect(cookies.hasAnyCredential, isTrue);

      cookies.clearDouyuSession();
      expect(cookies.hasAnyCredential, isFalse);

      cookies.yyCookie.v = 'yy-session';
      expect(cookies.hasAnyCredential, isTrue);
    });

    test('清空所有账号与斗鱼那组共用一份定义，不漏配套字段', () {
      cookies.bilibiliCookie.v = 'SESSDATA=xxx';
      cookies.bilibiliUid.v = 12345;
      cookies.huyaCookie.v = 'huya-session';
      cookies.douyuCookie.v = 'dy_auth=abc';
      cookies.douyuCookieSavedAt.v = 1791057199;
      cookies.douyuLtp0.v = 'long-term-passport-key';
      cookies.douyuDid.v = 'device-id';
      cookies.douyinCookie.v = 'douyin-session';
      cookies.kuaishouCookie.v = 'kuaishou-session';
      cookies.twitchCookie.v = 'twitch-session';
      cookies.soopCookie.v = 'soop-session';
      cookies.yyCookie.v = 'yy-session';
      cookies.bigoCookie.v = 'bigo-session';

      cookies.clearAllCookies();

      expect(cookies.bilibiliCookie.v, isEmpty);
      expect(cookies.bilibiliUid.v, 0);
      expect(cookies.huyaCookie.v, isEmpty);
      expect(cookies.douyuCookie.v, isEmpty);
      expect(cookies.douyuCookieSavedAt.v, 0);
      expect(cookies.douyuLtp0.v, isEmpty);
      expect(cookies.douyuDid.v, isEmpty);
      expect(cookies.douyinCookie.v, isEmpty);
      expect(cookies.kuaishouCookie.v, isEmpty);
      expect(cookies.twitchCookie.v, isEmpty);
      expect(cookies.soopCookie.v, isEmpty);
      expect(cookies.yyCookie.v, isEmpty);
      expect(cookies.bigoCookie.v, isEmpty);
    });

    test('导出与导入的字段集一致，且值能原样往返', () {
      cookies.bilibiliCookie.v = 'SESSDATA=xxx';
      cookies.bilibiliUid.v = 12345;
      cookies.douyuCookie.v = 'dy_auth=abc';
      cookies.douyuLtp0.v = 'long-term-passport-key';
      cookies.douyuDid.v = 'device-id';
      cookies.douyuCookieSavedAt.v = 1791057199;
      cookies.twitchCookie.v = 'twitch-session';

      final exported = cookies.toJson();
      // 备份的字段清单就是从 parseConfig 推出来的（backup_controller 用它做
      // 分节），两边一旦走偏，就会出现"导出了却恢复不回来"的字段。
      expect(exported.keys.toSet(), CookieSettingsController.extractConfig(null).keys.toSet());

      final parsed = CookieSettingsController.parseConfig(exported);
      expect(parsed['bilibiliCookie'], 'SESSDATA=xxx');
      expect(parsed['bilibiliUid'], 12345);
      expect(parsed['douyuCookie'], 'dy_auth=abc');
      expect(parsed['douyuLtp0'], 'long-term-passport-key');
      expect(parsed['douyuDid'], 'device-id');
      expect(parsed['douyuCookieSavedAt'], 1791057199);
      expect(parsed['twitchCookie'], 'twitch-session');

      final restored = CookieSettingsController()..clearAllCookies();
      restored.fromJson(parsed);
      expect(restored.douyuLtp0.v, 'long-term-passport-key');
      expect(restored.douyuDid.v, 'device-id');
      expect(restored.douyuCookieSavedAt.v, 1791057199);
      expect(restored.bilibiliUid.v, 12345);
    });
  });
}
