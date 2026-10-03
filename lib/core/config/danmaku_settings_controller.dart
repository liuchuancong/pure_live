import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/storage/hive_rx.dart';
import 'package:pure_live/core/config/display_mode_service.dart';
import 'package:pure_live/core/models/app_refresh_rate_mode.dart';

class DanmakuSettingsController extends GetxController {
  static const double defaultDanmakuTopArea = 0.0;
  static const double defaultDanmakuArea = 1.0;
  static const double defaultDanmakuBottomArea = 0.5;
  static const double defaultDanmakuSpeed = 120.0;
  static const double defaultDanmakuFontSize = 16.0;
  static const int defaultDanmakuFontWeight = 500;
  static const double defaultDanmakuFontBorder = 1.5;
  static const double defaultDanmakuOpacity = 1.0;
  static const int defaultDanmakuFps = 60;
  static const bool defaultDanmakuAutoFps = true;
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
  static const bool defaultPipDanmakuAutoFps = true;
  static const bool defaultNoEmojiMode = false;
  static const bool defaultPipDanmakuNoEmojiMode = false;

  /// 小窗弹幕比例的取值区间：只做缩小，1.0 表示与主弹幕同样大小。
  ///
  /// 小窗比房间画面小，弹幕不该比主画面更大；滑块、恢复备份的钳制和小窗渲染策略
  /// 共用这两个常量，避免三处各写一份范围而漂移。
  static const double pipDanmakuScaleMin = 0.4;
  static const double pipDanmakuScaleMax = 1.0;
  static const double defaultPipDanmakuScaleValue = 0.4;
  // Completeness is the safe default: `dms` and `if` are optional decoration
  // markers rather than a protocol-level visibility contract. Users can still
  // opt into the heuristic when they prefer a quieter room feed.
  static const bool defaultFilterDouyuSuspectedAutomatedMessages = false;
  // Preserve the complete platform feed unless the user explicitly chooses
  // fuzzy suppression. Enabling this by default can hide a large share of
  // short messages in busy rooms even though the transport received them.
  static const bool defaultEnableDanmakuSimilarityFilter = false;

  static int normalizeFontWeight(Object? value, {int fallback = 500}) {
    final raw = value is num ? value.toInt() : fallback;
    return ((raw.clamp(100, 900) / 100).round() * 100).clamp(100, 900).toInt();
  }

  static double _boundedDouble(Object? value, {required double fallback, required double min, required double max}) {
    final raw = value == null ? fallback : (value as num).toDouble();
    if (!raw.isFinite) return fallback;
    return raw.clamp(min, max).toDouble();
  }

  static int _boundedInt(Object? value, {required int fallback, required int min, required int max}) {
    final rawNumber = value == null ? fallback.toDouble() : (value as num).toDouble();
    if (!rawNumber.isFinite) return fallback;
    return rawNumber.toInt().clamp(min, max).toInt();
  }

  final RxBool hideDanmaku = hiveBool('hideDanmaku', false);
  final RxBool noEmojiMode = hiveBool('noEmojiMode', defaultNoEmojiMode);
  final RxDouble danmakuTopArea = hiveDouble('danmakuTopArea', defaultDanmakuTopArea);
  final RxDouble danmakuArea = hiveDouble('danmakuArea', defaultDanmakuArea);
  final RxDouble danmakuBottomArea = hiveDouble('danmakuBottomArea', defaultDanmakuBottomArea);
  final RxDouble danmakuSpeed = hiveDouble('danmakuSpeed', defaultDanmakuSpeed);
  final RxDouble danmakuFontSize = hiveDouble('danmakuFontSize', defaultDanmakuFontSize);
  final RxInt danmakuFontWeight = hiveInt('danmakuFontWeight', defaultDanmakuFontWeight);
  final RxDouble danmakuFontBorder = hiveDouble('danmakuFontBorder', defaultDanmakuFontBorder);
  final RxDouble danmakuOpacity = hiveDouble('danmakuOpacity', defaultDanmakuOpacity);

  /// Same-screen cap forwarded to FlameBarrageWidget.maxVisibleCount.
  final RxInt danmakuMaxVisibleCount = hiveInt('danmakuMaxVisibleCount', 48);
  final RxBool enableDanmakuStroke = hiveBool('enableDanmakuStroke', true);

