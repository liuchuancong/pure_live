import 'package:pure_live/common/index.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';

class BiliBiliWebLoginController extends GetxController {
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();
  final showWebView = true.obs;
  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri("https://passport.bilibili.com/login")));
  }

  void toQRLogin() async {
    showWebView.value = false;
    await Future.delayed(const Duration(milliseconds: 500));
    await Get.offAndToNamed(RoutePath.kBiliBiliQRLogin);
  }

  void onLoadStop(InAppWebViewController controller, WebUri? uri) async {
    if (uri == null) {
      return;
    }
    if (uri.host == "m.bilibili.com") {
      var cookies = await cookieManager.getCookies(url: uri);
      var cookieStr = cookies.map((e) => "${e.name}=${e.value}").join(";");
      BiliBiliAccountService.instance.setCookie(cookieStr);
      await BiliBiliAccountService.instance.loadUserInfo();
      showWebView.value = false;
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.of(Get.context!).pop(true);
    }
  }
}
