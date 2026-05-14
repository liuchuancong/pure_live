import 'package:get/get.dart';

class RouteObserverController extends GetxController {
  static RouteObserverController get to => Get.find();
  final currentRoute = ''.obs;
  void updateRoute(String? route) {
    currentRoute.value = route ?? '';
  }
}