  /// 海量模式：弹幕到达立即上屏（不再按 emit-interval 排队），同时同屏条数不再
  /// 受 [danmakuMaxVisibleCount] 截断 —— 真实上限交给轨道排布与画面几何。
  ///
  /// Hive 键沿用旧名 `danmakuRealtimeMode`（原「突发即时显示」），这样老用户已经
  /// 打开过的选择在升级后依然生效。
  final RxBool danmakuMassMode = hiveBool('danmakuRealtimeMode', false);

  /// 海量模式生效时的同屏上限。
  ///
  /// 这个数不是密度策略，只是把 `maxVisibleCount` 这道闸门抬到轨道几何之上：
  /// 真正能同时上屏多少条仍由轨道间距、字号和画面高度决定。
  static const int massModeMaxVisibleCount = 1000;

  /// 当前生效的同屏上限：海量模式不再受设置里的条数限制。
  int get effectiveMaxVisibleCount => danmakuMassMode.v ? massModeMaxVisibleCount : danmakuMaxVisibleCount.v;

  final RxDouble danmakuLetterSpacing = hiveDouble('danmakuLetterSpacing', 0.0);
  final RxInt danmakuFps = hiveInt('danmakuFps', defaultDanmakuFps);
  final RxBool danmakuAutoFps = hiveBool('danmakuAutoFps', defaultDanmakuAutoFps);
  final RxBool enableDanmakuTapInteraction = hiveBool('enableDanmakuTapInteraction', true);
  final RxBool enableDanmakuLongPressInteraction = hiveBool('enableDanmakuLongPressInteraction', true);
  final RxBool collapseRepeatedDanmaku = hiveBool('collapseRepeatedDanmaku', false);
  final RxInt repeatedDanmakuWindowSeconds = hiveInt('repeatedDanmakuWindowSeconds', 5);
  final RxInt danmakuInteractionMigration = hiveInt('danmakuInteractionMigration', 0);
  final RxString savedDanmakuTemplate = hiveString('savedDanmakuTemplate', '');
  final RxString danmakuFontFamilyName = hiveString('danmakuFontFamilyName', 'Default');

  /// Scale factor applied on top of the main danmaku config when rendering
  /// the compact (picture-in-picture / small-window) surface. `null` means
  /// auto: the factor follows the compact window's width against the 350px
  /// reference. A number pins the factor explicitly.
  /// The old per-pip config cohort (font size, speed, opacity, ...) was
  /// folded into the main danmaku settings; these Hive keys are legacy.
  final RxBool pipDanmakuScaleAuto = hiveBool('pipDanmakuAutoScale', true);
  final RxDouble pipDanmakuScaleValue = hiveDouble('pipDanmakuScaleValue', defaultPipDanmakuScaleValue);

  // Douyu sometimes emits legitimate room-local chat packets without either
  // decoration/fan marker. Preserve them unless the user explicitly enables
  // the heuristic filter.
  final RxBool filterDouyuSuspectedAutomatedMessages = hiveBool(
    'filterDouyuSuspectedAutomatedMessages',
    defaultFilterDouyuSuspectedAutomatedMessages,
  );

