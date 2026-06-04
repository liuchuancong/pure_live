import 'package:pure_live/common/index.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';

class BiliBiliWebLoginController extends GetxController {
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri("https://passport.bilibili.com/login")));
  }

  void toQRLogin() async {
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
      Navigator.of(Get.context!).pop(true);
    }
  }
}
