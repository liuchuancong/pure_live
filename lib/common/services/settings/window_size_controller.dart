import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class WindowSizeController extends GetxController {
  static WindowSizeController get to => Get.find<WindowSizeController>();

  final storedWidth = HiveRx.double('window_width', 1280.0);
  final storedHeight = HiveRx.double('window_height', 720.0);

  final windowSize = const Size(1280, 720).obs;
  final isTracking = false.obs;

  @override
  void onInit() {
    super.onInit();
    windowSize.value = Size(storedWidth.v, storedHeight.v);

    debounce(windowSize, (Size size) {
      storedWidth.v = size.width;
      storedHeight.v = size.height;
    }, time: const Duration(milliseconds: 500));
  }

  void updateSize(Size size) {
    windowSize.value = size;
  }

  void setTracking(bool tracking) {
    isTracking.value = tracking;
  }
}