  //   Enable danmaku Similarity Filter
  final RxBool enableDanmakuSimilarityFilter = hiveBool(
    'enableDanmakuSimilarityFilter',
    defaultEnableDanmakuSimilarityFilter,
  );
  final RxInt danmakuSimilarityThreshold = hiveInt('danmakuSimilarityThreshold', 85);
  final RxInt danmakuSimilarityCacheDuration = hiveInt('danmakuSimilarityCacheDuration', 3);
  final RxInt danmakuSimilarityMaxCacheSize = hiveInt('danmakuSimilarityMaxCacheSize', 100);
  @override
  void onInit() {
    super.onInit();
    danmakuTopArea.v = _boundedDouble(danmakuTopArea.v, fallback: defaultDanmakuTopArea, min: 0, max: 300);
    danmakuArea.v = _boundedDouble(danmakuArea.v, fallback: defaultDanmakuArea, min: 0, max: 1);
    danmakuBottomArea.v = _boundedDouble(danmakuBottomArea.v, fallback: defaultDanmakuBottomArea, min: 0, max: 300);
    danmakuSpeed.v = _boundedDouble(danmakuSpeed.v, fallback: defaultDanmakuSpeed, min: 20, max: 400);
    danmakuFontSize.v = _boundedDouble(danmakuFontSize.v, fallback: defaultDanmakuFontSize, min: 10, max: 30);
    danmakuFontWeight.v = normalizeFontWeight(danmakuFontWeight.v);
    danmakuFontBorder.v = _boundedDouble(danmakuFontBorder.v, fallback: defaultDanmakuFontBorder, min: 0, max: 4);
    danmakuLetterSpacing.v = _boundedDouble(danmakuLetterSpacing.v, fallback: 0.0, min: -2, max: 8);
    danmakuOpacity.v = _boundedDouble(danmakuOpacity.v, fallback: defaultDanmakuOpacity, min: 0, max: 1);
    danmakuFps.v = _boundedInt(danmakuFps.v, fallback: defaultDanmakuFps, min: 30, max: 240);
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
    // The compact surface shares the main danmaku FPS policy.
    final auto = danmakuAutoFps.v;
    final configured = danmakuFps.v;
    if (!auto) return configured.clamp(30, 240).toInt();
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

  Map<String, dynamic> toJson() {
    return {
      'hideDanmaku': hideDanmaku.v,
      'noEmojiMode': noEmojiMode.v,
      'danmakuTopArea': danmakuTopArea.v,
      'danmakuArea': danmakuArea.v,
      'danmakuMaxVisibleCount': danmakuMaxVisibleCount.v,
      'danmakuBottomArea': danmakuBottomArea.v,
      'danmakuSpeed': danmakuSpeed.v,
      'danmakuFontSize': danmakuFontSize.v,
      'danmakuFontWeight': danmakuFontWeight.v,
      'danmakuFontBorder': danmakuFontBorder.v,
      'danmakuLetterSpacing': danmakuLetterSpacing.v,
      // 备份键沿用旧名，老备份里的取值仍还原成海量模式。
      'danmakuRealtimeMode': danmakuMassMode.v,
      'danmakuOpacity': danmakuOpacity.v,
      'danmakuFontFamilyName': danmakuFontFamilyName.v,
      'enableDanmakuStroke': enableDanmakuStroke.v,
      'danmakuFps': danmakuFps.v,
      'danmakuAutoFps': danmakuAutoFps.v,
      'enableDanmakuTapInteraction': enableDanmakuTapInteraction.v,
      'enableDanmakuLongPressInteraction': enableDanmakuLongPressInteraction.v,
      'collapseRepeatedDanmaku': collapseRepeatedDanmaku.v,
      'repeatedDanmakuWindowSeconds': repeatedDanmakuWindowSeconds.v,
      'savedDanmakuTemplate': savedDanmakuTemplate.v,
      'pipDanmakuAutoScale': pipDanmakuScaleAuto.v,
      'pipDanmakuScaleValue': pipDanmakuScaleValue.v,
      'filterDouyuSuspectedAutomatedMessages': filterDouyuSuspectedAutomatedMessages.v,
      'enableDanmakuSimilarityFilter': enableDanmakuSimilarityFilter.v,
      'danmakuSimilarityThreshold': danmakuSimilarityThreshold.v,
      'danmakuSimilarityCacheDuration': danmakuSimilarityCacheDuration.v,
      'danmakuSimilarityMaxCacheSize': danmakuSimilarityMaxCacheSize.v,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    T typed<T>(dynamic value) => value as T;
    return {
      'hideDanmaku': typed<bool>(json['hideDanmaku'] ?? false),
      'noEmojiMode': typed<bool>(json['noEmojiMode'] ?? defaultNoEmojiMode),
      'danmakuTopArea': typed<double>(
        _boundedDouble(json['danmakuTopArea'], fallback: defaultDanmakuTopArea, min: 0, max: 300),
      ),
      'danmakuArea': typed<double>(_boundedDouble(json['danmakuArea'], fallback: defaultDanmakuArea, min: 0, max: 1)),
      'danmakuBottomArea': typed<double>(
        _boundedDouble(json['danmakuBottomArea'], fallback: defaultDanmakuBottomArea, min: 0, max: 300),
      ),
      'danmakuSpeed': typed<double>(
        _boundedDouble(json['danmakuSpeed'], fallback: defaultDanmakuSpeed, min: 20, max: 400),
      ),
      'danmakuFontSize': typed<double>(
        _boundedDouble(json['danmakuFontSize'], fallback: defaultDanmakuFontSize, min: 10, max: 30),
      ),
      'danmakuFontWeight': typed<int>(normalizeFontWeight(json['danmakuFontWeight'])),
      'danmakuFontBorder': typed<double>(
        _boundedDouble(json['danmakuFontBorder'], fallback: defaultDanmakuFontBorder, min: 0, max: 4),
      ),
      // fromJson 会读这两个键；漏在返回表里就是 null 赋值给 RxDouble/RxBool，
      // 恢复备份会在这一行抛错并中断整段导入。
      'danmakuLetterSpacing': typed<double>(
        _boundedDouble(json['danmakuLetterSpacing'], fallback: 0.0, min: -2, max: 8),
      ),
      // 备份键沿用旧名，键名不变才能读回老备份。
      'danmakuRealtimeMode': typed<bool>(json['danmakuRealtimeMode'] ?? false),
      'danmakuOpacity': typed<double>(
        _boundedDouble(json['danmakuOpacity'], fallback: defaultDanmakuOpacity, min: 0, max: 1),
      ),
      'danmakuFontFamilyName': typed<String>(json['danmakuFontFamilyName'] ?? 'Default'),
      'enableDanmakuStroke': typed<bool>(json['enableDanmakuStroke'] ?? true),
      'danmakuFps': typed<int>(_boundedInt(json['danmakuFps'], fallback: defaultDanmakuFps, min: 30, max: 240)),
      'danmakuAutoFps': typed<bool>(json['danmakuAutoFps'] ?? defaultDanmakuAutoFps),
      'enableDanmakuTapInteraction': typed<bool>(json['enableDanmakuTapInteraction'] ?? true),
      'enableDanmakuLongPressInteraction': typed<bool>(json['enableDanmakuLongPressInteraction'] ?? true),
      'collapseRepeatedDanmaku': typed<bool>(json['collapseRepeatedDanmaku'] ?? false),
      'repeatedDanmakuWindowSeconds': typed<int>(
        (json['repeatedDanmakuWindowSeconds'] ?? 5).toInt().clamp(1, 30).toInt(),
      ),
      'savedDanmakuTemplate': typed<String>(json['savedDanmakuTemplate']?.toString() ?? ''),
      'pipDanmakuAutoScale': typed<bool>(json['pipDanmakuAutoScale'] ?? true),
      'pipDanmakuScaleValue': typed<double>(
        // 只做缩小：>1 会让小窗弹幕比主弹幕还大，与设置意图相反。
        (json['pipDanmakuScaleValue'] ?? defaultPipDanmakuScaleValue)
            .toDouble()
            .clamp(pipDanmakuScaleMin, pipDanmakuScaleMax)
            .toDouble(),
      ),
      'filterDouyuSuspectedAutomatedMessages': typed<bool>(
        json['filterDouyuSuspectedAutomatedMessages'] ?? defaultFilterDouyuSuspectedAutomatedMessages,
      ),
      'enableDanmakuSimilarityFilter': typed<bool>(
        json['enableDanmakuSimilarityFilter'] ?? defaultEnableDanmakuSimilarityFilter,
      ),
      'danmakuSimilarityThreshold': typed<int>(
        (json['danmakuSimilarityThreshold'] ?? 85).toInt().clamp(50, 100).toInt(),
      ),
      'danmakuSimilarityCacheDuration': typed<int>(
        (json['danmakuSimilarityCacheDuration'] ?? 3).toInt().clamp(1, 60).toInt(),
      ),
      'danmakuSimilarityMaxCacheSize': typed<int>(
        (json['danmakuSimilarityMaxCacheSize'] ?? 100).toInt().clamp(20, 1000).toInt(),
      ),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    hideDanmaku.v = parsed['hideDanmaku'];
    noEmojiMode.v = parsed['noEmojiMode'];
    danmakuTopArea.v = parsed['danmakuTopArea'];
    danmakuArea.v = parsed['danmakuArea'];
    danmakuBottomArea.v = parsed['danmakuBottomArea'];
    danmakuSpeed.v = parsed['danmakuSpeed'];
    danmakuFontSize.v = parsed['danmakuFontSize'];
    danmakuFontWeight.v = parsed['danmakuFontWeight'];
    danmakuFontBorder.v = parsed['danmakuFontBorder'];
    danmakuLetterSpacing.v = parsed['danmakuLetterSpacing'];
    danmakuMassMode.v = parsed['danmakuRealtimeMode'];
    danmakuOpacity.v = parsed['danmakuOpacity'];
    danmakuFontFamilyName.v = parsed['danmakuFontFamilyName'];
    enableDanmakuStroke.v = parsed['enableDanmakuStroke'];
    danmakuFps.v = parsed['danmakuFps'];
    danmakuAutoFps.v = parsed['danmakuAutoFps'];
    enableDanmakuTapInteraction.v = parsed['enableDanmakuTapInteraction'];
    enableDanmakuLongPressInteraction.v = parsed['enableDanmakuLongPressInteraction'];
    collapseRepeatedDanmaku.v = parsed['collapseRepeatedDanmaku'];
    repeatedDanmakuWindowSeconds.v = parsed['repeatedDanmakuWindowSeconds'];
    savedDanmakuTemplate.v = parsed['savedDanmakuTemplate'];
    pipDanmakuScaleAuto.v = parsed['pipDanmakuAutoScale'];
    pipDanmakuScaleValue.v = parsed['pipDanmakuScaleValue'];
    filterDouyuSuspectedAutomatedMessages.v = parsed['filterDouyuSuspectedAutomatedMessages'];
    enableDanmakuSimilarityFilter.v = parsed['enableDanmakuSimilarityFilter'];
    danmakuSimilarityThreshold.v = parsed['danmakuSimilarityThreshold'];
    danmakuSimilarityCacheDuration.v = parsed['danmakuSimilarityCacheDuration'];
    danmakuSimilarityMaxCacheSize.v = parsed['danmakuSimilarityMaxCacheSize'];
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final danmaku = rootConfig?['danmaku'] as Map<String, dynamic>? ?? {};
    return {
      'hideDanmaku': danmaku['hideDanmaku'] ?? false,
      'noEmojiMode': danmaku['noEmojiMode'] ?? defaultNoEmojiMode,
      'danmakuTopArea': _boundedDouble(danmaku['danmakuTopArea'], fallback: defaultDanmakuTopArea, min: 0, max: 300),
      'danmakuArea': _boundedDouble(danmaku['danmakuArea'], fallback: defaultDanmakuArea, min: 0, max: 1),
      'danmakuBottomArea': _boundedDouble(
        danmaku['danmakuBottomArea'],
        fallback: defaultDanmakuBottomArea,
        min: 0,
        max: 300,
      ),
      'danmakuSpeed': _boundedDouble(danmaku['danmakuSpeed'], fallback: defaultDanmakuSpeed, min: 20, max: 400),
      'danmakuFontSize': _boundedDouble(danmaku['danmakuFontSize'], fallback: defaultDanmakuFontSize, min: 10, max: 30),
      'danmakuFontWeight': normalizeFontWeight(danmaku['danmakuFontWeight']),
      'danmakuFontBorder': _boundedDouble(
        danmaku['danmakuFontBorder'],
        fallback: defaultDanmakuFontBorder,
        min: 0,
        max: 4,
      ),
      'danmakuOpacity': _boundedDouble(danmaku['danmakuOpacity'], fallback: defaultDanmakuOpacity, min: 0, max: 1),
      'danmakuFontFamilyName': danmaku['danmakuFontFamilyName'] ?? 'Default',
      'enableDanmakuStroke': danmaku['enableDanmakuStroke'] ?? true,
      'danmakuFps': _boundedInt(danmaku['danmakuFps'], fallback: defaultDanmakuFps, min: 30, max: 240),
      'danmakuAutoFps': danmaku['danmakuAutoFps'] ?? defaultDanmakuAutoFps,
      'enableDanmakuTapInteraction': danmaku['enableDanmakuTapInteraction'] ?? true,
      'enableDanmakuLongPressInteraction': danmaku['enableDanmakuLongPressInteraction'] ?? true,
      'collapseRepeatedDanmaku': danmaku['collapseRepeatedDanmaku'] ?? false,
      'repeatedDanmakuWindowSeconds': (danmaku['repeatedDanmakuWindowSeconds'] ?? 5).toInt().clamp(1, 30).toInt(),
      'savedDanmakuTemplate': danmaku['savedDanmakuTemplate']?.toString() ?? '',
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
      'pipDanmakuAutoFps': danmaku['pipDanmakuAutoFps'] ?? defaultPipDanmakuAutoFps,
      'filterDouyuSuspectedAutomatedMessages':
          danmaku['filterDouyuSuspectedAutomatedMessages'] ?? defaultFilterDouyuSuspectedAutomatedMessages,
      'enableDanmakuSimilarityFilter': danmaku['enableDanmakuSimilarityFilter'] ?? defaultEnableDanmakuSimilarityFilter,
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
