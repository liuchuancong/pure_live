import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class AppSettingsController extends GetxController {
  final HiveRxInt autoRefreshTime = HiveRxInt('autoRefreshTime', 3);
  final HiveRxBool enableDenseFavorites = HiveRxBool('enableDenseFavorites', true);
  final HiveRxBool enableBackgroundPlay = HiveRxBool('enableBackgroundPlay', false);
  final HiveRxBool enableRotateScreen = HiveRxBool('enableRotateScreen', false);

  final HiveRxBool enableScreenKeepOn = HiveRxBool('enableScreenKeepOn', true);

  final HiveRxBool enableAutoCheckUpdate = HiveRxBool('enableAutoCheckUpdate', true);
  final HiveRxBool enableFullScreenDefault = HiveRxBool('enableFullScreenDefault', false);
  final HiveRxBool showSplashPage = HiveRxBool('showSplashPage', true);

  late final HiveRx<List<String>> savedMenuIds = HiveRx.stringList(
    'savedMenuIds',
    HomeMenu.values.map((e) => e.id).toList(),
  );

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
