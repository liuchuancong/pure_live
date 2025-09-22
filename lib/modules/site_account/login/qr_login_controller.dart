import 'dart:async';

import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';

class SiteQRLoginController extends GetxController {
  final Site site;

  @override
  void onInit() {
    loadQRCode();
    super.onInit();
  }

  Timer? timer;

  var qrcodeUrl = "".obs;
  var qrcodeKey = "";

  /// 二维码状态
  /// - [0] 加载中
  /// - [1] 未扫描
  /// - [2] 已扫描，待确认
  /// - [3] 二维码已经失效
  /// - [4] 登录失败
  Rx<QRStatus> qrStatus = QRStatus.loading.obs;

  SiteQRLoginController({required this.site});

  void loadQRCode() async {
    try {
      var qrBean = await site.liveSite.loadQRCode();

      qrStatus.value = qrBean.qrStatus;
      qrcodeUrl.value = qrBean.qrcodeUrl;
      qrcodeKey = qrBean.qrcodeKey;
      startPoll();
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
      qrStatus.value = QRStatus.failed;
    }
  }

  void startPoll() {
    timer = timer ?? Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        pollQRStatus();
      },
    );
  }

  void pollQRStatus() async {
    try {
      try {
        var qrBean = QRBean()
        ..qrcodeUrl=qrcodeUrl.value
        ..qrcodeKey=qrcodeKey
        ..qrStatus=qrStatus.value
        ;
        qrBean = await site.liveSite.pollQRStatus(site, qrBean);

        qrStatus.value = qrBean.qrStatus;
        qrcodeUrl.value = qrBean.qrcodeUrl;
        qrcodeKey = qrBean.qrcodeKey;
        switch(qrStatus.value) {
          case QRStatus.expired:
            timer?.cancel();
            timer = null;
          break;
          case QRStatus.success:
            Navigator.of(Get.context!).pop(true);
            break;
          default:
            break;
        }
      } catch (e) {
        CoreLog.error(e);
        SmartDialog.showToast(e.toString());
        qrStatus.value = QRStatus.failed;
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast(e.toString());
    }
  }

  @override
  void onClose() {
    timer?.cancel();
    super.onClose();
  }
}
