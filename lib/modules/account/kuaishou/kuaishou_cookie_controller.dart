import 'package:pure_live/common/index.dart';

class KuaishouCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = SettingsService.to.cookieManager.kuaishouCookie.v;
  }

  void setCookie(String cookie) {
    cookieController.text = cookie;
    SettingsService.to.cookieManager.kuaishouCookie.v = cookie;
  }
}
