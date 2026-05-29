import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class CookieSettingsController extends GetxController {
  final bilibiliCookie = HiveRx.string('bilibiliCookie', '');

  final huyaCookie = HiveRx.string('huyaCookie', '');

  final douyinCookie = HiveRx.string('douyinCookie', '');

  final kuaishouCookie = HiveRx.string('kuaishouCookie', '');

  void clearAllCookies() {
    bilibiliCookie.v = '';
    huyaCookie.v = '';
    douyinCookie.v = '';
    kuaishouCookie.v = '';
  }
}
