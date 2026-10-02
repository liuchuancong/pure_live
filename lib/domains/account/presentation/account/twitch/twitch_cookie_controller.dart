import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/network/cookie_sanitizer.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';

class TwitchCookieBindingCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = CookieSettingsController.to.twitchCookie.v;
  }

  void setCookie(String cookie) {
    final normalized = normalizeAccountCookie(cookie);
    cookieController.text = normalized;
    CookieSettingsController.to.twitchCookie.v = normalized;
  }

  @override
  void onClose() {
    cookieController.dispose();
    super.onClose();
  }
}
