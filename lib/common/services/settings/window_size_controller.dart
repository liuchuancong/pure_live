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
    return displayId.v.trim().isNotEmpty && hasValidBounds;
  }

  bool get hasValidBounds {
    return windowsPipWidth.v.isFinite &&
        windowsPipHeight.v.isFinite &&
        windowsPipWidth.v > 0 &&
        windowsPipHeight.v > 0 &&
        windowsPipX.v.isFinite &&
        windowsPipY.v.isFinite;
  }

  Size get size => Size(windowsPipWidth.v, windowsPipHeight.v);

  Offset get position => Offset(windowsPipX.v, windowsPipY.v);

  void update(Size size, Offset position, String displayId) {
    if (!size.isFinite || size.isEmpty || !position.isFinite || displayId.trim().isEmpty) {
      return;
    }

    _assign(
      WindowSizeController.normalizePipGeometry({
        'windowsPip': {
          'displayId': displayId,
          'windowsPipWidth': size.width,
          'windowsPipHeight': size.height,
          'windowsPipX': position.dx,
          'windowsPipY': position.dy,
        },
      }),
    );
  }

  void clear() {
    displayId.v = '';
    windowsPipWidth.v = 0.0;
    windowsPipHeight.v = 0.0;
    windowsPipX.v = 0.0;
    windowsPipY.v = 0.0;
  }

  Map<String, dynamic> toJson() {
    return WindowSizeController.normalizePipGeometry({
      'windowsPip': {
        'displayId': displayId.v,
        'windowsPipWidth': windowsPipWidth.v,
        'windowsPipHeight': windowsPipHeight.v,
        'windowsPipX': windowsPipX.v,
        'windowsPipY': windowsPipY.v,
      },
    });
  }

  void fromJson(Map<String, dynamic> json) {
    _assign(WindowSizeController.normalizePipGeometry(json, strict: true));
  }

  void repairStored() {
    _assign(toJson());
  }

  void _assign(Map<String, dynamic> values) {
    displayId.v = values['displayId'] as String;
    windowsPipWidth.v = values['windowsPipWidth'] as double;
    windowsPipHeight.v = values['windowsPipHeight'] as double;
    windowsPipX.v = values['windowsPipX'] as double;
    windowsPipY.v = values['windowsPipY'] as double;
  }
}

class WindowSizeController extends GetxController {
  static WindowSizeController get to => Get.find<WindowSizeController>();

  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 720;
  static const double minWindowWidth = 400;
  static const double minWindowHeight = 300;
  static const double maxWindowDimension = 16384;

  final RxDouble storedWidth = hiveDouble('window_width', defaultWindowWidth);
  final RxDouble storedHeight = hiveDouble('window_height', defaultWindowHeight);

  /// Whether the PiP window position should be remembered.
  final RxBool rememberPipPosition = hiveBool('rememberPipPosition', true);

  final WindowPipGeometry windowsPip = WindowPipGeometry();

  final windowSize = const Size(defaultWindowWidth, defaultWindowHeight).obs;
  final isTracking = false.obs;
  final List<Worker> _workers = [];
  bool _writingStoredSize = false;

  double get resolvedStoredWidth => normalizeStoredWidth(storedWidth.v);
  double get resolvedStoredHeight => normalizeStoredHeight(storedHeight.v);
  Size get storedSize => Size(resolvedStoredWidth, resolvedStoredHeight);

