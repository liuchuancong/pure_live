import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class MeteredNetworkService extends GetxService {
  static MeteredNetworkService get to => Get.find<MeteredNetworkService>();

  final RxBool _metered = false.obs;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// 当前是否为移动网络
  bool get isMetered => _metered.value;

  /// Rx 状态
  RxBool get metered => _metered;

  @override
  void onInit() {
    super.onInit();

    if (!PlatformUtils.isDesktop) {
      _init();
    }
  }

  void _init() {
    if (_subscription != null) {
      return;
    }

    _subscription = Connectivity().onConnectivityChanged.listen(
      _apply,
      onError: (Object error) {
        debugPrint('Network: 网络类型监听中断 $error');
      },
    );
  }

  /// 请求前检查网络
  ///
  /// true  = 有网络，可以继续请求
  /// false = 无网络，禁止请求
  Future<bool> checkNetworkBeforeRequest() async {
    if (PlatformUtils.isDesktop) {
      return true;
    }

    try {
      final results = await Connectivity().checkConnectivity();

      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return false;
      }

      _apply(results);

      return true;
    } catch (error) {
      debugPrint('Network: 检查网络状态失败 $error');

      // 检查失败时不阻止请求
      return true;
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final metered = _resolveMetered(results);

    if (metered == null) {
      return;
    }

    if (metered != _metered.value) {
      debugPrint(metered ? 'Network: 切换到移动数据网络' : 'Network: 切换到 WLAN / 局域网');

      _metered.value = metered;
    }
  }

  /// Wi-Fi / Ethernet 优先于 Mobile。
  ///
  /// Android 网络切换过程中可能同时返回：
  ///
  /// [wifi, mobile]
  ///
  /// 此时认为是非计费网络。
  bool? _resolveMetered(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet)) {
      return false;
    }

    if (results.contains(ConnectivityResult.mobile)) {
      return true;
    }

    return null;
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _subscription = null;
    super.onClose();
  }
}
