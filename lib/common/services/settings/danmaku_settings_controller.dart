import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/display_mode_service.dart';
import 'package:pure_live/common/models/app_refresh_rate_mode.dart';

class DanmakuSettingsController extends GetxController {
  static const bool defaultEnablePipDanmaku = true;
  static const bool defaultPipDanmakuAutoScale = true;
  static const bool defaultPipDanmakuUseOriginalColor = true;
  static const int defaultPipDanmakuColor = 0xFFFFFFFF;
  static const double defaultPipDanmakuFontSize = 12.0;
  static const int defaultPipDanmakuFontWeight = 500;
  static const double defaultPipDanmakuSpeed = 90.0;
  static const double defaultPipDanmakuOpacity = 0.9;
  static const double defaultPipDanmakuArea = 0.5;
  static const int defaultPipDanmakuMaxVisibleCount = 6;
  static const double defaultPipDanmakuEmitInterval = 0.35;
  static const int defaultPipDanmakuFps = 30;
  static const bool defaultNoEmojiMode = false;
  static const bool defaultPipDanmakuNoEmojiMode = false;

  static int normalizeFontWeight(Object? value, {int fallback = 500}) {
    final raw = value is num ? value.toInt() : fallback;
    return ((raw.clamp(100, 900) / 100).round() * 100).clamp(100, 900).toInt();
  }

  final RxBool hideDanmaku = hiveBool('hideDanmaku', false);
  final RxBool noEmojiMode = hiveBool('noEmojiMode', defaultNoEmojiMode);
  final RxDouble danmakuTopArea = hiveDouble('danmakuTopArea', 0.0);
  final RxDouble danmakuArea = hiveDouble('danmakuArea', 1.0);
  final RxDouble danmakuBottomArea = hiveDouble('danmakuBottomArea', 0.5);
  final RxDouble danmakuSpeed = hiveDouble('danmakuSpeed', 120.0);
  final RxDouble danmakuFontSize = hiveDouble('danmakuFontSize', 16.0);
  final RxInt danmakuFontWeight = hiveInt('danmakuFontWeight', 500);
  final RxDouble danmakuFontBorder = hiveDouble('danmakuFontBorder', 1.5);
  final RxDouble danmakuOpacity = hiveDouble('danmakuOpacity', 1.0);
  final RxBool enableDanmakuDisplay = hiveBool('enableDanmakuDisplay', true);
  final RxBool enableDanmakuStroke = hiveBool('enableDanmakuStroke', true);
  final RxInt danmakuFps = hiveInt('danmakuFps', 60);
  final RxBool danmakuAutoFps = hiveBool('danmakuAutoFps', true);
  final RxBool enableDanmakuTapInteraction = hiveBool('enableDanmakuTapInteraction', true);
  final RxBool enableDanmakuLongPressInteraction = hiveBool('enableDanmakuLongPressInteraction', true);
  final RxBool collapseRepeatedDanmaku = hiveBool('collapseRepeatedDanmaku', false);
  final RxInt repeatedDanmakuWindowSeconds = hiveInt('repeatedDanmakuWindowSeconds', 5);
  final RxInt danmakuInteractionMigration = hiveInt('danmakuInteractionMigration', 0);
  final RxString savedDanmakuTemplate = hiveString('savedDanmakuTemplate', '');
  final RxString danmakuFontFamilyName = hiveString('danmakuFontFamilyName', 'Default');
  final RxBool enablePipDanmaku = hiveBool('enablePipDanmaku', defaultEnablePipDanmaku);
  final RxBool pipDanmakuAutoScale = hiveBool('pipDanmakuAutoScale', defaultPipDanmakuAutoScale);
  // Keep the upstream storage key for existing users while exposing a
  // consistently-spelled Dart API and backup key.
  final RxBool pipDanmakuNoEmojiMode = hiveBool('pipDanmaNoEmojiMode', defaultPipDanmakuNoEmojiMode);
  final RxBool pipDanmakuUseOriginalColor = hiveBool('pipDanmakuUseOriginalColor', defaultPipDanmakuUseOriginalColor);
  final RxInt pipDanmakuColor = hiveInt('pipDanmakuColor', defaultPipDanmakuColor);
  final RxDouble pipDanmakuFontSize = hiveDouble('pipDanmakuFontSize', defaultPipDanmakuFontSize);
  final RxInt pipDanmakuFontWeight = hiveInt('pipDanmakuFontWeight', 500);
  final RxDouble pipDanmakuSpeed = hiveDouble('pipDanmakuSpeed', defaultPipDanmakuSpeed);
  final RxDouble pipDanmakuOpacity = hiveDouble('pipDanmakuOpacity', defaultPipDanmakuOpacity);
  final RxDouble pipDanmakuArea = hiveDouble('pipDanmakuArea', defaultPipDanmakuArea);
  final RxInt pipDanmakuMaxVisibleCount = hiveInt('pipDanmakuMaxVisibleCount', defaultPipDanmakuMaxVisibleCount);
  final RxDouble pipDanmakuEmitInterval = hiveDouble('pipDanmakuEmitInterval', defaultPipDanmakuEmitInterval);
  final RxInt pipDanmakuFps = hiveInt('pipDanmakuFps', defaultPipDanmakuFps);
  final RxBool pipDanmakuAutoFps = hiveBool('pipDanmakuAutoFps', true);

