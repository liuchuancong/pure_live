import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';

class AppSettingsController extends GetxController {
  final RxInt autoRefreshTime = hiveInt('autoRefreshTime', 3);
  final RxBool enableDenseFavorites = hiveBool('enableDenseFavorites', true);
  final RxBool enableBackgroundPlay = hiveBool('enableBackgroundPlay', false);
  final RxBool enableRotateScreen = hiveBool('enableRotateScreen', false);

  final RxBool enableScreenKeepOn = hiveBool('enableScreenKeepOn', true);

  final RxBool enableAutoCheckUpdate = hiveBool('enableAutoCheckUpdate', true);
  final RxBool enableFullScreenDefault = hiveBool('enableFullScreenDefault', false);
  final RxBool showSplashPage = hiveBool('showSplashPage', true);

  late final RxList<String> savedMenuIds = hiveStringList('savedMenuIds', HomeMenu.values.map((e) => e.id).toList());

  void toggleMenuVisibility(HomeMenu menu, bool visible) {
    final ids = List<String>.from(savedMenuIds.v);
    if (visible) {
      if (!ids.contains(menu.id)) ids.add(menu.id);
    } else {
      ids.removeWhere((id) => id == menu.id);
    }
    savedMenuIds.v = ids;
  }

  // ======================
  // 备份/恢复
  // ======================
  Map<String, dynamic> toJson() {
    return {
      'autoRefreshTime': autoRefreshTime.v,
      'enableDenseFavorites': enableDenseFavorites.v,
      'enableBackgroundPlay': enableBackgroundPlay.v,
      'enableRotateScreen': enableRotateScreen.v,
      'enableScreenKeepOn': enableScreenKeepOn.v,
      'enableAutoCheckUpdate': enableAutoCheckUpdate.v,
      'enableFullScreenDefault': enableFullScreenDefault.v,
      'showSplashPage': showSplashPage.v,
      'savedMenuIds': savedMenuIds.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    autoRefreshTime.v = json['autoRefreshTime'] ?? 3;
    enableDenseFavorites.v = json['enableDenseFavorites'] ?? true;
    enableBackgroundPlay.v = json['enableBackgroundPlay'] ?? false;
    enableRotateScreen.v = json['enableRotateScreen'] ?? false;
    enableScreenKeepOn.v = json['enableScreenKeepOn'] ?? true;
    enableAutoCheckUpdate.v = json['enableAutoCheckUpdate'] ?? true;
    enableFullScreenDefault.v = json['enableFullScreenDefault'] ?? false;
    showSplashPage.v = json['showSplashPage'] ?? true;
    savedMenuIds.v = List<String>.from(json['savedMenuIds'] ?? HomeMenu.values.map((e) => e.id).toList());
  }
}
