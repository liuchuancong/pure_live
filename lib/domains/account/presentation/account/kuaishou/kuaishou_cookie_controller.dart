import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/config/cookie_sanitizer.dart';

class KuaishouCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.kuaishouCookie.v;
  }

  void setCookie(String cookie) {
    final normalized = normalizeAccountCookie(cookie);
    cookieController.text = normalized;
    SettingsService.to.cookieManager.kuaishouCookie.v = normalized;
  }

  @override
  void onClose() {
    cookieController.dispose();
    super.onClose();
  }
}
