import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/models/bilibili_user_info_page.dart';

class BiliBiliAccountService extends GetxController {
  static BiliBiliAccountService get instance => Get.find<BiliBiliAccountService>();

  final RxBool logined = false.obs;
  final RxString name = ''.obs;

  String get currentCookie => SettingsService.to.cookieManager.bilibiliCookie.v;

  @override
  void onInit() {
    super.onInit();
    Future.delayed(const Duration(seconds: 1), _initAfterDelay);
  }

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
      SettingsService.to.cookieManager.bilibiliUid.value = info.mid ?? 0;
    } catch (_) {
      ToastUtil.show(i18n("bilibili_user_info_failed"));
    }
  }

  void setCookie(String cookie) {
    SettingsService.to.cookieManager.bilibiliCookie.value = cookie;
  }

  void _clearLocalAccountState() {
    name.value = i18n("not_logged_in");
    SettingsService.to.cookieManager.bilibiliUid.value = 0;
  }

  void logout() async {
    SettingsService.to.cookieManager.bilibiliCookie.value = "";
    SettingsService.to.cookieManager.bilibiliUid.value = 0;
    await CookieManager.instance().deleteAllCookies();
  }
}
