import 'package:pure_live/common/index.dart';

class TwitchCookieBindingCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.twitchCookie.v;
  }

  void setCookie(String cookie) {
    cookieController.text = cookie;
    SettingsService.to.cookieManager.twitchCookie.v = cookie;
  }

  @override
  void onClose() {
    cookieController.dispose();
    super.onClose();
  }
}
