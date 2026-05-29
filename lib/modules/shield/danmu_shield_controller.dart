import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/base/base_controller.dart';

class DanmuShieldController extends BaseController {
  final TextEditingController textEditingController = TextEditingController();

  void add() {
    final text = textEditingController.text.trim();
    if (text.isEmpty) {
      ToastUtil.show(i18n('please_input_keyword'));
      return;
    }

    SettingsService.to.fav.addShieldList(text);
    textEditingController.clear();
  }

  Color get themeColor => HexColor(SettingsService.to.theme.themeColorSwitch.v);

  void remove(int itemIndex) {
    SettingsService.to.fav.removeShieldList(itemIndex);
  }
}
