import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/storage/hive_rx.dart';

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

  /// 竖屏源的整套几何。
  ///
  /// 横屏记住的矩形套到竖屏源上必然是错的（16:9 的框里放竖屏画面只剩黑边），
  /// 所以横竖屏各记一套，切换源方向时不需要每次手动调整。键名沿用 2026-08-27
  /// 就存在的 `windows_pip_portrait_*`，那套实现在后续某次合并里被丢掉了。
  final RxString portraitDisplayId = hiveString('windows_pip_portrait_display_id', '');

  /// Stores the portrait PiP window width.
  final RxDouble portraitWidth = hiveDouble('windows_pip_portrait_width', 0.0);

  /// Stores the portrait PiP window height.
  final RxDouble portraitHeight = hiveDouble('windows_pip_portrait_height', 0.0);

  /// Stores the portrait PiP window horizontal position.
  final RxDouble portraitX = hiveDouble('windows_pip_portrait_x', 0.0);

  /// Stores the portrait PiP window vertical position.
  final RxDouble portraitY = hiveDouble('windows_pip_portrait_y', 0.0);

  bool get isValid {
    return displayId.v.trim().isNotEmpty && hasValidBounds;
  }

  bool get portraitIsValid {
    return portraitDisplayId.v.trim().isNotEmpty && portraitHasValidBounds;
  }

  bool get hasValidBounds {
    return windowsPipWidth.v.isFinite &&
        windowsPipHeight.v.isFinite &&
        windowsPipWidth.v > 0 &&
        windowsPipHeight.v > 0 &&
        windowsPipX.v.isFinite &&
        windowsPipY.v.isFinite;
  }

  bool get portraitHasValidBounds {
    return portraitWidth.v.isFinite &&
        portraitHeight.v.isFinite &&
        portraitWidth.v > 0 &&
        portraitHeight.v > 0 &&
        portraitX.v.isFinite &&
        portraitY.v.isFinite;
  }

  Size get size => Size(windowsPipWidth.v, windowsPipHeight.v);

  Size get portraitSize => Size(portraitWidth.v, portraitHeight.v);

  Offset get position => Offset(windowsPipX.v, windowsPipY.v);

  Offset get portraitPosition => Offset(portraitX.v, portraitY.v);

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

  void updatePortrait(Size size, Offset position, String displayId) {
    if (!size.isFinite || size.isEmpty || !position.isFinite || displayId.trim().isEmpty) {
      return;
    }

    _assignPortrait(
      WindowSizeController.normalizePipPortraitGeometry({
        'windowsPipPortrait': {
          'displayId': displayId,
          'windowsPipPortraitWidth': size.width,
          'windowsPipPortraitHeight': size.height,
          'windowsPipPortraitX': position.dx,
          'windowsPipPortraitY': position.dy,
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
    clearPortrait();
  }

  void clearPortrait() {
    portraitDisplayId.v = '';
    portraitWidth.v = 0.0;
    portraitHeight.v = 0.0;
    portraitX.v = 0.0;
    portraitY.v = 0.0;
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

  Map<String, dynamic> portraitToJson() {
    return WindowSizeController.normalizePipPortraitGeometry({
      'windowsPipPortrait': {
        'displayId': portraitDisplayId.v,
        'windowsPipPortraitWidth': portraitWidth.v,
        'windowsPipPortraitHeight': portraitHeight.v,
        'windowsPipPortraitX': portraitX.v,
        'windowsPipPortraitY': portraitY.v,
      },
    });
  }

  void fromJson(Map<String, dynamic> json) {
    _assign(WindowSizeController.normalizePipGeometry(json, strict: true));
  }

  void fromPortraitJson(Map<String, dynamic> json) {
    _assignPortrait(WindowSizeController.normalizePipPortraitGeometry(json, strict: true));
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

  void _assignPortrait(Map<String, dynamic> values) {
    portraitDisplayId.v = values['displayId'] as String;
    portraitWidth.v = values['windowsPipPortraitWidth'] as double;
    portraitHeight.v = values['windowsPipPortraitHeight'] as double;
    portraitX.v = values['windowsPipPortraitX'] as double;
    portraitY.v = values['windowsPipPortraitY'] as double;
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
      'windowsPipPortrait': windowsPip.portraitToJson(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    _writeStoredSize(Size(parsed['storedWidth'] as double, parsed['storedHeight'] as double));
    rememberPipPosition.v = parsed['rememberPipPosition'];
    windowsPip.fromJson(parsed['windowsPip']);
    windowsPip.fromPortraitJson(parsed['windowsPipPortrait']);
  }

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    final width = _parseStoredDimension(json['storedWidth'], fallback: defaultWindowWidth, min: minWindowWidth);
    final height = _parseStoredDimension(json['storedHeight'], fallback: defaultWindowHeight, min: minWindowHeight);
    return {
      'storedWidth': width,
      'storedHeight': height,
      'rememberPipPosition': json['rememberPipPosition'] as bool? ?? true,
      'windowsPip': normalizePipGeometry(json, strict: true),
      'windowsPipPortrait': normalizePipPortraitGeometry(json, strict: true),
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
    final portraitPip = parsed['windowsPipPortrait'] as Map<String, dynamic>;

    return {
      'storedWidth': parsed['storedWidth'],
      'storedHeight': parsed['storedHeight'],
      'rememberPipPosition': parsed['rememberPipPosition'],
      'windowsPip': pip,
      'windowsPipPortrait': portraitPip,
      // Keep the legacy aliases in extracted configuration so older backup
      // editors and downgrade imports preserve the rectangle losslessly.
      'windowsPipDisplayId': pip['displayId'],
      'windowsPipWidth': pip['windowsPipWidth'],
      'windowsPipHeight': pip['windowsPipHeight'],
      'windowsPipX': pip['windowsPipX'],
      'windowsPipY': pip['windowsPipY'],
      'windowsPipPortraitDisplayId': portraitPip['displayId'],
      'windowsPipPortraitWidth': portraitPip['windowsPipPortraitWidth'],
      'windowsPipPortraitHeight': portraitPip['windowsPipPortraitHeight'],
      'windowsPipPortraitX': portraitPip['windowsPipPortraitX'],
      'windowsPipPortraitY': portraitPip['windowsPipPortraitY'],
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

    if (updateFields.keys.any(_isLegacyPipPortraitGeometryKey)) {
      final pip = normalizePipPortraitGeometry(windowSize);
      const aliases = <String, String>{
        'windowsPipPortraitDisplayId': 'displayId',
        'windowsPipPortraitWidth': 'windowsPipPortraitWidth',
        'windowsPipPortraitHeight': 'windowsPipPortraitHeight',
        'windowsPipPortraitX': 'windowsPipPortraitX',
        'windowsPipPortraitY': 'windowsPipPortraitY',
      };
      for (final alias in aliases.entries) {
        if (updateFields.containsKey(alias.key)) {
          pip[alias.value] = updateFields[alias.key];
        }
      }
      windowSize['windowsPipPortrait'] = pip;
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

  static bool _isLegacyPipPortraitGeometryKey(String key) =>
      key == 'windowsPipPortraitDisplayId' ||
      key == 'windowsPipPortraitWidth' ||
      key == 'windowsPipPortraitHeight' ||
      key == 'windowsPipPortraitX' ||
      key == 'windowsPipPortraitY';

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
    return _normalizePipRect(windowSize, section: 'windowsPip', prefix: 'windowsPip', strict: strict);
  }

  /// 竖屏源的 PiP 矩形。
  ///
  /// 与横屏那套共用同一段校验（[_normalizePipRect] 只按前缀取键），所以两套的有限性、
  /// 上下限与清零规则不会再分叉——2026-08-27 加过的那套竖屏几何就是在一处合并里被整个
  /// 丢掉的。旧版本把竖屏字段平铺在 `windowsPip` 段里（`portraitWidth` 等），这里一并
  /// 作为备选键读回，那时的备份仍然可用。
  static Map<String, dynamic> normalizePipPortraitGeometry(Map<String, dynamic> windowSize, {bool strict = false}) {
    return _normalizePipRect(
      windowSize,
      section: 'windowsPipPortrait',
      prefix: 'windowsPipPortrait',
      legacyPrefix: 'portrait',
      strict: strict,
    );
  }

  static Map<String, dynamic> _normalizePipRect(
    Map<String, dynamic> windowSize, {
    required String section,
    required String prefix,
    String? legacyPrefix,
    bool strict = false,
  }) {
    final nested = windowSize[section];
    if (strict && nested != null && nested is! Map) throw const FormatException('Invalid PiP rectangle');
    final pip = nested is Map ? Map<String, dynamic>.from(nested) : const <String, dynamic>{};
    final legacy = legacyPrefix == null || windowSize['windowsPip'] is! Map
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(windowSize['windowsPip'] as Map);

    double number(String suffix) {
      final value =
          pip['$prefix$suffix'] ??
          (legacyPrefix == null ? null : legacy['$legacyPrefix$suffix']) ??
          windowSize['$prefix$suffix'];
      if (strict && value != null && (value is! num || !value.isFinite)) {
        throw FormatException('Invalid PiP coordinate: $prefix$suffix');
      }
      return value is num ? value.toDouble() : 0.0;
    }

    final displayValue =
        pip['displayId'] ??
        (legacyPrefix == null ? null : legacy['${legacyPrefix}DisplayId']) ??
        windowSize['${prefix}DisplayId'];
    final displayId = strict ? (displayValue as String? ?? '') : (displayValue?.toString() ?? '');
    final width = number('Width');
    final height = number('Height');
    final x = number('X');
    final y = number('Y');
    if (!width.isFinite || !height.isFinite || !x.isFinite || !y.isFinite || width <= 0 || height <= 0) {
      return <String, dynamic>{
        'displayId': '',
        '${prefix}Width': 0.0,
        '${prefix}Height': 0.0,
        '${prefix}X': 0.0,
        '${prefix}Y': 0.0,
      };
    }

    return <String, dynamic>{
      'displayId': displayId.trim(),
      '${prefix}Width': width.clamp(0.0, maxWindowDimension).toDouble(),
      '${prefix}Height': height.clamp(0.0, maxWindowDimension).toDouble(),
      '${prefix}X': x,
      '${prefix}Y': y,
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
