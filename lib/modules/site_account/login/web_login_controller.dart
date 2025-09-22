import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';

class SiteWebLoginController extends BaseController {
  final Site site;
  InAppWebViewController? webViewController;
  final CookieManager cookieManager = CookieManager.instance();

  SiteWebLoginController({required this.site});

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
    webViewController!.loadUrl(
      urlRequest: site.liveSite.webLoginURLRequest(),
    );
  }

  void toQRLogin() async {
    await Get.offAndToNamed(RoutePath.kSiteQRLogin,
        parameters: {"site": site.id});
  }

  void onLoadStop(InAppWebViewController controller, WebUri? uri) async {
    CoreLog.d("onLoadStop ..... $uri");
    if (uri == null) {
      return;
    }
    if (site.liveSite.webLoginHandle(uri)) {
      var cookies = await cookieManager.getCookies(url: uri);
      var cookieStr = cookies.map((e) => "${e.name}=${e.value}").join(";");
      CoreLog.d("cookieStr: $cookieStr");
      await site.liveSite.loadUserInfo(site, cookieStr);
      Navigator.of(Get.context!).pop(true);
    }
  }
}
