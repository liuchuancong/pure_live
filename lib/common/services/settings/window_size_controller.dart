import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

//  需要指定显示到哪一个屏幕 可能存在多个显示屏
class WindowPipGeometry {
  /// Stores the display ID where the PiP window was last displayed.
  final RxString displayId = hiveString('windows_pip_display_id', '');

  /// Stores the PiP window width.
  final RxDouble windowsPipWidth = hiveDouble('windows_pip_width', 0.0);

  /// Stores the PiP window height.
  final RxDouble windowsPipHeight = hiveDouble('windows_pip_height', 0.0);

  /// Stores the PiP window horizontal position.
  final RxDouble windowsPipX = hiveDouble('windows_pip_x', 0.0);

  /// Stores the PiP window vertical position.
  final RxDouble windowsPipY = hiveDouble('windows_pip_y', 0.0);

  bool get isValid {
    return displayId.v.isNotEmpty &&
        windowsPipWidth.v > 0 &&
        windowsPipHeight.v > 0 &&
        windowsPipX.v.isFinite &&
        windowsPipY.v.isFinite;
  }

  Size get size => Size(windowsPipWidth.v, windowsPipHeight.v);

  Offset get position => Offset(windowsPipX.v, windowsPipY.v);

  void update(Size size, Offset position, String displayId) {
    if (!size.isFinite || size.isEmpty || !position.isFinite || displayId.isEmpty) {
      return;
    }

    this.displayId.v = displayId;
    windowsPipWidth.v = size.width;
    windowsPipHeight.v = size.height;
    windowsPipX.v = position.dx;
    windowsPipY.v = position.dy;
  }

  void clear() {
    displayId.v = '';
    windowsPipWidth.v = 0.0;
    windowsPipHeight.v = 0.0;
    windowsPipX.v = 0.0;
    windowsPipY.v = 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'displayId': displayId.v,
      'windowsPipWidth': windowsPipWidth.v,
      'windowsPipHeight': windowsPipHeight.v,
      'windowsPipX': windowsPipX.v,
      'windowsPipY': windowsPipY.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    displayId.v = json['displayId'] ?? '';
    windowsPipWidth.v = (json['windowsPipWidth'] as num?)?.toDouble() ?? 0.0;
    windowsPipHeight.v = (json['windowsPipHeight'] as num?)?.toDouble() ?? 0.0;
    windowsPipX.v = (json['windowsPipX'] as num?)?.toDouble() ?? 0.0;
    windowsPipY.v = (json['windowsPipY'] as num?)?.toDouble() ?? 0.0;
  }
}

class WindowSizeController extends GetxController {
  static WindowSizeController get to => Get.find<WindowSizeController>();

  final RxDouble storedWidth = hiveDouble('window_width', 1280.0);
  final RxDouble storedHeight = hiveDouble('window_height', 720.0);

  /// Whether the PiP window position should be remembered.
  final RxBool rememberPipPosition = hiveBool('rememberPipPosition', true);

  final WindowPipGeometry windowsPip = WindowPipGeometry();

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

  void clearWindowsPipGeometry() {
    windowsPip.clear();
  }

  void setTracking(bool tracking) {
    isTracking.value = tracking;
  }

  Map<String, dynamic> toJson() {
    return {
      'storedWidth': storedWidth.v,
      'storedHeight': storedHeight.v,
      'rememberPipPosition': rememberPipPosition.v,
      'windowsPip': windowsPip.toJson(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    storedWidth.v = (json['storedWidth'] as num?)?.toDouble() ?? 1280.0;

    storedHeight.v = (json['storedHeight'] as num?)?.toDouble() ?? 720.0;

    rememberPipPosition.v = json['rememberPipPosition'] ?? true;

    final pip = json['windowsPip'];

    if (pip is Map) {
      windowsPip.fromJson(Map<String, dynamic>.from(pip));
    }

    windowSize.value = Size(storedWidth.v, storedHeight.v);
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final windowSize = rootConfig?['windowSize'] as Map<String, dynamic>? ?? {};

    final pip = windowSize['windowsPip'];

    return {
      'storedWidth': (windowSize['storedWidth'] ?? 1280.0).toDouble(),
      'storedHeight': (windowSize['storedHeight'] ?? 720.0).toDouble(),
      'rememberPipPosition': windowSize['rememberPipPosition'] ?? true,
      'windowsPip': pip is Map ? Map<String, dynamic>.from(pip) : <String, dynamic>{},
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final windowSize = Map<String, dynamic>.from(rootConfig['windowSize'] ?? {});

    updateFields.forEach((key, value) {
      windowSize[key] = value;
    });

    rootConfig['windowSize'] = windowSize;

    return rootConfig;
  }
}
