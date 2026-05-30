import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class CookieSettingsController extends GetxController {
  final HiveRx<String> bilibiliCookie = HiveRx.string('bilibiliCookie', '');
  final HiveRx<String> huyaCookie = HiveRx.string('huyaCookie', '');
  final HiveRx<String> douyinCookie = HiveRx.string('douyinCookie', '');
  final HiveRx<String> kuaishouCookie = HiveRx.string('kuaishouCookie', '');

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
    };
  }

  void fromJson(Map<String, dynamic> json) {
    bilibiliCookie.v = json['bilibiliCookie'] ?? '';
    huyaCookie.v = json['huyaCookie'] ?? '';
    douyinCookie.v = json['douyinCookie'] ?? '';
    kuaishouCookie.v = json['kuaishouCookie'] ?? '';
  }
}
