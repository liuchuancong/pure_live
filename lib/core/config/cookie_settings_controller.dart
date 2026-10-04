import 'dart:async';

import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/storage/hive_rx.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/core/network/cookie_sanitizer.dart';

class CookieSettingsController extends GetxController {
  static CookieSettingsController get to => Get.find();

  /// 恢复 Cookie 后的账号联动端口。
  ///
  /// 账号域（BiliBiliAccountService）的具体实现由 App 装配层绑定
  /// （见 InitialServices._bindCorePorts）；Core 的凭据存储因此不认识业务域。
  static void Function()? onRestored;

  final RxString bilibiliCookie = hiveString('bilibiliCookie', '');
  final RxInt bilibiliUid = hiveInt('bilibiliUid', 0);
  final RxString huyaCookie = hiveString('huyaCookie', '');
  final RxString douyuCookie = hiveString('douyuCookie', '');

  /// When the stored Douyu cookie was last obtained or renewed (epoch seconds,
  /// 0 = unknown).
  ///
  /// The web cookie's `dy_auth` is opaque, so its expiry cannot be read from the
  /// string itself — Douyu's seven-day rule lives in the `Set-Cookie` attributes
  /// a browser keeps and a pasted header does not. Remembering when it was saved
  /// is what makes "renew it before it breaks" possible.
  final RxInt douyuCookieSavedAt = hiveInt('douyuCookieSavedAt', 0);

  /// The long-term key and device id from the passport request.
  ///
  /// Douyu's silent renewal needs both, and they are *not* part of the page
  /// cookie — the viewer copies them from `passport.douyu.com` separately, which
  /// is why they are stored next to the cookie instead of inside it.
  final RxString douyuLtp0 = hiveString('douyuLtp0', '');
  final RxString douyuDid = hiveString('douyuDid', '');
  final RxString douyinCookie = hiveString('douyinCookie', '');
  final RxString kuaishouCookie = hiveString('kuaishouCookie', '');
  final RxString twitchCookie = hiveString('twitchCookie', '');
  final RxString soopCookie = hiveString('soopCookie', '');
  final RxString yyCookie = hiveString('yyCookie', '');

  @override
  void onInit() {
    super.onInit();
    _normalizeStoredCookies();
    // Taobao Live was retired in 3.2.8; do not keep its account cookie.
    unawaited(HivePrefUtil.remove('taobaoCookie'));
  }

  void _normalizeStoredCookies() {
    for (final cookie in [
      bilibiliCookie,
      huyaCookie,
      douyuCookie,
      douyinCookie,
      kuaishouCookie,
      twitchCookie,
      soopCookie,
      yyCookie,
    ]) {
      final normalized = normalizeAccountCookie(cookie.v);
      if (normalized != cookie.v) cookie.v = normalized;
    }
  }

  /// 还存不存在任何登录凭据。
  ///
  /// 「清除所有账号」按它决定可不可点：没东西可清的时候给一个能点的破坏性按钮，
  /// 只会让人怀疑自己是不是没登出干净。斗鱼的续期凭据也算——它单独留着就是
  /// 登出没登出的那种状态。
  bool get hasAnyCredential {
    for (final value in <RxString>[
      bilibiliCookie,
      huyaCookie,
      douyuCookie,
      douyuLtp0,
      douyuDid,
      douyinCookie,
      kuaishouCookie,
      twitchCookie,
      soopCookie,
      yyCookie,
    ]) {
      if (value.v.isNotEmpty) return true;
    }
    return false;
  }

  /// 斗鱼这一组是一个会话，不是一个字段。
  ///
  /// `douyuLtp0` 是 passport 的长期续期密钥，`douyuDid` 是它绑定的设备号：
  /// 留着它们，"已登出"就只是把 cookie 抹了——凭据仍在本地，也仍会跟着
  /// 勾选了敏感数据的备份一起导出。续期本身要读到非空 cookie 才会发请求
  /// （见 `DouyuUtils.refreshSession`），所以清掉不影响任何在用的能力；
  /// 重新登录时那一页本来就三个字段一起填。
  void clearDouyuSession() {
    douyuCookie.v = '';
    douyuCookieSavedAt.v = 0;
    douyuLtp0.v = '';
    douyuDid.v = '';
  }

  void clearAllCookies() {
    bilibiliCookie.v = '';
    huyaCookie.v = '';
    douyinCookie.v = '';
    kuaishouCookie.v = '';
    twitchCookie.v = '';
    soopCookie.v = '';
    yyCookie.v = '';
    bilibiliUid.v = 0;
    clearDouyuSession();
  }

  Map<String, dynamic> toJson() {
    return {
      'bilibiliCookie': bilibiliCookie.v,
      'huyaCookie': huyaCookie.v,
      'douyuCookie': douyuCookie.v,
      'douyuCookieSavedAt': douyuCookieSavedAt.v,
      'douyuLtp0': douyuLtp0.v,
      'douyuDid': douyuDid.v,
      'douyinCookie': douyinCookie.v,
      'kuaishouCookie': kuaishouCookie.v,
      'bilibiliUid': bilibiliUid.v,
      'twitchCookie': twitchCookie.v,
      'soopCookie': soopCookie.v,
      'yyCookie': yyCookie.v,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'bilibiliCookie': normalizeAccountCookie((json['bilibiliCookie'] ?? '') as String),
      'huyaCookie': normalizeAccountCookie((json['huyaCookie'] ?? '') as String),
      'douyuCookie': normalizeAccountCookie((json['douyuCookie'] ?? '') as String),
      'douyuCookieSavedAt': (json['douyuCookieSavedAt'] ?? 0) as int,
      'douyuLtp0': normalizeAccountCookie((json['douyuLtp0'] ?? '') as String),
      'douyuDid': normalizeAccountCookie((json['douyuDid'] ?? '') as String),
      'douyinCookie': normalizeAccountCookie((json['douyinCookie'] ?? '') as String),
      'kuaishouCookie': normalizeAccountCookie((json['kuaishouCookie'] ?? '') as String),
      'bilibiliUid': (json['bilibiliUid'] ?? 0) as int,
      'twitchCookie': normalizeAccountCookie((json['twitchCookie'] ?? '') as String),
      'soopCookie': normalizeAccountCookie((json['soopCookie'] ?? '') as String),
      'yyCookie': normalizeAccountCookie((json['yyCookie'] ?? '') as String),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    bilibiliCookie.v = parsed['bilibiliCookie'];
    huyaCookie.v = parsed['huyaCookie'];
    douyuCookie.v = parsed['douyuCookie'];
    douyuCookieSavedAt.v = parsed['douyuCookieSavedAt'];
    douyuLtp0.v = parsed['douyuLtp0'];
    douyuDid.v = parsed['douyuDid'];
    douyinCookie.v = parsed['douyinCookie'];
    kuaishouCookie.v = parsed['kuaishouCookie'];
    bilibiliUid.v = parsed['bilibiliUid'];
    twitchCookie.v = parsed['twitchCookie'];
    soopCookie.v = parsed['soopCookie'];
    yyCookie.v = parsed['yyCookie'];

    onRestored?.call();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final cookie = rootConfig?['cookie'] as Map<String, dynamic>? ?? {};
    return parseConfig(cookie);
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final cookie = Map<String, dynamic>.from(rootConfig['cookie'] ?? {});
    updateFields.forEach((k, v) => cookie[k] = v);
    rootConfig['cookie'] = cookie;
    return rootConfig;
  }
}
