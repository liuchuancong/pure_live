import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

//  需要指定显示到哪一个屏幕 可能存在多个显示屏

class WindowPipGeometry {
  final RxString displayId = hiveString('windows_pip_display_id', '');
  final RxDouble windowsPipWidth = hiveDouble('windows_pip_width', 0.0);
  final RxDouble windowsPipHeight = hiveDouble('windows_pip_height', 0.0);
  final RxDouble windowsPipX = hiveDouble('windows_pip_x', 0.0);
  final RxDouble windowsPipY = hiveDouble('windows_pip_y', 0.0);

  final RxString portraitDisplayId = hiveString('windows_pip_portrait_display_id', '');
  final RxDouble portraitWidth = hiveDouble('windows_pip_portrait_width', 0.0);
  final RxDouble portraitHeight = hiveDouble('windows_pip_portrait_height', 0.0);
  final RxDouble portraitX = hiveDouble('windows_pip_portrait_x', 0.0);
  final RxDouble portraitY = hiveDouble('windows_pip_portrait_y', 0.0);

  bool get isValid {
    return displayId.v.isNotEmpty && hasValidBounds;
  }

  bool get portraitIsValid {
    return portraitDisplayId.v.isNotEmpty && portraitHasValidBounds;
  }

  bool get hasValidBounds {
    return windowsPipWidth.v > 0 &&
        windowsPipHeight.v > 0 &&
        windowsPipX.v.isFinite &&
        windowsPipY.v.isFinite;
  }

  bool get portraitHasValidBounds {
    return portraitWidth.v > 0 &&
        portraitHeight.v > 0 &&
        portraitX.v.isFinite &&
        portraitY.v.isFinite;
  }

  Size get size => Size(windowsPipWidth.v, windowsPipHeight.v);

  Offset get position => Offset(windowsPipX.v, windowsPipY.v);

  Size get portraitSize => Size(portraitWidth.v, portraitHeight.v);

  Offset get portraitPosition => Offset(portraitX.v, portraitY.v);

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

  void updatePortrait(Size size, Offset position, String displayId) {
    if (!size.isFinite || size.isEmpty || !position.isFinite || displayId.isEmpty) {
      return;
    }

    portraitDisplayId.v = displayId;
    portraitWidth.v = size.width;
    portraitHeight.v = size.height;
    portraitX.v = position.dx;
    portraitY.v = position.dy;
  }

  void clear() {
    displayId.v = '';
    windowsPipWidth.v = 0.0;
    windowsPipHeight.v = 0.0;
    windowsPipX.v = 0.0;
    windowsPipY.v = 0.0;
  }

  void clearPortrait() {
    portraitDisplayId.v = '';
    portraitWidth.v = 0.0;
    portraitHeight.v = 0.0;
    portraitX.v = 0.0;
    portraitY.v = 0.0;
  }

  void clearAll() {
    clear();
    clearPortrait();
  }

  Map<String, dynamic> toJson() {
    return {
      'displayId': displayId.v,
      'windowsPipWidth': windowsPipWidth.v,
      'windowsPipHeight': windowsPipHeight.v,
      'windowsPipX': windowsPipX.v,
      'windowsPipY': windowsPipY.v,
      'portraitDisplayId': portraitDisplayId.v,
      'portraitWidth': portraitWidth.v,
      'portraitHeight': portraitHeight.v,
      'portraitX': portraitX.v,
      'portraitY': portraitY.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    displayId.v = json['displayId'] ?? '';
    windowsPipWidth.v = (json['windowsPipWidth'] as num?)?.toDouble() ?? 0.0;
    windowsPipHeight.v = (json['windowsPipHeight'] as num?)?.toDouble() ?? 0.0;
    windowsPipX.v = (json['windowsPipX'] as num?)?.toDouble() ?? 0.0;
    windowsPipY.v = (json['windowsPipY'] as num?)?.toDouble() ?? 0.0;

    portraitDisplayId.v = json['portraitDisplayId'] ?? '';
    portraitWidth.v = (json['portraitWidth'] as num?)?.toDouble() ?? 0.0;
    portraitHeight.v = (json['portraitHeight'] as num?)?.toDouble() ?? 0.0;
    portraitX.v = (json['portraitX'] as num?)?.toDouble() ?? 0.0;
    portraitY.v = (json['portraitY'] as num?)?.toDouble() ?? 0.0;
  }
}

class WindowSizeController extends GetxController {
  static WindowSizeController get to => Get.find<WindowSizeController>();

