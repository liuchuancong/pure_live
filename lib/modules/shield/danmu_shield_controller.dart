import 'package:pure_live/common/index.dart';

class DanmuShieldController extends GetxController {
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
