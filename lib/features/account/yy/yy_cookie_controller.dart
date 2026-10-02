import 'package:pure_live/core/index.dart';
import 'package:pure_live/services/settings/cookie_value.dart';

class YyCookieBindingCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.yyCookie.v;
  }

  void setCookie(String cookie) {
    final normalized = normalizeAccountCookie(cookie);
    cookieController.text = normalized;
    SettingsService.to.cookieManager.yyCookie.v = normalized;
  }

  @override
  void onClose() {
    cookieController.dispose();
    super.onClose();
  }
}
