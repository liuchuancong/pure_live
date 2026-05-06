import 'dart:async';
import 'package:get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';

class BiliBiliAccountService extends GetxController {
  static BiliBiliAccountService get instance => Get.find<BiliBiliAccountService>();
  final SettingsService settingsService = Get.find<SettingsService>();

  var logined = false.obs;

  var cookie = "".obs;
  var uid = 0;
  var name = "未登录".obs;
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
          name.value = info.uname ?? "未登录";
          uid = info.mid ?? 0;
          setSite();
        } else {
          ToastUtil.show("哔哩哔哩登录已失效，请重新登录");
          logout();
        }
      } catch (e) {
        ToastUtil.show("获取哔哩哔哩用户信息失败，可前往账号管理重试");
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
    HivePrefUtil.setString(kBilibiliCookie, '');
    logined.value = false;
    CookieManager cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
  }
}
