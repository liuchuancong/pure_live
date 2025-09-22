import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';

class HuyaCookieController extends GetxController {
  final TextEditingController cookieController = TextEditingController();
  final SettingsService settingsService = Get.find<SettingsService>();

  @override
  void onInit() {
    super.onInit();
    // cookieController.text = settingsService.huyaCookie.value;
  }

  void setCookie(String cookie) {
    cookieController.text = cookie;
    // settingsService.huyaCookie.value = cookie;
  }
}
