import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class AppSettingsController extends GetxController {
  final autoRefreshTime = HiveRx.int('autoRefreshTime', 3);
  final enableDenseFavorites = HiveRx.bool('enableDenseFavorites', true);
  final enableBackgroundPlay = HiveRx.bool('enableBackgroundPlay', false);
  final enableRotateScreen = HiveRx.bool('enableRotateScreen', false);

  final enableScreenKeepOn = HiveRx.bool('enableScreenKeepOn', true);

  final enableAutoCheckUpdate = HiveRx.bool('enableAutoCheckUpdate', true);
  final enableFullScreenDefault = HiveRx.bool('enableFullScreenDefault', false);
  final showSplashPage = HiveRx.bool('showSplashPage', true);

  late final savedMenuIds = HiveRx.stringList('savedMenuIds', HomeMenu.values.map((e) => e.id).toList());

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
