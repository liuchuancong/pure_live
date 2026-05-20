import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';

class BiliBiliAccountService extends GetxController {
  static BiliBiliAccountService get instance => Get.find<BiliBiliAccountService>();
  final SettingsService settingsService = Get.find<SettingsService>();

  var logined = false.obs;

  var cookie = "".obs;
  var uid = 0;
  var name = i18n("not_logged_in").obs;
  static const String kBilibiliCookie = "bilibiliCookie";
  @override
  void onInit() {
    cookie.value = HivePrefUtil.getString(kBilibiliCookie) ?? '';
    logined.value = cookie.isNotEmpty;
    loadUserInfo();
    super.onInit();
  }

  Future loadUserInfo() async {
    if (cookie.isEmpty) {
      return;
    }
    Timer(const Duration(seconds: 1), () async {
      try {
        var result = await HttpClient.instance.getJson(
          "https://api.bilibili.com/x/member/web/account",
          header: {"Cookie": cookie},
        );
        if (result["code"] == 0) {
          var info = BiliBiliUserInfoModel.fromJson(result["data"]);
          name.value = info.uname ?? i18n("not_logged_in");
          uid = info.mid ?? 0;
          setSite();
        } else {
          ToastUtil.show(i18n("bilibili_login_expired"));
          logout();
        }
      } catch (e) {
        ToastUtil.show(i18n("bilibili_user_info_failed"));
      }
    });
  }

  void setSite() {
    var site = (Sites.of(Sites.bilibiliSite).liveSite as BiliBiliSite);
    site.userId = uid;
    site.cookie = cookie.value;
  }

  void setCookie(String cookie) {
    this.cookie.value = cookie;
    settingsService.bilibiliCookie.value = cookie;
    logined.value = cookie.isNotEmpty;
  }

  void resetCookie(String cookie) {
    this.cookie.value = cookie;
    logined.value = cookie.isNotEmpty;
  }

  void logout() async {
    cookie.value = "";
    uid = 0;
    name.value = i18n("not_logged_in");
    setSite();
    HivePrefUtil.setString(kBilibiliCookie, '');
    logined.value = false;
    CookieManager cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
  }
}
