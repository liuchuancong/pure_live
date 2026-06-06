import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class BaseController extends GetxController {
  var pageLoadding = false.obs;
  var loadding = false.obs;
  var pageEmpty = false.obs;
  var pageError = false.obs;
  var notLogin = false.obs;
  var errorMsg = "".obs;
  var showCellularBanner = false.obs;
  static bool neverShowCellularBanner = false;

  Future<bool> checkNetworkBeforeRequest() async {
    if (PlatformUtils.isDesktop) return true;
    try {
      final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty) {
        handleError("network_disconnected", showPageError: true);
        return false;
      }
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        if (!neverShowCellularBanner) {
          showCellularBanner.value = true;
        }
      } else {
        showCellularBanner.value = false;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  void handleError(Object exception, {bool showPageError = false}) {
    var msg = exceptionToString(exception);
    if (exception == "network_disconnected") {
      msg = i18n("network_disconnected_msg");
    }
    errorMsg.value = msg;
    final exceptionStr = exception.toString().toLowerCase();
    if (exceptionStr.contains("loginrequired") ||
        exceptionStr.contains("unauthorized") ||
        exceptionStr.contains("未登录")) {
      notLogin.value = true;
      pageError.value = false;
    } else {
      notLogin.value = false;
      pageError.value = true;
    }
    if (!showPageError) {
      ToastUtil.show(msg);
    }
  }

  String exceptionToString(Object exception) {
    if (exception is String) return exception;
    String msg = exception.toString().replaceAll("Exception:", "").trim();
    if (msg.isEmpty) {
      msg = "未知错误，请重试";
    }
    return msg;
  }

  void onLogin() => notLogin.value = false;
  void onLogout() => notLogin.value = true;
}
