import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';

class BiliBiliAccountService extends GetxController {
  static BiliBiliAccountService get instance => Get.find<BiliBiliAccountService>();

  final logined = false.obs;
  final name = i18n("not_logged_in").obs;
  int uid = 0;

  String get currentCookie => SettingsService.to.cookieManager.bilibiliCookie.v;

  @override
  void onInit() {
    super.onInit();
    logined.value = currentCookie.isNotEmpty;
    ever(SettingsService.to.cookieManager.bilibiliCookie, (v) {
      final val = v.toString();
      logined.value = val.isNotEmpty;
      if (val.isEmpty) {
        _clearLocalAccountState();
      } else {
        loadUserInfo();
      }
    });
    loadUserInfo();
  }

  Future<void> loadUserInfo() async {
    if (currentCookie.isEmpty) return;

    await Future.delayed(const Duration(seconds: 1));
    if (currentCookie.isEmpty) return;

    try {
      final result = await HttpClient.instance.getJson("https://bilibili.com", header: {"Cookie": currentCookie});
      if (result["code"] == 0) {
        final info = BiliBiliUserInfoModel.fromJson(result["data"]);
        name.value = info.uname ?? i18n("not_logged_in");
        uid = info.mid ?? 0;
        setSite();
      } else {
        ToastUtil.show(i18n("bilibili_login_expired"));
        logout();
      }
    } catch (_) {
      ToastUtil.show(i18n("bilibili_user_info_failed"));
    }
  }

  void setSite() {
    BiliBiliSite.userId = uid;
    BiliBiliSite.cookie = currentCookie;
  }

  void setCookie(String cookie) {
    SettingsService.to.cookieManager.bilibiliCookie.v = cookie;
  }

  void _clearLocalAccountState() {
    uid = 0;
    name.value = i18n("not_logged_in");
    setSite();
  }

  void logout() async {
    SettingsService.to.cookieManager.bilibiliCookie.v = "";
    final cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
  }
}
