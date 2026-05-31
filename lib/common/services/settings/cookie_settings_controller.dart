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
}
