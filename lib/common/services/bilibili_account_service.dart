import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/pref_util.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/sites.dart';

class BiliBiliAccountService extends GetxController {
  static BiliBiliAccountService get instance => Get.find<BiliBiliAccountService>();
  final SettingsService settingsService = Get.find<SettingsService>();

  var logined = false.obs;

  var cookie = "".obs;
  var uid = 0;
  var name = "".obs;
  static const String kBilibiliCookie = "bilibiliCookie";
  @override
  void onInit() {
    cookie.value = PrefUtil.getString(kBilibiliCookie) ?? '';
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
          header: {
            "Cookie": cookie,
          },
        );
        if (result["code"] == 0) {
          var info = BiliBiliUserInfoModel.fromJson(result["data"]);
          name.value = info.uname ?? "";
          uid = info.mid ?? 0;
          setSite();
        } else {
          SmartDialog.showToast("哔哩哔哩登录已失效，请重新登录");
          logout();
        }
      } catch (e) {
        CoreLog.error(e);
        SmartDialog.showToast("获取哔哩哔哩用户信息失败，可前往账号管理重试");
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
    name.value = "未登录";
    setSite();
    PrefUtil.setString(kBilibiliCookie, '');
    logined.value = false;
    CookieManager cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
  }
}