  //   Enable danmaku Similarity Filter
  final RxBool enableDanmakuSimilarityFilter = hiveBool('enableDanmakuSimilarityFilter', true);
  final RxInt danmakuSimilarityThreshold = hiveInt('danmakuSimilarityThreshold', 85);
  final RxInt danmakuSimilarityCacheDuration = hiveInt('danmakuSimilarityCacheDuration', 3);
  final RxInt danmakuSimilarityMaxCacheSize = hiveInt('danmakuSimilarityMaxCacheSize', 100);
  @override
  void onInit() {
    super.onInit();
    danmakuFontWeight.v = normalizeFontWeight(danmakuFontWeight.v);
    pipDanmakuFontWeight.v = normalizeFontWeight(pipDanmakuFontWeight.v);
    danmakuSimilarityThreshold.v = danmakuSimilarityThreshold.v.clamp(50, 100).toInt();
    danmakuSimilarityCacheDuration.v = danmakuSimilarityCacheDuration.v.clamp(1, 60).toInt();
    danmakuSimilarityMaxCacheSize.v = danmakuSimilarityMaxCacheSize.v.clamp(20, 1000).toInt();
    if (danmakuInteractionMigration.v < 1) {
      enableDanmakuTapInteraction.v = true;
      enableDanmakuLongPressInteraction.v = true;
      danmakuInteractionMigration.v = 1;
    }
  }

  int resolvedDanmakuFps({bool pip = false, AppRefreshRateMode refreshRateMode = AppRefreshRateMode.powerSaving}) {
    final auto = pip ? pipDanmakuAutoFps.v : danmakuAutoFps.v;
    final configured = pip ? pipDanmakuFps.v : danmakuFps.v;
    if (!auto) return configured.clamp(pip ? 15 : 30, 240).toInt();
    return resolveAdaptiveDanmakuFps(DisplayModeService.info.value, pip: pip, refreshRateMode: refreshRateMode);
  }

  /// Resolves both room and PiP renderers from the single interface policy.
  ///
  /// Power saving keeps the existing 60/30 caps, balanced gives both surfaces
  /// a stable 60 FPS budget while touch-driven UI can temporarily use the
  /// display maximum, and Highest follows the detected device maximum for all
  /// UI/danmaku surfaces. A local manual value remains an explicit override.
  static int resolveAdaptiveDanmakuFps(
    DisplayModeInfo? display, {
    bool pip = false,
    AppRefreshRateMode refreshRateMode = AppRefreshRateMode.powerSaving,
  }) {
    final current = display?.currentRefreshRate ?? 0;
    final maximum = display?.maxRefreshRate ?? 0;
    final detected = maximum > 0 ? maximum : (current > 0 ? current : 60);
    final deviceMaximum = detected.round().clamp(pip ? 15 : 30, 240).toInt();
    return switch (refreshRateMode) {
      AppRefreshRateMode.powerSaving => deviceMaximum.clamp(pip ? 15 : 30, pip ? 30 : 60).toInt(),
      AppRefreshRateMode.balanced => deviceMaximum.clamp(pip ? 15 : 30, 60).toInt(),
      AppRefreshRateMode.performance => deviceMaximum,
    };
  }

  void resetPipDanmaku() {
    enablePipDanmaku.v = defaultEnablePipDanmaku;
    pipDanmakuAutoScale.v = defaultPipDanmakuAutoScale;
    pipDanmakuNoEmojiMode.v = defaultPipDanmakuNoEmojiMode;
    pipDanmakuUseOriginalColor.v = defaultPipDanmakuUseOriginalColor;
    pipDanmakuColor.v = defaultPipDanmakuColor;
    pipDanmakuFontSize.v = defaultPipDanmakuFontSize;
    pipDanmakuFontWeight.v = defaultPipDanmakuFontWeight;
    pipDanmakuSpeed.v = defaultPipDanmakuSpeed;
    pipDanmakuOpacity.v = defaultPipDanmakuOpacity;
    pipDanmakuArea.v = defaultPipDanmakuArea;
    pipDanmakuMaxVisibleCount.v = defaultPipDanmakuMaxVisibleCount;
    pipDanmakuEmitInterval.v = defaultPipDanmakuEmitInterval;
    pipDanmakuFps.v = defaultPipDanmakuFps;
    pipDanmakuAutoFps.v = true;
  }

