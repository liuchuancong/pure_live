import 'dart:io';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:pure_live/common/global/platform_utils.dart';
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

  static Future<void> offAndToRoomDetail({required LiveRoom liveRoom}) async {
    Get.offAndToNamed(RoutePath.kLivePlay, arguments: liveRoom, parameters: {"site": liveRoom.platform!});
  }

  /// 跳转至哔哩哔哩登录
  static Future toBiliBiliLogin() async {
    var contents = [i18n("sms_login"), i18n("qrcode_login")];
    if (Platform.isAndroid || Platform.isIOS) {
      var result = await Utils.showOptionDialog(contents, '', title: i18n("select_login_method"));
      if (result == i18n("sms_login")) {
        await Get.toNamed(RoutePath.kBiliBiliWebLogin);
      } else if (result == i18n("qrcode_login")) {
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
    if (route.settings.name == RoutePath.kLivePlay) {
      try {
        final livePlayController = Get.find<LivePlayController>();
        livePlayController.success.value = false;
        final settings = Get.find<SettingsService>();
        final manager = GlobalPlayerService.instance.playerManager;
        if (settings.floatPlay.value) {
          Future.delayed(Duration(milliseconds: 200), () {
            manager.showAppFloating();
          });
        } else {
          manager.close();
        }
        if (PlatformUtils.isMobile) {
          WindowService().doExitFullScreen();
        }
      } catch (e) {
        log("BackButtonObserver Error: ${e.toString()}");
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == RoutePath.kLivePlay) {
      final manager = GlobalPlayerService.instance.playerManager;
      manager.closeAppFloating();
    }
  }
}
