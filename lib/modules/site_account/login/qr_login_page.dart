import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/core/interface/live_site_mixin.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/site_account/login/qr_login_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SiteQRLoginPage extends GetView<SiteQRLoginController> {
  const SiteQRLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${S.current.supabase_sign_in} ${Sites.getSiteName(controller.site.id)}")),
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
                      Text(S.current.qr_loading_failed),
                      TextButton(
                        onPressed: controller.loadQRCode,
                        child: Text(S.current.retry),
                      ),
                    ],
                  );
                }
                if (controller.qrStatus.value == QRStatus.failed) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(S.current.qr_loading_expired),
                      TextButton(
                        onPressed: controller.loadQRCode,
                        child: Text(S.current.qr_loading_refresh),
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
                    const SizedBox(
                      height: 8,
                    ),
                    Visibility(
                      visible: controller.qrStatus.value == QRStatus.scanned,
                      child: Text(S.current.qr_confirm),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              S.current.login_by_qr_info(Sites.getSiteName(controller.site.id)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
