import 'package:pure_live/core/index.dart';

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

  Color get themeColor => SettingsService.to.theme.themeColor;

  void remove(String keyword) {
    final favorites = SettingsService.to.fav;
    favorites.removeShieldList(favorites.shieldList.indexOf(keyword));
  }

  @override
  void onClose() {
    textEditingController.dispose();
    super.onClose();
  }
}
