import 'package:pure_live/common/index.dart';

class SoopCookieBindingCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.soopCookie.v;
  }

  void setCookie(String cookie) {
    cookieController.text = cookie;
    SettingsService.to.cookieManager.soopCookie.v = cookie;
  }
}
