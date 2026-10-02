import 'package:pure_live/get/get.dart';

/// 当前路由名。Core 只读取它（桌面托盘、播放器让位），更新由 app 层的路由观察者负责。
/// 记录当前路由名，供需要判断页面是否在前台的模块读取。
class RouteObserverController extends GetxController {
  static RouteObserverController get to => Get.find();
  final currentRoute = ''.obs;
  void updateRoute(String? route) {
    currentRoute.value = route ?? "";
  }
}
