import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';

class CookieSettingsController extends GetxController {
  final RxString bilibiliCookie = hiveString('bilibiliCookie', '');
  final RxInt bilibiliUid = hiveInt('bilibiliUid', 0);
  final RxString huyaCookie = hiveString('huyaCookie', '');
  final RxString douyinCookie = hiveString('douyinCookie', '');
  final RxString kuaishouCookie = hiveString('kuaishouCookie', '');

  void clearAllCookies() {
    bilibiliCookie.v = '';
    huyaCookie.v = '';
    douyinCookie.v = '';
    kuaishouCookie.v = '';
  }

  Map<String, dynamic> toJson() {
    return {
      'bilibiliCookie': bilibiliCookie.v,
      'huyaCookie': huyaCookie.v,
      'douyinCookie': douyinCookie.v,
      'kuaishouCookie': kuaishouCookie.v,
      'bilibiliUid': bilibiliUid.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    bilibiliCookie.v = json['bilibiliCookie'] ?? '';
    huyaCookie.v = json['huyaCookie'] ?? '';
    douyinCookie.v = json['douyinCookie'] ?? '';
    kuaishouCookie.v = json['kuaishouCookie'] ?? '';
    bilibiliUid.v = json['bilibiliUid'] ?? 0;
    BiliBiliAccountService.instance.setCookie(bilibiliCookie.v);
    BiliBiliAccountService.instance.loadUserInfo();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final cookie = rootConfig?['cookie'] as Map<String, dynamic>? ?? {};
    return {
      'bilibiliCookie': cookie['bilibiliCookie'] ?? '',
      'huyaCookie': cookie['huyaCookie'] ?? '',
      'douyinCookie': cookie['douyinCookie'] ?? '',
      'kuaishouCookie': cookie['kuaishouCookie'] ?? '',
      'bilibiliUid': cookie['bilibiliUid'] ?? 0,
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final cookie = Map<String, dynamic>.from(rootConfig['cookie'] ?? {});
    updateFields.forEach((k, v) => cookie[k] = v);
    rootConfig['cookie'] = cookie;
    return rootConfig;
  }
}