  final RxDouble storedWidth = hiveDouble('window_width', 1280.0);
  final RxDouble storedHeight = hiveDouble('window_height', 720.0);

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
    windowsPip.clearAll();
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

    windowsPip.fromJson(_extractPipGeometry(json));

    windowSize.value = Size(storedWidth.v, storedHeight.v);
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final windowSize = rootConfig?['windowSize'] as Map<String, dynamic>? ?? {};

    final player = rootConfig?['player'] as Map<String, dynamic>? ?? {};

    final pip = _extractPipGeometry(windowSize);

    return {
      'storedWidth': (windowSize['storedWidth'] ?? 1280.0).toDouble(),
      'storedHeight': (windowSize['storedHeight'] ?? 720.0).toDouble(),
      'rememberPipPosition':
          windowSize['rememberPipPosition'] ?? player['rememberPipPosition'] ?? true,
      'windowsPip': pip,
      'windowsPipDisplayId': pip['displayId'],
      'windowsPipWidth': pip['windowsPipWidth'],
      'windowsPipHeight': pip['windowsPipHeight'],
      'windowsPipX': pip['windowsPipX'],
      'windowsPipY': pip['windowsPipY'],
      'windowsPipPortraitDisplayId': pip['portraitDisplayId'],
      'windowsPipPortraitWidth': pip['portraitWidth'],
      'windowsPipPortraitHeight': pip['portraitHeight'],
      'windowsPipPortraitX': pip['portraitX'],
      'windowsPipPortraitY': pip['portraitY'],
    };
  }

  static Map<String, dynamic> mergeConfig(
    Map<String, dynamic> rootConfig,
    Map<String, dynamic> updateFields,
  ) {
    final windowSize = Map<String, dynamic>.from(rootConfig['windowSize'] ?? {});

    updateFields.forEach((key, value) {
      windowSize[key] = value;
    });

    if (updateFields.keys.any(_isPipGeometryKey)) {
      final pip = _extractPipGeometry(windowSize);

      const aliases = <String, String>{
        'windowsPipDisplayId': 'displayId',
        'windowsPipWidth': 'windowsPipWidth',
        'windowsPipHeight': 'windowsPipHeight',
        'windowsPipX': 'windowsPipX',
        'windowsPipY': 'windowsPipY',
        'windowsPipPortraitDisplayId': 'portraitDisplayId',
        'windowsPipPortraitWidth': 'portraitWidth',
        'windowsPipPortraitHeight': 'portraitHeight',
        'windowsPipPortraitX': 'portraitX',
        'windowsPipPortraitY': 'portraitY',
      };

      for (final alias in aliases.entries) {
        if (updateFields.containsKey(alias.key)) {
          pip[alias.value] = updateFields[alias.key];
        }
      }

      windowSize['windowsPip'] = pip;
    }

    rootConfig['windowSize'] = windowSize;

    return rootConfig;
  }

  static bool _isPipGeometryKey(String key) =>
      key == 'windowsPipDisplayId' ||
      key == 'windowsPipWidth' ||
      key == 'windowsPipHeight' ||
      key == 'windowsPipX' ||
      key == 'windowsPipY' ||
      key == 'windowsPipPortraitDisplayId' ||
      key == 'windowsPipPortraitWidth' ||
      key == 'windowsPipPortraitHeight' ||
      key == 'windowsPipPortraitX' ||
      key == 'windowsPipPortraitY';

  static Map<String, dynamic> _extractPipGeometry(Map<String, dynamic> windowSize) {
    final nested = windowSize['windowsPip'];

    final pip = nested is Map ? Map<String, dynamic>.from(nested) : <String, dynamic>{};

    double number(String key) {
      final value = pip[key] ?? windowSize[key];
      return value is num ? value.toDouble() : 0.0;
    }

    return {
      'displayId': (pip['displayId'] ?? windowSize['windowsPipDisplayId'] ?? '').toString(),
      'windowsPipWidth': number('windowsPipWidth'),
      'windowsPipHeight': number('windowsPipHeight'),
      'windowsPipX': number('windowsPipX'),
      'windowsPipY': number('windowsPipY'),
      'portraitDisplayId':
          (pip['portraitDisplayId'] ?? windowSize['windowsPipPortraitDisplayId'] ?? '').toString(),
      'portraitWidth': number('portraitWidth'),
      'portraitHeight': number('portraitHeight'),
      'portraitX': number('portraitX'),
      'portraitY': number('portraitY'),
    };
  }
}
