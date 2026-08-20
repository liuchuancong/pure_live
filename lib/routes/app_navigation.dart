import 'dart:io';
import 'dart:async';
import 'dart:developer';

import 'package:flutter/scheduler.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

/// APP页面跳转封装
/// * 需要参数的页面都应使用此类
/// * 如不需要参数，可以使用Get.toNamed
class AppNavigator {
  static bool _openingLiveRoom = false;

  /// 跳转至分类详情
  static void toCategoryDetail({required Site site, required LiveArea category}) {
    Get.toNamed(RoutePath.kAreaRooms, arguments: [site, category]);
  }

  /// 跳转至直播间
  static Future<void> toLiveRoomDetail({required LiveRoom liveRoom}) async {
    if (_openingLiveRoom) return;
    final platform = (liveRoom.platform?.trim() ?? '').toLowerCase();
    final roomId = liveRoom.roomId?.trim() ?? '';
    if (platform.isEmpty || roomId.isEmpty || !Sites.isSupported(platform)) {
      ToastUtil.show(i18n('get_room_info_failed_retry'));
      return;
    }
    final normalizedRoom = liveRoom.platform == platform && liveRoom.roomId == roomId
        ? liveRoom
        : liveRoom.copyWith(platform: platform, roomId: roomId);
    _openingLiveRoom = true;
    try {
      final manager = GlobalPlayerService.instance.player;
      if (manager.isAppFloatingActive) {
        if (manager.currentFloatRoom == normalizedRoom) {
          manager.prepareRoomSessionReentry(normalizedRoom);
        } else {
          manager.cancelRoomSessionReentry();
        }
        await manager.closeAppFloating();
      } else {
        manager.cancelRoomSessionReentry();
      }
      await Get.toNamed(RoutePath.kLivePlay, arguments: normalizedRoom, parameters: {"site": platform});
    } finally {
      _openingLiveRoom = false;
    }
  }

  static Future<void> offAndToRoomDetail({required LiveRoom liveRoom}) async {
    final platform = (liveRoom.platform?.trim() ?? '').toLowerCase();
    final roomId = liveRoom.roomId?.trim() ?? '';
    if (platform.isEmpty || roomId.isEmpty || !Sites.isSupported(platform)) {
      ToastUtil.show(i18n('get_room_info_failed_retry'));
      return;
    }
    final normalizedRoom = liveRoom.platform == platform && liveRoom.roomId == roomId
        ? liveRoom
        : liveRoom.copyWith(platform: platform, roomId: roomId);
    await Get.offAndToNamed(RoutePath.kLivePlay, arguments: normalizedRoom, parameters: {"site": platform});
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
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route.settings.name == RoutePath.kLivePlay) {
      try {
        final livePlayController = Get.find<LivePlayController>();
        final state = livePlayController.state.value;

        // 更新房间状态
        livePlayController.updateRoom(success: false);

        final manager = GlobalPlayerService.instance.player;
        if (SettingsService.to.player.floatPlay.v) {
          // Route.completed fires after the reverse transition and overlay
          // entries are removed. A fixed delay raced on high-refresh devices
          // and briefly mounted the room and floating player at the same time.
          final routeUnmounted = route is TransitionRoute<dynamic>
              ? route.completed.then<void>((_) {})
              : SchedulerBinding.instance.endOfFrame;
          livePlayController.prepareAppFloating(routeUnmounted: routeUnmounted);
          unawaited(
            routeUnmounted.then((_) {
              manager.showAppFloating();
            }),
          );
        } else {
          // 清理播放器
          final videoController = state.player.videoController;
          if (videoController != null) {
            videoController.clearListener();
          }

          // The same close path must stop AudioService and the native player.
          // Audio-only previously bypassed LiveAudioService.stop(), leaving a
          // stale background player attached during the next room entry.
          unawaited(manager.close());
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
      final manager = GlobalPlayerService.instance.player;
      unawaited(manager.closeAppFloating());
    }
  }
}
