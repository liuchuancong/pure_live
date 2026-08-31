import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/services/settings/metered_network_service.dart';

class BaseController extends GetxController {
  final pageLoadding = false.obs;
  final loadding = false.obs;
  final pageEmpty = false.obs;
  final pageError = false.obs;
  final notLogin = false.obs;
  final errorMsg = ''.obs;

  /// 是否显示移动网络提示
  final showCellularBanner = false.obs;

  static bool neverShowCellularBanner = false;

  Worker? _meteredWorker;

  @override
  void onInit() {
    super.onInit();

    if (!PlatformUtils.isDesktop) {
      _meteredWorker = ever<bool>(MeteredNetworkService.to.metered, (_) {
        _updateCellularBanner();
      });

      _updateCellularBanner();
    }
  }

  /// 请求前检查网络
  Future<bool> checkNetworkBeforeRequest() async {
    if (PlatformUtils.isDesktop) {
      return true;
    }
    final result = await MeteredNetworkService.to.checkNetworkBeforeRequest();
    _updateCellularBanner();
    return result;
  }

  void _updateCellularBanner() {
    showCellularBanner.value = MeteredNetworkService.to.isMetered && !neverShowCellularBanner;
  }

  /// 永久关闭移动网络提示
  void disableCellularBannerForever() {
    neverShowCellularBanner = true;
    showCellularBanner.value = false;
  }

  void handleError(Object exception, {bool showPageError = false}) {
    var msg = exceptionToString(exception);

    if (exception == 'network_disconnected') {
      msg = i18n('network_disconnected_msg');
    }

    errorMsg.value = msg;

    final exceptionStr = exception.toString().toLowerCase();

    if (exceptionStr.contains('loginrequired') ||
        exceptionStr.contains('unauthorized') ||
        exceptionStr.contains('未登录')) {
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
    if (exception is String) {
      return exception;
    }

    var msg = exception.toString().replaceAll('Exception:', '').trim();

    if (msg.isEmpty) {
      msg = '未知错误，请重试';
    }

    return msg;
  }

  void onLogin() {
    notLogin.value = false;
  }

  void onLogout() {
    notLogin.value = true;
  }

  @override
  void onClose() {
    _meteredWorker?.dispose();
    _meteredWorker = null;
    super.onClose();
  }
}
