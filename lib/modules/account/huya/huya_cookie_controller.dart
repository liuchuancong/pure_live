import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/cookie_validator.dart';

class HuyaCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.huyaCookie.v;
  }

  /// 保存后自动校验有效性并通知；校验通过（或平台不支持校验）时返回上一级。
  Future<void> setCookie(String cookie) async {
    cookieController.text = cookie;
    SettingsService.to.cookieManager.huyaCookie.v = cookie;

    final result = await CookieValidator.validate('huya', cookie);
    switch (result) {
      case CookieValidationStatus.valid:
        SnackBarUtil.success(i18n('cookie_valid'));
        Get.back();
      case CookieValidationStatus.invalid:
        SnackBarUtil.error(i18n('cookie_invalid'));
      case CookieValidationStatus.error:
        SnackBarUtil.error(i18n('cookie_check_failed'));
      case CookieValidationStatus.unverified:
        SnackBarUtil.success(i18n('cookie_saved'));
        Get.back();
    }
  }

  @override
  void onClose() {
    cookieController.dispose();
    super.onClose();
  }
}
