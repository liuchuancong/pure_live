import 'package:pure_live/common/index.dart';

class KuaishouCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();
  final SettingsService settingsService = Get.find<SettingsService>();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = settingsService.kuaishouCookie.value;
  }

  void setCookie(String cookie) {
    cookieController.text = cookie;
    settingsService.kuaishouCookie.value = cookie;
  }
}