  @override
  void onInit() {
    super.onInit();

    _writeStoredSize(storedSize);
    windowsPip.repairStored();

    _workers.add(everAll([storedWidth, storedHeight], (_) => _repairStoredSize()));

    _workers.add(
      debounce(windowSize, (Size size) {
        if (!_isUsableWindowSize(size)) {
          if (windowSize.value != storedSize) windowSize.value = storedSize;
          return;
        }
        _writeStoredSize(_normalizeWindowSize(size), updateWindowSize: false);
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
    if (!_isUsableWindowSize(size)) return;
    windowSize.value = _normalizeWindowSize(size);
  }

  void saveWindowSize(Size size) {
    if (!_isSupportedWindowSize(size)) return;
    _writeStoredSize(size);
  }

  void clearWindowsPipGeometry() {
    windowsPip.clear();
  }

  void setTracking(bool tracking) {
    isTracking.value = tracking;
  }

  Map<String, dynamic> toJson() {
    return {
      'storedWidth': resolvedStoredWidth,
      'storedHeight': resolvedStoredHeight,
      'rememberPipPosition': rememberPipPosition.v,
      'windowsPip': windowsPip.toJson(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    _writeStoredSize(Size(parsed['storedWidth'] as double, parsed['storedHeight'] as double));
    rememberPipPosition.v = parsed['rememberPipPosition'];
    windowsPip.fromJson(parsed['windowsPip']);
  }

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    final width = _parseStoredDimension(json['storedWidth'], fallback: defaultWindowWidth, min: minWindowWidth);
    final height = _parseStoredDimension(json['storedHeight'], fallback: defaultWindowHeight, min: minWindowHeight);
    return {
      'storedWidth': width,
      'storedHeight': height,
      'rememberPipPosition': json['rememberPipPosition'] as bool? ?? true,
      'windowsPip': normalizePipGeometry(json, strict: true),
    };
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final windowSize = rootConfig?['windowSize'] as Map<String, dynamic>? ?? {};
    final player = rootConfig?['player'] as Map<String, dynamic>? ?? {};
    final parsed = parseConfig({
      ...windowSize,
      'rememberPipPosition': windowSize['rememberPipPosition'] ?? player['rememberPipPosition'] ?? true,
    });
    final pip = parsed['windowsPip'] as Map<String, dynamic>;

    return {
      'storedWidth': parsed['storedWidth'],
      'storedHeight': parsed['storedHeight'],
      'rememberPipPosition': parsed['rememberPipPosition'],
      'windowsPip': pip,
      // Keep the legacy aliases in extracted configuration so older backup
      // editors and downgrade imports preserve the rectangle losslessly.
      'windowsPipDisplayId': pip['displayId'],
      'windowsPipWidth': pip['windowsPipWidth'],
      'windowsPipHeight': pip['windowsPipHeight'],
      'windowsPipX': pip['windowsPipX'],
      'windowsPipY': pip['windowsPipY'],
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final windowSize = Map<String, dynamic>.from(rootConfig['windowSize'] ?? {});

    updateFields.forEach((key, value) {
      windowSize[key] = value;
    });

    if (updateFields.keys.any(_isLegacyPipGeometryKey)) {
      final pip = normalizePipGeometry(windowSize);
      const aliases = <String, String>{
        'windowsPipDisplayId': 'displayId',
        'windowsPipWidth': 'windowsPipWidth',
        'windowsPipHeight': 'windowsPipHeight',
        'windowsPipX': 'windowsPipX',
        'windowsPipY': 'windowsPipY',
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

  static bool _isLegacyPipGeometryKey(String key) =>
      key == 'windowsPipDisplayId' ||
      key == 'windowsPipWidth' ||
      key == 'windowsPipHeight' ||
      key == 'windowsPipX' ||
      key == 'windowsPipY';

  static double normalizeStoredWidth(num value) {
    return _normalizeStoredDimension(value, fallback: defaultWindowWidth, min: minWindowWidth);
  }

  static double normalizeStoredHeight(num value) {
    return _normalizeStoredDimension(value, fallback: defaultWindowHeight, min: minWindowHeight);
  }

  static Size? tryParseWindowSize(String width, String height) {
    final parsedWidth = int.tryParse(width.trim());
    final parsedHeight = int.tryParse(height.trim());
    if (parsedWidth == null || parsedHeight == null) return null;
    final size = Size(parsedWidth.toDouble(), parsedHeight.toDouble());
    return _isSupportedWindowSize(size) ? size : null;
  }

  static Map<String, dynamic> normalizePipGeometry(Map<String, dynamic> windowSize, {bool strict = false}) {
    final nested = windowSize['windowsPip'];
    if (strict && nested != null && nested is! Map) throw const FormatException('Invalid PiP rectangle');
    final pip = nested is Map ? Map<String, dynamic>.from(nested) : const <String, dynamic>{};

    double number(String key) {
      final value = pip[key] ?? windowSize[key];
      if (strict && value != null && (value is! num || !value.isFinite)) {
        throw FormatException('Invalid PiP coordinate: $key');
      }
      return value is num ? value.toDouble() : 0.0;
    }

    final displayValue = pip['displayId'] ?? windowSize['windowsPipDisplayId'];
    final displayId = strict ? (displayValue as String? ?? '') : (displayValue?.toString() ?? '');
    final width = number('windowsPipWidth');
    final height = number('windowsPipHeight');
    final x = number('windowsPipX');
    final y = number('windowsPipY');
    if (!width.isFinite || !height.isFinite || !x.isFinite || !y.isFinite || width <= 0 || height <= 0) {
      return const {
        'displayId': '',
        'windowsPipWidth': 0.0,
        'windowsPipHeight': 0.0,
        'windowsPipX': 0.0,
        'windowsPipY': 0.0,
      };
    }

    return {
      'displayId': displayId.trim(),
      'windowsPipWidth': width.clamp(0.0, maxWindowDimension).toDouble(),
      'windowsPipHeight': height.clamp(0.0, maxWindowDimension).toDouble(),
      'windowsPipX': x,
      'windowsPipY': y,
    };
  }

  static double _parseStoredDimension(Object? raw, {required double fallback, required double min}) {
    final value = (raw as num?)?.toDouble() ?? fallback;
    if (!value.isFinite) throw const FormatException('Invalid window size');
    return _normalizeStoredDimension(value, fallback: fallback, min: min);
  }

  static double _normalizeStoredDimension(num raw, {required double fallback, required double min}) {
    final value = raw.toDouble();
    if (!value.isFinite) return fallback;
    return value.clamp(min, maxWindowDimension).toDouble();
  }

  static bool _isUsableWindowSize(Size size) {
    return size.isFinite && size.width >= minWindowWidth && size.height >= minWindowHeight;
  }

  static bool _isSupportedWindowSize(Size size) {
    return _isUsableWindowSize(size) && size.width <= maxWindowDimension && size.height <= maxWindowDimension;
  }

  static Size _normalizeWindowSize(Size size) {
    return Size(normalizeStoredWidth(size.width), normalizeStoredHeight(size.height));
  }

  void _repairStoredSize() {
    if (_writingStoredSize) return;
    _writeStoredSize(storedSize);
  }

  void _writeStoredSize(Size size, {bool updateWindowSize = true}) {
    final normalized = _normalizeWindowSize(size);
    _writingStoredSize = true;
    try {
      storedWidth.v = normalized.width;
      storedHeight.v = normalized.height;
    } finally {
      _writingStoredSize = false;
    }
    if (updateWindowSize && windowSize.value != normalized) windowSize.value = normalized;
  }
}
