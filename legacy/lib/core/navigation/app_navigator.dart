import 'dart:io';
import 'dart:async';
import 'dart:developer';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/widgets/app_prompt_dialogs.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/core/navigation/official_category_policy.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';

class AppNavigator {
  static bool _openingLiveRoom = false;
  static bool _openingOfficialCategory = false;

  static Future<void> toCategoryDetail({required Site site, required LiveArea category}) async {
    if (OfficialCategoryPolicy.isOfficial(category)) {
      if (_openingOfficialCategory) return;
      final uri = site.id == Sites.ccSite ? OfficialCategoryPolicy.uriFor(category) : null;
      if (uri == null) {
        ToastUtil.show(i18n('external_browser_not_opened'));
        return;
      }
      _openingOfficialCategory = true;
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          ToastUtil.show(i18n('external_browser_not_opened'));
        }
      } catch (_) {
        ToastUtil.show(i18n('external_browser_not_opened'));
      } finally {
        _openingOfficialCategory = false;
      }
      return;
    }
    Get.toNamed(RoutePath.kAreaRooms, arguments: [site, category]);
  }

  static Future<void> toLiveRoomDetail({required LiveRoom liveRoom}) async {
    if (_openingLiveRoom) return;
    final platform = (liveRoom.platform?.trim() ?? '').toLowerCase();
    final roomId = liveRoom.roomId?.trim() ?? '';
    if (platform.isEmpty || roomId.isEmpty || !Sites.isSupported(platform)) {
      ToastUtil.show(i18n(Sites.isRetired(platform) ? 'platform_retired' : 'get_room_info_failed_retry'));
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
    } catch (error, stackTrace) {
      log('Open live room route failed', name: 'AppNavigator', error: error, stackTrace: stackTrace);
      ToastUtil.show(i18n('get_room_info_failed_retry'));
    } finally {
      _openingLiveRoom = false;
    }
  }

  static Future<void> offAndToRoomDetail({required LiveRoom liveRoom}) async {
    final platform = (liveRoom.platform?.trim() ?? '').toLowerCase();
    final roomId = liveRoom.roomId?.trim() ?? '';
    if (platform.isEmpty || roomId.isEmpty || !Sites.isSupported(platform)) {
      ToastUtil.show(i18n(Sites.isRetired(platform) ? 'platform_retired' : 'get_room_info_failed_retry'));
      return;
    }
    final normalizedRoom = liveRoom.platform == platform && liveRoom.roomId == roomId
        ? liveRoom
        : liveRoom.copyWith(platform: platform, roomId: roomId);
    await Get.offAndToNamed(RoutePath.kLivePlay, arguments: normalizedRoom, parameters: {"site": platform});
  }

  static Future<void> toMultiview() async {
    await Get.toNamed(RoutePath.kMultiview);
  }

  static Future toBiliBiliLogin() async {
    var contents = [i18n("sms_login"), i18n("qrcode_login")];
    if (Platform.isAndroid || Platform.isIOS) {
      var result = await AppPromptDialogs.showOptionDialog(contents, '', title: i18n("select_login_method"));
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
