import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class WindowSizeController extends GetxController {
  static WindowSizeController get to => Get.find<WindowSizeController>();

  final RxDouble storedWidth = hiveDouble('window_width', 1280.0);
  final RxDouble storedHeight = hiveDouble('window_height', 720.0);
  final RxDouble windowsPipWidth = hiveDouble('windows_pip_width', 0.0);
  final RxDouble windowsPipHeight = hiveDouble('windows_pip_height', 0.0);
  final RxDouble windowsPipX = hiveDouble('windows_pip_x', 0.0);
  final RxDouble windowsPipY = hiveDouble('windows_pip_y', 0.0);

  final windowSize = const Size(1280, 720).obs;
  final isTracking = false.obs;
  final List<Worker> _workers = [];

  @override
  void onInit() {
    super.onInit();
    windowSize.value = Size(storedWidth.v, storedHeight.v);

    _workers.add(
      debounce(windowSize, (Size size) {
        storedWidth.v = size.width;
        storedHeight.v = size.height;
      }, time: const Duration(milliseconds: 500)),
    );

    _workers.add(
      debounce(isTracking, (bool tracking) {
        if (tracking) {
          isTracking.value = false;
        }
      }, time: const Duration(seconds: 2)),
    );
  }

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    super.onClose();
  }

  void updateSize(Size size) {
    windowSize.value = size;
  }

  void setTracking(bool tracking) {
    isTracking.value = tracking;
  }

  void updateWindowsPipGeometry(Size size, Offset position) {
    if (!size.isFinite || size.isEmpty || !position.isFinite) return;
    windowsPipWidth.v = size.width;
    windowsPipHeight.v = size.height;
    windowsPipX.v = position.dx;
    windowsPipY.v = position.dy;
  }

  Map<String, dynamic> toJson() {
    return {
      'storedWidth': storedWidth.v,
      'storedHeight': storedHeight.v,
      'windowsPipWidth': windowsPipWidth.v,
      'windowsPipHeight': windowsPipHeight.v,
      'windowsPipX': windowsPipX.v,
      'windowsPipY': windowsPipY.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    storedWidth.v = (json['storedWidth'] as num?)?.toDouble() ?? 1280.0;
    storedHeight.v = (json['storedHeight'] as num?)?.toDouble() ?? 720.0;
    windowsPipWidth.v = (json['windowsPipWidth'] as num?)?.toDouble() ?? 0.0;
    windowsPipHeight.v = (json['windowsPipHeight'] as num?)?.toDouble() ?? 0.0;
    windowsPipX.v = (json['windowsPipX'] as num?)?.toDouble() ?? 0.0;
    windowsPipY.v = (json['windowsPipY'] as num?)?.toDouble() ?? 0.0;
    windowSize.value = Size(storedWidth.v, storedHeight.v);
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final windowSize = rootConfig?['windowSize'] as Map<String, dynamic>? ?? {};
    return {
      'storedWidth': (windowSize['storedWidth'] ?? 1280.0).toDouble(),
      'storedHeight': (windowSize['storedHeight'] ?? 720.0).toDouble(),
      'windowsPipWidth': (windowSize['windowsPipWidth'] ?? 0.0).toDouble(),
      'windowsPipHeight': (windowSize['windowsPipHeight'] ?? 0.0).toDouble(),
      'windowsPipX': (windowSize['windowsPipX'] ?? 0.0).toDouble(),
      'windowsPipY': (windowSize['windowsPipY'] ?? 0.0).toDouble(),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final windowSize = Map<String, dynamic>.from(rootConfig['windowSize'] ?? {});
    updateFields.forEach((k, v) => windowSize[k] = v);
    rootConfig['windowSize'] = windowSize;
    return rootConfig;
  }
}
