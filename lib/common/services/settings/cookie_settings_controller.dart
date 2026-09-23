import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';
import 'package:pure_live/common/services/settings/cookie_value.dart';

class CookieSettingsController extends GetxController {
  final RxString bilibiliCookie = hiveString('bilibiliCookie', '');
  final RxInt bilibiliUid = hiveInt('bilibiliUid', 0);
  final RxString huyaCookie = hiveString('huyaCookie', '');
  final RxString douyuCookie = hiveString('douyuCookie', '');
  final RxString douyinCookie = hiveString('douyinCookie', '');
  final RxString kuaishouCookie = hiveString('kuaishouCookie', '');
  final RxString twitchCookie = hiveString('twitchCookie', '');
  final RxString soopCookie = hiveString('soopCookie', '');
  final RxString yyCookie = hiveString('yyCookie', '');
  final RxString taobaoCookie = hiveString('taobaoCookie', '');

  @override
  void onInit() {
    super.onInit();
    _normalizeStoredCookies();
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
      taobaoCookie,
    ]) {
      final normalized = normalizeAccountCookie(cookie.v);
      if (normalized != cookie.v) cookie.v = normalized;
    }
  }

  void clearAllCookies() {
    bilibiliCookie.v = '';
    huyaCookie.v = '';
    douyuCookie.v = '';
    douyinCookie.v = '';
    kuaishouCookie.v = '';
    twitchCookie.v = '';
    soopCookie.v = '';
    yyCookie.v = '';
    taobaoCookie.v = '';
    bilibiliUid.v = 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'bilibiliCookie': bilibiliCookie.v,
      'huyaCookie': huyaCookie.v,
      'douyuCookie': douyuCookie.v,
      'douyinCookie': douyinCookie.v,
      'kuaishouCookie': kuaishouCookie.v,
      'bilibiliUid': bilibiliUid.v,
      'twitchCookie': twitchCookie.v,
      'soopCookie': soopCookie.v,
      'yyCookie': yyCookie.v,
      'taobaoCookie': taobaoCookie.v,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'bilibiliCookie': normalizeAccountCookie((json['bilibiliCookie'] ?? '') as String),
      'huyaCookie': normalizeAccountCookie((json['huyaCookie'] ?? '') as String),
      'douyuCookie': normalizeAccountCookie((json['douyuCookie'] ?? '') as String),
      'douyinCookie': normalizeAccountCookie((json['douyinCookie'] ?? '') as String),
      'kuaishouCookie': normalizeAccountCookie((json['kuaishouCookie'] ?? '') as String),
      'bilibiliUid': (json['bilibiliUid'] ?? 0) as int,
      'twitchCookie': normalizeAccountCookie((json['twitchCookie'] ?? '') as String),
      'soopCookie': normalizeAccountCookie((json['soopCookie'] ?? '') as String),
      'yyCookie': normalizeAccountCookie((json['yyCookie'] ?? '') as String),
      'taobaoCookie': normalizeAccountCookie((json['taobaoCookie'] ?? '') as String),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    bilibiliCookie.v = parsed['bilibiliCookie'];
    huyaCookie.v = parsed['huyaCookie'];
    douyuCookie.v = parsed['douyuCookie'];
    douyinCookie.v = parsed['douyinCookie'];
    kuaishouCookie.v = parsed['kuaishouCookie'];
    bilibiliUid.v = parsed['bilibiliUid'];
    twitchCookie.v = parsed['twitchCookie'];
    soopCookie.v = parsed['soopCookie'];
    yyCookie.v = parsed['yyCookie'];
    taobaoCookie.v = parsed['taobaoCookie'];

    BiliBiliAccountService.instance.setCookie(bilibiliCookie.v);
    BiliBiliAccountService.instance.loadUserInfo();
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
