import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/site/douyin_site.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';

class AccountController extends GetxController {
  final cookie = SettingsService.to.cookieManager;

  final douyinNickName = ''.obs;
  @override
  onInit() {
    super.onInit();
    Future.delayed(const Duration(milliseconds: 300), () {
      loadDouyinAccount();
    });
  }

  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog(i18n("logout_bilibili_confirm"), title: i18n("logout"));
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      AppNavigator.toBiliBiliLogin();
    }
  }

  Future<void> loadDouyinAccount() async {
    try {
      final cookie = SettingsService.to.cookieManager;
      if (cookie.douyinCookie.value.isNotEmpty) {
        final result = await DouyinSite().getUserInfoByCookie(cookie.douyinCookie.value);
        if (result.isNotEmpty && result['nickname'] != null) {
          douyinNickName.value = result['nickname'];
        }
      }
    } catch (e, stack) {
      Log.e("Load Douyin account failed: $e", stack);
    }
  }
}
