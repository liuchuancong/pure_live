import 'package:pure_live/common/index.dart';

class RouteObserverController extends GetxController {
  static RouteObserverController get to => Get.find();
  final currentRoute = ''.obs;
  void updateRoute(String? route) {
    currentRoute.value = route ?? '';
  }
}
