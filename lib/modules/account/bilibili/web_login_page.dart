import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/modules/account/bilibili/web_login_controller.dart';

class BiliBiliWebLoginPage extends GetView<BiliBiliWebLoginController> {
  const BiliBiliWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("bilibili_login")),
        actions: [
          TextButton.icon(
            onPressed: controller.toQRLogin,
            icon: const Icon(Icons.qr_code),
            label: Text(i18n("qr_login")),
          ),
        ],
      ),
      body: InAppWebView(
        onWebViewCreated: controller.onWebViewCreated,
        onLoadStop: controller.onLoadStop,
        initialSettings: InAppWebViewSettings(
          userAgent:
              "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/118.0.0.0",
          useShouldOverrideUrlLoading: false,
        ),
        shouldOverrideUrlLoading: (webController, navigationAction) async {
          var uri = navigationAction.request.url;
          if (uri == null) {
            return NavigationActionPolicy.ALLOW;
          }
          if (uri.host == "m.bilibili.com" || uri.host == "www.bilibili.com") {
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
