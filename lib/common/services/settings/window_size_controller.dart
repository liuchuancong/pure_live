import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class WindowSizeController extends GetxController {
  static WindowSizeController get to => Get.find<WindowSizeController>();

  final RxDouble storedWidth = hiveDouble('window_width', 1280.0);
  final RxDouble storedHeight = hiveDouble('window_height', 720.0);

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

    debounce(isTracking, (bool tracking) {
      if (tracking) {
        isTracking.value = false;
      }
    }, time: const Duration(seconds: 2));
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

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final windowSize = rootConfig?['windowSize'] as Map<String, dynamic>? ?? {};
    return {
      'storedWidth': (windowSize['storedWidth'] ?? 1280.0).toDouble(),
      'storedHeight': (windowSize['storedHeight'] ?? 720.0).toDouble(),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final windowSize = Map<String, dynamic>.from(rootConfig['windowSize'] ?? {});
    updateFields.forEach((k, v) => windowSize[k] = v);
    rootConfig['windowSize'] = windowSize;
    return rootConfig;
  }
}
