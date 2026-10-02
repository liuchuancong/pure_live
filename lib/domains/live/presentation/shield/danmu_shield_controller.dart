import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';

class DanmuShieldController extends GetxController {
  final TextEditingController textEditingController = TextEditingController();

  void add() {
    final text = textEditingController.text.trim();
    if (text.isEmpty) {
      ToastUtil.show(i18n('please_input_keyword'));
      return;
    }

    FavoriteRoomController.to.addShieldList(text);
    textEditingController.clear();
  }

  Color get themeColor => SettingsService.to.theme.themeColor;

  void remove(String keyword) {
    final favorites = FavoriteRoomController.to;
    favorites.removeShieldList(favorites.shieldList.indexOf(keyword));
  }

  @override
  void onClose() {
    textEditingController.dispose();
    super.onClose();
  }
}
