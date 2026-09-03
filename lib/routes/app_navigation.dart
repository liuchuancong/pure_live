import 'dart:io';
import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';

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
      await Get.toNamed(
        RoutePath.kLivePlay,
        arguments: normalizedRoom,
        parameters: {'site': platform},
      );
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
    await Get.offAndToNamed(
      RoutePath.kLivePlay,
      arguments: normalizedRoom,
      parameters: {'site': platform},
    );
  }

  /// 跳转至多画面同看页面。
  ///
  /// 房间分配由页面内交互完成，无需携带参数。
  static Future<void> toMultiview() async {
    await Get.toNamed(RoutePath.kMultiview);
  }

  /// 跳转至哔哩哔哩登录
  static Future toBiliBiliLogin() async {
    var contents = [i18n('sms_login'), i18n('qrcode_login')];
    if (Platform.isAndroid || Platform.isIOS) {
      var result = await Utils.showOptionDialog(contents, '', title: i18n('select_login_method'));
      if (result == i18n('sms_login')) {
        await Get.toNamed(RoutePath.kBiliBiliWebLogin);
      } else if (result == i18n('qrcode_login')) {
        await Get.toNamed(RoutePath.kBiliBiliQRLogin);
      }
    } else {
      await Get.toNamed(RoutePath.kBiliBiliQRLogin);
    }
  }
}
