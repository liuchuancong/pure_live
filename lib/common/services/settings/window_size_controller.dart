import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class WindowSizeController extends GetxController {
  static WindowSizeController get to => Get.find<WindowSizeController>();

  final HiveRx<double> storedWidth = HiveRx.double('window_width', 1280.0);
  final HiveRx<double> storedHeight = HiveRx.double('window_height', 720.0);

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

  Map<String, dynamic> toJson() {
    return {'storedWidth': storedWidth.v, 'storedHeight': storedHeight.v};
  }

  void fromJson(Map<String, dynamic> json) {
    storedWidth.v = (json['storedWidth'] as num?)?.toDouble() ?? 1280.0;
    storedHeight.v = (json['storedHeight'] as num?)?.toDouble() ?? 720.0;
    windowSize.value = Size(storedWidth.v, storedHeight.v);
  }
}
