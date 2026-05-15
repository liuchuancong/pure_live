import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';

class DanmuShieldController extends BaseController {
  final TextEditingController textEditingController = TextEditingController();
  final SettingsService settingsController = Get.find<SettingsService>();
  void add() {
    if (textEditingController.text.isEmpty) {
      ToastUtil.show(i18n('please_input_keyword'));
      return;
    }

    settingsController.addShieldList(textEditingController.text.trim());
    textEditingController.text = "";
  }

  Color get themeColor => HexColor(settingsController.themeColorSwitch.value);
  void remove(int itemIndex) {
    settingsController.removeShieldList(itemIndex);
  }
}
