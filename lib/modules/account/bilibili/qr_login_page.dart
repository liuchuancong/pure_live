import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/modules/account/bilibili/qr_login_controller.dart';

class BiliBiliQRLoginPage extends GetView<BiliBiliQRLoginController> {
  const BiliBiliQRLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("bilibili_login"))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Obx(
              () {
                if (controller.qrStatus.value == QRStatus.loading) {
                  return const CircularProgressIndicator();
                }

                if (controller.qrStatus.value == QRStatus.failed) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(i18n("qr_load_failed")),
                      TextButton(
                        onPressed: controller.loadQRCode,
                        child: Text(i18n("retry")),
                      ),
                    ],
                  );
                }

                if (controller.qrStatus.value == QRStatus.failed) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(i18n("qr_expired")),
                      TextButton(
                        onPressed: controller.loadQRCode,
                        child: Text(i18n("refresh_qr")),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: QrImageView(
                        data: controller.qrcodeUrl.value,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                        size: 200.0,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Visibility(
                      visible: controller.qrStatus.value == QRStatus.scanned,
                      child: Text(i18n("qr_scanned_confirm")),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              i18n("qr_login_tip"),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}