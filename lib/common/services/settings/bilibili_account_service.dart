import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';

class BiliBiliAccountService extends GetxController {
  static BiliBiliAccountService get instance => Get.find<BiliBiliAccountService>();

  final RxBool logined = false.obs;
  final RxString name = ''.obs;
  int uid = 0;

  String get currentCookie => SettingsService.to.cookieManager.bilibiliCookie.v;

  @override
  void onInit() {
    super.onInit();
    Future.delayed(const Duration(seconds: 1), _initAfterDelay);
  }

  /// 延时后执行的初始化逻辑
  void _initAfterDelay() {
    logined.value = currentCookie.isNotEmpty;

    ever<String>(SettingsService.to.cookieManager.bilibiliCookie, (val) {
      logined.value = val.isNotEmpty;
      val.isEmpty ? _clearLocalAccountState() : loadUserInfo();
    });

    if (currentCookie.isNotEmpty) {
      loadUserInfo();
    }
  }

  Future<void> loadUserInfo() async {
    if (currentCookie.isEmpty) return;

    try {
      final result = await HttpClient.instance.getJson(
        "https://api.bilibili.com/x/member/web/account",
        header: {"Cookie": currentCookie},
      );

      if (result == null || result["code"] != 0) {
        ToastUtil.show(i18n("bilibili_login_expired"));
        logout();
        return;
      }

      final info = BiliBiliUserInfoModel.fromJson(result["data"]);
      name.value = info.uname ?? i18n("not_logged_in");
      uid = info.mid ?? 0;
      setSite();
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
    await CookieManager.instance().deleteAllCookies();
  }
}