  Map<String, dynamic> toJson() {
    return {
      'hideDanmaku': hideDanmaku.v,
      'noEmojiMode': noEmojiMode.v,
      'danmakuTopArea': danmakuTopArea.v,
      'danmakuArea': danmakuArea.v,
      'danmakuBottomArea': danmakuBottomArea.v,
      'danmakuSpeed': danmakuSpeed.v,
      'danmakuFontSize': danmakuFontSize.v,
      'danmakuFontWeight': danmakuFontWeight.v,
      'danmakuFontBorder': danmakuFontBorder.v,
      'danmakuOpacity': danmakuOpacity.v,
      'enableDanmakuDisplay': enableDanmakuDisplay.v,
      'danmakuFontFamilyName': danmakuFontFamilyName.v,
      'enableDanmakuStroke': enableDanmakuStroke.v,
      'danmakuFps': danmakuFps.v,
      'danmakuAutoFps': danmakuAutoFps.v,
      'enableDanmakuTapInteraction': enableDanmakuTapInteraction.v,
      'enableDanmakuLongPressInteraction': enableDanmakuLongPressInteraction.v,
      'collapseRepeatedDanmaku': collapseRepeatedDanmaku.v,
      'repeatedDanmakuWindowSeconds': repeatedDanmakuWindowSeconds.v,
      'savedDanmakuTemplate': savedDanmakuTemplate.v,
      'enablePipDanmaku': enablePipDanmaku.v,
      'pipDanmakuAutoScale': pipDanmakuAutoScale.v,
      'pipDanmakuNoEmojiMode': pipDanmakuNoEmojiMode.v,
      'pipDanmakuUseOriginalColor': pipDanmakuUseOriginalColor.v,
      'pipDanmakuColor': pipDanmakuColor.v,
      'pipDanmakuFontSize': pipDanmakuFontSize.v,
      'pipDanmakuFontWeight': pipDanmakuFontWeight.v,
      'pipDanmakuSpeed': pipDanmakuSpeed.v,
      'pipDanmakuOpacity': pipDanmakuOpacity.v,
      'pipDanmakuArea': pipDanmakuArea.v,
      'pipDanmakuMaxVisibleCount': pipDanmakuMaxVisibleCount.v,
      'pipDanmakuEmitInterval': pipDanmakuEmitInterval.v,
      'pipDanmakuFps': pipDanmakuFps.v,
      'pipDanmakuAutoFps': pipDanmakuAutoFps.v,
      'enableDanmakuSimilarityFilter': enableDanmakuSimilarityFilter.v,
      'danmakuSimilarityThreshold': danmakuSimilarityThreshold.v,
      'danmakuSimilarityCacheDuration': danmakuSimilarityCacheDuration.v,
      'danmakuSimilarityMaxCacheSize': danmakuSimilarityMaxCacheSize.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    hideDanmaku.v = json['hideDanmaku'] ?? false;
    noEmojiMode.v = json['noEmojiMode'] ?? defaultNoEmojiMode;
    danmakuTopArea.v = json['danmakuTopArea']?.toDouble() ?? 0.0;
    danmakuArea.v = json['danmakuArea']?.toDouble() ?? 1.0;
    danmakuBottomArea.v = json['danmakuBottomArea']?.toDouble() ?? 0.5;
    danmakuSpeed.v = (json['danmakuSpeed'] ?? 120.0).toDouble().clamp(20.0, 400.0).toDouble();
    danmakuFontSize.v = json['danmakuFontSize']?.toDouble() ?? 16.0;
    danmakuFontWeight.v = normalizeFontWeight(json['danmakuFontWeight']);
    danmakuFontBorder.v = (json['danmakuFontBorder']?.toDouble() ?? 1.5).clamp(0.0, 4.0).toDouble();
    danmakuOpacity.v = json['danmakuOpacity']?.toDouble() ?? 1.0;
    enableDanmakuDisplay.v = json['enableDanmakuDisplay'] ?? true;
    danmakuFontFamilyName.v = json['danmakuFontFamilyName'] ?? 'Default';
    enableDanmakuStroke.v = json['enableDanmakuStroke'] ?? true;
    danmakuFps.v = json['danmakuFps']?.toInt() ?? 60;
    danmakuAutoFps.v = json['danmakuAutoFps'] ?? true;
    enableDanmakuTapInteraction.v = json['enableDanmakuTapInteraction'] ?? true;
    enableDanmakuLongPressInteraction.v = json['enableDanmakuLongPressInteraction'] ?? true;
    collapseRepeatedDanmaku.v = json['collapseRepeatedDanmaku'] ?? false;
    repeatedDanmakuWindowSeconds.v = (json['repeatedDanmakuWindowSeconds'] ?? 5).toInt().clamp(1, 30).toInt();
    savedDanmakuTemplate.v = json['savedDanmakuTemplate']?.toString() ?? '';
    enablePipDanmaku.v = json['enablePipDanmaku'] ?? defaultEnablePipDanmaku;
    pipDanmakuAutoScale.v = json['pipDanmakuAutoScale'] ?? defaultPipDanmakuAutoScale;
    pipDanmakuNoEmojiMode.v =
        json['pipDanmakuNoEmojiMode'] ?? json['pipDanmaNoEmojiMode'] ?? defaultPipDanmakuNoEmojiMode;
    pipDanmakuUseOriginalColor.v = json['pipDanmakuUseOriginalColor'] ?? defaultPipDanmakuUseOriginalColor;
    pipDanmakuColor.v = json['pipDanmakuColor']?.toInt() ?? defaultPipDanmakuColor;
    pipDanmakuFontSize.v = (json['pipDanmakuFontSize'] ?? defaultPipDanmakuFontSize)
        .toDouble()
        .clamp(8.0, 24.0)
        .toDouble();
    pipDanmakuFontWeight.v = normalizeFontWeight(json['pipDanmakuFontWeight']);
    pipDanmakuSpeed.v = (json['pipDanmakuSpeed'] ?? defaultPipDanmakuSpeed).toDouble().clamp(20.0, 400.0).toDouble();
    pipDanmakuOpacity.v = (json['pipDanmakuOpacity'] ?? defaultPipDanmakuOpacity).toDouble().clamp(0.1, 1.0).toDouble();
    pipDanmakuArea.v = (json['pipDanmakuArea'] ?? defaultPipDanmakuArea).toDouble().clamp(0.1, 1.0).toDouble();
    pipDanmakuMaxVisibleCount.v = (json['pipDanmakuMaxVisibleCount'] ?? defaultPipDanmakuMaxVisibleCount)
        .toInt()
        .clamp(1, 20)
        .toInt();
    pipDanmakuEmitInterval.v = (json['pipDanmakuEmitInterval'] ?? defaultPipDanmakuEmitInterval)
        .toDouble()
        .clamp(0.05, 2.0)
        .toDouble();
    pipDanmakuFps.v = (json['pipDanmakuFps'] ?? defaultPipDanmakuFps).toInt().clamp(15, 240).toInt();
    pipDanmakuAutoFps.v = json['pipDanmakuAutoFps'] ?? true;
    enableDanmakuSimilarityFilter.v = json['enableDanmakuSimilarityFilter'] ?? true;
    danmakuSimilarityThreshold.v = (json['danmakuSimilarityThreshold'] ?? 85).toInt().clamp(50, 100).toInt();
    danmakuSimilarityCacheDuration.v = (json['danmakuSimilarityCacheDuration'] ?? 3).toInt().clamp(1, 60).toInt();
    danmakuSimilarityMaxCacheSize.v = (json['danmakuSimilarityMaxCacheSize'] ?? 100).toInt().clamp(20, 1000).toInt();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final danmaku = rootConfig?['danmaku'] as Map<String, dynamic>? ?? {};
    return {
      'hideDanmaku': danmaku['hideDanmaku'] ?? false,
      'noEmojiMode': danmaku['noEmojiMode'] ?? defaultNoEmojiMode,
      'danmakuTopArea': (danmaku['danmakuTopArea'] ?? 0.0).toDouble(),
      'danmakuArea': (danmaku['danmakuArea'] ?? 1.0).toDouble(),
      'danmakuBottomArea': (danmaku['danmakuBottomArea'] ?? 0.5).toDouble(),
      'danmakuSpeed': (danmaku['danmakuSpeed'] ?? 120.0).toDouble().clamp(20.0, 400.0).toDouble(),
      'danmakuFontSize': (danmaku['danmakuFontSize'] ?? 16.0).toDouble(),
      'danmakuFontWeight': normalizeFontWeight(danmaku['danmakuFontWeight']),
      'danmakuFontBorder': (danmaku['danmakuFontBorder'] ?? 1.5).toDouble().clamp(0.0, 4.0).toDouble(),
      'danmakuOpacity': (danmaku['danmakuOpacity'] ?? 1.0).toDouble(),
      'enableDanmakuDisplay': danmaku['enableDanmakuDisplay'] ?? true,
      'danmakuFontFamilyName': danmaku['danmakuFontFamilyName'] ?? 'Default',
      'enableDanmakuStroke': danmaku['enableDanmakuStroke'] ?? true,
      'danmakuFps': (danmaku['danmakuFps'] ?? 60).toInt(),
      'danmakuAutoFps': danmaku['danmakuAutoFps'] ?? true,
      'enableDanmakuTapInteraction': danmaku['enableDanmakuTapInteraction'] ?? true,
      'enableDanmakuLongPressInteraction': danmaku['enableDanmakuLongPressInteraction'] ?? true,
      'collapseRepeatedDanmaku': danmaku['collapseRepeatedDanmaku'] ?? false,
      'repeatedDanmakuWindowSeconds': (danmaku['repeatedDanmakuWindowSeconds'] ?? 5).toInt().clamp(1, 30).toInt(),
      'savedDanmakuTemplate': danmaku['savedDanmakuTemplate']?.toString() ?? '',
      'enablePipDanmaku': danmaku['enablePipDanmaku'] ?? defaultEnablePipDanmaku,
      'pipDanmakuAutoScale': danmaku['pipDanmakuAutoScale'] ?? defaultPipDanmakuAutoScale,
      'pipDanmakuNoEmojiMode':
          danmaku['pipDanmakuNoEmojiMode'] ?? danmaku['pipDanmaNoEmojiMode'] ?? defaultPipDanmakuNoEmojiMode,
      'pipDanmakuUseOriginalColor': danmaku['pipDanmakuUseOriginalColor'] ?? defaultPipDanmakuUseOriginalColor,
      'pipDanmakuColor': (danmaku['pipDanmakuColor'] ?? defaultPipDanmakuColor).toInt(),
      'pipDanmakuFontSize': (danmaku['pipDanmakuFontSize'] ?? defaultPipDanmakuFontSize)
          .toDouble()
          .clamp(8.0, 24.0)
          .toDouble(),
      'pipDanmakuFontWeight': normalizeFontWeight(
        danmaku['pipDanmakuFontWeight'],
        fallback: defaultPipDanmakuFontWeight,
      ),
      'pipDanmakuSpeed': (danmaku['pipDanmakuSpeed'] ?? defaultPipDanmakuSpeed)
          .toDouble()
          .clamp(20.0, 400.0)
          .toDouble(),
      'pipDanmakuOpacity': (danmaku['pipDanmakuOpacity'] ?? defaultPipDanmakuOpacity)
          .toDouble()
          .clamp(0.1, 1.0)
          .toDouble(),
      'pipDanmakuArea': (danmaku['pipDanmakuArea'] ?? defaultPipDanmakuArea).toDouble().clamp(0.1, 1.0).toDouble(),
      'pipDanmakuMaxVisibleCount': (danmaku['pipDanmakuMaxVisibleCount'] ?? defaultPipDanmakuMaxVisibleCount)
          .toInt()
          .clamp(1, 20)
          .toInt(),
      'pipDanmakuEmitInterval': (danmaku['pipDanmakuEmitInterval'] ?? defaultPipDanmakuEmitInterval)
          .toDouble()
          .clamp(0.05, 2.0)
          .toDouble(),
      'pipDanmakuFps': (danmaku['pipDanmakuFps'] ?? defaultPipDanmakuFps).toInt().clamp(15, 240).toInt(),
      'pipDanmakuAutoFps': danmaku['pipDanmakuAutoFps'] ?? true,
      'enableDanmakuSimilarityFilter': danmaku['enableDanmakuSimilarityFilter'] ?? true,
      'danmakuSimilarityThreshold': (danmaku['danmakuSimilarityThreshold'] ?? 85).toInt().clamp(50, 100).toInt(),
      'danmakuSimilarityCacheDuration': (danmaku['danmakuSimilarityCacheDuration'] ?? 3).toInt().clamp(1, 60).toInt(),
      'danmakuSimilarityMaxCacheSize': (danmaku['danmakuSimilarityMaxCacheSize'] ?? 100)
          .toInt()
          .clamp(20, 1000)
          .toInt(),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final danmaku = Map<String, dynamic>.from(rootConfig['danmaku'] ?? {});
    updateFields.forEach((k, v) => danmaku[k] = v);
    rootConfig['danmaku'] = danmaku;
    return rootConfig;
  }
}
