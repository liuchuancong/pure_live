import 'dart:io';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/player/fullscreen.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/switchable_global_player.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

/// APP页面跳转封装
/// * 需要参数的页面都应使用此类
/// * 如不需要参数，可以使用Get.toNamed
class AppNavigator {
  /// 跳转至分类详情
  static void toCategoryDetail({required Site site, required LiveArea category}) {
    Get.toNamed(RoutePath.kAreaRooms, arguments: [site, category]);
  }

  /// 跳转至直播间
  static Future<void> toLiveRoomDetail({required LiveRoom liveRoom}) async {
    Get.toNamed(RoutePath.kLivePlay, arguments: liveRoom, parameters: {"site": liveRoom.platform!});
  }

  /// 跳转至哔哩哔哩登录
  static Future toBiliBiliLogin() async {
    var contents = ['短信登陆', '二维码登陆'];
    if (Platform.isAndroid || Platform.isIOS) {
      var result = await Utils.showOptionDialog(contents, '', title: '请选择登陆方式');
      if (result == '短信登陆') {
        await Get.toNamed(RoutePath.kBiliBiliWebLogin);
      } else if (result == '二维码登陆') {
        await Get.toNamed(RoutePath.kBiliBiliQRLogin);
      }
    } else {
      await Get.toNamed(RoutePath.kBiliBiliQRLogin);
    }
  }
}

class BackButtonObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // 处理路由弹出事件
    if (route.settings.name == RoutePath.kLivePlay) {
      try {
        SwitchableGlobalPlayer().stop();
        Get.find<LivePlayController>().success.value = false;
        if (PlatformUtils.isMobile) {
          WindowService().doExitFullScreen();
        }
        Get.find<LivePlayController>().onDelete();
      } catch (e) {
        log(e.toString());
      }
    }
  }
}
