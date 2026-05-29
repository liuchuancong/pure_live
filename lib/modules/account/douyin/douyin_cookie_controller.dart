import 'package:pure_live/common/index.dart';

class DouyinCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.douyinCookie.v;
  }

  void setCookie(String cookie) {
    cookieController.text = cookie;
    SettingsService.to.cookieManager.douyinCookie.v = cookie;
  }
}
