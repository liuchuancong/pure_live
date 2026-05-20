import 'package:pure_live/common/index.dart';

class DouyinCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();
  final SettingsService settingsService = Get.find<SettingsService>();

  @override
  void onInit() {
    super.onInit();
    cookieController.text = settingsService.douyinCookie.value;
  }

  void setCookie(String cookie) {
    cookieController.text = cookie;
    settingsService.douyinCookie.value = cookie;
  }
}
